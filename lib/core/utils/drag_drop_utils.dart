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
}) {
  final colorScheme = theme.colorScheme;
  
  return Material(
    elevation: 8,
    shadowColor: Colors.black.withOpacity(0.3),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: width,
      height: showHint ? 108 : 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 底层：图片占满整个卡片
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
                      Colors.black.withOpacity(0.7),
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
                            color: Colors.black.withOpacity(0.8),
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
                        color: Colors.white.withOpacity(0.9),
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
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

/// 构建图片区域
///
/// 图片占满整个空间
Widget _buildImageSection(ThemeData theme, ImageDragData dragData) {
  final colorScheme = theme.colorScheme;
  
  // 如果有预览数据或文件存在，显示图片
  if (dragData.previewBytes != null || 
      (dragData.path.isNotEmpty && File(dragData.path).existsSync())) {
    return _buildImageContent(dragData);
  }
  
  // 占位符样式
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
          color: colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          dragData.isPng ? Icons.image_rounded : Icons.insert_drive_file_rounded,
          size: 22,
          color: colorScheme.primary.withOpacity(0.6),
        ),
      ),
    ),
  );
}

/// 构建图片内容
Widget _buildImageContent(ImageDragData dragData) {
  if (dragData.previewBytes != null) {
    return Image.memory(
      dragData.previewBytes!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
    );
  }
  
  return Image.file(
    File(dragData.path),
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
  );
}

/// 错误占位符
Widget _buildErrorPlaceholder() {
  return Center(
    child: Icon(
      Icons.broken_image_rounded,
      size: 24,
      color: Colors.grey[400],
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
