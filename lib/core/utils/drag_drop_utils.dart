import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models/gallery/local_image_record.dart';

const protectedDragFeedbackMarkerKey = ValueKey<String>(
  'protected-drag-feedback-marker',
);

/// 拖拽数据格式常量
class DragDropFormats {
  /// PNG 图像格式
  static const String png = 'image/png';

  /// 文件 URI 格式
  static const String fileUri = 'text/uri-list';

  /// 自定义本地图像记录格式
  static const String localImageRecord = 'application/x-local-image-record';
}

/// 图像拖拽数据包装类
///
/// 用于在拖拽操作中传递 LocalImageRecord 数据
class ImageDragData {
  /// 图像记录
  final LocalImageRecord record;

  /// 可选的预览图像数据
  final Uint8List? previewBytes;

  /// 创建图像拖拽数据
  const ImageDragData({required this.record, this.previewBytes});

  /// 从 LocalImageRecord 创建拖拽数据
  factory ImageDragData.fromRecord(
    LocalImageRecord record, {
    Uint8List? previewBytes,
  }) {
    return ImageDragData(record: record, previewBytes: previewBytes);
  }

  /// 获取文件路径
  String get path => record.path;

  /// 获取文件名
  String get fileName {
    final parts = record.path.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : record.path;
  }

  /// 获取文件扩展名
  String get extension {
    final name = fileName;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(dotIndex + 1).toLowerCase() : '';
  }

  /// 是否为 PNG 格式
  bool get isPng => extension == 'png';
}

/// 构建图像拖拽预览 Widget
///
/// 小而精美的设计，图片占满，名称作为底部覆层
///
/// [theme] - 当前主题
/// [dragData] - 拖拽数据
/// [width] - 预览宽度，默认 80
/// [hintText] - 操作提示文字
/// [showHint] - 是否显示操作提示
Widget buildImageDragFeedback(
  ThemeData theme,
  ImageDragData dragData, {
  double width = 80,
  String? hintText,
  bool showHint = true,
  Widget? previewWidget,
  ImageProvider? previewProvider,
}) {
  final colorScheme = theme.colorScheme;

  return Material(
    elevation: 8,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: width,
      height: showHint ? 108 : 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 底层：图片占满整个卡片
            if (previewWidget != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: width,
                      height: showHint ? 108 : 92,
                      child: previewWidget,
                    ),
                  ),
                ),
              )
            else if (previewProvider != null)
              Image(
                image: previewProvider,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) =>
                    _buildPlaceholder(theme, dragData),
              )
            else
              _buildImageSection(theme, dragData),

            // 中层：底部渐变遮罩（让文字更清晰）
            Positioned(
              left: 0,
              right: 0,
              bottom: showHint ? 20 : 0,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),

            // 上层：文件名和大小（覆层在底部）
            Positioned(
              left: 0,
              right: 0,
              bottom: showHint ? 22 : 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dragData.fileName,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatFileSize(dragData.record.size),
                      style: TextStyle(
                        fontSize: 7,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 提示区域（固定在底部，不透明背景）
            if (showHint)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(11),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 9,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        hintText ?? '拖拽以分享',
                        style: TextStyle(
                          fontSize: 8,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Feedback used while external drag protection is effective. It deliberately
/// accepts no image bytes, file path, file name, or encoded size.
Widget buildProtectedImageDragFeedback(
  ThemeData theme, {
  double width = 280,
  String? hintText,
  int? pixelWidth,
  int? pixelHeight,
  String? format,
}) {
  final structuredDetails = <String>[
    if (pixelWidth != null && pixelHeight != null) '${pixelWidth}x$pixelHeight',
    if (format != null && format.isNotEmpty) format.toUpperCase(),
  ].join('  ');

  return RepaintBoundary(
    key: protectedDragFeedbackMarkerKey,
    child: Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: 108,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF123B3A)),
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: width * 0.36,
                height: 18,
                color: const Color(0xFFFFB000),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: width * 0.18,
                height: 18,
                color: const Color(0xFF00D6C9),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'NAI SAFE DRAG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (structuredDetails.isNotEmpty)
                    Text(
                      structuredDetails,
                      style: const TextStyle(
                        color: Color(0xFFD6FFFA),
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
            ),
            if (hintText != null && hintText.isNotEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  height: 20,
                  alignment: Alignment.center,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Text(
                    hintText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 构建图片区域
///
/// 图片占满整个空间，优先使用 previewBytes，否则从文件路径加载
Widget _buildImageSection(ThemeData theme, ImageDragData dragData) {
  // 如果有预览数据，使用内存图片
  if (dragData.previewBytes != null) {
    return Image.memory(
      dragData.previewBytes!,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _buildPlaceholder(theme, dragData),
    );
  }

  // 否则直接从文件路径加载（异步加载，无需等待）
  if (dragData.path.isNotEmpty) {
    final file = File(dragData.path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _buildPlaceholder(theme, dragData),
      );
    }
  }

  // 回退到占位符
  return _buildPlaceholder(theme, dragData);
}

/// 构建占位符
Widget _buildPlaceholder(ThemeData theme, ImageDragData dragData) {
  final colorScheme = theme.colorScheme;
  return Container(
    width: double.infinity,
    height: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorScheme.surfaceContainerHighest,
          colorScheme.surfaceContainerHigh,
        ],
      ),
    ),
    child: Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          dragData.isPng
              ? Icons.image_rounded
              : Icons.insert_drive_file_rounded,
          size: 22,
          color: colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
    ),
  );
}

/// 格式化文件大小
String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)}KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
