import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/prompt/algorithm_config.dart';
import '../../data/models/prompt/default_categories.dart';
import '../../data/models/prompt/pool_mapping.dart';
import '../../data/models/prompt/random_category.dart';
import '../../data/models/prompt/random_preset.dart';
import '../../data/models/prompt/random_tag_group.dart';
import '../../data/models/prompt/tag_category.dart';
import '../../data/models/prompt/tag_group_mapping.dart';
import '../../data/services/wordlist_service.dart';
import 'tag_library_provider.dart';

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
      orElse: () =>
          presets.isNotEmpty ? presets.first : RandomPreset.defaultPreset(),
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
@Riverpod()
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
      // 迁移旧版默认预设
      final defaultIndex = presets.indexWhere((p) => p.isDefault);
      if (defaultIndex != -1) {
        var needsUpdate = false;
        var updatedDefault = presets[defaultIndex];

        // 如果 categories 为空，填充默认类别
        if (updatedDefault.categories.isEmpty) {
          updatedDefault = updatedDefault.copyWith(
            categories: DefaultCategories.createDefault(),
          );
          needsUpdate = true;
        }

        if (needsUpdate) {
          updatedDefault = updatedDefault.copyWith(version: 2);
          presets[defaultIndex] = updatedDefault;
          await _savePreset(updatedDefault);
        }
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

  /// 更新词库版本
  ///
  /// 当用户切换模型版本时，更新默认预设以匹配新版本
  Future<void> updateWordlistVersion(WordlistType version) async {
    // 找到默认预设
    final defaultIndex = state.presets.indexWhere((p) => p.isDefault);
    if (defaultIndex == -1) return;

    // 创建新版本的默认预设
    final newDefault = RandomPreset.defaultPreset(version: version);

    final newPresets = [...state.presets];
    newPresets[defaultIndex] = newDefault;

    state = state.copyWith(presets: newPresets);
    await _savePreset(newDefault);
  }

  /// 创建新预设
  Future<RandomPreset> createPreset({
    required String name,
    String? description,
    bool copyFromCurrent = true,
  }) async {
    final currentPreset = state.selectedPreset;
    final isBasedOnDefault = copyFromCurrent &&
        (currentPreset?.isDefault == true ||
            currentPreset?.isBasedOnDefault == true);

    final newPreset = copyFromCurrent && currentPreset != null
        ? RandomPreset.copyFrom(currentPreset, name: name).copyWith(
            isBasedOnDefault: isBasedOnDefault,
          )
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

  /// 更新预设描述
  Future<void> updatePresetDescription(String id, String description) async {
    final preset = state.presets.firstWhereOrNull((p) => p.id == id);
    if (preset == null) return;
    await updatePreset(preset.copyWith(description: description));
  }

  /// 添加预设到状态（用于预设复制）
  Future<void> addPreset(RandomPreset preset) async {
    final newPresets = [...state.presets, preset];
    state = state.copyWith(
      presets: newPresets,
      selectedPresetId: preset.id,
    );
    await _savePreset(preset);
    await _box.put(_selectedIdKey, preset.id);
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

  /// 从当前预设删除类别（按 ID）
  Future<void> removeCategory(String categoryId) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.removeCategory(categoryId));
  }

  /// 从当前预设删除类别（按 key）
  Future<void> removeCategoryByKey(String categoryKey) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.removeCategoryByKey(categoryKey));
  }

  /// 更新当前预设的单个类别
  Future<void> updateCategory(RandomCategory category) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.updateCategory(category));
  }

  /// 更新或添加类别（按 key 匹配）
  Future<void> upsertCategoryByKey(RandomCategory category) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.upsertCategoryByKey(category));
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

  // ========== Tag Group 映射管理 ==========

  /// 添加 Tag Group 映射到当前预设
  Future<void> addTagGroupMapping(TagGroupMapping mapping) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.addTagGroupMapping(mapping));
  }

  /// 从当前预设删除 Tag Group 映射
  Future<void> removeTagGroupMapping(String mappingId) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.removeTagGroupMapping(mappingId));
  }

  /// 更新当前预设的 Tag Group 映射
  Future<void> updateTagGroupMapping(TagGroupMapping mapping) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.updateTagGroupMapping(mapping));
  }

  /// 切换当前预设的 Tag Group 映射启用状态
  Future<void> toggleTagGroupMappingEnabled(String mappingId) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.toggleTagGroupMappingEnabled(mappingId));
  }

  // ========== Pool 映射管理 ==========

  /// 添加 Pool 映射到当前预设
  Future<void> addPoolMapping(PoolMapping mapping) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.addPoolMapping(mapping));
  }

  /// 从当前预设删除 Pool 映射
  Future<void> removePoolMapping(String mappingId) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.removePoolMapping(mappingId));
  }

  /// 更新当前预设的 Pool 映射
  Future<void> updatePoolMapping(PoolMapping mapping) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.updatePoolMapping(mapping));
  }

  /// 切换当前预设的 Pool 映射启用状态
  Future<void> togglePoolMappingEnabled(String mappingId) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    await updatePreset(preset.togglePoolMappingEnabled(mappingId));
  }

  // ========== 分组管理 ==========

  /// 添加分组到指定类别
  ///
  /// [categoryKey] 类别的 key（如 'hairColor'）
  /// [group] 要添加的分组
  Future<void> addGroupToCategory(
    String categoryKey,
    RandomTagGroup group,
  ) async {
    final preset = state.selectedPreset;
    if (preset == null) {
      return;
    }

    final category = preset.findCategoryByKey(categoryKey);
    if (category == null) {
      return;
    }

    final updatedCategory = category.addGroup(group);
    await updatePreset(preset.updateCategory(updatedCategory));
  }

  /// 从指定类别移除分组
  Future<void> removeGroupFromCategory(
    String categoryKey,
    String groupId,
  ) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    final category = preset.findCategoryByKey(categoryKey);
    if (category == null) return;

    final updatedCategory = category.removeGroup(groupId);
    await updatePreset(preset.updateCategory(updatedCategory));
  }

  /// 更新自定义词组（在所有预设的所有类别中查找并更新）
  Future<void> updateCustomGroup(
    String groupId,
    RandomTagGroup newGroup,
  ) async {
    // 遍历所有预设，找到并更新匹配的词组
    for (final preset in state.presets) {
      var presetUpdated = false;
      var updatedPreset = preset;

      for (final category in preset.categories) {
        final existingGroup = category.findGroupById(groupId);
        if (existingGroup != null) {
          // 保持原有ID，更新其他属性
          final updatedGroup = newGroup.copyWith(id: groupId);
          final updatedCategory = category.updateGroup(updatedGroup);
          updatedPreset = updatedPreset.updateCategory(updatedCategory);
          presetUpdated = true;
        }
      }

      if (presetUpdated) {
        await updatePreset(updatedPreset);
      }
    }
  }

  /// 切换分组启用状态
  Future<void> toggleGroupEnabled(String categoryKey, String groupId) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    final category = preset.findCategoryByKey(categoryKey);
    if (category == null) return;

    final group = category.findGroupById(groupId);
    if (group == null) return;

    final updatedGroup = group.copyWith(enabled: !group.enabled);
    final updatedCategory = category.updateGroup(updatedGroup);
    await updatePreset(preset.updateCategory(updatedCategory));
  }

  // ========== 批量 Tag Group 管理 ==========

  /// 批量更新选中的组（完整版本，包含添加新映射）
  Future<void> updateSelectedGroupsWithTree(
    Set<String> selectedGroupTitles,
    Map<
            String,
            ({
              String displayName,
              TagSubCategory category,
              bool includeChildren
            })>
        groupInfoMap,
  ) async {
    final preset = state.selectedPreset;
    if (preset == null) return;

    final existingGroupTitles =
        preset.tagGroupMappings.map((m) => m.groupTitle).toSet();

    // 更新现有映射的 enabled 状态
    final updatedMappings = preset.tagGroupMappings.map((m) {
      final shouldBeEnabled = selectedGroupTitles.contains(m.groupTitle);
      if (m.enabled != shouldBeEnabled) {
        return m.copyWith(enabled: shouldBeEnabled);
      }
      return m;
    }).toList();

    // 添加新的映射
    final newGroupTitles =
        selectedGroupTitles.difference(existingGroupTitles).toList();

    if (newGroupTitles.isNotEmpty) {
      for (final groupTitle in newGroupTitles) {
        final info = groupInfoMap[groupTitle];
        if (info != null) {
          updatedMappings.add(
            TagGroupMapping(
              id: const Uuid().v4(),
              groupTitle: groupTitle,
              displayName: info.displayName,
              targetCategory: info.category,
              createdAt: DateTime.now(),
              includeChildren: info.includeChildren,
              enabled: true,
            ),
          );
        }
      }
    }

    await updatePreset(preset.copyWith(tagGroupMappings: updatedMappings));
  }

  // ========== 重置与词组开关 ==========

  /// 重置预设为默认配置
  ///
  /// 重置逻辑：
  /// 1. 恢复所有官方默认词组的配置（概率、排序等）
  /// 2. 保留用户自定义词组，但将其禁用（enabled = false）
  /// 3. 恢复类别配置
  Future<void> resetToDefault(String presetId) async {
    final presetIndex = state.presets.indexWhere((p) => p.id == presetId);
    if (presetIndex == -1) return;

    final preset = state.presets[presetIndex];
    final defaultPreset = RandomPreset.defaultPreset();

    final mergedCategories = <RandomCategory>[];

    for (final defaultCat in defaultPreset.categories) {
      final existingCat = preset.categories.firstWhereOrNull(
        (c) => c.key == defaultCat.key,
      );

      if (existingCat == null) {
        // 类别不存在，直接添加默认类别
        mergedCategories.add(defaultCat);
      } else {
        // 类别存在，合并词组
        final mergedGroups = <RandomTagGroup>[];

        // 1. 添加默认词组（恢复默认配置）
        for (final defaultGroup in defaultCat.groups) {
          mergedGroups.add(defaultGroup.copyWith(enabled: true));
        }

        // 2. 添加用户自定义词组（禁用）
        for (final customGroup in existingCat.groups) {
          final isDefaultGroup = defaultCat.groups.any(
            (g) => g.sourceId == customGroup.sourceId && g.sourceId != null,
          );
          if (!isDefaultGroup &&
              customGroup.sourceType == TagGroupSourceType.custom) {
            mergedGroups.add(customGroup.copyWith(enabled: false));
          }
        }

        mergedCategories.add(
          existingCat.copyWith(
            groups: mergedGroups,
            probability: defaultCat.probability,
            enabled: defaultCat.enabled,
          ),
        );
      }
    }

    // 保存更新后的预设
    final resetPreset = preset.copyWith(
      categories: mergedCategories,
      algorithmConfig: defaultPreset.algorithmConfig,
      updatedAt: DateTime.now(),
    );

    final newPresets = [...state.presets];
    newPresets[presetIndex] = resetPreset;
    state = state.copyWith(presets: newPresets);
    await _savePreset(resetPreset);
  }
}

/// 计算真实的标签数量（包括内置词库）
///
/// 这个 Provider 会从 TagLibrary 获取内置词库的标签数量
/// 性能优化：使用 select 只监听必要的数据变化
@riverpod
int presetTotalTagCount(Ref ref) {
  // 只监听 preset 和 library 的变化，不监听其他无关状态
  final preset = ref.watch(
    randomPresetNotifierProvider.select((s) => s.selectedPreset),
  );
  if (preset == null) return 0;

  final library = ref.watch(
    tagLibraryNotifierProvider.select((s) => s.library),
  );

  int totalCount = 0;

  // 1. 计算类别中的标签数
  for (final cat in preset.categories) {
    for (final group in cat.groups) {
      if (group.sourceType == TagGroupSourceType.custom) {
        // 自定义类型：直接计算 tags.length
        totalCount += group.tagCount;
      } else if (group.sourceType == TagGroupSourceType.builtin) {
        // 内置词库类型：从 TagLibrary 获取标签数
        if (library != null && group.sourceId != null) {
          final category =
              TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
                    (c) => c?.name == group.sourceId,
                    orElse: () => null,
                  );
          if (category != null) {
            totalCount += library.getCategory(category).length;
          }
        }
      }
      // tagGroup 和 pool 类型在下面单独计算
    }
  }

  // 2. TagGroup 映射中的标签数
  totalCount += preset.tagGroupMappings
      .where((m) => m.enabled)
      .fold(0, (sum, m) => sum + m.lastSyncedTagCount);

  return totalCount;
}

/// 获取单个词组的真实标签数量
///
/// 根据词组的 sourceType 和 sourceId 计算正确的标签数
@riverpod
int groupTagCount(Ref ref, RandomTagGroup group) {
  // 自定义类型：直接返回 tags.length
  if (group.sourceType == TagGroupSourceType.custom) {
    return group.tagCount;
  }

  // 内置词库类型：从 TagLibrary 获取
  if (group.sourceType == TagGroupSourceType.builtin) {
    final library = ref.watch(
      tagLibraryNotifierProvider.select((s) => s.library),
    );
    if (library != null && group.sourceId != null) {
      final category = TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
            (c) => c?.name == group.sourceId,
            orElse: () => null,
          );
      if (category != null) {
        return library.getCategory(category).length;
      }
    }
    return 0;
  }

  // TagGroup/Pool 类型：从缓存服务获取（返回已同步的数量）
  // 这里暂时返回 0，因为实际数量在 tagGroupMappings 中
  return group.tagCount;
}
