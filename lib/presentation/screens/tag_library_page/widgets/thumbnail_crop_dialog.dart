import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../l10n/app_localizations.dart';

/// 缩略图裁剪调整结果
class ThumbnailCropResult {
  final double offsetX;
  final double offsetY;
  final double scale;

  const ThumbnailCropResult({
    required this.offsetX,
    required this.offsetY,
    required this.scale,
  });

  @override
  String toString() =>
      'ThumbnailCropResult(offsetX: $offsetX, offsetY: $offsetY, scale: $scale)';
}

/// 缩略图裁剪调整对话框
///
/// 显示完整图像，用户通过拖拽矩形框选择显示区域。
/// 矩形框的比例与 EntryCard 一致。
class ThumbnailCropDialog extends StatefulWidget {
  final String imagePath;
  final double initialOffsetX;
  final double initialOffsetY;
  final double initialScale;
  final ValueChanged<ThumbnailCropResult> onConfirm;

  const ThumbnailCropDialog({
    super.key,
    required this.imagePath,
    this.initialOffsetX = 0.0,
    this.initialOffsetY = 0.0,
    this.initialScale = 1.0,
    required this.onConfirm,
  });

  @override
  State<ThumbnailCropDialog> createState() => _ThumbnailCropDialogState();
}

class _ThumbnailCropDialogState extends State<ThumbnailCropDialog> {
  // 图像尺寸
  Size? _imageSize;

  // 裁剪框状态
  double _cropX = 0.0; // 裁剪框中心 X（相对于图像中心）
  double _cropY = 0.0; // 裁剪框中心 Y（相对于图像中心）
  double _cropScale = 1.0; // 裁剪框缩放（1.0 = 完整显示图像）

  // 显示区域尺寸
  static const double _displayWidth = 640.0;
  static const double _displayHeight = 360.0;

  // EntryCard 比例
  static const double _cardAspectRatio = 2.5; // 200 / 80

  @override
  void initState() {
    super.initState();
    _cropScale = widget.initialScale.clamp(1.0, 3.0);
    _loadImageSize();
  }

  /// 加载图像尺寸
  void _loadImageSize() {
    final imageProvider = FileImage(File(widget.imagePath));
    imageProvider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool synchronousCall) {
        if (mounted) {
          setState(() {
            _imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
            // 根据初始 offset 计算裁剪框位置
            _cropX = widget.initialOffsetX;
            _cropY = widget.initialOffsetY;
          });
        }
      }),
    );
  }

  /// 计算图像在显示区域中的尺寸（保持比例）
  Size get _displayedImageSize {
    if (_imageSize == null) return const Size(_displayWidth, _displayHeight);

    final imageAspectRatio = _imageSize!.width / _imageSize!.height;
    const displayAspectRatio = _displayWidth / _displayHeight;

    if (imageAspectRatio > displayAspectRatio) {
      // 图像更宽，以宽度为准
      const width = _displayWidth;
      final height = width / imageAspectRatio;
      return Size(width, height);
    } else {
      // 图像更高，以高度为准
      const height = _displayHeight;
      final width = height * imageAspectRatio;
      return Size(width, height);
    }
  }

  /// 计算裁剪框尺寸
  Size get _cropBoxSize {
    final displayedSize = _displayedImageSize;

    // 裁剪框的比例是 EntryCard 的比例
    // 当 scale = 1.0 时，裁剪框尽可能大但保持比例
    // 当 scale > 1.0 时，裁剪框变小（放大图像）

    // 基础裁剪框尺寸（scale = 1.0）
    double baseWidth, baseHeight;

    if (displayedSize.width / displayedSize.height > _cardAspectRatio) {
      // 图像比裁剪框更宽，以高度为准
      baseHeight = displayedSize.height;
      baseWidth = baseHeight * _cardAspectRatio;
    } else {
      // 图像比裁剪框更高，以宽度为准
      baseWidth = displayedSize.width;
      baseHeight = baseWidth / _cardAspectRatio;
    }

    // 根据缩放调整裁剪框大小
    final scaleFactor = 1.0 / _cropScale;
    return Size(baseWidth * scaleFactor, baseHeight * scaleFactor);
  }

  /// 处理拖拽
  void _onPanUpdate(DragUpdateDetails details) {
    if (_imageSize == null) return;

    setState(() {
      // 将像素偏移转换为相对偏移（-1.0 ~ 1.0）
      final displayedSize = _displayedImageSize;
      final maxOffsetX = (displayedSize.width - _cropBoxSize.width) / 2;
      final maxOffsetY = (displayedSize.height - _cropBoxSize.height) / 2;

      if (maxOffsetX > 0) {
        _cropX += details.delta.dx / maxOffsetX;
        _cropX = _cropX.clamp(-1.0, 1.0);
      }
      if (maxOffsetY > 0) {
        _cropY += details.delta.dy / maxOffsetY;
        _cropY = _cropY.clamp(-1.0, 1.0);
      }
    });
  }

  /// 处理缩放
  void _onScaleUpdate(double newScale) {
    setState(() {
      _cropScale = newScale.clamp(1.0, 3.0);
      // 缩放时重新约束位置
      _cropX = _cropX.clamp(-1.0, 1.0);
      _cropY = _cropY.clamp(-1.0, 1.0);
    });
  }

  /// 重置
  void _reset() {
    setState(() {
      _cropX = 0.0;
      _cropY = 0.0;
      _cropScale = 1.0;
    });
  }

  /// 确认
  void _confirm() {
    widget.onConfirm(
      ThumbnailCropResult(
        offsetX: _cropX,
        offsetY: _cropY,
        scale: _cropScale,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(theme, l10n),

            // 调整区域
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 提示文字
                      _buildHint(theme, l10n),
                      const SizedBox(height: 12),

                      // 图像调整区域
                      _buildAdjustArea(),
                      const SizedBox(height: 16),

                      // 实时预览
                      _buildLivePreview(theme, l10n),
                      const SizedBox(height: 16),

                      // 缩放控制
                      _buildScaleControl(theme),
                    ],
                  ),
                ),
              ),
            ),

            // 底部按钮
            _buildFooter(theme, l10n),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.crop_free,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            l10n.tagLibrary_adjustThumbnailTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: l10n.common_cancel,
          ),
        ],
      ),
    );
  }

  /// 构建提示
  Widget _buildHint(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        Icon(
          Icons.touch_app,
          size: 16,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.tagLibrary_dragToMove,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建调整区域
  Widget _buildAdjustArea() {
    if (_imageSize == null) {
      return Container(
        width: _displayWidth,
        height: _displayHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade900,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: _displayWidth,
      height: _displayHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade900,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Listener(
          onPointerSignal: (PointerSignalEvent event) {
            if (event is PointerScrollEvent) {
              // 滚轮缩放：向上滚动放大，向下滚动缩小
              final delta = event.scrollDelta.dy;
              final scaleDelta = delta > 0 ? -0.1 : 0.1;
              final newScale = (_cropScale + scaleDelta).clamp(1.0, 3.0);
              if (newScale != _cropScale) {
                setState(() {
                  _cropScale = newScale;
                });
              }
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景图像
              Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
                width: _displayedImageSize.width,
                height: _displayedImageSize.height,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade800,
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 48, color: Colors.white38),
                  ),
                ),
              ),

              // 遮罩层（裁剪框外的暗色区域）
              CustomPaint(
                size: Size(_displayedImageSize.width, _displayedImageSize.height),
                painter: _CropOverlayPainter(
                  cropBoxSize: _cropBoxSize,
                  offsetX: _cropX,
                  offsetY: _cropY,
                ),
              ),

              // 可拖拽的裁剪框
              Positioned(
                left: (_displayWidth - _cropBoxSize.width) / 2 + _cropX * (_displayedImageSize.width - _cropBoxSize.width) / 2,
                top: (_displayHeight - _cropBoxSize.height) / 2 + _cropY * (_displayedImageSize.height - _cropBoxSize.height) / 2,
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  child: Container(
                  width: _cropBoxSize.width,
                  height: _cropBoxSize.height,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.open_with,
                      color: Colors.white,
                      size: 24,
                    ),
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

/// 构建实时预览
  Widget _buildLivePreview(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tagLibrary_livePreview,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 实时预览图
              Container(
                width: 200,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildPreviewImage(),
                ),
              ),
              const SizedBox(width: 16),
              // 数值显示
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildValueRow(
                      l10n.tagLibrary_horizontalOffset,
                      _cropX.toStringAsFixed(2),
                    ),
                    const SizedBox(height: 4),
                    _buildValueRow(
                      l10n.tagLibrary_verticalOffset,
                      _cropY.toStringAsFixed(2),
                    ),
                    const SizedBox(height: 4),
                    _buildValueRow(
                      l10n.tagLibrary_zoomRatio,
                      '${_cropScale.toStringAsFixed(2)}x',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建预览图片（应用变换）
  Widget _buildPreviewImage() {
    if (_imageSize == null) {
      return Container(color: Colors.grey.shade800);
    }

    // 计算预览图中的裁剪区域
    final displayedSize = _displayedImageSize;
    final cropSize = _cropBoxSize;

    // 裁剪框相对于图像的位置
    final maxOffsetX = (displayedSize.width - cropSize.width).clamp(0, double.infinity);
    final maxOffsetY = (displayedSize.height - cropSize.height).clamp(0, double.infinity);

    final offsetX = _cropX * maxOffsetX / 2;
    final offsetY = _cropY * maxOffsetY / 2;

    // 将显示坐标转换为图像坐标
    final imageScaleX = _imageSize!.width / displayedSize.width;
    final imageScaleY = _imageSize!.height / displayedSize.height;

    final sourceCropWidth = cropSize.width * imageScaleX;
    final sourceCropHeight = cropSize.height * imageScaleY;
    final sourceOffsetX = (_imageSize!.width - sourceCropWidth) / 2 + offsetX * imageScaleX;
    final sourceOffsetY = (_imageSize!.height - sourceCropHeight) / 2 + offsetY * imageScaleY;

    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: Offset(-sourceOffsetX, -sourceOffsetY),
          child: Image.file(
            File(widget.imagePath),
            fit: BoxFit.none,
            width: _imageSize!.width,
            height: _imageSize!.height,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  /// 构建数值行
  Widget _buildValueRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// 构建缩放控制
  Widget _buildScaleControl(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.zoom_out,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          Expanded(
            child: Slider(
              value: _cropScale,
              min: 1.0,
              max: 3.0,
              divisions: 20,
              label: '${_cropScale.toStringAsFixed(2)}x',
              onChanged: _onScaleUpdate,
            ),
          ),
          Icon(
            Icons.zoom_in,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_cropScale.toStringAsFixed(2)}x',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildFooter(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 重置按钮
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.common_reset),
          ),
          const SizedBox(width: 8),
          // 取消按钮
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_cancel),
          ),
          const SizedBox(width: 8),
          // 确认按钮
          FilledButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check),
            label: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
  }
}

/// 裁剪框遮罩绘制器
class _CropOverlayPainter extends CustomPainter {
  final Size cropBoxSize;
  final double offsetX;
  final double offsetY;

  _CropOverlayPainter({
    required this.cropBoxSize,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // 计算裁剪框位置（中心对齐）
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final maxOffsetX = (size.width - cropBoxSize.width) / 2;
    final maxOffsetY = (size.height - cropBoxSize.height) / 2;

    final cropLeft = centerX - cropBoxSize.width / 2 + offsetX * maxOffsetX;
    final cropTop = centerY - cropBoxSize.height / 2 + offsetY * maxOffsetY;
    final cropRight = cropLeft + cropBoxSize.width;
    final cropBottom = cropTop + cropBoxSize.height;

    // 绘制整个背景，然后挖空中间
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 绘制半透明背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // 使用混合模式清除中间区域
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear;

    canvas.drawRect(
      Rect.fromLTRB(cropLeft, cropTop, cropRight, cropBottom),
      clearPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropBoxSize != cropBoxSize ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.offsetY != offsetY;
  }
}

/// 显示缩略图裁剪对话框的便捷方法
Future<void> showThumbnailCropDialog({
  required BuildContext context,
  required String imagePath,
  double initialOffsetX = 0.0,
  double initialOffsetY = 0.0,
  double initialScale = 1.0,
  required ValueChanged<ThumbnailCropResult> onConfirm,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => ThumbnailCropDialog(
      imagePath: imagePath,
      initialOffsetX: initialOffsetX,
      initialOffsetY: initialOffsetY,
      initialScale: initialScale,
      onConfirm: onConfirm,
    ),
  );
}
