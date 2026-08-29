import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/model_capabilities.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/prompt/default_presets.dart';
import '../../data/models/prompt/prompt_config.dart';
import '../../data/models/prompt/random_preset.dart';
import '../../data/models/prompt/random_prompt_result.dart';
import '../../data/services/official_random_prompt_generator.dart';
import '../../data/services/random_prompt_legacy_adapter.dart';
import '../../data/services/random_prompt_generator.dart';
import '../../data/services/wordlist_service.dart';
import 'random_mode_provider.dart';
import 'random_preset_provider.dart';

part 'prompt_config_provider.g.dart';

class UnsupportedRandomPromptModelException implements Exception {
  const UnsupportedRandomPromptModelException(this.model);

  static const errorCode = 'GENERATION_ERROR_UNSUPPORTED_RANDOM_MODEL';

  final String model;

  String get encodedMessage => '$errorCode|$model';

  @override
  String toString() => encodedMessage;
}

/// 随机提示词配置状态
class PromptConfigState {
  final List<RandomPromptPreset> presets;
  final String? selectedPresetId;
  final bool isLoading;
  final String? error;

  const PromptConfigState({
    this.presets = const [],
    this.selectedPresetId,
    this.isLoading = false,
    this.error,
  });

  RandomPromptPreset? get selectedPreset {
    if (selectedPresetId == null) return null;
    return presets.firstWhere(
      (p) => p.id == selectedPresetId,
      orElse: () => presets.isNotEmpty
          ? presets.first
          : DefaultPresets.createDefaultPreset(),
    );
  }

  PromptConfigState copyWith({
    List<RandomPromptPreset>? presets,
    String? selectedPresetId,
    bool? isLoading,
    String? error,
  }) {
    return PromptConfigState(
      presets: presets ?? this.presets,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 随机提示词配置管理器
@Riverpod(keepAlive: true)
class PromptConfigNotifier extends _$PromptConfigNotifier {
  static const String _boxName = 'prompt_configs';
  static const String _presetsKey = 'presets';
  static const String _selectedKey = 'selected_preset_id';

  Box? _box;
  Completer<void>? _loadCompleter;

  @override
  PromptConfigState build() {
    // 只在首次构建时创建 Completer 并加载
    _loadCompleter ??= Completer<void>();
    if (!_loadCompleter!.isCompleted) {
      _loadPresets();
    }
    return const PromptConfigState(isLoading: true);
  }

  /// 获取加载完成的 Future
  Future<void> get whenLoaded => _loadCompleter?.future ?? Future.value();

  /// 加载预设
  Future<void> _loadPresets() async {
    try {
      _box = await Hive.openBox(_boxName);

      final presetsJson = _box?.get(_presetsKey) as String?;
      final selectedId = _box?.get(_selectedKey) as String?;

      List<RandomPromptPreset> presets;
      if (presetsJson != null) {
        final List<dynamic> decoded = jsonDecode(presetsJson);
        presets = decoded
            .map((e) => RandomPromptPreset.fromJson(e as Map<String, dynamic>))
            .where((p) => !p.isDefault) // 过滤掉默认预设
            .toList();
      } else {
        // 首次使用不再自动创建额外预设，直接使用内置离线随机模式。
        presets = [];
      }

      state = PromptConfigState(
        presets: presets,
        selectedPresetId: selectedId ?? presets.firstOrNull?.id,
        isLoading: false,
      );
      _loadCompleter?.complete();
    } catch (e) {
      state = PromptConfigState(
        presets: [],
        isLoading: false,
        error: e.toString(),
      );
      _loadCompleter?.completeError(e);
    }
  }

  /// 保存预设到本地
  Future<void> _savePresets(List<RandomPromptPreset> presets) async {
    final json = jsonEncode(presets.map((e) => e.toJson()).toList());
    await _box?.put(_presetsKey, json);
  }

  /// 统一随机提示词生成入口
  ///
  /// 根据当前模式（默认/自定义/混合）生成随机提示词。
  ///
  /// [model] 必须来自当前生成参数。每次随机化都重新解析模型，确保切换
  /// 模型后不会沿用上一次的官网 recipe。无法识别的模型只允许使用不依赖
  /// 官网词库的自定义模式，避免静默套用不兼容的官方标签。
  Future<RandomPromptResult> generateRandomPrompt({
    required String model,
    int? seed,
  }) async {
    final mode = ref.read(randomModeNotifierProvider);
    final capabilities = ModelCapabilityRegistry.tryOf(model);
    if (capabilities == null && mode != RandomGenerationMode.custom) {
      throw UnsupportedRandomPromptModelException(model);
    }
    final modelProfile = capabilities?.randomPromptProfile;
    if (mode != RandomGenerationMode.naiOfficial) {
      final presetNotifier = ref.read(randomPresetNotifierProvider.notifier);
      await presetNotifier.whenLoaded;

      final presetState = ref.read(randomPresetNotifierProvider);
      if (presetState.error != null) {
        AppLogger.w(
          'random preset state failed to load: ${presetState.error}',
          'RandomGen',
        );
        throw StateError(presetState.error!);
      }
    }

    return switch (mode) {
      RandomGenerationMode.naiOfficial => _generateOfficialPrompt(
        seed: seed,
        modelProfile: modelProfile!,
      ),
      RandomGenerationMode.custom => _generateCustomPresetPrompt(seed: seed),
      RandomGenerationMode.hybrid => _generateHybridPrompt(
        seed: seed,
        modelProfile: modelProfile!,
      ),
    };
  }

  /// 官网模式生成
  Future<RandomPromptResult> _generateOfficialPrompt({
    int? seed,
    required RandomPromptProfile modelProfile,
  }) async {
    final generator = OfficialRandomPromptGenerator(
      ref.read(wordlistServiceProvider),
    );
    final result = await generator.generate(profile: modelProfile, seed: seed);
    AppLogger.d(
      'official ${modelProfile.name} result: '
          '${result.characterCount} characters',
      'RandomGen',
    );
    return result;
  }

  /// 自定义模式生成
  Future<RandomPromptResult> _generateCustomPresetPrompt({int? seed}) async {
    final generator = ref.read(randomPromptGeneratorProvider);
    final preset =
        _selectedCustomRandomPreset() ??
        ref.read(randomPresetNotifierProvider).defaultPreset;

    if (preset.categories.isEmpty) {
      return RandomPromptResult(
        mainPrompt: '',
        mode: RandomGenerationMode.custom,
        seed: seed,
      );
    }

    return generator.generateFromPreset(
      preset: preset,
      seed: seed,
      mode: RandomGenerationMode.custom,
    );
  }

  /// 混合模式先执行官网 recipe，再以 catalog preset 补充同一提示词结构。
  Future<RandomPromptResult> _generateHybridPrompt({
    int? seed,
    required RandomPromptProfile modelProfile,
  }) async {
    final official = await _generateOfficialPrompt(
      seed: seed,
      modelProfile: modelProfile,
    );
    final generator = ref.read(randomPromptGeneratorProvider);
    final presetState = ref.read(randomPresetNotifierProvider);
    final extensionPreset =
        _selectedCustomRandomPreset() ?? presetState.defaultPreset;
    final extension = await generator.generateFromPreset(
      preset: extensionPreset,
      isV4Model: modelProfile.supportsCharacterPrompts,
      seed: seed == null ? null : seed ^ 0x5f3759df,
      mode: RandomGenerationMode.hybrid,
    );
    return _mergeHybridResults(official, extension, seed: seed);
  }

  RandomPromptResult _mergeHybridResults(
    RandomPromptResult official,
    RandomPromptResult extension, {
    required int? seed,
  }) {
    final mainPrompt = _mergePromptTags(
      official.mainPrompt,
      _withoutStructureTags(extension.mainPrompt),
    );
    final characters = <GeneratedCharacter>[];
    for (var index = 0; index < official.characters.length; index++) {
      final officialCharacter = official.characters[index];
      final extensionPrompt = index < extension.characters.length
          ? _withoutRoleTag(extension.characters[index].prompt)
          : '';
      characters.add(
        officialCharacter.copyWith(
          prompt: _mergePromptTags(officialCharacter.prompt, extensionPrompt),
        ),
      );
    }
    return RandomPromptResult(
      mainPrompt: mainPrompt,
      characters: characters,
      noHumans: official.noHumans,
      seed: seed,
      mode: RandomGenerationMode.hybrid,
    );
  }

  String _withoutStructureTags(String prompt) {
    final countPattern = RegExp(r'^\d+(?:girl|girls|boy|boys|other|others)$');
    const structural = {
      'no humans',
      'zero pictured',
      'solo',
      'duo',
      'trio',
      'female',
      'male',
      'ambiguous gender',
    };
    return prompt
        .split(', ')
        .where(
          (tag) => !structural.contains(tag) && !countPattern.hasMatch(tag),
        )
        .join(', ');
  }

  String _withoutRoleTag(String prompt) => prompt
      .split(', ')
      .where((tag) => tag != 'girl' && tag != 'boy' && tag != 'other')
      .join(', ');

  String _mergePromptTags(String primary, String extension) {
    final seen = <String>{};
    return [primary, extension]
        .expand((prompt) => prompt.split(', '))
        .where((tag) => tag.isNotEmpty && seen.add(tag))
        .join(', ');
  }

  RandomPreset? _selectedCustomRandomPreset() {
    final presetState = ref.read(randomPresetNotifierProvider);
    final selectedPreset = presetState.selectedPreset;
    if (selectedPreset != null && !selectedPreset.isDefault) {
      return selectedPreset;
    }

    final legacyPreset = state.selectedPreset;
    if (legacyPreset != null && legacyPreset.configs.isNotEmpty) {
      return RandomPromptLegacyAdapter.fromPreset(legacyPreset);
    }

    return null;
  }

  /// 选择预设
  Future<void> selectPreset(String presetId) async {
    await _box?.put(_selectedKey, presetId);
    state = state.copyWith(selectedPresetId: presetId);
  }

  /// 添加预设
  Future<void> addPreset(RandomPromptPreset preset) async {
    final newPresets = [...state.presets, preset];
    await _savePresets(newPresets);
    state = state.copyWith(presets: newPresets);
  }

  /// 更新预设
  Future<void> updatePreset(RandomPromptPreset preset) async {
    final newPresets = state.presets.map((p) {
      if (p.id == preset.id) {
        return preset.copyWith(updatedAt: DateTime.now());
      }
      return p;
    }).toList();
    await _savePresets(newPresets);
    state = state.copyWith(presets: newPresets);
  }

  /// 删除预设
  Future<void> deletePreset(String presetId) async {
    final newPresets = state.presets.where((p) => p.id != presetId).toList();
    await _savePresets(newPresets);

    // 如果删除的是当前选中的预设，切换到第一个
    String? newSelectedId = state.selectedPresetId;
    if (newSelectedId == presetId) {
      newSelectedId = newPresets.firstOrNull?.id;
      await _box?.put(_selectedKey, newSelectedId);
    }

    state = state.copyWith(
      presets: newPresets,
      selectedPresetId: newSelectedId,
    );
  }

  /// 复制预设
  Future<void> duplicatePreset(String presetId) async {
    final source = state.presets.where((p) => p.id == presetId).firstOrNull;
    if (source == null) return;

    final copy = RandomPromptPreset.create(
      name: '${source.name} (副本)',
      configs: source.configs,
    );
    await addPreset(copy);
  }

  /// 移动预设位置
  ///
  /// [direction] 为正数表示向下移动，负数表示向上移动
  Future<void> movePreset(String presetId, int direction) async {
    final currentIndex = state.presets.indexWhere((p) => p.id == presetId);
    if (currentIndex == -1) return;

    final newIndex = currentIndex + direction;
    if (newIndex < 0 || newIndex >= state.presets.length) return;

    final newPresets = List<RandomPromptPreset>.from(state.presets);
    final preset = newPresets.removeAt(currentIndex);
    newPresets.insert(newIndex, preset);

    await _savePresets(newPresets);
    state = state.copyWith(presets: newPresets);
  }

  /// 导出预设为 JSON
  String exportPreset(String presetId) {
    final preset = state.presets.where((p) => p.id == presetId).firstOrNull;
    if (preset == null) return '{}';
    return jsonEncode(preset.toJson());
  }

  /// 导入预设
  Future<void> importPreset(String json) async {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final preset = RandomPromptPreset.fromJson(decoded);
    // 生成新的 ID 避免冲突
    final newPreset = RandomPromptPreset.create(
      name: preset.name,
      configs: preset.configs,
    );
    await addPreset(newPreset);
  }

  /// 重置预设为默认配置
  Future<void> resetPreset(String presetId) async {
    final index = state.presets.indexWhere((p) => p.id == presetId);
    if (index == -1) return;

    final original = state.presets[index];
    final defaultPreset = DefaultPresets.createDefaultPreset();
    final resetPreset = original.copyWith(
      configs: defaultPreset.configs,
      updatedAt: DateTime.now(),
    );

    final newPresets = [...state.presets];
    newPresets[index] = resetPreset;
    await _savePresets(newPresets);
    state = state.copyWith(presets: newPresets);
  }
}
