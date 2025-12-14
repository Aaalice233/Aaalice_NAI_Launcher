import 'package:freezed_annotation/freezed_annotation.dart';

import 'tag_category.dart';

part 'category_filter_config.freezed.dart';
part 'category_filter_config.g.dart';

/// 分类过滤配置
///
/// 控制各分类是否启用 Danbooru 补充标签
/// 与同步配置解耦，仅影响显示和生成
@freezed
class CategoryFilterConfig with _$CategoryFilterConfig {
  const CategoryFilterConfig._();

  const factory CategoryFilterConfig({
    /// 各分类的 Danbooru 补充启用状态
    /// key: TagSubCategory.name
    /// value: 是否启用
    @Default({}) Map<String, bool> categoryEnabled,
  }) = _CategoryFilterConfig;

  factory CategoryFilterConfig.fromJson(Map<String, dynamic> json) =>
      _$CategoryFilterConfigFromJson(json);

  /// 所有可配置的分类列表
  static const configurableCategories = [
    TagSubCategory.hairColor,
    TagSubCategory.eyeColor,
    TagSubCategory.hairStyle,
    TagSubCategory.expression,
    TagSubCategory.pose,
    TagSubCategory.clothing,
    TagSubCategory.accessory,
    TagSubCategory.bodyFeature,
    TagSubCategory.background,
    TagSubCategory.scene,
    TagSubCategory.style,
    TagSubCategory.characterCount,
  ];

  /// 检查指定分类是否启用 Danbooru 补充
  bool isEnabled(TagSubCategory category) {
    return categoryEnabled[category.name] ?? false;
  }

  /// 设置指定分类的启用状态
  CategoryFilterConfig setEnabled(TagSubCategory category, bool enabled) {
    final newMap = Map<String, bool>.from(categoryEnabled);
    newMap[category.name] = enabled;
    return copyWith(categoryEnabled: newMap);
  }

  /// 设置所有分类的启用状态
  CategoryFilterConfig setAllEnabled(bool enabled) {
    final newMap = <String, bool>{};
    for (final category in configurableCategories) {
      newMap[category.name] = enabled;
    }
    return copyWith(categoryEnabled: newMap);
  }

  /// 检查是否所有分类都启用
  bool get allEnabled {
    for (final category in configurableCategories) {
      if (!isEnabled(category)) return false;
    }
    return true;
  }

  /// 检查是否有任意分类启用
  bool get anyEnabled {
    for (final category in configurableCategories) {
      if (isEnabled(category)) return true;
    }
    return false;
  }

  /// 获取启用的分类数量
  int get enabledCount {
    int count = 0;
    for (final category in configurableCategories) {
      if (isEnabled(category)) count++;
    }
    return count;
  }

  /// 获取总分类数量
  int get totalCategories => configurableCategories.length;
}
