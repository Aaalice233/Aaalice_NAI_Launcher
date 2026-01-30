import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../services/wordlist_service.dart';
import 'algorithm_config.dart';
import 'default_categories.dart';
import 'default_tag_group_mappings.dart';
import 'pool_mapping.dart';
import 'random_category.dart';
import 'random_tag_group.dart';
import 'tag_group_mapping.dart';

part 'random_preset.freezed.dart';
part 'random_preset.g.dart';

/// 随机提示词预设
///
/// 包含完整的算法配置和类别/分组配置
@freezed
class RandomPreset with _$RandomPreset {
  const RandomPreset._();

  const factory RandomPreset({
    /// 预设ID
    required String id,

    /// 预设名称
    required String name,

    /// 预设描述
    String? description,

    /// 是否为默认预设（不可删除）
    @Default(false) bool isDefault,

    /// 是否基于默认预设创建（用于判断是否显示重置按钮）
    @Default(false) bool isBasedOnDefault,

    /// 数据版本
    @Default(2) int version,

    /// 算法配置
    @Default(AlgorithmConfig()) AlgorithmConfig algorithmConfig,

    /// 类别概率配置（旧版兼容，新版已弃用）
    @Default(CategoryProbabilityConfig())
    CategoryProbabilityConfig categoryProbabilities,

    /// 类别列表
    @Default([]) List<RandomCategory> categories,

    /// Tag Group 映射配置
    @Default([]) List<TagGroupMapping> tagGroupMappings,

    /// Pool 映射配置
    @Default([]) List<PoolMapping> poolMappings,

    /// 创建时间
    DateTime? createdAt,

    /// 最后修改时间
    DateTime? updatedAt,
  }) = _RandomPreset;

  factory RandomPreset.fromJson(Map<String, dynamic> json) =>
      _$RandomPresetFromJson(json);

  /// 创建新的自定义预设
  factory RandomPreset.create({
    required String name,
    String? description,
    AlgorithmConfig? algorithmConfig,
    List<RandomCategory>? categories,
  }) {
    final now = DateTime.now();
    return RandomPreset(
      id: const Uuid().v4(),
      name: name,
      description: description,
      version: 2,
      algorithmConfig: algorithmConfig ?? const AlgorithmConfig(),
      categories: categories ?? [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 创建默认预设（NAI 官网配置）
  ///
  /// [version] 词库版本，默认为 V4
  factory RandomPreset.defaultPreset({
    WordlistType version = WordlistType.v4,
  }) {
    return RandomPreset(
      id: 'default',
      name: _getDefaultPresetName(version),
      description: _getDefaultPresetDescription(version),
      isDefault: true,
      version: 2,
      algorithmConfig: _getDefaultAlgorithmConfig(version),
      categories: DefaultCategories.createDefaultForVersion(version),
      tagGroupMappings: DefaultTagGroupMappings.createDefaultMappings(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 获取默认预设名称
  static String _getDefaultPresetName(WordlistType version) {
    switch (version) {
      case WordlistType.v4:
        return '默认模式 (V4)';
      case WordlistType.legacy:
        return '默认模式 (Legacy)';
      case WordlistType.furry:
        return '默认模式 (Furry)';
    }
  }

  /// 获取默认预设描述
  static String _getDefaultPresetDescription(WordlistType version) {
    switch (version) {
      case WordlistType.v4:
        return '基于 NAI V4 模型的随机算法配置，支持多角色';
      case WordlistType.legacy:
        return '基于 NAI Legacy 模型的随机算法配置';
      case WordlistType.furry:
        return '基于 NAI Furry 模型的随机算法配置';
    }
  }

  /// 获取默认算法配置
  static AlgorithmConfig _getDefaultAlgorithmConfig(WordlistType version) {
    // NAI 官方概率配置
    // 角色数量: 1人70%, 2人20%, 3人7%, 4人3%
    // 性别: female 60%, male 30%, other 10%
    // 强调概率: 2%
    return AlgorithmConfig(
      characterCountWeights: const [
        [1, 70],
        [2, 20],
        [3, 7],
        [4, 3],
      ],
      genderWeights: const {
        'male': 30,
        'female': 60,
        'other': 10,
      },
      globalEmphasisProbability: 0.02,
      globalEmphasisBracketCount: 1,
      enableSeasonalWordlists: true,
      wordlistType: version.name,
      isV4Model: version == WordlistType.v4,
    );
  }

  /// 从现有预设复制创建新预设
  factory RandomPreset.copyFrom(RandomPreset source, {required String name}) {
    final now = DateTime.now();
    return RandomPreset(
      id: const Uuid().v4(),
      name: name,
      description: source.description,
      isDefault: false,
      version: 2,
      algorithmConfig: source.algorithmConfig,
      categoryProbabilities: source.categoryProbabilities,
      categories: source.categories.map((c) => c.deepCopy()).toList(),
      tagGroupMappings: source.tagGroupMappings
          .map(
            (m) => m.copyWith(
              id: 'mapping_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}',
            ),
          )
          .toList(),
      poolMappings: source.poolMappings
          .map(
            (m) => m.copyWith(
              id: 'pool_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}',
            ),
          )
          .toList(),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 获取词库总标签数
  ///
  /// 包括：
  /// - categories 中的自定义标签
  /// - tagGroupMappings 中已同步的 Danbooru 标签
  /// - poolMappings 中已同步的 Pool 标签
  int get totalTagCount {
    // 1. 类别中的自定义标签（只计算 custom 和 builtin 类型）
    int customTagCount = 0;
    for (final cat in categories) {
      for (final group in cat.groups) {
        if (group.sourceType == TagGroupSourceType.custom ||
            group.sourceType == TagGroupSourceType.builtin) {
          customTagCount += group.tagCount;
        }
      }
    }

    // 2. TagGroup 映射中的标签数
    final tagGroupTagCount = tagGroupMappings
        .where((m) => m.enabled)
        .fold(0, (sum, m) => sum + m.lastSyncedTagCount);

    // 3. Pool 不计算标签数（Pool 是基于帖子的，不是基于标签的）

    return customTagCount + tagGroupTagCount;
  }

  /// 获取启用的标签数
  int get enabledTagCount {
    return categories.fold(0, (sum, cat) => sum + cat.enabledTagCount);
  }

  /// 获取类别数量
  int get categoryCount => categories.length;

  /// 获取启用的类别数量
  int get enabledCategoryCount => categories.where((c) => c.enabled).length;

  /// 更新最后修改时间
  RandomPreset touch() {
    return copyWith(updatedAt: DateTime.now());
  }

  /// 更新算法配置
  RandomPreset updateAlgorithmConfig(AlgorithmConfig config) {
    return copyWith(
      algorithmConfig: config,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新类别概率配置
  RandomPreset updateCategoryProbabilities(CategoryProbabilityConfig config) {
    return copyWith(
      categoryProbabilities: config,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新类别列表
  RandomPreset updateCategories(List<RandomCategory> newCategories) {
    return copyWith(
      categories: newCategories,
      updatedAt: DateTime.now(),
    );
  }

  /// 添加类别
  RandomPreset addCategory(RandomCategory category) {
    return copyWith(
      categories: [...categories, category],
      updatedAt: DateTime.now(),
    );
  }

  /// 删除类别
  RandomPreset removeCategory(String categoryId) {
    return copyWith(
      categories: categories.where((c) => c.id != categoryId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// 按 key 删除类别
  RandomPreset removeCategoryByKey(String key) {
    return copyWith(
      categories: categories.where((c) => c.key != key).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// 更新单个类别
  RandomPreset updateCategory(RandomCategory updatedCategory) {
    final index = categories.indexWhere((c) => c.id == updatedCategory.id);
    if (index == -1) return this;

    final newCategories = [...categories];
    newCategories[index] = updatedCategory;
    return copyWith(
      categories: newCategories,
      updatedAt: DateTime.now(),
    );
  }

  /// 按 key 更新或添加类别
  RandomPreset upsertCategoryByKey(RandomCategory category) {
    final index = categories.indexWhere((c) => c.key == category.key);
    if (index == -1) {
      // 不存在则添加
      return addCategory(category);
    }

    // 存在则更新
    final newCategories = [...categories];
    newCategories[index] = category;
    return copyWith(
      categories: newCategories,
      updatedAt: DateTime.now(),
    );
  }

  /// 通过ID查找类别
  RandomCategory? findCategoryById(String categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  /// 通过key查找类别
  RandomCategory? findCategoryByKey(String key) {
    for (final category in categories) {
      if (category.key == key) return category;
    }
    return null;
  }

  // ========== Tag Group 映射管理 ==========

  /// 添加 Tag Group 映射
  RandomPreset addTagGroupMapping(TagGroupMapping mapping) {
    return copyWith(
      tagGroupMappings: [...tagGroupMappings, mapping],
      updatedAt: DateTime.now(),
    );
  }

  /// 删除 Tag Group 映射
  RandomPreset removeTagGroupMapping(String mappingId) {
    return copyWith(
      tagGroupMappings:
          tagGroupMappings.where((m) => m.id != mappingId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// 更新 Tag Group 映射
  RandomPreset updateTagGroupMapping(TagGroupMapping updatedMapping) {
    final index = tagGroupMappings.indexWhere((m) => m.id == updatedMapping.id);
    if (index == -1) return this;

    final newMappings = [...tagGroupMappings];
    newMappings[index] = updatedMapping;
    return copyWith(
      tagGroupMappings: newMappings,
      updatedAt: DateTime.now(),
    );
  }

  /// 切换 Tag Group 映射启用状态
  RandomPreset toggleTagGroupMappingEnabled(String mappingId) {
    final index = tagGroupMappings.indexWhere((m) => m.id == mappingId);
    if (index == -1) return this;

    final mapping = tagGroupMappings[index];
    final newMappings = [...tagGroupMappings];
    newMappings[index] = mapping.copyWith(enabled: !mapping.enabled);
    return copyWith(
      tagGroupMappings: newMappings,
      updatedAt: DateTime.now(),
    );
  }

  /// 通过ID查找 Tag Group 映射
  TagGroupMapping? findTagGroupMappingById(String mappingId) {
    for (final mapping in tagGroupMappings) {
      if (mapping.id == mappingId) return mapping;
    }
    return null;
  }

  // ========== Pool 映射管理 ==========

  /// 添加 Pool 映射
  RandomPreset addPoolMapping(PoolMapping mapping) {
    return copyWith(
      poolMappings: [...poolMappings, mapping],
      updatedAt: DateTime.now(),
    );
  }

  /// 删除 Pool 映射
  RandomPreset removePoolMapping(String mappingId) {
    return copyWith(
      poolMappings: poolMappings.where((m) => m.id != mappingId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// 更新 Pool 映射
  RandomPreset updatePoolMapping(PoolMapping updatedMapping) {
    final index = poolMappings.indexWhere((m) => m.id == updatedMapping.id);
    if (index == -1) return this;

    final newMappings = [...poolMappings];
    newMappings[index] = updatedMapping;
    return copyWith(
      poolMappings: newMappings,
      updatedAt: DateTime.now(),
    );
  }

  /// 切换 Pool 映射启用状态
  RandomPreset togglePoolMappingEnabled(String mappingId) {
    final index = poolMappings.indexWhere((m) => m.id == mappingId);
    if (index == -1) return this;

    final mapping = poolMappings[index];
    final newMappings = [...poolMappings];
    newMappings[index] = mapping.copyWith(enabled: !mapping.enabled);
    return copyWith(
      poolMappings: newMappings,
      updatedAt: DateTime.now(),
    );
  }

  /// 通过ID查找 Pool 映射
  PoolMapping? findPoolMappingById(String mappingId) {
    for (final mapping in poolMappings) {
      if (mapping.id == mappingId) return mapping;
    }
    return null;
  }

  /// 重置为默认配置
  RandomPreset resetToDefault() {
    return copyWith(
      algorithmConfig: const AlgorithmConfig(),
      categoryProbabilities: const CategoryProbabilityConfig(),
      categories: DefaultCategories.createDefault(),
      tagGroupMappings: [], // 完全清除所有 Danbooru TagGroup 映射
      poolMappings: [], // 完全清除所有 Danbooru Pool 映射
      updatedAt: DateTime.now(),
    );
  }

  /// 导出为 JSON 字符串（用于分享）
  Map<String, dynamic> toExportJson() {
    return {
      'name': name,
      'description': description,
      'version': version,
      'algorithmConfig': algorithmConfig.toJson(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'tagGroupMappings': tagGroupMappings.map((m) => m.toJson()).toList(),
      'poolMappings': poolMappings.map((m) => m.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// 从导出的 JSON 导入
  static RandomPreset fromExportJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 2;
    if (version > 2) {
      throw FormatException('不支持的预设版本: $version，请更新应用后重试');
    }

    final now = DateTime.now();

    // 解析类别列表
    List<RandomCategory> categories = [];
    if (json['categories'] != null) {
      categories = (json['categories'] as List)
          .map((c) => RandomCategory.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    // 解析 Tag Group 映射列表
    List<TagGroupMapping> tagGroupMappings = [];
    if (json['tagGroupMappings'] != null) {
      tagGroupMappings = (json['tagGroupMappings'] as List)
          .map((m) => TagGroupMapping.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    // 解析 Pool 映射列表
    List<PoolMapping> poolMappings = [];
    if (json['poolMappings'] != null) {
      poolMappings = (json['poolMappings'] as List)
          .map((m) => PoolMapping.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    return RandomPreset(
      id: const Uuid().v4(),
      name: json['name'] as String? ?? '导入的预设',
      description: json['description'] as String?,
      isDefault: false,
      version: 2,
      algorithmConfig: json['algorithmConfig'] != null
          ? AlgorithmConfig.fromJson(
              json['algorithmConfig'] as Map<String, dynamic>,
            )
          : const AlgorithmConfig(),
      categoryProbabilities: json['categoryProbabilities'] != null
          ? CategoryProbabilityConfig.fromJson(
              json['categoryProbabilities'] as Map<String, dynamic>,
            )
          : const CategoryProbabilityConfig(),
      categories: categories,
      tagGroupMappings: tagGroupMappings,
      poolMappings: poolMappings,
      createdAt: now,
      updatedAt: now,
    );
  }
}
