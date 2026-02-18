import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '_internal/loading_overlay.dart';
import '_internal/picker_handler.dart';
import '_internal/preview_thumbnail.dart';
import 'image_picker_result.dart';
import 'image_picker_type.dart';

export 'image_picker_result.dart';
export 'image_picker_type.dart';

/// 通用图像选择卡片组件
///
/// 支持：
/// - 图像/文件/目录三种选择模式
/// - 悬浮效果和边缘发光
/// - 拖拽上传
/// - 即时 loading 反馈
/// - 缩略图预览
class ImagePickerCard extends StatefulWidget {
  /// 卡片标签
  final String label;

  /// 图标
  final IconData icon;

  /// 提示文本（如"可选"）
  final String? hintText;

  /// 是否必填
  final bool isRequired;

  /// 是否支持多选
  final bool allowMultiple;

  /// 选择类型
  final ImagePickerType type;

  /// 自定义扩展名（type=file 时有效）
  final List<String>? allowedExtensions;

  /// 卡片宽度
  final double? width;

  /// 卡片高度（默认 100）
  final double height;

  /// 是否启用边缘发光效果
  final bool enableGlowEffect;

  /// 是否启用拖拽上传
  final bool enableDragDrop;

  /// 已选图像数据（用于显示预览）
  final Uint8List? selectedImage;

  /// 已选路径（用于目录/文件模式显示）
  final String? selectedPath;

  /// 图像/单文件选择回调
  /// [bytes] 文件字节数据
  /// [fileName] 文件名
  /// [path] 文件路径（可能为空，如 Web 平台）
  final void Function(Uint8List bytes, String fileName, String? path)?
      onImageSelected;

  /// 多文件选择回调
  final void Function(List<ImagePickerResult> files)? onMultipleSelected;

  /// 目录选择回调
  final void Function(String path)? onDirectorySelected;

  /// 错误回调
  final void Function(String error)? onError;

  /// 清除已选回调
  final VoidCallback? onClear;

  /// 自定义点击回调（设置后将跳过内置的文件选择逻辑）
  final VoidCallback? onTap;

  const ImagePickerCard({
    super.key,
    required this.label,
    required this.icon,
    this.hintText,
    this.isRequired = false,
    this.allowMultiple = false,
    this.type = ImagePickerType.image,
    this.allowedExtensions,
    this.width,
    this.height = 100,
    this.enableGlowEffect = true,
    this.enableDragDrop = true,
    this.selectedImage,
    this.selectedPath,
    this.onImageSelected,
    this.onMultipleSelected,
    this.onDirectorySelected,
    this.onError,
    this.onClear,
    this.onTap,
  });

  @override
  State<ImagePickerCard> createState() => _ImagePickerCardState();
}

class _ImagePickerCardState extends State<ImagePickerCard> {
  bool _isHovered = false;
  bool _isLoading = false;
  bool _isDragOver = false;

  bool get _hasSelection =>
      widget.selectedImage != null || widget.selectedPath != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget card = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: _isLoading ? SystemMouseCursors.wait : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isLoading ? null : _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(
              color: _getBorderColor(theme),
              width: _isHovered || _isDragOver ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
            color: _getBackgroundColor(theme),
            boxShadow: _buildBoxShadow(theme),
          ),
          child: Stack(
            children: [
              // 主内容
              _buildContent(theme),

              // 加载状态覆盖层
              if (_isLoading) const LoadingOverlay(),

              // 清除按钮（有选择且悬浮时）
              if (_hasSelection && _isHovered && widget.onClear != null)
                _buildClearButton(theme),

              // 拖拽覆盖层
              if (_isDragOver) _buildDragOverlay(theme),
            ],
          ),
        ),
      ),
    );

    // 包装拖拽支持
    if (widget.enableDragDrop && widget.type != ImagePickerType.directory) {
      card = _wrapWithDropRegion(card);
    }

    return card;
  }

  Widget _buildContent(ThemeData theme) {
    if (_hasSelection) {
      return _buildSelectedContent(theme);
    }
    return _buildDefaultContent(theme);
  }

  /// 默认内容（未选择状态）
  Widget _buildDefaultContent(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.icon,
            size: 28,
            color: _isHovered || _isDragOver
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _isHovered || _isDragOver
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.hintText != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.hintText!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 已选择内容（带缩略图预览）
  Widget _buildSelectedContent(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final thumbnailSize = widget.height - 16;
        // 宽度足够时显示横排布局，否则只显示缩略图
        final showTextInfo = constraints.maxWidth > thumbnailSize + 80;

        if (!showTextInfo) {
          // 紧凑模式：只显示缩略图
          return Center(
            child: PreviewThumbnail(
              imageBytes: widget.selectedImage,
              imagePath: widget.selectedPath,
              fallbackIcon: widget.icon,
              size: constraints.maxWidth.clamp(40, thumbnailSize),
              borderRadius: 8,
            ),
          );
        }

        // 标准模式：缩略图 + 文字信息
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // 缩略图
              PreviewThumbnail(
                imageBytes: widget.selectedImage,
                imagePath: widget.selectedPath,
                fallbackIcon: widget.icon,
                size: thumbnailSize,
                borderRadius: 8,
              ),
              const SizedBox(width: 12),
              // 标签和文件名
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.selectedPath != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _getDisplayPath(widget.selectedPath!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 清除按钮
  Widget _buildClearButton(ThemeData theme) {
    return Positioned(
      top: 4,
      right: 4,
      child: Material(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onClear,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.close,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// 拖拽覆盖层
  Widget _buildDragOverlay(ThemeData theme) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// 包装拖拽支持
  Widget _wrapWithDropRegion(Widget child) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          if (!_isDragOver) {
            setState(() => _isDragOver = true);
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (event) {
        if (_isDragOver) {
          setState(() => _isDragOver = false);
        }
      },
      onPerformDrop: (event) async {
        setState(() => _isDragOver = false);
        await _handleDrop(event);
      },
      child: child,
    );
  }

  /// 处理拖拽放置
  Future<void> _handleDrop(PerformDropEvent event) async {
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;

      // 尝试获取文件 URI
      if (reader.canProvide(Formats.fileUri)) {
        final progress = reader.getValue(Formats.fileUri, (uri) async {
          if (uri == null) return;

          try {
            final file = File(uri.toFilePath());
            final filePath = file.path;
            final fileName = filePath.split(Platform.pathSeparator).last;
            final bytes = await file.readAsBytes();

            if (mounted) {
              _handleFileResult(bytes, fileName, filePath);
            }
          } catch (e) {
            widget.onError?.call('读取文件失败: $e');
          }
        }, onError: (e) {
          widget.onError?.call('获取文件URI失败: $e');
        });
        // 关键检查：如果返回 null，说明格式不可用
        if (progress != null) return;
      }

      // 尝试获取 PNG 数据
      if (reader.canProvide(Formats.png)) {
        final progress = reader.getFile(Formats.png, (file) async {
          try {
            final bytes = await file.readAll();
            final fileName = file.fileName ?? 'dropped_image.png';
            if (mounted) {
              _handleFileResult(Uint8List.fromList(bytes), fileName, null);
            }
          } catch (e) {
            widget.onError?.call('读取图片失败: $e');
          }
        }, onError: (e) {
          widget.onError?.call('获取PNG失败: $e');
        });
        // 关键检查：如果返回 null，说明格式不可用
        if (progress != null) return;
      }

      // 尝试获取 JPEG 数据
      if (reader.canProvide(Formats.jpeg)) {
        final progress = reader.getFile(Formats.jpeg, (file) async {
          try {
            final bytes = await file.readAll();
            final fileName = file.fileName ?? 'dropped_image.jpg';
            if (mounted) {
              _handleFileResult(Uint8List.fromList(bytes), fileName, null);
            }
          } catch (e) {
            widget.onError?.call('读取图片失败: $e');
          }
        }, onError: (e) {
          widget.onError?.call('获取JPEG失败: $e');
        });
        // 关键检查：如果返回 null，说明格式不可用
        if (progress != null) return;
      }
    }
  }

  /// 处理文件结果
  void _handleFileResult(Uint8List bytes, String fileName, String? path) {
    widget.onImageSelected?.call(bytes, fileName, path);
  }

  /// 处理点击事件
  Future<void> _handleTap() async {
    // 如果设置了自定义点击回调，直接调用
    if (widget.onTap != null) {
      HapticFeedback.selectionClick();
      widget.onTap!();
      return;
    }

    // 立即更新 UI 为加载状态
    setState(() => _isLoading = true);

    // 触觉反馈
    HapticFeedback.selectionClick();

    // 确保 UI 刷新
    await Future.delayed(const Duration(milliseconds: 16));

    try {
      switch (widget.type) {
        case ImagePickerType.image:
          await _pickImage();
          break;
        case ImagePickerType.file:
          await _pickFile();
          break;
        case ImagePickerType.directory:
          await _pickDirectory();
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    if (widget.allowMultiple) {
      final results = await PickerHandler.pickMultipleImages(
        onError: widget.onError,
      );
      if (results.isNotEmpty) {
        widget.onMultipleSelected?.call(results);
      }
    } else {
      final result = await PickerHandler.pickImage(
        onError: widget.onError,
      );
      if (result != null) {
        widget.onImageSelected
            ?.call(result.bytes, result.fileName, result.path);
      }
    }
  }

  Future<void> _pickFile() async {
    final extensions = widget.allowedExtensions ?? ['*'];
    final result = await PickerHandler.pickFile(
      extensions: extensions,
      allowMultiple: widget.allowMultiple,
      onError: widget.onError,
    );
    if (result != null) {
      widget.onImageSelected?.call(result.bytes, result.fileName, result.path);
    }
  }

  Future<void> _pickDirectory() async {
    final path = await PickerHandler.pickDirectory(
      onError: widget.onError,
    );
    if (path != null) {
      widget.onDirectorySelected?.call(path);
    }
  }

  Color _getBorderColor(ThemeData theme) {
    if (_isDragOver) {
      return theme.colorScheme.primary;
    }
    if (_hasSelection) {
      return _isHovered
          ? theme.colorScheme.primary
          : theme.colorScheme.primary.withOpacity(0.6);
    }
    return _isHovered
        ? theme.colorScheme.primary
        : theme.colorScheme.outline.withOpacity(0.5);
  }

  Color _getBackgroundColor(ThemeData theme) {
    if (_isDragOver) {
      return theme.colorScheme.primary.withOpacity(0.08);
    }
    if (_hasSelection) {
      return _isHovered
          ? theme.colorScheme.primary.withOpacity(0.08)
          : theme.colorScheme.primary.withOpacity(0.04);
    }
    return _isHovered
        ? theme.colorScheme.primary.withOpacity(0.05)
        : Colors.transparent;
  }

  List<BoxShadow>? _buildBoxShadow(ThemeData theme) {
    if (!widget.enableGlowEffect) return null;
    if (!_isHovered && !_isDragOver) return null;

    return [
      BoxShadow(
        color: theme.colorScheme.primary.withOpacity(0.15),
        blurRadius: 20,
        spreadRadius: 0,
      ),
    ];
  }

  String _getDisplayPath(String path) {
    // 只显示文件名或最后一级目录名
    final parts = path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : path;
  }
}
