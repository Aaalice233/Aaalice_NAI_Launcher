import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../prompt_assistant/services/prompt_assistant_service.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../widgets/settings_card.dart';

class PromptAssistantSettingsSection extends ConsumerWidget {
  const PromptAssistantSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(promptAssistantConfigProvider);
    final notifier = ref.read(promptAssistantConfigProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: context.l10n.settings_integrationConnectionSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                value: state.enabled,
                title: Text(context.l10n.promptAssistant_enableAssistant),
                subtitle: Text(
                  context.l10n.promptAssistant_settingsInputSwitchSubtitle,
                ),
                onChanged: notifier.setEnabled,
              ),
              if (PlatformCapabilities
                  .current
                  .supportsDesktopOverlayInteractions)
                SwitchListTile(
                  value: state.desktopOverlayEnabled,
                  title: Text(context.l10n.promptAssistant_desktopOverlayTitle),
                  subtitle: Text(
                    context.l10n.promptAssistant_desktopOverlaySubtitle,
                  ),
                  onChanged: notifier.setDesktopOverlayEnabled,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: context.l10n.promptAssistant_taskRouting,
          description: context.l10n.promptAssistant_taskRoutingSubtitle,
          child: _buildRouting(context, state, notifier),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: context.l10n.promptAssistant_providerManagement,
          description: context.l10n.promptAssistant_providerManagementSubtitle,
          child: _buildProviders(context, ref, state, notifier),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: context.l10n.promptAssistant_ruleTemplates,
          description: context.l10n.promptAssistant_ruleTemplatesSubtitle,
          child: _buildRules(context, state, notifier),
        ),
      ],
    );
  }

  Widget _buildRouting(
    BuildContext context,
    PromptAssistantConfigState state,
    PromptAssistantConfigNotifier notifier,
  ) {
    final providerItems = state.providers
        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth > 860;
            final cards = AssistantTaskType.values
                .where((taskType) => taskType != AssistantTaskType.chat)
                .map(
                  (taskType) => _buildTaskRouteCardForTask(
                    context: context,
                    state: state,
                    notifier: notifier,
                    taskType: taskType,
                    providerItems: providerItems,
                  ),
                )
                .toList();

            if (twoCols) {
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  cards[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTaskRouteCardForTask({
    required BuildContext context,
    required PromptAssistantConfigState state,
    required PromptAssistantConfigNotifier notifier,
    required AssistantTaskType taskType,
    required List<DropdownMenuItem<String>> providerItems,
  }) {
    final providerId = state.routing.providerIdFor(taskType);
    final modelName = state.routing.modelFor(taskType);
    final models = state.modelsForProviderTask(
      providerId: providerId,
      taskType: taskType,
    );
    final modelItems = models
        .map((m) => DropdownMenuItem(value: m.name, child: Text(m.displayName)))
        .toList();
    final hasRealModel = models.any(
      (m) => m.name.trim().isNotEmpty && m.name.trim() != 'default-model',
    );
    final useCurrentModel =
        models.any((m) => m.name == modelName) &&
        !(modelName.trim() == 'default-model' && hasRealModel);
    final modelValue = useCurrentModel
        ? modelName
        : models.isNotEmpty
        ? models.first.name
        : null;

    return _buildTaskRouteCard(
      context: context,
      title: _assistantTaskLabel(context, taskType),
      providerValue: providerItems.any((item) => item.value == providerId)
          ? providerId
          : null,
      providerItems: providerItems,
      onProviderChanged: (value) {
        if (value == null) return;
        final providerModels = state.modelsForProviderTask(
          providerId: value,
          taskType: taskType,
        );
        final firstModel = providerModels.isNotEmpty
            ? providerModels.first
            : ModelConfig(
                providerId: value,
                name: 'default-model',
                displayName: 'default-model',
                forTask: taskType,
              );
        unawaited(notifier.upsertModel(firstModel.copyWith(forTask: taskType)));
        notifier.setRouting(
          state.routing.copyWithTask(
            taskType: taskType,
            providerId: value,
            model: firstModel.name,
          ),
        );
      },
      modelValue: modelValue,
      modelItems: modelItems,
      onModelChanged: modelItems.isEmpty
          ? null
          : (value) {
              if (value == null) return;
              final selectedModel = models.firstWhere(
                (model) => model.name == value,
              );
              unawaited(notifier.upsertModel(selectedModel));
              notifier.setRouting(
                state.routing.copyWithTask(
                  taskType: taskType,
                  providerId: providerId,
                  model: value,
                ),
              );
            },
    );
  }

  Widget _buildTaskRouteCard({
    required BuildContext context,
    required String title,
    required String? providerValue,
    required List<DropdownMenuItem<String>> providerItems,
    required ValueChanged<String?> onProviderChanged,
    required String? modelValue,
    required List<DropdownMenuItem<String>> modelItems,
    required ValueChanged<String?>? onModelChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.promptAssistant_taskRouteTitle(title),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: providerValue,
            isExpanded: true,
            items: providerItems,
            onChanged: onProviderChanged,
            decoration: InputDecoration(
              labelText: context.l10n.promptAssistant_provider,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: modelValue,
            isExpanded: true,
            hint: Text(context.l10n.promptAssistant_noModelsPullFirst),
            items: modelItems,
            onChanged: onModelChanged,
            decoration: InputDecoration(
              labelText: context.l10n.promptAssistant_model,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviders(
    BuildContext context,
    WidgetRef ref,
    PromptAssistantConfigState state,
    PromptAssistantConfigNotifier notifier,
  ) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const ValueKey('prompt-assistant-add-provider'),
            onPressed: () => _showProviderDialog(context, notifier, state),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.promptAssistant_addProvider),
          ),
        ),
        const SizedBox(height: 8),
        ...state.providers.map((provider) {
          final hasApiKey = state.providerHasApiKey[provider.id] ?? false;

          Widget buildDetails() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${provider.protocol.label}  ${provider.baseUrl}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    hasApiKey
                        ? context.l10n.promptAssistant_apiKeyConfigured
                        : context.l10n.promptAssistant_apiKeyNotConfigured,
                    provider.allowImageInput
                        ? context.l10n.promptAssistant_supportsImageInput
                        : context.l10n.promptAssistant_textOnly,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }

          Widget buildActions() {
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showConnectionDialog(
                    context,
                    notifier,
                    provider: provider,
                  ),
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(context.l10n.promptAssistant_connectionConfig),
                ),
                Icon(hasApiKey ? Icons.key : Icons.key_off, size: 18),
                IconButton(
                  icon: const Icon(Icons.download_for_offline_outlined),
                  tooltip: context.l10n.promptAssistant_pullModelList,
                  onPressed: () =>
                      _pullProviderModels(context, ref, notifier, provider.id),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: context.l10n.promptAssistant_editProvider,
                  onPressed: () => _showProviderDialog(
                    context,
                    notifier,
                    state,
                    provider: provider,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.promptAssistant_deleteProvider,
                  onPressed: () async {
                    final confirmed = await ThemedConfirmDialog.showDelete(
                      context: context,
                      itemName: provider.name,
                    );
                    if (!confirmed || !context.mounted) return;
                    await notifier.deleteProvider(provider.id);
                  },
                ),
              ],
            );
          }

          return Container(
            key: ValueKey('prompt-assistant-provider-${provider.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useStackedLayout = constraints.maxWidth < 720;
                final toggle = Switch(
                  value: provider.enabled,
                  onChanged: (value) {
                    notifier.upsertProvider(provider.copyWith(enabled: value));
                  },
                );

                if (useStackedLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          toggle,
                          const SizedBox(width: 8),
                          Expanded(child: buildDetails()),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: buildActions(),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    toggle,
                    const SizedBox(width: 8),
                    Expanded(child: buildDetails()),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: buildActions(),
                    ),
                  ],
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Future<void> _pullProviderModels(
    BuildContext context,
    WidgetRef ref,
    PromptAssistantConfigNotifier notifier,
    String providerId,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.promptAssistant_pullingModels)),
    );

    try {
      final service = ref.read(promptAssistantServiceProvider);
      final modelNames = await service.fetchAvailableModels(providerId);
      if (modelNames.isEmpty) {
        throw StateError(l10n.promptAssistant_emptyModelList);
      }

      // 以接口返回的最新列表为准同步：新增缺失模型、清理已弃用的 API 模型、
      // 保留手动/默认模型，并在需要时迁移受影响的任务路由。
      await notifier.syncProviderModels(providerId, modelNames);

      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.promptAssistant_modelsSynced(modelNames.length)),
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.promptAssistant_pullModelsFailed('$e'))),
      );
    }
  }

  Widget _buildRules(
    BuildContext context,
    PromptAssistantConfigState state,
    PromptAssistantConfigNotifier notifier,
  ) {
    final rules =
        state.rules
            .where((rule) => rule.taskType != AssistantTaskType.chat)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return Column(
      children: [
        ...rules.map(
          (rule) => ListTile(
            title: Text(_displayRuleName(context, rule)),
            subtitle: Text(
              _displayRuleContent(context, rule),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            leading: Switch(
              value: rule.enabled,
              onChanged: (value) {
                notifier.upsertRule(rule.copyWith(enabled: value));
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showRuleDialog(context, notifier, rule: rule),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _showRuleDialog(context, notifier),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.promptAssistant_addRule),
          ),
        ),
      ],
    );
  }

  Future<void> _showProviderDialog(
    BuildContext context,
    PromptAssistantConfigNotifier notifier,
    PromptAssistantConfigState state, {
    ProviderConfig? provider,
  }) async {
    final nameController = TextEditingController(text: provider?.name ?? '');
    final baseController = TextEditingController(text: provider?.baseUrl ?? '');
    final keyController = TextEditingController();
    var preset =
        provider?.preset ??
        (provider == null
            ? ProviderPreset.openaiChat
            : provider.protocol == ProviderProtocol.openaiResponses
            ? ProviderPreset.openaiCompatibleResponses
            : ProviderPreset.openaiCompatibleChat);
    var allowImageInput =
        provider?.allowImageInput ?? preset.defaultAllowImageInput;

    void applyProtocol(ProviderPreset value) {
      final previousPreset = preset;
      final currentName = nameController.text.trim();
      final currentBaseUrl = baseController.text.trim();
      preset = value;
      allowImageInput = value.defaultAllowImageInput;
      if (provider == null) {
        nameController.text = value.defaultName;
        baseController.text = value.defaultBaseUrl;
        return;
      }
      if (currentName.isEmpty || currentName == previousPreset.defaultName) {
        nameController.text = value.defaultName;
      }
      if (currentBaseUrl.isEmpty ||
          currentBaseUrl == previousPreset.defaultBaseUrl) {
        baseController.text = value.defaultBaseUrl;
      }
    }

    if (provider == null) {
      applyProtocol(preset);
    }

    final confirmed = await AdaptivePresenter.showForm<bool>(
      context: context,
      sideSheetWidth: 520,
      title: provider == null
          ? context.l10n.promptAssistant_addProvider
          : context.l10n.promptAssistant_editProviderTitle,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (context, setState) => Column(
          key: const ValueKey('prompt-assistant-provider-dialog'),
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.promptAssistant_name,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProviderPreset>(
                    initialValue: preset,
                    isExpanded: true,
                    items: ProviderPreset.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => applyProtocol(value));
                      }
                    },
                    decoration: InputDecoration(
                      labelText: context.l10n.promptAssistant_protocol,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: baseController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'Base URL'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: allowImageInput,
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.promptAssistant_allowImageInput),
                    subtitle: Text(
                      context.l10n.promptAssistant_allowImageInputSubtitle,
                    ),
                    onChanged: (value) {
                      setState(() => allowImageInput = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: keyController,
                    decoration: InputDecoration(
                      labelText: context.l10n.promptAssistant_apiKeyLeaveEmpty,
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.common_cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.common_save),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final enteredName = nameController.text.trim();
    final enteredBaseUrl = baseController.text.trim();
    final enteredApiKey = keyController.text;
    nameController.dispose();
    baseController.dispose();
    keyController.dispose();
    if (confirmed != true) return;

    final resolvedName = enteredName.isEmpty ? preset.defaultName : enteredName;
    final resolvedId =
        provider?.id ??
        _uniqueProviderId(
          state,
          _providerIdFromName(resolvedName, fallback: preset.defaultId),
        );
    final next = ProviderConfig(
      id: resolvedId,
      name: resolvedName,
      type: preset.legacyType,
      protocol: preset.defaultProtocol,
      preset: preset,
      baseUrl: enteredBaseUrl,
      enabled: provider?.enabled ?? true,
      allowImageInput: allowImageInput,
    );

    await notifier.upsertProvider(next);

    if (enteredApiKey.trim().isNotEmpty) {
      await notifier.setProviderApiKey(resolvedId, enteredApiKey);
    }

    for (final taskType in AssistantTaskType.values) {
      final hasModel = state.models.any(
        (m) => m.providerId == resolvedId && m.forTask == taskType,
      );
      if (!hasModel) {
        final defaultModels = next.preset?.defaultModelNames ?? const [];
        final modelName = defaultModels.isNotEmpty
            ? defaultModels.first
            : 'default-model';
        await notifier.upsertModel(
          ModelConfig(
            providerId: resolvedId,
            name: modelName,
            displayName: modelName,
            forTask: taskType,
            isDefault: true,
          ),
        );
      }
    }
  }

  String _uniqueProviderId(PromptAssistantConfigState state, String baseId) {
    if (!state.providers.any((provider) => provider.id == baseId)) {
      return baseId;
    }
    var index = 2;
    while (state.providers.any(
      (provider) => provider.id == '${baseId}_$index',
    )) {
      index++;
    }
    return '${baseId}_$index';
  }

  String _providerIdFromName(String name, {required String fallback}) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? fallback : normalized;
  }

  Future<void> _showConnectionDialog(
    BuildContext context,
    PromptAssistantConfigNotifier notifier, {
    required ProviderConfig provider,
  }) async {
    final baseController = TextEditingController(text: provider.baseUrl);
    final keyController = TextEditingController();
    var clearApiKey = false;
    var allowImageInput = provider.allowImageInput;

    final confirmed = await AdaptivePresenter.showForm<bool>(
      context: context,
      sideSheetWidth: 520,
      title: context.l10n.promptAssistant_connectionTitle(provider.name),
      builder: (context, scrollController) => StatefulBuilder(
        builder: (context, setState) => Column(
          key: const ValueKey('prompt-assistant-connection-dialog'),
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: baseController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Base URL',
                      hintText: context.l10n.promptAssistant_baseUrlHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyController,
                    decoration: InputDecoration(
                      labelText: context.l10n.promptAssistant_apiKeyLeaveEmpty,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: clearApiKey,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.l10n.promptAssistant_clearCurrentApiKey,
                    ),
                    onChanged: (value) {
                      setState(() => clearApiKey = value ?? false);
                    },
                  ),
                  SwitchListTile(
                    value: allowImageInput,
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.promptAssistant_allowImageInput),
                    subtitle: Text(
                      provider.protocol.supportsImagePayload
                          ? context
                                .l10n
                                .promptAssistant_protocolSupportsImagePayload
                          : context
                                .l10n
                                .promptAssistant_protocolTextOnlyWarning,
                    ),
                    onChanged: (value) {
                      setState(() => allowImageInput = value);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.common_cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.common_save),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final enteredBaseUrl = baseController.text.trim();
    final enteredApiKey = keyController.text;
    baseController.dispose();
    keyController.dispose();
    if (confirmed != true) return;

    await notifier.upsertProvider(
      provider.copyWith(
        baseUrl: enteredBaseUrl,
        allowImageInput: allowImageInput,
      ),
    );

    if (clearApiKey) {
      await notifier.setProviderApiKey(provider.id, '');
      return;
    }

    if (enteredApiKey.trim().isNotEmpty) {
      await notifier.setProviderApiKey(provider.id, enteredApiKey);
    }
  }

  Future<void> _showRuleDialog(
    BuildContext context,
    PromptAssistantConfigNotifier notifier, {
    PromptRuleTemplate? rule,
  }) async {
    final nameController = TextEditingController(text: rule?.name ?? '');
    final contentController = TextEditingController(text: rule?.content ?? '');
    final newRuleName = context.l10n.promptAssistant_newRule;
    var taskType = rule?.taskType ?? AssistantTaskType.llm;

    final confirmed = await AdaptivePresenter.showForm<bool>(
      context: context,
      sideSheetWidth: 560,
      title: rule == null
          ? context.l10n.promptAssistant_addRuleTitle
          : context.l10n.promptAssistant_editRuleTitle,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (context, setState) => Column(
          key: const ValueKey('prompt-assistant-rule-dialog'),
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.promptAssistant_name,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AssistantTaskType>(
                    initialValue: taskType,
                    isExpanded: true,
                    items: AssistantTaskType.values
                        .where((value) => value != AssistantTaskType.chat)
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              _assistantTaskLabel(context, value),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => taskType = value);
                    },
                    decoration: InputDecoration(
                      labelText: context.l10n.promptAssistant_taskType,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    minLines: 4,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: context.l10n.promptAssistant_ruleContent,
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (rule != null && !rule.isDefault)
                        TextButton(
                          onPressed: () async {
                            final confirmed =
                                await ThemedConfirmDialog.showDelete(
                                  context: context,
                                  itemName: _displayRuleName(context, rule),
                                );
                            if (!confirmed || !context.mounted) return;
                            await notifier.removeRule(rule.id);
                            if (context.mounted) {
                              Navigator.pop(context, false);
                            }
                          },
                          child: Text(context.l10n.common_delete),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.common_cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.common_save),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final enteredName = nameController.text.trim();
    final enteredContent = contentController.text.trim();
    nameController.dispose();
    contentController.dispose();
    if (confirmed != true) return;

    final next = PromptRuleTemplate(
      id: rule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
      name: enteredName.isEmpty ? newRuleName : enteredName,
      taskType: taskType,
      content: enteredContent,
      enabled: rule?.enabled ?? true,
      isDefault: rule?.isDefault ?? false,
      order: rule?.order ?? 100,
    );

    await notifier.upsertRule(next);
  }

  String _assistantTaskLabel(BuildContext context, AssistantTaskType taskType) {
    switch (taskType) {
      case AssistantTaskType.llm:
        return context.l10n.promptAssistant_taskOptimize;
      case AssistantTaskType.translate:
        return context.l10n.promptAssistant_taskTranslate;
      case AssistantTaskType.reverse:
        return context.l10n.promptAssistant_taskReverse;
      case AssistantTaskType.characterReplace:
        return context.l10n.promptAssistant_taskCharacterReplace;
      case AssistantTaskType.custom:
        return context.l10n.promptAssistant_taskCustom;
      case AssistantTaskType.chat:
        return context.l10n.agentChat_tab;
    }
  }

  String _displayRuleName(BuildContext context, PromptRuleTemplate rule) {
    if (!rule.isDefault) return rule.name;
    final l10n = context.l10n;
    return switch (rule.id) {
      'opt_default' => l10n.promptAssistant_defaultOptimizeRuleName,
      'translate_default' => l10n.promptAssistant_defaultTranslateRuleName,
      'reverse_default' => l10n.promptAssistant_defaultReverseRuleName,
      'character_replace_default' =>
        l10n.promptAssistant_defaultCharacterReplaceRuleName,
      'custom_default' => l10n.promptAssistant_defaultCustomRuleName,
      _ => rule.name,
    };
  }

  String _displayRuleContent(BuildContext context, PromptRuleTemplate rule) {
    if (!rule.isDefault || !_usesBuiltinDefaultContent(rule)) {
      return rule.content;
    }
    final l10n = context.l10n;
    return switch (rule.id) {
      'opt_default' => l10n.promptAssistant_defaultOptimizeRuleContent,
      'translate_default' => l10n.promptAssistant_defaultTranslateRuleContent,
      'reverse_default' => l10n.promptAssistant_defaultReverseRuleContent,
      'character_replace_default' =>
        l10n.promptAssistant_defaultCharacterReplaceRuleContent,
      'custom_default' => l10n.promptAssistant_defaultCustomRuleContent,
      _ => rule.content,
    };
  }

  bool _usesBuiltinDefaultContent(PromptRuleTemplate rule) {
    PromptRuleTemplate? defaultRule;
    for (final candidate in PromptAssistantConfigState.defaults().rules) {
      if (candidate.id == rule.id) {
        defaultRule = candidate;
        break;
      }
    }
    if (defaultRule == null) return false;
    return rule.content.trim() == defaultRule.content.trim();
  }
}
