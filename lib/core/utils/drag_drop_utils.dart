import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models/gallery/local_image_record.dart';

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
  const ImageDragData({
    required this.record,
    this.previewBytes,
  });

  /// 从 LocalImageRecord 创建拖拽数据
  factory ImageDragData.fromRecord(
    LocalImageRecord record, {
    Uint8List? previewBytes,
  }) {
    return ImageDragData(
      record: record,
      previewBytes: previewBytes,
    );
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
/// 基于 entry_list_item.dart 的 _buildDragFeedback 实现
///
/// [theme] - 当前主题
/// [dragData] - 拖拽数据
/// [width] - 预览宽度，默认 240
/// [hintText] - 操作提示文字，如 "拖拽到分类" 或 "拖拽以分享"
/// [showHint] - 是否显示操作提示，默认 true
Widget buildImageDragFeedback(
  ThemeData theme,
  ImageDragData dragData, {
  double width = 240,
  String? hintText,
  bool showHint = true,
}) {
  return Material(
    elevation: 12,
    borderRadius: BorderRadius.circular(10),
    color: theme.colorScheme.surfaceContainerHigh,
    shadowColor: Colors.black54,
    child: Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // 缩略图
          _buildThumbnail(theme, dragData),
          const SizedBox(width: 8),
          // 信息
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dragData.fileName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 12,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatFileSize(dragData.record.size),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                // 操作提示
                if (showHint) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.drive_file_move_outline,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hintText ?? '拖拽以分享',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 构建缩略图
///
/// 优先使用预览字节数据，其次尝试从文件路径加载缩略图
Widget _buildThumbnail(ThemeData theme, ImageDragData dragData) {
  // 如果有预览字节数据，使用内存图像
  if (dragData.previewBytes != null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.memory(
        dragData.previewBytes!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(theme);
        },
      ),
    );
  }

  // 尝试从文件路径加载缩略图
  if (dragData.path.isNotEmpty) {
    final file = File(dragData.path);
    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          file,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFileTypeIcon(theme, dragData);
          },
        ),
      );
    }
  }

  // 使用文件类型图标作为占位符
  return _buildFileTypeIcon(theme, dragData);
}

/// 构建文件类型图标占位符
Widget _buildFileTypeIcon(ThemeData theme, ImageDragData dragData) {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Icon(
      dragData.isPng ? Icons.image : Icons.insert_drive_file,
      size: 20,
      color: theme.colorScheme.primary,
    ),
  );
}

/// 构建占位符
Widget _buildPlaceholder(ThemeData theme) {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Icon(
      Icons.broken_image,
      size: 20,
      color: theme.colorScheme.outline,
    ),
  );
}

/// 格式化文件大小
String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
