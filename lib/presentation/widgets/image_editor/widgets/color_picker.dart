import 'package:flutter/material.dart';

/// HSV 颜色选择器
class HSVColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const HSVColorPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  @override
  State<HSVColorPicker> createState() => _HSVColorPickerState();
}

class _HSVColorPickerState extends State<HSVColorPicker> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.color);
    _hexController = TextEditingController(text: _colorToHex(widget.color));
  }

  @override
  void didUpdateWidget(HSVColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _hsvColor = HSVColor.fromColor(widget.color);
      _hexController.text = _colorToHex(widget.color);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Color? _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'ff$hex';
    }
    if (hex.length != 8) return null;
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) return null;
    return Color(intValue);
  }

  void _onColorChanged(HSVColor color) {
    setState(() {
      _hsvColor = color;
      _hexController.text = _colorToHex(color.toColor());
    });
    widget.onColorChanged(color.toColor());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hex 输入框
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _hsvColor.toColor(),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _hexController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF4a90d9)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF3a3a3a),
                ),
                onSubmitted: (value) {
                  final color = _hexToColor(value);
                  if (color != null) {
                    _onColorChanged(HSVColor.fromColor(color));
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // SV 面板
        SizedBox(
          height: 120,
          child: _SVPanel(
            hsvColor: _hsvColor,
            onChanged: _onColorChanged,
          ),
        ),

        const SizedBox(height: 8),

        // Hue 滑块
        SizedBox(
          height: 20,
          child: _HueSlider(
            hue: _hsvColor.hue,
            onChanged: (hue) {
              _onColorChanged(_hsvColor.withHue(hue));
            },
          ),
        ),
      ],
    );
  }
}

/// SV 面板
class _SVPanel extends StatelessWidget {
  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onChanged;

  const _SVPanel({
    required this.hsvColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) => _handleTouch(details.localPosition, constraints),
          onPanUpdate: (details) => _handleTouch(details.localPosition, constraints),
          child: Stack(
            children: [
              // 背景渐变
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white,
                      HSVColor.fromAHSV(1, hsvColor.hue, 1, 1).toColor(),
                    ],
                  ),
                ),
              ),
              // 暗度渐变
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black,
                    ],
                  ),
                ),
              ),
              // 选择指示器
              Positioned(
                left: hsvColor.saturation * constraints.maxWidth - 8,
                top: (1 - hsvColor.value) * constraints.maxHeight - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleTouch(Offset position, BoxConstraints constraints) {
    final saturation = (position.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final value = 1 - (position.dy / constraints.maxHeight).clamp(0.0, 1.0);
    onChanged(hsvColor.withSaturation(saturation).withValue(value));
  }
}

/// Hue 滑块
class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueSlider({
    required this.hue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) => _handleTouch(details.localPosition, constraints),
          onPanUpdate: (details) => _handleTouch(details.localPosition, constraints),
          child: Stack(
            children: [
              // 色相渐变
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
              ),
              // 选择指示器
              Positioned(
                left: (hue / 360) * constraints.maxWidth - 4,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleTouch(Offset position, BoxConstraints constraints) {
    final newHue = (position.dx / constraints.maxWidth * 360).clamp(0.0, 360.0);
    onChanged(newHue);
  }
}
