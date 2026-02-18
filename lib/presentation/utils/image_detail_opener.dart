import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/common/image_detail/image_detail_data.dart';
import '../widgets/common/image_detail/image_detail_viewer.dart';

/// 图像详情页打开器
///
/// 提供统一的详情页打开功能，包含：
/// - 防重复点击机制
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
  static final Map<String, bool> _openingFlags = {};
  static final Map<String, Timer> _resetTimers = {};

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
  /// [key] - 可选的 key，用于区分不同位置的打开操作
  static Future<void> showSingle(
    BuildContext context, {
    required ImageDetailData image,
    bool showMetadataPanel = true,
    ImageDetailCallbacks? callbacks,
    String key = 'default',
  }) async {
    return showMultiple(
      context,
      images: [image],
      initialIndex: 0,
      showMetadataPanel: showMetadataPanel,
      showThumbnails: false,
      callbacks: callbacks,
      key: key,
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
  /// [key] - 可选的 key，用于区分不同位置的打开操作
  static Future<void> showMultiple(
    BuildContext context, {
    required List<ImageDetailData> images,
    int initialIndex = 0,
    bool showMetadataPanel = true,
    bool showThumbnails = true,
    ImageDetailCallbacks? callbacks,
    String key = 'default',
  }) async {
    // 检查是否正在打开
    if (_openingFlags[key] == true) {
      return;
    }

    // 设置标志
    _openingFlags[key] = true;

    // 取消之前的定时器（如果有）
    _resetTimers[key]?.cancel();

    try {
      // 立即打开详情页
      await ImageDetailViewer.show(
        context,
        images: images,
        initialIndex: initialIndex,
        showMetadataPanel: showMetadataPanel,
        showThumbnails: showThumbnails && images.length > 1,
        callbacks: callbacks,
      );
    } finally {
      // 延迟重置标志，防止快速连续点击
      _resetTimers[key] = Timer(const Duration(milliseconds: 300), () {
        _openingFlags[key] = false;
        _resetTimers.remove(key);
      });
    }
  }

  /// 立即打开详情页（不等待）
  ///
  /// 适用于需要立即响应的场景，不阻塞当前调用
  static void showSingleImmediate(
    BuildContext context, {
    required ImageDetailData image,
    bool showMetadataPanel = true,
    ImageDetailCallbacks? callbacks,
    String? heroTag,
    String key = 'default',
  }) {
    // 检查是否正在打开
    if (_openingFlags[key] == true) {
      return;
    }

    // 设置标志
    _openingFlags[key] = true;

    // 取消之前的定时器（如果有）
    _resetTimers[key]?.cancel();

    // 使用 microtask 确保不阻塞当前帧
    Future.microtask(() {
      if (!context.mounted) {
        _openingFlags[key] = false;
        return;
      }

      ImageDetailViewer.showSingle(
        context,
        image: image,
        showMetadataPanel: showMetadataPanel,
        callbacks: callbacks,
        heroTag: heroTag,
      ).whenComplete(() {
        // 详情页关闭后重置标志
        _resetTimers[key] = Timer(const Duration(milliseconds: 300), () {
          _openingFlags[key] = false;
          _resetTimers.remove(key);
        });
      });
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
    String key = 'default',
  }) {
    // 检查是否正在打开
    if (_openingFlags[key] == true) {
      return;
    }

    // 设置标志
    _openingFlags[key] = true;

    // 取消之前的定时器（如果有）
    _resetTimers[key]?.cancel();

    // 使用 microtask 确保不阻塞当前帧
    Future.microtask(() {
      if (!context.mounted) {
        _openingFlags[key] = false;
        return;
      }

      ImageDetailViewer.show(
        context,
        images: images,
        initialIndex: initialIndex,
        showMetadataPanel: showMetadataPanel,
        showThumbnails: showThumbnails && images.length > 1,
        callbacks: callbacks,
      ).whenComplete(() {
        // 详情页关闭后重置标志
        _resetTimers[key] = Timer(const Duration(milliseconds: 300), () {
          _openingFlags[key] = false;
          _resetTimers.remove(key);
        });
      });
    });
  }

  /// 强制重置指定 key 的标志
  ///
  /// 在特殊情况下使用，如页面销毁时
  static void reset(String key) {
    _openingFlags[key] = false;
    _resetTimers[key]?.cancel();
    _resetTimers.remove(key);
  }

  /// 强制重置所有标志
  ///
  /// 在应用重置或测试时使用
  static void resetAll() {
    for (final timer in _resetTimers.values) {
      timer.cancel();
    }
    _resetTimers.clear();
    _openingFlags.clear();
  }

  /// 检查指定 key 是否正在打开
  static bool isOpening(String key) {
    return _openingFlags[key] == true;
  }
}
