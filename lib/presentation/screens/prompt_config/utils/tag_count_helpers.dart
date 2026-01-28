import '../../../../data/models/prompt/category_filter_config.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../../../../data/models/prompt/tag_library.dart';

/// 标签计数辅助工具类
class TagCountHelpers {
  TagCountHelpers._();

  /// NAI 官方类别及其选中概率配置
  /// 参考: docs/NAI随机提示词功能分析.md
  static Map<TagSubCategory, int> getNaiCategoryConfig() {
    return {
      // 角色特征类（概率约50%）
      TagSubCategory.hairColor: 50,
      TagSubCategory.eyeColor: 50,
      TagSubCategory.hairStyle: 50,
      TagSubCategory.expression: 50,
      TagSubCategory.pose: 50,
      TagSubCategory.clothing: 50,
      TagSubCategory.accessory: 50,
      TagSubCategory.bodyFeature: 30,
      // 场景/画风类
      TagSubCategory.background: 90,
      TagSubCategory.scene: 50,
      TagSubCategory.style: 30,
      // 人数（由算法决定，显示供参考）
      TagSubCategory.characterCount: 100,
    };
  }

  /// 计算内置词库的标签数量
  ///
  /// [library] 标签库
  /// [categories] 随机类别列表
  /// [filterConfig] 过滤配置
  static int calculateBuiltinLibraryTagCount(
    TagLibrary? library,
    List<RandomCategory> categories,
    CategoryFilterConfig filterConfig,
  ) {
    if (library == null) return 0;

    int tagCount = 0;
    for (final randomCategory in categories) {
      final category = TagSubCategory.values.firstWhere(
        (e) => e.name == randomCategory.key,
        orElse: () => TagSubCategory.hairColor,
      );
      if (randomCategory.enabled && filterConfig.isBuiltinEnabled(category)) {
        tagCount += library
            .getCategory(category)
            .where((t) => !t.isDanbooruSupplement)
            .length;
      }
    }
    return tagCount;
  }

  /// 计算 NAI 模式下内置词库的标签数量
  ///
  /// 与 calculateBuiltinLibraryTagCount 的区别是：
  /// - 这里使用 NAI 固定的类别配置作为遍历源
  /// - 需要额外检查对应的 RandomCategory 是否启用
  ///
  /// [library] 标签库
  /// [categories] 随机类别列表（用于检查启用状态）
  /// [filterConfig] 过滤配置
  static int calculateNaiBuiltinTagCount(
    TagLibrary? library,
    List<RandomCategory> categories,
    CategoryFilterConfig filterConfig,
  ) {
    if (library == null) return 0;

    int tagCount = 0;
    final categoryConfig = getNaiCategoryConfig();

    for (final category in categoryConfig.keys) {
      // 查找对应的 RandomCategory
      final randomCategory = categories.cast<RandomCategory?>().firstWhere(
            (c) => c?.key == category.name,
            orElse: () => null,
          );
      final categoryEnabled = randomCategory?.enabled ?? true;
      if (categoryEnabled && filterConfig.isBuiltinEnabled(category)) {
        tagCount += library
            .getCategory(category)
            .where((t) => !t.isDanbooruSupplement)
            .length;
      }
    }
    return tagCount;
  }
}
