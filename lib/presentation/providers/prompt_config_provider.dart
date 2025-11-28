import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/prompt/default_presets.dart';
import '../../data/models/prompt/prompt_config.dart';

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
@riverpod
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
            .toList();
      } else {
        // 首次使用，创建默认预设
        presets = DefaultPresets.allDefaults;
        await _savePresets(presets);
      }

      state = PromptConfigState(
        presets: presets,
        selectedPresetId: selectedId ?? presets.firstOrNull?.id,
        isLoading: false,
      );
    } catch (e) {
      state = PromptConfigState(
        presets: DefaultPresets.allDefaults,
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
    final preset = state.selectedPreset;
    if (preset == null) {
      return DefaultPresets.createDefaultPreset().generate(seed: seed);
    }
    return preset.generate(seed: seed);
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
    final source = state.presets.firstWhere((p) => p.id == presetId);
    final copy = RandomPromptPreset.create(
      name: '${source.name} (副本)',
      configs: source.configs,
    );
    await addPreset(copy);
  }

  /// 导出预设为 JSON
  String exportPreset(String presetId) {
    final preset = state.presets.firstWhere((p) => p.id == presetId);
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

  /// 重置为默认预设
  Future<void> resetToDefaults() async {
    final presets = DefaultPresets.allDefaults;
    await _savePresets(presets);
    await _box?.put(_selectedKey, presets.first.id);
    state = PromptConfigState(
      presets: presets,
      selectedPresetId: presets.first.id,
      isLoading: false,
    );
  }
}
