import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/prompt/algorithm_config.dart';
import '../../data/models/prompt/default_categories.dart';
import '../../data/models/prompt/random_category.dart';
import '../../data/models/prompt/random_preset.dart';

part 'random_preset_provider.g.dart';

/// 随机预设状态
class RandomPresetState {
  final List<RandomPreset> presets;
  final String? selectedPresetId;
  final bool isLoading;
  final String? error;

  const RandomPresetState({
    this.presets = const [],
    this.selectedPresetId,
    this.isLoading = false,
    this.error,
  });

  /// 获取当前选中的预设
  RandomPreset? get selectedPreset {
    if (selectedPresetId == null) return null;
    return presets.firstWhere(
      (p) => p.id == selectedPresetId,
      orElse: () => presets.isNotEmpty ? presets.first : RandomPreset.defaultPreset(),
    );
  }

  /// 获取默认预设
  RandomPreset get defaultPreset {
    return presets.firstWhere(
      (p) => p.isDefault,
      orElse: () => RandomPreset.defaultPreset(),
    );
  }

  RandomPresetState copyWith({
    List<RandomPreset>? presets,
    String? selectedPresetId,
    bool? isLoading,
    String? error,
  }) {
    return RandomPresetState(
      presets: presets ?? this.presets,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 随机预设管理器
@Riverpod(keepAlive: true)
class RandomPresetNotifier extends _$RandomPresetNotifier {
  static const String _boxName = 'random_presets';
  static const String _selectedIdKey = 'selected_preset_id';

  late Box<String> _box;

  @override
  RandomPresetState build() {
    _init();
    return const RandomPresetState(isLoading: true);
  }

  Future<void> _init() async {
    try {
      _box = await Hive.openBox<String>(_boxName);
      await _loadPresets();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载预设失败: $e',
      );
    }
  }

  /// 加载所有预设
  Future<void> _loadPresets() async {
    final presets = <RandomPreset>[];

    // 加载存储的预设
    for (final key in _box.keys) {
      if (key == _selectedIdKey) continue;
      try {
        final json = _box.get(key);
        if (json != null) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final preset = RandomPreset.fromJson(data);
          presets.add(preset);
        }
      } catch (e) {
        // 忽略无效的预设数据
      }
    }

    // 确保有默认预设
    if (!presets.any((p) => p.isDefault)) {
      final defaultPreset = RandomPreset.defaultPreset();
      presets.insert(0, defaultPreset);
      await _savePreset(defaultPreset);
    } else {
      // 迁移旧版默认预设：如果 categories 为空，填充默认类别
      final defaultIndex = presets.indexWhere((p) => p.isDefault);
      if (defaultIndex != -1 && presets[defaultIndex].categories.isEmpty) {
        final updatedDefault = presets[defaultIndex].copyWith(
          categories: DefaultCategories.createDefault(),
          version: 2,
        );
        presets[defaultIndex] = updatedDefault;
        await _savePreset(updatedDefault);
      }
    }

    // 按创建时间排序，默认预设在最前
    presets.sort((a, b) {
      if (a.isDefault) return -1;
      if (b.isDefault) return 1;
      return (a.createdAt ?? DateTime.now())
          .compareTo(b.createdAt ?? DateTime.now());
    });

    // 获取上次选中的预设ID
    final selectedId = _box.get(_selectedIdKey) ?? presets.first.id;

    state = state.copyWith(
      presets: presets,
      selectedPresetId: selectedId,
      isLoading: false,
    );
  }

  /// 保存预设到存储
  Future<void> _savePreset(RandomPreset preset) async {
    await _box.put(preset.id, jsonEncode(preset.toJson()));
  }

  /// 删除预设从存储
  Future<void> _deletePreset(String id) async {
    await _box.delete(id);
  }

  /// 选择预设
  Future<void> selectPreset(String id) async {
    state = state.copyWith(selectedPresetId: id);
    await _box.put(_selectedIdKey, id);
  }

  /// 创建新预设
  Future<RandomPreset> createPreset({
    required String name,
    String? description,
    bool copyFromCurrent = true,
  }) async {
    final newPreset = copyFromCurrent && state.selectedPreset != null
        ? RandomPreset.copyFrom(state.selectedPreset!, name: name)
        : RandomPreset.create(name: name, description: description);

    final newPresets = [...state.presets, newPreset];
    state = state.copyWith(
      presets: newPresets,
      selectedPresetId: newPreset.id,
    );

    await _savePreset(newPreset);
    await _box.put(_selectedIdKey, newPreset.id);

    return newPreset;
  }

  /// 更新预设
  Future<void> updatePreset(RandomPreset preset) async {
    final index = state.presets.indexWhere((p) => p.id == preset.id);
    if (index == -1) return;

    final updatedPreset = preset.touch();
    final newPresets = [...state.presets];
    newPresets[index] = updatedPreset;

    state = state.copyWith(presets: newPresets);
    await _savePreset(updatedPreset);
  }

  /// 重命名预设
  Future<void> renamePreset(String id, String newName) async {
    final preset = state.presets.firstWhereOrNull((p) => p.id == id);
    if (preset == null) return;
    await updatePreset(preset.copyWith(name: newName));
  }

  /// 删除预设
  Future<void> deletePreset(String id) async {
    final preset = state.presets.firstWhereOrNull((p) => p.id == id);
    if (preset == null || preset.isDefault) return; // 不能删除默认预设或不存在的预设

    final newPresets = state.presets.where((p) => p.id != id).toList();
    var newSelectedId = state.selectedPresetId;

    // 如果删除的是当前选中的，选择默认预设
    if (state.selectedPresetId == id && newPresets.isNotEmpty) {
      newSelectedId = newPresets.first.id;
    }

    state = state.copyWith(
      presets: newPresets,
      selectedPresetId: newSelectedId,
    );

    await _deletePreset(id);
    if (newSelectedId != null && state.selectedPresetId != newSelectedId) {
      await _box.put(_selectedIdKey, newSelectedId);
    }
  }

  /// 更新当前预设的算法配置
  Future<void> updateAlgorithmConfig(AlgorithmConfig config) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.updateAlgorithmConfig(config));
  }

  /// 更新当前预设的类别概率配置
  Future<void> updateCategoryProbabilities(
    CategoryProbabilityConfig config,
  ) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.updateCategoryProbabilities(config));
  }

  /// 更新当前预设的类别列表
  Future<void> updateCategories(List<RandomCategory> categories) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.updateCategories(categories));
  }

  /// 添加类别到当前预设
  Future<void> addCategory(RandomCategory category) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.addCategory(category));
  }

  /// 从当前预设删除类别
  Future<void> removeCategory(String categoryId) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.removeCategory(categoryId));
  }

  /// 更新当前预设的单个类别
  Future<void> updateCategory(RandomCategory category) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.updateCategory(category));
  }

  /// 重置当前预设为默认配置
  Future<void> resetCurrentPreset() async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.resetToDefault());
  }

  /// 导出预设
  String? exportPreset(String id) {
    final preset = state.presets.firstWhereOrNull((p) => p.id == id);
    if (preset == null) return null;
    return jsonEncode(preset.toExportJson());
  }

  /// 导入预设
  Future<RandomPreset?> importPreset(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final preset = RandomPreset.fromExportJson(data);

      final newPresets = [...state.presets, preset];
      state = state.copyWith(presets: newPresets);

      await _savePreset(preset);
      return preset;
    } catch (e) {
      state = state.copyWith(error: '导入预设失败: $e');
      return null;
    }
  }

  /// 复制预设
  Future<RandomPreset?> duplicatePreset(String id, String newName) async {
    final source = state.presets.firstWhereOrNull((p) => p.id == id);
    if (source == null) return null;

    final newPreset = RandomPreset.copyFrom(source, name: newName);

    final newPresets = [...state.presets, newPreset];
    state = state.copyWith(presets: newPresets);

    await _savePreset(newPreset);
    return newPreset;
  }
}
