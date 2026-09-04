import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../adaptive/adaptive_presenter.dart';
import 'thumbnail_selection_preview.dart';

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
  double _gestureStartScale = 1.0;
  Offset? _lastGestureFocalPoint;

  // 桌面端保持原有高效预览尺寸，紧凑窗口由实际 constraints 决定。
  static const Size _desktopDisplaySize = Size(640, 360);

  @override
  void initState() {
    super.initState();
    _cropX = widget.initialOffsetX.clamp(-1.0, 1.0);
    _cropY = widget.initialOffsetY.clamp(-1.0, 1.0);
    _cropScale = widget.initialScale.clamp(1.0, 3.0);
    _loadImageSize();
  }

  /// 加载图像尺寸
  void _loadImageSize() {
    final imageProvider = FileImage(File(widget.imagePath));
    imageProvider
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((info, _) {
            if (!mounted) return;
            setState(() {
              _imageSize = Size(
                info.image.width.toDouble(),
                info.image.height.toDouble(),
              );
            });
          }),
        );
  }

  /// 计算图像在当前预览区域中的尺寸（保持比例）
  Size _displayedImageSize(Size displaySize) {
    if (_imageSize == null) return displaySize;
    return displayedThumbnailImageSize(_imageSize!, displaySize);
  }

  /// 计算裁剪框尺寸
  Size _cropBoxSize(Size displayedSize) {
    return thumbnailCropBoxSize(displayedSize, _cropScale);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _cropScale;
    _lastGestureFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size displaySize) {
    if (_imageSize == null) return;

    final previousFocalPoint = _lastGestureFocalPoint;
    final focalDelta = previousFocalPoint == null
        ? Offset.zero
        : details.localFocalPoint - previousFocalPoint;
    _lastGestureFocalPoint = details.localFocalPoint;

    setState(() {
      _cropScale = (_gestureStartScale * details.scale).clamp(1.0, 3.0);
      _moveCropBy(focalDelta, displaySize);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastGestureFocalPoint = null;
  }

  void _moveCropBy(Offset delta, Size displaySize) {
    final displayedSize = _displayedImageSize(displaySize);
    final cropSize = _cropBoxSize(displayedSize);
    final maxOffsetX = (displayedSize.width - cropSize.width) / 2;
    final maxOffsetY = (displayedSize.height - cropSize.height) / 2;

    if (maxOffsetX > 0) {
      _cropX = (_cropX + delta.dx / maxOffsetX).clamp(-1.0, 1.0);
    }
    if (maxOffsetY > 0) {
      _cropY = (_cropY + delta.dy / maxOffsetY).clamp(-1.0, 1.0);
    }
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
      ThumbnailCropResult(offsetX: _cropX, offsetY: _cropY, scale: _cropScale),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compact = constraints.maxWidth < 600;
        final short = constraints.maxHeight < 400;
        final compactActions =
            constraints.maxWidth < 360 ||
            constraints.maxHeight < 360 ||
            textScale >= 2;

        return Align(
          child: SizedBox(
            key: const ValueKey('thumbnail-crop-frame'),
            width: constraints.maxWidth.clamp(0, 720).toDouble(),
            height: constraints.maxHeight.clamp(0, 566).toDouble(),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 16,
                      short ? 8 : 12,
                      compact ? 12 : 16,
                      short ? 8 : 12,
                    ),
                    child: Column(
                      children: [
                        if (!short) ...[
                          _buildHint(theme, l10n),
                          const SizedBox(height: 12),
                        ],
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, previewConstraints) {
                              final displaySize = Size(
                                previewConstraints.maxWidth.clamp(
                                  1,
                                  _desktopDisplaySize.width,
                                ),
                                previewConstraints.maxHeight.clamp(
                                  1,
                                  _desktopDisplaySize.height,
                                ),
                              );
                              return Center(
                                child: ScrollConfiguration(
                                  behavior: const _NoScrollBehavior(),
                                  child: _buildAdjustArea(displaySize),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildFooter(theme, l10n, compactActions: compactActions),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建提示
  Widget _buildHint(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        Icon(Icons.touch_app, size: 16, color: theme.colorScheme.outline),
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
  Widget _buildAdjustArea(Size displaySize) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.grey.shade900,
    );
    if (_imageSize == null) {
      return Container(
        key: const ValueKey('thumbnail-crop-preview'),
        width: displaySize.width,
        height: displaySize.height,
        decoration: decoration,
        child: Center(
          child: CircularProgressIndicator(
            value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
          ),
        ),
      );
    }

    final displayedSize = _displayedImageSize(displaySize);
    final cropSize = _cropBoxSize(displayedSize);
    final imageOffsetX = (displaySize.width - displayedSize.width) / 2;
    final imageOffsetY = (displaySize.height - displayedSize.height) / 2;
    final cropRect = thumbnailCropRect(
      displayedSize: displayedSize,
      cropBoxSize: cropSize,
      offsetX: _cropX,
      offsetY: _cropY,
    );

    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        final scaleDelta = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
        final newScale = (_cropScale + scaleDelta).clamp(1.0, 3.0);
        if (newScale != _cropScale) {
          setState(() => _cropScale = newScale);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: (details) => _onScaleUpdate(details, displaySize),
        onScaleEnd: _onScaleEnd,
        child: Container(
          key: const ValueKey('thumbnail-crop-preview'),
          width: displaySize.width,
          height: displaySize.height,
          decoration: decoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned(
                  left: imageOffsetX,
                  top: imageOffsetY,
                  child: Image.file(
                    File(widget.imagePath),
                    key: const ValueKey('thumbnail-crop-image'),
                    fit: BoxFit.contain,
                    width: displayedSize.width,
                    height: displayedSize.height,
                    errorBuilder: (_, __, ___) => Container(
                      width: displayedSize.width,
                      height: displayedSize.height,
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: imageOffsetX,
                  top: imageOffsetY,
                  child: CustomPaint(
                    size: displayedSize,
                    painter: _CropOverlayPainter(cropRect: cropRect),
                  ),
                ),
                Positioned(
                  left: imageOffsetX + cropRect.left,
                  top: imageOffsetY + cropRect.top,
                  child: IgnorePointer(
                    child: Container(
                      key: const ValueKey('thumbnail-crop-selection'),
                      width: cropSize.width,
                      height: cropSize.height,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
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
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildFooter(
    ThemeData theme,
    AppLocalizations l10n, {
    required bool compactActions,
  }) {
    final actions = compactActions
        ? <Widget>[
            IconButton(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt),
              tooltip: l10n.common_reset,
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: l10n.common_cancel,
            ),
            IconButton.filled(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              tooltip: l10n.common_confirm,
            ),
          ]
        : <Widget>[
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt),
              label: Text(l10n.common_reset),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.common_cancel),
            ),
            FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: Text(l10n.common_confirm),
            ),
          ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compactActions ? 12 : 16,
        vertical: compactActions ? 4 : 8,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: actions,
      ),
    );
  }
}

/// 裁剪框遮罩绘制器
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // 绘制整个背景，然后挖空中间
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 绘制半透明背景
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 使用混合模式清除中间区域
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.drawRect(cropRect, clearPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}

/// 禁用滚轮滚动的 ScrollBehavior
class _NoScrollBehavior extends ScrollBehavior {
  const _NoScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {};
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
  await AdaptivePresenter.showForm<void>(
    context: context,
    titleBuilder: (panelContext) => Row(
      children: [
        Icon(
          Icons.crop_free,
          color: Theme.of(panelContext).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            panelContext.l10n.tagLibrary_adjustThumbnailTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(panelContext).textTheme.titleLarge,
          ),
        ),
      ],
    ),
    dialogWidth: 720,
    builder: (_, __) => ThumbnailCropDialog(
      imagePath: imagePath,
      initialOffsetX: initialOffsetX,
      initialOffsetY: initialOffsetY,
      initialScale: initialScale,
      onConfirm: onConfirm,
    ),
  );
}
