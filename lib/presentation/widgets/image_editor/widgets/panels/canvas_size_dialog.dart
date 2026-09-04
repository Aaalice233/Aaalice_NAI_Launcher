import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/window_size_class.dart';

/// 内容处理模式
enum ContentHandlingMode {
  /// 裁剪 - 保持比例，裁剪多余部分
  crop('Crop'),

  /// 填充 - 保持比例，填充空白区域
  pad('Pad'),

  /// 拉伸 - 拉伸至填满画布
  stretch('Stretch');

  final String label;
  const ContentHandlingMode(this.label);

  @override
  String toString() => label;
}

/// 画布尺寸调整结果
class CanvasSizeResult {
  final Size size;
  final ContentHandlingMode mode;

  const CanvasSizeResult({required this.size, required this.mode});
}

/// 画布尺寸预设
class CanvasSizePreset {
  final int width;
  final int height;
  final String name;

  const CanvasSizePreset(this.width, this.height, this.name);

  @override
  String toString() => '$name ($width x $height)';
}

/// 预设尺寸列表
const canvasPresets = [
  CanvasSizePreset(512, 512, 'Square 512'),
  CanvasSizePreset(768, 768, 'Square 768'),
  CanvasSizePreset(1024, 1024, 'Square 1024'),
  CanvasSizePreset(768, 512, 'Landscape 3:2'),
  CanvasSizePreset(512, 768, 'Portrait 2:3'),
  CanvasSizePreset(832, 1216, 'NAI Portrait'),
  CanvasSizePreset(1216, 832, 'NAI Landscape'),
  CanvasSizePreset(1024, 768, 'Landscape 4:3'),
  CanvasSizePreset(768, 1024, 'Portrait 3:4'),
  CanvasSizePreset(1920, 1080, 'Full HD 16:9'),
];

/// 画布尺寸对话框
class CanvasSizeDialog extends StatefulWidget {
  final Size? initialSize;
  final ContentHandlingMode? initialMode;
  final String title;
  final String confirmText;
  final ScrollController? scrollController;

  const CanvasSizeDialog({
    super.key,
    this.initialSize,
    this.initialMode,
    this.title = 'Canvas Size',
    this.confirmText = 'Confirm',
    this.scrollController,
  });

  /// 显示对话框
  static Future<CanvasSizeResult?> show(
    BuildContext context, {
    Size? initialSize,
    ContentHandlingMode? initialMode,
    String? title,
    String? confirmText,
  }) {
    final resolvedTitle = title ?? context.l10n.editor_canvasSizeTitle;
    final resolvedConfirmText = confirmText ?? context.l10n.common_confirm;
    return AdaptivePresenter.showForm<CanvasSizeResult>(
      context: context,
      width: 480,
      titleBuilder: (context) => Text(
        resolvedTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      builder: (context, scrollController) => CanvasSizeDialog(
        initialSize: initialSize,
        initialMode: initialMode,
        title: resolvedTitle,
        confirmText: resolvedConfirmText,
        scrollController: scrollController,
      ),
    );
  }

  @override
  State<CanvasSizeDialog> createState() => _CanvasSizeDialogState();
}

class _CanvasSizeDialogState extends State<CanvasSizeDialog> {
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  CanvasSizePreset? _selectedPreset;
  ContentHandlingMode _selectedMode = ContentHandlingMode.crop;
  bool _linkDimensions = false;
  double _aspectRatio = 1.0;

  @override
  void initState() {
    super.initState();
    final initialWidth = widget.initialSize?.width.toInt() ?? 1024;
    final initialHeight = widget.initialSize?.height.toInt() ?? 1024;
    _widthController = TextEditingController(text: initialWidth.toString());
    _heightController = TextEditingController(text: initialHeight.toString());
    _aspectRatio = initialWidth / initialHeight;
    _selectedMode = widget.initialMode ?? ContentHandlingMode.crop;

    // 检查是否匹配预设
    for (final preset in canvasPresets) {
      if (preset.width == initialWidth && preset.height == initialHeight) {
        _selectedPreset = preset;
        break;
      }
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.adaptiveWindow.isCompact;

    return Column(
      key: const ValueKey('canvas-size-dialog'),
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('canvas-size-scroll'),
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(compact ? 12 : 16),
            children: [
              DropdownButtonFormField<CanvasSizePreset>(
                key: const ValueKey('canvas-size-preset'),
                initialValue: _selectedPreset,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.editor_presetSize,
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      context.l10n.editor_customSize,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...canvasPresets.map(
                    (preset) => DropdownMenuItem(
                      value: preset,
                      child: Text(
                        _presetLabel(context, preset),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (preset) {
                  setState(() {
                    _selectedPreset = preset;
                    if (preset != null) {
                      _widthController.text = preset.width.toString();
                      _heightController.text = preset.height.toString();
                      _aspectRatio = preset.width / preset.height;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ContentHandlingMode>(
                key: const ValueKey('canvas-size-mode'),
                initialValue: _selectedMode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.editor_contentHandling,
                  isDense: true,
                ),
                items: ContentHandlingMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(
                          _modeLabel(context, mode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (mode) {
                  if (mode != null) {
                    setState(() => _selectedMode = mode);
                  }
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stackInputs =
                      constraints.maxWidth < 400 ||
                      MediaQuery.textScalerOf(context).scale(1) >= 2;
                  if (stackInputs) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildWidthInput(),
                        Align(child: _buildLinkButton()),
                        _buildHeightInput(),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: _buildWidthInput()),
                      _buildLinkButton(),
                      Expanded(child: _buildHeightInput()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RatioChip(label: '1:1', onTap: () => _setRatio(1, 1)),
                  _RatioChip(label: '4:3', onTap: () => _setRatio(4, 3)),
                  _RatioChip(label: '3:4', onTap: () => _setRatio(3, 4)),
                  _RatioChip(label: '16:9', onTap: () => _setRatio(16, 9)),
                  _RatioChip(label: '9:16', onTap: () => _setRatio(9, 16)),
                ],
              ),
              const SizedBox(height: 16),
              _CanvasSizePreview(
                originalSize: widget.initialSize ?? const Size(1024, 1024),
                newWidth: int.tryParse(_widthController.text) ?? 1024,
                newHeight: int.tryParse(_heightController.text) ?? 1024,
                mode: _selectedMode,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.common_cancel),
                ),
                FilledButton(
                  onPressed: _isValid() ? _confirm : null,
                  child: Text(widget.confirmText),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWidthInput() {
    return ThemedInput(
      key: const ValueKey('canvas-size-width'),
      controller: _widthController,
      decoration: InputDecoration(
        labelText: context.l10n.editor_width,
        suffixText: 'px',
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        _selectedPreset = null;
        if (_linkDimensions) {
          final width = int.tryParse(value) ?? 0;
          if (width > 0) {
            _heightController.text = (width / _aspectRatio).round().toString();
          }
        }
        setState(() {});
      },
    );
  }

  Widget _buildHeightInput() {
    return ThemedInput(
      key: const ValueKey('canvas-size-height'),
      controller: _heightController,
      decoration: InputDecoration(
        labelText: context.l10n.editor_height,
        suffixText: 'px',
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        _selectedPreset = null;
        if (_linkDimensions) {
          final height = int.tryParse(value) ?? 0;
          if (height > 0) {
            _widthController.text = (height * _aspectRatio).round().toString();
          }
        }
        setState(() {});
      },
    );
  }

  Widget _buildLinkButton() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: IconButton(
        icon: Icon(
          _linkDimensions ? Icons.link : Icons.link_off,
          color: _linkDimensions
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        tooltip: _linkDimensions
            ? context.l10n.editor_unlockAspectRatio
            : context.l10n.editor_lockAspectRatio,
        onPressed: () {
          setState(() {
            _linkDimensions = !_linkDimensions;
            if (_linkDimensions) {
              final width = int.tryParse(_widthController.text) ?? 1;
              final height = int.tryParse(_heightController.text) ?? 1;
              _aspectRatio = width / height;
            }
          });
        },
      ),
    );
  }

  void _setRatio(int widthRatio, int heightRatio) {
    final currentWidth = int.tryParse(_widthController.text) ?? 1024;
    final newHeight = (currentWidth * heightRatio / widthRatio).round();

    setState(() {
      _heightController.text = newHeight.toString();
      _aspectRatio = widthRatio / heightRatio;
      _selectedPreset = null;
    });
  }

  String _modeLabel(BuildContext context, ContentHandlingMode mode) {
    switch (mode) {
      case ContentHandlingMode.crop:
        return context.l10n.editor_contentCrop;
      case ContentHandlingMode.pad:
        return context.l10n.editor_contentPad;
      case ContentHandlingMode.stretch:
        return context.l10n.editor_contentStretch;
    }
  }

  String _presetLabel(BuildContext context, CanvasSizePreset preset) {
    if (preset.width == preset.height) {
      return context.l10n.editor_canvasPresetSquare(preset.width);
    }
    if (preset.width == 832 && preset.height == 1216) {
      return context.l10n.editor_canvasPresetNaiPortrait;
    }
    if (preset.width == 1216 && preset.height == 832) {
      return context.l10n.editor_canvasPresetNaiLandscape;
    }
    if (preset.width == 1920 && preset.height == 1080) {
      return context.l10n.editor_canvasPresetFullHd;
    }
    if (preset.width > preset.height) {
      return context.l10n.editor_canvasPresetLandscape(
        _aspectRatioLabel(preset),
      );
    }
    return context.l10n.editor_canvasPresetPortrait(_aspectRatioLabel(preset));
  }

  String _aspectRatioLabel(CanvasSizePreset preset) {
    final divisor = _gcd(preset.width, preset.height);
    return '${preset.width ~/ divisor}:${preset.height ~/ divisor}';
  }

  int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a.abs();
  }

  bool _isValid() {
    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);
    return width != null &&
        height != null &&
        width >= 64 &&
        width <= 4096 &&
        height >= 64 &&
        height <= 4096;
  }

  void _confirm() {
    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);
    if (width != null && height != null) {
      Navigator.pop(
        context,
        CanvasSizeResult(
          size: Size(width.toDouble(), height.toDouble()),
          mode: _selectedMode,
        ),
      );
    }
  }
}

/// 比例快捷按钮
class _RatioChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RatioChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 画布尺寸视觉预览
class _CanvasSizePreview extends StatelessWidget {
  final Size originalSize;
  final int newWidth;
  final int newHeight;
  final ContentHandlingMode mode;

  const _CanvasSizePreview({
    required this.originalSize,
    required this.newWidth,
    required this.newHeight,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final newSize = Size(newWidth.toDouble(), newHeight.toDouble());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 预览标题
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.preview,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.editor_sizePreview,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 视觉对比
          _SizeComparison(
            originalSize: originalSize,
            newSize: newSize,
            mode: mode,
          ),

          const SizedBox(height: 12),

          // 尺寸信息
          _SizeInfo(
            originalSize: originalSize,
            newSize: newSize,
            mode: mode,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

/// 尺寸对比视觉展示
class _SizeComparison extends StatelessWidget {
  final Size originalSize;
  final Size newSize;
  final ContentHandlingMode mode;

  const _SizeComparison({
    required this.originalSize,
    required this.newSize,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewWidth = constraints.maxWidth.clamp(0, 280).toDouble();
        const previewHeight = 120.0;
        final maxWidth = originalSize.width > newSize.width
            ? originalSize.width
            : newSize.width;
        final maxHeight = originalSize.height > newSize.height
            ? originalSize.height
            : newSize.height;
        final scaleX = previewWidth / maxWidth;
        final scaleY = previewHeight / maxHeight;
        final scale = scaleX < scaleY ? scaleX : scaleY;

        return CustomPaint(
          size: Size(previewWidth, previewHeight),
          painter: _SizeComparisonPainter(
            originalSize: Size(
              originalSize.width * scale,
              originalSize.height * scale,
            ),
            newSize: Size(newSize.width * scale, newSize.height * scale),
            mode: mode,
            theme: theme,
          ),
        );
      },
    );
  }
}

/// 尺寸对比画笔
class _SizeComparisonPainter extends CustomPainter {
  final Size originalSize;
  final Size newSize;
  final ContentHandlingMode mode;
  final ThemeData theme;

  _SizeComparisonPainter({
    required this.originalSize,
    required this.newSize,
    required this.mode,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 绘制原始画布（虚线轮廓）
    final originalRect = Rect.fromCenter(
      center: center,
      width: originalSize.width,
      height: originalSize.height,
    );

    final originalPaint = Paint()
      ..color = theme.colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    final originalDashPath = Path()..addRect(originalRect);

    // 绘制虚线效果
    final dashPath = _createDashedPath(originalDashPath);
    canvas.drawPath(dashPath, originalPaint);

    // 绘制新画布（实线填充）
    final newRect = Rect.fromCenter(
      center: center,
      width: newSize.width,
      height: newSize.height,
    );

    final newPaint = Paint()
      ..color = theme.colorScheme.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(newRect, newPaint);

    final newStrokePaint = Paint()
      ..color = theme.colorScheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    canvas.drawRect(newRect, newStrokePaint);

    // 根据模式绘制效果指示器
    _drawModeIndicator(canvas, center, originalRect, newRect);
  }

  void _drawModeIndicator(
    Canvas canvas,
    Offset center,
    Rect originalRect,
    Rect newRect,
  ) {
    // 根据不同模式显示不同的视觉提示
    switch (mode) {
      case ContentHandlingMode.crop:
        // 裁剪模式：在重叠区域绘制阴影
        final intersectedRect = originalRect.intersect(newRect);
        if (intersectedRect.width > 0 && intersectedRect.height > 0) {
          final cropPaint = Paint()
            ..color = theme.colorScheme.error.withValues(alpha: 0.3)
            ..style = PaintingStyle.fill;
          canvas.drawRect(intersectedRect, cropPaint);
        }
        break;

      case ContentHandlingMode.pad:
        // 填充模式：在空白区域绘制点状图案
        if (newRect.width > originalRect.width ||
            newRect.height > originalRect.height) {
          _drawPattern(canvas, newRect, originalRect);
        }
        break;

      case ContentHandlingMode.stretch:
        // 拉伸模式：绘制箭头指示
        _drawStretchArrows(canvas, originalRect, newRect);
        break;
    }
  }

  void _drawPattern(Canvas canvas, Rect outerRect, Rect innerRect) {
    final patternPaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    // 绘制点状图案表示填充区域
    const dotSpacing = 8.0;
    const dotRadius = 1.5;

    // 上方填充区域
    if (outerRect.top < innerRect.top) {
      for (double x = outerRect.left; x <= outerRect.right; x += dotSpacing) {
        for (double y = outerRect.top; y < innerRect.top; y += dotSpacing) {
          canvas.drawCircle(Offset(x, y), dotRadius, patternPaint);
        }
      }
    }

    // 下方填充区域
    if (outerRect.bottom > innerRect.bottom) {
      for (double x = outerRect.left; x <= outerRect.right; x += dotSpacing) {
        for (
          double y = innerRect.bottom;
          y <= outerRect.bottom;
          y += dotSpacing
        ) {
          canvas.drawCircle(Offset(x, y), dotRadius, patternPaint);
        }
      }
    }

    // 左侧填充区域
    if (outerRect.left < innerRect.left) {
      for (double x = outerRect.left; x < innerRect.left; x += dotSpacing) {
        for (double y = outerRect.top; y <= outerRect.bottom; y += dotSpacing) {
          canvas.drawCircle(Offset(x, y), dotRadius, patternPaint);
        }
      }
    }

    // 右侧填充区域
    if (outerRect.right > innerRect.right) {
      for (double x = innerRect.right; x <= outerRect.right; x += dotSpacing) {
        for (double y = outerRect.top; y <= outerRect.bottom; y += dotSpacing) {
          canvas.drawCircle(Offset(x, y), dotRadius, patternPaint);
        }
      }
    }
  }

  void _drawStretchArrows(Canvas canvas, Rect originalRect, Rect newRect) {
    final arrowPaint = Paint()
      ..color = theme.colorScheme.secondary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // 绘制箭头表示拉伸方向
    if (newRect.width > originalRect.width) {
      // 水平拉伸箭头
      final y = originalRect.center.dy;
      _drawArrow(
        canvas,
        Offset(originalRect.right + 5, y),
        Offset(newRect.right - 5, y),
        arrowPaint,
      );
    }

    if (newRect.height > originalRect.height) {
      // 垂直拉伸箭头
      final x = originalRect.center.dx;
      _drawArrow(
        canvas,
        Offset(x, originalRect.bottom + 5),
        Offset(x, newRect.bottom - 5),
        arrowPaint,
      );
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);

    // 绘制箭头头部
    const arrowSize = 6.0;
    final direction = (end - start) / start.distance;
    final perpendicular = Offset(-direction.dy, direction.dx);

    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - direction.dx * arrowSize + perpendicular.dx * arrowSize / 2,
        end.dy - direction.dy * arrowSize + perpendicular.dy * arrowSize / 2,
      )
      ..lineTo(
        end.dx - direction.dx * arrowSize - perpendicular.dx * arrowSize / 2,
        end.dy - direction.dy * arrowSize - perpendicular.dy * arrowSize / 2,
      )
      ..close();

    final arrowFillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowFillPaint);
  }

  Path _createDashedPath(Path source) {
    final dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      final length = metric.length;
      const dashWidth = 5.0;
      const dashSpace = 3.0;
      var distance = 0.0;

      while (distance < length) {
        final add = distance + dashWidth;
        if (add > length) break;
        dest.addPath(metric.extractPath(distance, add), Offset.zero);
        distance = add + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _SizeComparisonPainter oldDelegate) {
    return oldDelegate.originalSize != originalSize ||
        oldDelegate.newSize != newSize ||
        oldDelegate.mode != mode;
  }
}

/// 尺寸信息文本
class _SizeInfo extends StatelessWidget {
  final Size originalSize;
  final Size newSize;
  final ContentHandlingMode mode;
  final ThemeData theme;

  const _SizeInfo({
    required this.originalSize,
    required this.newSize,
    required this.mode,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final widthDiff = newSize.width.toInt() - originalSize.width.toInt();
    final heightDiff = newSize.height.toInt() - originalSize.height.toInt();
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackInfo =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) >= 2;

        Widget infoLine({
          required IconData icon,
          required Color iconColor,
          required Widget value,
          required String label,
        }) {
          final labelWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: labelStyle)),
            ],
          );
          if (stackInfo) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), value],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: labelWidget),
              const SizedBox(width: 8),
              value,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            infoLine(
              icon: Icons.crop_square,
              iconColor: theme.colorScheme.outline,
              label: context.l10n.editor_originalSize,
              value: Text(
                '${originalSize.width.toInt()} x ${originalSize.height.toInt()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            infoLine(
              icon: Icons.check_box,
              iconColor: theme.colorScheme.primary,
              label: context.l10n.editor_newSize,
              value: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '${newSize.width.toInt()} x ${newSize.height.toInt()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (widthDiff != 0 || heightDiff != 0)
                    Text(
                      '(${widthDiff >= 0 ? '+' : ''}$widthDiff, ${heightDiff >= 0 ? '+' : ''}$heightDiff)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: widthDiff >= 0 && heightDiff >= 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _getModeIcon(mode),
                    size: 12,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getModeDescription(context, mode),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getModeIcon(ContentHandlingMode mode) {
    switch (mode) {
      case ContentHandlingMode.crop:
        return Icons.content_cut;
      case ContentHandlingMode.pad:
        return Icons.padding;
      case ContentHandlingMode.stretch:
        return Icons.open_in_full;
    }
  }

  String _getModeDescription(BuildContext context, ContentHandlingMode mode) {
    switch (mode) {
      case ContentHandlingMode.crop:
        return context.l10n.editor_cropModeDescription;
      case ContentHandlingMode.pad:
        return context.l10n.editor_padModeDescription;
      case ContentHandlingMode.stretch:
        return context.l10n.editor_stretchModeDescription;
    }
  }
}
