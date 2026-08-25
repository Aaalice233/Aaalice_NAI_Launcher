import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/prompt/default_presets.dart';
import '../../data/models/prompt/prompt_config.dart';
import '../../data/models/prompt/random_preset.dart';
import '../../data/models/prompt/random_prompt_result.dart';
import '../../data/services/random_preset_merger.dart';
import '../../data/services/random_prompt_legacy_adapter.dart';
import '../../data/services/random_prompt_generator.dart';
import 'random_mode_provider.dart';
import 'random_preset_provider.dart';
import 'tag_library_provider.dart';

part 'prompt_config_provider.g.dart';

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

  /// 生成随机提示词
  String generatePrompt({int? seed}) {
    // 如果预设还没加载完成，使用默认预设
    if (state.presets.isEmpty || state.isLoading) {
      return DefaultPresets.createDefaultPreset().generate(seed: seed);
    }

    final preset = state.selectedPreset;
    if (preset == null) {
      return state.presets.first.generate(seed: seed);
    }

    return preset.generate(seed: seed);
  }

  /// 统一随机提示词生成入口
  ///
  /// 根据当前模式（官网/自定义/混合）生成随机提示词
  /// [seed] 随机种子（可选）
  /// [isV4Model] 是否为 V4+ 模型（可选，默认 true）
  Future<RandomPromptResult> generateRandomPrompt({
    int? seed,
    bool isV4Model = true,
  }) async {
    final mode = ref.read(randomModeNotifierProvider);
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

    return switch (mode) {
      RandomGenerationMode.naiOfficial => _generateOfficialPrompt(
        seed: seed,
        isV4Model: isV4Model,
      ),
      RandomGenerationMode.custom => _generateCustomPresetPrompt(
        seed: seed,
        isV4Model: isV4Model,
      ),
      RandomGenerationMode.hybrid => _generateHybridPrompt(
        seed: seed,
        isV4Model: isV4Model,
      ),
    };
  }

  /// 官网模式生成
  Future<RandomPromptResult> _generateOfficialPrompt({
    int? seed,
    bool isV4Model = true,
  }) async {
    final generator = ref.read(randomPromptGeneratorProvider);
    final presetState = ref.read(randomPresetNotifierProvider);

    final preset = presetState.defaultPreset;
    if (preset.categories.isNotEmpty) {
      final result = await generator.generateFromPreset(
        preset: preset,
        isV4Model: isV4Model,
        seed: seed,
        mode: RandomGenerationMode.naiOfficial,
      );
      AppLogger.d(
        'official preset result: ${result.characterCount} characters, '
            'mainPrompt: ${result.mainPrompt}',
        'RandomGen',
      );
      return result;
    }

    // 默认预设异常为空时，保留原始 TagLibrary 生成能力作为兜底。
    final filterConfig = ref
        .read(tagLibraryNotifierProvider)
        .categoryFilterConfig;
    return generator.generateFromCatalog(
      seed: seed,
      isV4Model: isV4Model,
      categoryFilterConfig: filterConfig,
    );
  }

  /// 自定义模式生成
  Future<RandomPromptResult> _generateCustomPresetPrompt({
    int? seed,
    bool isV4Model = true,
  }) async {
    final generator = ref.read(randomPromptGeneratorProvider);
    final preset = _selectedCustomRandomPreset();

    if (preset == null || preset.categories.isEmpty) {
      return RandomPromptResult(
        mainPrompt: '',
        mode: RandomGenerationMode.custom,
        seed: seed,
      );
    }

    return generator.generateFromPreset(
      preset: preset,
      isV4Model: isV4Model,
      seed: seed,
      mode: RandomGenerationMode.custom,
    );
  }

  /// 混合模式生成
  Future<RandomPromptResult> _generateHybridPrompt({
    int? seed,
    bool isV4Model = true,
  }) async {
    final generator = ref.read(randomPromptGeneratorProvider);
    final presetState = ref.read(randomPresetNotifierProvider);
    final customPreset = _selectedCustomRandomPreset();

    if (customPreset == null || customPreset.categories.isEmpty) {
      return RandomPromptResult(
        mainPrompt: '',
        mode: RandomGenerationMode.hybrid,
        seed: seed,
      );
    }

    final mergedPreset = RandomPresetMerger.merge(
      officialPreset: presetState.defaultPreset,
      customPreset: customPreset,
    );

    return generator.generateFromPreset(
      preset: mergedPreset,
      isV4Model: isV4Model,
      seed: seed,
      mode: RandomGenerationMode.hybrid,
    );
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
