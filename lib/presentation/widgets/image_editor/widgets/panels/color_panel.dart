import 'package:flutter/material.dart';

import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../widgets/common/themed_input.dart';
import '../../core/editor_state.dart';

/// 颜色面板
class ColorPanel extends StatelessWidget {
  final EditorState state;

  const ColorPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.editor_colorPanelTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // 前景色/背景色
              Row(
                children: [
                  // 颜色预览
                  _ColorPreview(
                    foregroundColor: state.foregroundColor,
                    backgroundColor: state.backgroundColor,
                    onSwap: () => state.swapColors(),
                    onForegroundTap: () => _showColorPicker(
                      context,
                      state.foregroundColor,
                      (color) => state.setForegroundColor(color),
                    ),
                    onBackgroundTap: () => _showColorPicker(
                      context,
                      state.backgroundColor,
                      (color) => state.setBackgroundColor(color),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 快捷颜色
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _quickColors.map((color) {
                        return _QuickColorButton(
                          color: color,
                          isSelected:
                              state.foregroundColor.toARGB32() ==
                              color.toARGB32(),
                          onTap: () => state.setForegroundColor(color),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 颜色值显示
              Text(
                '#${state.foregroundColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showColorPicker(
    BuildContext context,
    Color initialColor,
    ValueChanged<Color> onColorChanged,
  ) {
    AdaptivePresenter.showForm<void>(
      context: context,
      sideSheetWidth: 440,
      titleBuilder: (context) => Text(
        context.l10n.editor_colorPickerTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      builder: (context, scrollController) => _ColorPickerDialog(
        initialColor: initialColor,
        onColorChanged: onColorChanged,
        scrollController: scrollController,
      ),
    );
  }
}

/// 快捷颜色列表
const _quickColors = [
  Colors.black,
  Colors.white,
  Colors.red,
  Colors.orange,
  Colors.yellow,
  Colors.green,
  Colors.cyan,
  Colors.blue,
  Colors.purple,
  Colors.pink,
  Colors.brown,
  Colors.grey,
];

/// 颜色预览组件
class _ColorPreview extends StatelessWidget {
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onSwap;
  final VoidCallback onForegroundTap;
  final VoidCallback onBackgroundTap;

  const _ColorPreview({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onSwap,
    required this.onForegroundTap,
    required this.onBackgroundTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          // 背景色
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onBackgroundTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // 前景色
          Positioned(
            left: 0,
            top: 0,
            child: GestureDetector(
              key: const Key('color_panel_foreground_preview'),
              onTap: onForegroundTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: foregroundColor,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // 交换按钮
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: onSwap,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                    ),
                  ],
                ),
                // 底色写死为白，图标也必须写死深色，
                // 否则在深色主题下会继承成近白色，变成白底白图标。
                child: const Icon(
                  Icons.swap_horiz,
                  size: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 快捷颜色按钮
class _QuickColorButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

/// 颜色选择器对话框
class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final ScrollController scrollController;

  const _ColorPickerDialog({
    required this.initialColor,
    required this.onColorChanged,
    required this.scrollController,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(
      text: widget.initialColor
          .toARGB32()
          .toRadixString(16)
          .substring(2)
          .toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('color_picker_scroll'),
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              _AdaptiveColorSurface(
                hsvColor: _hsvColor,
                onSVChanged: _updateSV,
                onHueChanged: _updateHue,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _hsvColor.toColor(),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ThemedInput(
                      key: const Key('color_picker_hex'),
                      controller: _hexController,
                      decoration: const InputDecoration(
                        prefixText: '#',
                        labelText: 'HEX',
                        isDense: true,
                      ),
                      onSubmitted: _parseHex,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('color_picker_cancel'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.l10n.common_cancel,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('color_picker_confirm'),
                    onPressed: () {
                      widget.onColorChanged(_hsvColor.toColor());
                      Navigator.pop(context);
                    },
                    child: Text(
                      context.l10n.common_confirm,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _updateSV(Offset position, Size size) {
    setState(() {
      _hsvColor = _hsvColor
          .withSaturation((position.dx / size.width).clamp(0.0, 1.0))
          .withValue((1 - position.dy / size.height).clamp(0.0, 1.0));
      _updateHexController();
    });
  }

  void _updateHue(double y, double height) {
    setState(() {
      _hsvColor = _hsvColor.withHue((y / height * 360).clamp(0.0, 360.0));
      _updateHexController();
    });
  }

  void _updateHexController() {
    _hexController.text = _hsvColor
        .toColor()
        .toARGB32()
        .toRadixString(16)
        .substring(2)
        .toUpperCase();
  }

  void _parseHex(String value) {
    try {
      final hex = value.replaceAll('#', '');
      if (hex.length == 6) {
        final color = Color(int.parse('FF$hex', radix: 16));
        setState(() {
          _hsvColor = HSVColor.fromColor(color);
        });
      }
    } catch (e) {
      AppLogger.w('Invalid hex color format: $value', 'ColorPanel');
    }
  }
}

class _AdaptiveColorSurface extends StatelessWidget {
  const _AdaptiveColorSurface({
    required this.hsvColor,
    required this.onSVChanged,
    required this.onHueChanged,
  });

  final HSVColor hsvColor;
  final void Function(Offset position, Size size) onSVChanged;
  final void Function(double y, double height) onHueChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const hueWidth = 24.0;
        const gap = 12.0;
        final surfaceWidth = constraints.maxWidth - hueWidth - gap;
        final surfaceSize = Size(surfaceWidth, surfaceWidth);

        return SizedBox(
          key: const Key('color_picker_surface'),
          height: surfaceSize.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: surfaceSize.width,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) =>
                      onSVChanged(details.localPosition, surfaceSize),
                  onPanUpdate: (details) =>
                      onSVChanged(details.localPosition, surfaceSize),
                  child: CustomPaint(
                    painter: _SVPicker(hue: hsvColor.hue),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: hsvColor.saturation * surfaceSize.width - 8,
                          top: (1 - hsvColor.value) * surfaceSize.height - 8,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: gap),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) =>
                    onHueChanged(details.localPosition.dy, surfaceSize.height),
                onPanUpdate: (details) =>
                    onHueChanged(details.localPosition.dy, surfaceSize.height),
                child: SizedBox(
                  width: hueWidth,
                  child: CustomPaint(
                    painter: _HuePicker(),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: hsvColor.hue / 360 * surfaceSize.height - 2,
                          left: -2,
                          right: -2,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 饱和度-明度选择器绑制器
class _SVPicker extends CustomPainter {
  final double hue;

  _SVPicker({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 色相背景
    canvas.drawRect(
      rect,
      Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
    );

    // 饱和度渐变
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
    );

    // 明度渐变
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SVPicker oldDelegate) {
    return hue != oldDelegate.hue;
  }
}

/// 色相选择器绑制器
class _HuePicker extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final colors = List.generate(
      7,
      (i) => HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
