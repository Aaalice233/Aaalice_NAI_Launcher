import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../../core/utils/app_logger.dart';
import '../../../../themes/design_tokens.dart';
import '../../../../widgets/common/image_picker_card/_internal/picker_handler.dart';

/// Vibe 预览图拖拽区
///
/// 支持：
/// - InteractiveViewer 缩放/平移
/// - DropRegion 拖拽设置预览图
/// - 右下角"更换预览图"按钮
/// - 拖拽覆盖层（虚线边框 + 提示）
/// - 图片自动缩放到最大 512×512
class VibePreviewDropZone extends StatefulWidget {
  /// 当前预览图数据
  final Uint8List? imageBytes;

  /// 预览图变更回调
  final ValueChanged<Uint8List>? onThumbnailChanged;

  /// 关闭回调
  final VoidCallback? onClose;

  const VibePreviewDropZone({
    super.key,
    this.imageBytes,
    this.onThumbnailChanged,
    this.onClose,
  });

  @override
  State<VibePreviewDropZone> createState() => _VibePreviewDropZoneState();
}

class _VibePreviewDropZoneState extends State<VibePreviewDropZone> {
  final TransformationController _transformationController =
      TransformationController();
  bool _isDragging = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.2).clamp(0.5, 4.0);
    _applyScale(newScale);
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.2).clamp(0.5, 4.0);
    _applyScale(newScale);
  }

  void _applyScale(double scale) {
    final size = context.size;
    if (size == null) return;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final matrix = Matrix4.identity()
      ..translate(centerX - centerX * scale, centerY - centerY * scale)
      ..scale(scale);

    _transformationController.value = matrix;
  }

  Future<void> _pickImage() async {
    final result = await PickerHandler.pickImage(
      onError: (msg) => AppLogger.w(msg, 'VibePreviewDropZone'),
    );
    if (result == null) return;

    final resized = await _resizeImage(result.bytes);
    widget.onThumbnailChanged?.call(resized);
  }

  Future<void> _handleDrop(PerformDropEvent event) async {
    setState(() => _isDragging = false);

    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;

      // 尝试读取图片格式（SimpleFileFormat 需用 getFile 而非 getValue）
      for (final format in [Formats.png, Formats.jpeg]) {
        if (reader.canProvide(format)) {
          final progress = reader.getFile(
            format,
            (file) async {
              try {
                final bytes = await file.readAll();
                if (!mounted) return;
                final resized = await _resizeImage(bytes);
                widget.onThumbnailChanged?.call(resized);
              } catch (e) {
                AppLogger.w(
                  'Failed to read dropped image: $e',
                  'VibePreviewDropZone',
                );
              }
            },
            onError: (e) {
              AppLogger.w(
                'Failed to get dropped file: $e',
                'VibePreviewDropZone',
              );
            },
          );
          // 关键检查：如果返回 null，说明格式不可用
          if (progress != null) return;
        }
      }
    }
  }

  /// 缩放图片到最大 512×512
  static Future<Uint8List> _resizeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final srcW = image.width;
      final srcH = image.height;

      if (srcW <= 512 && srcH <= 512) {
        image.dispose();
        return bytes;
      }

      final scale = 512.0 / (srcW > srcH ? srcW : srcH);
      final dstW = (srcW * scale).round();
      final dstH = (srcH * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()),
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()),
        Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );

      final picture = recorder.endRecording();
      final resized = await picture.toImage(dstW, dstH);
      final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();
      resized.dispose();
      picture.dispose();

      return byteData?.buffer.asUint8List() ?? bytes;
    } catch (e) {
      AppLogger.w('Failed to resize image: $e', 'VibePreviewDropZone');
      return bytes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          if (!_isDragging) setState(() => _isDragging = true);
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (_) {
        if (_isDragging) setState(() => _isDragging = false);
      },
      onPerformDrop: (event) async {
        // 重要：不要等待 _handleDrop 完成，让拖放回调立即返回
        unawaited(_handleDrop(event));
        return;
      },
      child: Stack(
        children: [
          // 图片预览
          GestureDetector(
            onDoubleTap: _resetZoom,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: widget.imageBytes != null
                    ? Image.memory(
                        widget.imageBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
          ),

          // 拖拽覆盖层
          if (_isDragging) _buildDragOverlay(),

          // 关闭按钮（左上角圆形按钮）
          Positioned(
            top: DesignTokens.spacingMd,
            left: DesignTokens.spacingMd,
            child: _buildCircularCloseButton(
              onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
            ),
          ),

          // 缩放控制 + 更换预览图
          Positioned(
            bottom: DesignTokens.spacingMd,
            right: DesignTokens.spacingMd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconButton(
                  icon: Icons.add,
                  onPressed: _zoomIn,
                  tooltip: '放大',
                ),
                const SizedBox(height: DesignTokens.spacingXs),
                _buildIconButton(
                  icon: Icons.remove,
                  onPressed: _zoomOut,
                  tooltip: '缩小',
                ),
                const SizedBox(height: DesignTokens.spacingXs),
                _buildIconButton(
                  icon: Icons.fit_screen,
                  onPressed: _resetZoom,
                  tooltip: '重置缩放',
                ),
                const SizedBox(height: DesignTokens.spacingMd),
                if (widget.onThumbnailChanged != null)
                  _buildIconButton(
                    icon: Icons.image_outlined,
                    onPressed: _pickImage,
                    tooltip: '更换预览图',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 64, color: Colors.white54),
        SizedBox(height: DesignTokens.spacingMd),
        Text(
          '无预览图像',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        SizedBox(height: DesignTokens.spacingXs),
        Text(
          '拖拽图片到此处设置预览图',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildDragOverlay() {
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.all(DesignTokens.spacingLg),
        decoration: BoxDecoration(
          borderRadius: DesignTokens.borderRadiusXl,
          border: Border.all(
            color: Colors.white.withOpacity(0.6),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          color: Colors.white.withOpacity(0.08),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.file_download_outlined,
                  size: 48, color: Colors.white70,),
              SizedBox(height: DesignTokens.spacingSm),
              Text(
                '释放以设置预览图',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withOpacity(0.5),
        borderRadius: DesignTokens.borderRadiusLg,
        child: InkWell(
          onTap: onPressed,
          borderRadius: DesignTokens.borderRadiusLg,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  /// 构建左上角圆形关闭按钮
  Widget _buildCircularCloseButton({
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: '关闭 (Esc)',
      child: Material(
        color: Colors.black.withOpacity(0.5),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.close, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
