import 'package:flutter/material.dart';

import '../../core/editor_state.dart';

/// 颜色面板
class ColorPanel extends StatelessWidget {
  final EditorState state;

  const ColorPanel({
    super.key,
    required this.state,
  });

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
                '颜色',
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
                              state.foregroundColor.value == color.value,
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
                '#${state.foregroundColor.value.toRadixString(16).substring(2).toUpperCase()}',
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
    showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: initialColor,
        onColorChanged: onColorChanged,
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
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.swap_horiz, size: 14),
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

  const _ColorPickerDialog({
    required this.initialColor,
    required this.onColorChanged,
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
      text: widget.initialColor.value
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

    return AlertDialog(
      title: const Text('选择颜色'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 色相选择
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // 饱和度-明度选择器
                  Expanded(
                    child: GestureDetector(
                      onPanDown: (details) => _updateSV(
                        details.localPosition,
                        const Size(200, 200),
                      ),
                      onPanUpdate: (details) => _updateSV(
                        details.localPosition,
                        const Size(200, 200),
                      ),
                      child: CustomPaint(
                        painter: _SVPicker(hue: _hsvColor.hue),
                        child: Stack(
                          children: [
                            Positioned(
                              left: _hsvColor.saturation * 200 - 8,
                              top: (1 - _hsvColor.value) * 200 - 8,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
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
                  const SizedBox(width: 16),
                  // 色相条
                  GestureDetector(
                    onPanDown: (details) =>
                        _updateHue(details.localPosition.dy, 200),
                    onPanUpdate: (details) =>
                        _updateHue(details.localPosition.dy, 200),
                    child: SizedBox(
                      width: 20,
                      height: 200,
                      child: CustomPaint(
                        painter: _HuePicker(),
                        child: Stack(
                          children: [
                            Positioned(
                              top: _hsvColor.hue / 360 * 200 - 2,
                              left: -2,
                              right: -2,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.white, width: 1),
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
            ),

            const SizedBox(height: 16),

            // 颜色预览和HEX输入
            Row(
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
                  child: TextField(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onColorChanged(_hsvColor.toColor());
            Navigator.pop(context);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  void _updateSV(Offset position, Size size) {
    setState(() {
      _hsvColor = _hsvColor
          .withSaturation(
            (position.dx / size.width).clamp(0.0, 1.0),
          )
          .withValue(
            (1 - position.dy / size.height).clamp(0.0, 1.0),
          );
      _updateHexController();
    });
  }

  void _updateHue(double y, double height) {
    setState(() {
      _hsvColor = _hsvColor.withHue(
        (y / height * 360).clamp(0.0, 360.0),
      );
      _updateHexController();
    });
  }

  void _updateHexController() {
    _hexController.text =
        _hsvColor.toColor().value.toRadixString(16).substring(2).toUpperCase();
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
    } catch (_) {}
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
