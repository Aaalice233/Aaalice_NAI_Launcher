import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/prompt/default_presets.dart';
import '../../data/models/prompt/prompt_config.dart';
import '../../data/models/prompt/random_prompt_result.dart';
import '../../data/services/random_prompt_generator.dart';
import 'random_mode_provider.dart';
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

  @override
  PromptConfigState build() {
    _loadPresets();
    return const PromptConfigState(isLoading: true);
  }

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
        // 首次使用，不再自动创建默认预设（默认使用 NAI 官方模式）
        presets = [];
      }

      state = PromptConfigState(
        presets: presets,
        selectedPresetId: selectedId ?? presets.firstOrNull?.id,
        isLoading: false,
      );
    } catch (e) {
      state = PromptConfigState(
        presets: [],
        isLoading: false,
        error: e.toString(),
      );
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
  /// 根据当前模式（官网/自定义）生成随机提示词
  /// [seed] 随机种子（可选）
  /// [isV4Model] 是否为 V4+ 模型（可选，默认 true）
  Future<RandomPromptResult> generateRandomPrompt({
    int? seed,
    bool isV4Model = true,
  }) async {
    final mode = ref.read(randomModeNotifierProvider);

    if (mode == RandomGenerationMode.naiOfficial) {
      // 官网模式：使用 NAI 算法生成
      return _generateNaiStylePrompt(seed: seed, isV4Model: isV4Model);
    } else {
      // 自定义模式：使用现有预设生成
      return _generateCustomPrompt(seed: seed);
    }
  }

  /// 官网模式生成
  Future<RandomPromptResult> _generateNaiStylePrompt({
    int? seed,
    bool isV4Model = true,
  }) async {
    final generator = ref.read(randomPromptGeneratorProvider);
    final filterConfig = ref.read(tagLibraryNotifierProvider).categoryFilterConfig;
    return generator.generateNaiStyle(
      seed: seed,
      isV4Model: isV4Model,
      categoryFilterConfig: filterConfig,
    );
  }

  /// 自定义模式生成
  RandomPromptResult _generateCustomPrompt({int? seed}) {
    final prompt = generatePrompt(seed: seed);
    return RandomPromptResult(
      mainPrompt: prompt,
      mode: RandomGenerationMode.custom,
      seed: seed,
    );
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
