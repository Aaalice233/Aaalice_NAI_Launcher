import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../data/models/prompt_assistant/prompt_assistant_models.dart';

final promptAssistantConfigProvider =
    StateNotifierProvider<
      PromptAssistantConfigNotifier,
      PromptAssistantConfigState
    >((ref) => PromptAssistantConfigNotifier(ref));

class PromptAssistantConfigNotifier
    extends StateNotifier<PromptAssistantConfigState> {
  PromptAssistantConfigNotifier(this._ref)
    : super(PromptAssistantConfigState.defaults()) {
    _load();
  }

  final Ref _ref;

  LocalStorageService get _local => _ref.read(localStorageServiceProvider);
  SecureStorageService get _secure => _ref.read(secureStorageServiceProvider);

  Future<void> _load() async {
    final raw = _local.getSetting<String>(
      StorageKeys.promptAssistantConfigJson,
    );
    if (raw != null && raw.isNotEmpty) {
      try {
        state = PromptAssistantConfigState.decode(raw);
      } catch (_) {
        state = PromptAssistantConfigState.defaults();
      }
    }

    final keyMap = <String, bool>{};
    for (final provider in state.providers) {
      final key = await _secure.getPromptAssistantApiKey(provider.id);
      keyMap[provider.id] = key != null && key.isNotEmpty;
    }
    state = state.copyWith(providerHasApiKey: keyMap);
  }

  Future<void> _save() async {
    await _local.setSetting(
      StorageKeys.promptAssistantConfigJson,
      state.encode(),
    );
  }

  Future<String?> getProviderApiKey(String providerId) async {
    return _secure.getPromptAssistantApiKey(providerId);
  }

  /// 服务商已删除时忽略：页内编辑可能在删除之后才提交，不能留下孤立密钥。
  Future<void> setProviderApiKey(String providerId, String apiKey) async {
    if (!state.providers.any((provider) => provider.id == providerId)) return;
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _secure.deletePromptAssistantApiKey(providerId);
    } else {
      await _secure.savePromptAssistantApiKey(providerId, trimmed);
    }
    final next = Map<String, bool>.from(state.providerHasApiKey)
      ..[providerId] = trimmed.isNotEmpty;
    state = state.copyWith(providerHasApiKey: next);
  }

  Future<void> setResponseTimeoutSeconds(int seconds) async {
    if (!PromptAssistantConfigState.responseTimeoutChoices.contains(seconds)) {
      throw ArgumentError.value(
        seconds,
        'seconds',
        'Unsupported response timeout',
      );
    }
    state = state.copyWith(responseTimeoutSeconds: seconds);
    await _save();
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _save();
  }

  Future<void> setDesktopOverlayEnabled(bool value) async {
    state = state.copyWith(desktopOverlayEnabled: value);
    await _save();
  }

  Future<void> setAgentPermissionMode(AgentPermissionMode mode) async {
    state = state.copyWith(agentPermissionMode: mode);
    await _save();
  }

  Future<void> upsertProvider(ProviderConfig provider) async {
    final providers = [...state.providers];
    final idx = providers.indexWhere((p) => p.id == provider.id);
    if (idx >= 0) {
      providers[idx] = provider;
    } else {
      providers.add(provider);
    }
    state = state.copyWith(providers: providers);
    await _save();
  }

  /// 同 [setProviderApiKey]，服务商已删除时不能被延迟提交写回来。
  Future<void> setProviderBaseUrl(String providerId, String baseUrl) async {
    final index = state.providers.indexWhere((p) => p.id == providerId);
    if (index < 0) return;
    final trimmed = baseUrl.trim();
    final provider = state.providers[index];
    if (provider.baseUrl == trimmed) return;
    await upsertProvider(provider.copyWith(baseUrl: trimmed));
  }

  Future<void> deleteProvider(String providerId) async {
    final providers = state.providers.where((p) => p.id != providerId).toList();
    final models = state.models
        .where((m) => m.providerId != providerId)
        .toList();
    var routing = state.routing;
    for (final taskType in AssistantTaskType.values) {
      if (routing.providerIdFor(taskType) == providerId) {
        final fallback = _firstAvailableRoute(
          providers: providers,
          models: models,
          taskType: taskType,
        );
        routing = routing.copyWithTask(
          taskType: taskType,
          providerId: fallback.providerId,
          model: fallback.model,
        );
      }
    }
    final keys = Map<String, bool>.from(state.providerHasApiKey)
      ..remove(providerId);
    state = state.copyWith(
      providers: providers,
      models: models,
      routing: routing,
      providerHasApiKey: keys,
    );
    await _secure.deletePromptAssistantApiKey(providerId);
    await _save();
  }

  ({String providerId, String model}) _firstAvailableRoute({
    required List<ProviderConfig> providers,
    required List<ModelConfig> models,
    required AssistantTaskType taskType,
  }) {
    for (final provider in providers) {
      if (!provider.enabled) continue;
      final providerModels = models
          .where((m) => m.providerId == provider.id && m.forTask == taskType)
          .toList();
      final realModel = providerModels.cast<ModelConfig?>().firstWhere(
        (model) => model != null && !model.isPlaceholder,
        orElse: () => null,
      );
      if (realModel != null) {
        return (providerId: provider.id, model: realModel.name);
      }
      final presetModels = provider.preset?.defaultModelNames ?? const [];
      final presetModel = presetModels.isEmpty ? '' : presetModels.first;
      if (presetModel.isNotEmpty) {
        return (providerId: provider.id, model: presetModel);
      }
    }
    return (providerId: '', model: '');
  }

  Future<void> upsertModel(ModelConfig model) async {
    final models = [...state.models];
    final idx = models.indexWhere(
      (m) =>
          m.providerId == model.providerId &&
          m.name == model.name &&
          m.forTask == model.forTask,
    );
    if (idx >= 0) {
      models[idx] = model;
    } else {
      models.add(model);
    }
    state = state.copyWith(models: models);
    await _save();
  }

  /// 每个模型按全部任务各存一份，与 [PromptAssistantConfigState.decode] 的展开规则一致；
  /// 已有的模型跳过，加入真实模型后清掉占位模型。
  Future<void> addProviderModels(
    String providerId,
    Iterable<String> names, {
    required ModelSource source,
  }) async {
    final existing = {
      for (final model in state.models)
        if (model.providerId == providerId && !model.isPlaceholder) model.name,
    };
    final added = <String>[
      for (final raw in names)
        if (raw.trim().isNotEmpty && existing.add(raw.trim())) raw.trim(),
    ];
    if (added.isEmpty) return;

    final models = [
      for (final model in state.models)
        if (model.providerId != providerId || !model.isPlaceholder) model,
      for (final name in added)
        for (final task in AssistantTaskType.values)
          ModelConfig(
            providerId: providerId,
            name: name,
            displayName: name,
            forTask: task,
            source: source,
          ),
    ];
    state = state.copyWith(
      models: models,
      routing: _repointRoutes(providerId, models),
    );
    await _save();
  }

  /// 同时移除该模型在所有任务下的副本；指向它的任务路由改到同服务商剩余的模型。
  Future<void> removeProviderModels(
    String providerId,
    Iterable<String> names,
  ) async {
    final removed = names.toSet();
    final models = [
      for (final model in state.models)
        if (model.providerId != providerId || !removed.contains(model.name))
          model,
    ];
    if (models.length == state.models.length) return;
    state = state.copyWith(
      models: models,
      routing: _repointRoutes(providerId, models),
    );
    await _save();
  }

  /// [displayName] 留空或与模型 ID 相同时回到目录里的官方名。
  Future<void> renameProviderModel(
    String providerId,
    String name,
    String displayName,
  ) async {
    final trimmed = displayName.trim();
    final next = trimmed.isEmpty ? name : trimmed;
    bool matches(ModelConfig model) =>
        model.providerId == providerId && model.name == name;
    if (!state.models.any(
      (model) => matches(model) && model.displayName != next,
    )) {
      return;
    }
    state = state.copyWith(
      models: [
        for (final model in state.models)
          matches(model) ? model.copyWith(displayName: next) : model,
      ],
    );
    await _save();
  }

  TaskRoutingConfig _repointRoutes(
    String providerId,
    List<ModelConfig> models,
  ) {
    final next = state.copyWith(models: models);
    var routing = state.routing;
    for (final taskType in AssistantTaskType.values) {
      if (routing.providerIdFor(taskType) != providerId) continue;
      final candidates = next.modelsForProviderTask(
        providerId: providerId,
        taskType: taskType,
      );
      if (candidates.any((model) => model.name == routing.modelFor(taskType))) {
        continue;
      }
      final fallback = candidates.isNotEmpty
          ? (providerId: providerId, model: candidates.first.name)
          : _firstAvailableRoute(
              providers: state.providers,
              models: models,
              taskType: taskType,
            );
      routing = routing.copyWithTask(
        taskType: taskType,
        providerId: fallback.providerId,
        model: fallback.model,
      );
    }
    return routing;
  }

  Future<void> setRouting(TaskRoutingConfig routing) async {
    state = state.copyWith(routing: routing);
    await _save();
  }

  Future<void> upsertRule(PromptRuleTemplate rule) async {
    final rules = [...state.rules];
    final idx = rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      rules[idx] = rule;
    } else {
      rules.add(rule);
    }
    state = state.copyWith(rules: rules);
    await _save();
  }

  Future<void> removeRule(String ruleId) async {
    final matchingRules = state.rules.where((r) => r.id == ruleId);
    if (matchingRules.isNotEmpty && matchingRules.first.isDefault) {
      return;
    }
    state = state.copyWith(
      rules: state.rules.where((r) => r.id != ruleId).toList(),
    );
    await _save();
  }

  Future<void> reorderRules(List<String> orderedIds) async {
    final orderMap = <String, int>{
      for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
    };
    final updated =
        state.rules
            .map((r) => r.copyWith(order: orderMap[r.id] ?? r.order))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    state = state.copyWith(rules: updated);
    await _save();
  }
}
