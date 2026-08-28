import 'package:flutter/material.dart';

/// 项目统一开关。
///
/// 复用 Material 原生状态、键盘与无障碍行为，只允许调用方覆盖语义颜色和尺寸。
class ThemedSwitch extends StatelessWidget {
  const ThemedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.scale = 1,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveOnChanged = enabled ? onChanged : null;

    return Opacity(
      opacity: effectiveOnChanged == null ? 0.5 : 1,
      child: SizedBox(
        width: 52 * scale,
        height: 40 * scale,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Switch(
            value: value,
            onChanged: effectiveOnChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            activeTrackColor: activeColor ?? colors.primary,
            inactiveTrackColor: inactiveColor ?? colors.surfaceContainerHighest,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (thumbColor != null) return thumbColor;
              if (states.contains(WidgetState.selected)) {
                return colors.onPrimary;
              }
              return colors.onSurfaceVariant;
            }),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
      ),
    );
  }
}
