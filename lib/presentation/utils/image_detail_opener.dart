import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/common/image_detail/image_detail_data.dart';
import '../widgets/common/image_detail/image_detail_viewer.dart';

/// 图像详情页打开器
///
/// 提供统一的详情页打开功能，包含：
/// - 可选的防重复点击机制
/// - 立即响应（不阻塞 UI）
/// - 统一的回调处理
///
/// 使用示例：
/// ```dart
/// final opener = ImageDetailOpener.of(context);
/// opener.showSingle(imageData);
/// // 或
/// ImageDetailOpener.showSingle(context, image: imageData);
/// ```
class ImageDetailOpener {
  /// 获取全局单例实例
  static ImageDetailOpener of(BuildContext context) {
    return ImageDetailOpener();
  }

  /// 显示单图详情页
  ///
  /// [context] - BuildContext
  /// [image] - 图像详情数据
  /// [showMetadataPanel] - 是否显示元数据面板
  /// [callbacks] - 回调函数
  static Future<void> showSingle(
    BuildContext context, {
    required ImageDetailData image,
    bool showMetadataPanel = true,
    ImageDetailCallbacks? callbacks,
  }) async {
    return showMultiple(
      context,
      images: [image],
      initialIndex: 0,
      showMetadataPanel: showMetadataPanel,
      showThumbnails: false,
      callbacks: callbacks,
    );
  }

  /// 显示多图详情页
  ///
  /// [context] - BuildContext
  /// [images] - 图像详情数据列表
  /// [initialIndex] - 初始显示索引
  /// [showMetadataPanel] - 是否显示元数据面板
  /// [showThumbnails] - 是否显示缩略图
  /// [callbacks] - 回调函数
  static Future<void> showMultiple(
    BuildContext context, {
    required List<ImageDetailData> images,
    int initialIndex = 0,
    bool showMetadataPanel = true,
    bool showThumbnails = true,
    ImageDetailCallbacks? callbacks,
  }) async {
    // 直接打开详情页，不再使用全局互锁
    await ImageDetailViewer.show(
      context,
      images: images,
      initialIndex: initialIndex,
      showMetadataPanel: showMetadataPanel,
      showThumbnails: showThumbnails && images.length > 1,
      callbacks: callbacks,
    );
  }

  /// 立即打开单图详情页（不等待）
  ///
  /// 适用于需要立即响应的场景，不阻塞当前调用
  static void showSingleImmediate(
    BuildContext context, {
    required ImageDetailData image,
    bool showMetadataPanel = true,
    ImageDetailCallbacks? callbacks,
    String? heroTag,
  }) {
    // 使用 microtask 确保不阻塞当前帧
    Future.microtask(() {
      if (!context.mounted) return;

      ImageDetailViewer.showSingle(
        context,
        image: image,
        showMetadataPanel: showMetadataPanel,
        callbacks: callbacks,
        heroTag: heroTag,
      );
    });
  }

  /// 立即打开多图详情页（不等待）
  ///
  /// 适用于需要立即响应的场景，不阻塞当前调用
  static void showMultipleImmediate(
    BuildContext context, {
    required List<ImageDetailData> images,
    int initialIndex = 0,
    bool showMetadataPanel = true,
    bool showThumbnails = true,
    ImageDetailCallbacks? callbacks,
  }) {
    // 使用 microtask 确保不阻塞当前帧
    Future.microtask(() {
      if (!context.mounted) return;

      ImageDetailViewer.show(
        context,
        images: images,
        initialIndex: initialIndex,
        showMetadataPanel: showMetadataPanel,
        showThumbnails: showThumbnails && images.length > 1,
        callbacks: callbacks,
      );
    });
  }
}
