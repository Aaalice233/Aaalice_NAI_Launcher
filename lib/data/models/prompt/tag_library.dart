import 'package:freezed_annotation/freezed_annotation.dart';

import 'category_filter_config.dart';
import 'tag_category.dart';
import 'weighted_tag.dart';

part 'tag_library.freezed.dart';
part 'tag_library.g.dart';

/// 词库来源
enum TagLibrarySource {
  /// NAI 官方固定词库
  @JsonValue('nai')
  nai,

  /// 从 Danbooru 拉取
  @JsonValue('danbooru')
  danbooru,

  /// 用户自定义
  @JsonValue('custom')
  custom,

  /// 内置默认
  @JsonValue('builtin')
  builtin,
}

/// 标签词库模型
///
/// 存储按类别分组的带权重标签
@freezed
class TagLibrary with _$TagLibrary {
  const TagLibrary._();

  const factory TagLibrary({
    /// 词库ID
    required String id,

    /// 词库名称
    required String name,

    /// 最后更新时间
    required DateTime lastUpdated,

    /// 版本号
    @Default(1) int version,

    /// 词库来源
    required TagLibrarySource source,

    /// 是否包含 Danbooru 补充标签
    @Default(false) bool hasDanbooruSupplement,

    /// Danbooru 补充标签数量
    @Default(0) int danbooruSupplementCount,

    /// 按类别分组的标签
    /// key: TagSubCategory 的名称
    /// value: 该类别下的所有带权重标签
    @Default({}) Map<String, List<WeightedTag>> categories,
  }) = _TagLibrary;

  factory TagLibrary.fromJson(Map<String, dynamic> json) =>
      _$TagLibraryFromJson(json);

  /// 创建空词库
  factory TagLibrary.empty({
    required String id,
    required String name,
    required TagLibrarySource source,
  }) {
    return TagLibrary(
      id: id,
      name: name,
      lastUpdated: DateTime.now(),
      source: source,
    );
  }

  /// 获取指定类别的标签列表
  List<WeightedTag> getCategory(TagSubCategory category) {
    return categories[category.name] ?? [];
  }

  /// 设置指定类别的标签列表
  TagLibrary setCategory(TagSubCategory category, List<WeightedTag> tags) {
    final newCategories = Map<String, List<WeightedTag>>.from(categories);
    newCategories[category.name] = tags;
    return copyWith(
      categories: newCategories,
      lastUpdated: DateTime.now(),
    );
  }

  /// 合并另一个词库
  TagLibrary merge(TagLibrary other, {bool preserveWeights = true}) {
    final newCategories = Map<String, List<WeightedTag>>.from(categories);

    for (final entry in other.categories.entries) {
      if (preserveWeights && newCategories.containsKey(entry.key)) {
        // 保留现有权重，只添加新标签
        final existingTags = {
          for (final t in newCategories[entry.key]!) t.tag: t,
        };
        for (final tag in entry.value) {
          if (!existingTags.containsKey(tag.tag)) {
            existingTags[tag.tag] = tag;
          }
        }
        newCategories[entry.key] = existingTags.values.toList();
      } else {
        newCategories[entry.key] = entry.value;
      }
    }

    return copyWith(
      categories: newCategories,
      lastUpdated: DateTime.now(),
      version: version + 1,
    );
  }

  /// 获取总标签数
  int get totalTagCount {
    return categories.values.fold(0, (sum, list) => sum + list.length);
  }

  /// 获取过滤后的标签数量（根据是否包含 Danbooru 补充）
  int getFilteredTagCount({required bool includeDanbooruSupplement}) {
    if (includeDanbooruSupplement) {
      return totalTagCount;
    }
    // 只计算非 Danbooru 来源的标签
    return categories.values.fold(0, (sum, list) {
      return sum + list.where((t) => !t.isDanbooruSupplement).length;
    });
  }

  /// 获取分类级过滤后的标签数量
  ///
  /// 根据 [CategoryFilterConfig] 配置，各分类独立决定是否包含 Danbooru 补充
  int getFilteredTagCountWithConfig(CategoryFilterConfig filterConfig) {
    int total = 0;
    for (final entry in categories.entries) {
      // 尝试解析分类名称
      final category = TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
        (c) => c?.name == entry.key,
        orElse: () => null,
      );

      // 如果分类配置启用了 Danbooru 补充，计入全部标签
      // 否则只计入非 Danbooru 来源的标签
      if (category != null && filterConfig.isEnabled(category)) {
        total += entry.value.length;
      } else {
        total += entry.value.where((t) => !t.isDanbooruSupplement).length;
      }
    }
    return total;
  }

  /// 获取过滤后的类别标签
  List<WeightedTag> getFilteredCategory(
    TagSubCategory category, {
    required bool includeDanbooruSupplement,
  }) {
    final tags = getCategory(category);
    if (includeDanbooruSupplement) {
      return tags;
    }
    return tags.where((t) => !t.isDanbooruSupplement).toList();
  }

  /// 检查词库是否为空
  bool get isEmpty => categories.isEmpty || totalTagCount == 0;

  /// 检查词库是否有效
  bool get isValid => !isEmpty;
}
