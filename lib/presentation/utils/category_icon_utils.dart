import 'package:flutter/material.dart';

import '../../data/models/prompt/tag_category.dart';

/// 分类图标工具类
///
/// 提供 TagSubCategory 到 IconData 的映射
class CategoryIconUtils {
  CategoryIconUtils._();

  /// 获取分类对应的图标
  static IconData getCategoryIcon(TagSubCategory category) {
    return switch (category) {
      TagSubCategory.hairColor => Icons.palette,
      TagSubCategory.eyeColor => Icons.remove_red_eye,
      TagSubCategory.hairStyle => Icons.face,
      TagSubCategory.expression => Icons.emoji_emotions,
      TagSubCategory.pose => Icons.accessibility_new,
      TagSubCategory.clothing => Icons.checkroom,
      TagSubCategory.accessory => Icons.watch,
      TagSubCategory.bodyFeature => Icons.accessibility,
      TagSubCategory.background => Icons.landscape,
      TagSubCategory.scene => Icons.photo_camera,
      TagSubCategory.style => Icons.brush,
      TagSubCategory.characterCount => Icons.group,
      _ => Icons.label,
    };
  }
}
