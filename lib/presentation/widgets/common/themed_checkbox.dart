import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';

/// 项目统一复选框。
///
/// 外观跟随 Material 主题，原生保留三态、键盘、焦点与无障碍语义。
class ThemedCheckbox extends StatelessWidget {
  const ThemedCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.enabled = true,
    this.activeColor,
    this.checkColor,
    this.borderColor,
    this.size = 20,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final bool enabled;
  final Color? activeColor;
  final Color? checkColor;
  final Color? borderColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final minimumExtent = context.interactionPolicy.minimumControlExtent;
    final targetExtent = math.max(size, minimumExtent);

    return SizedBox.square(
      dimension: targetExtent,
      child: Checkbox(
        value: tristate ? value : (value ?? false),
        onChanged: enabled ? onChanged : null,
        tristate: tristate,
        activeColor: activeColor,
        checkColor: checkColor,
        side: borderColor == null ? null : BorderSide(color: borderColor!),
        materialTapTargetSize: minimumExtent >= 48
            ? MaterialTapTargetSize.padded
            : MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// 带标题和说明的统一复选项。
class ThemedCheckboxListTile extends StatelessWidget {
  const ThemedCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.tristate = false,
    this.enabled = true,
    this.controlAffinity = ListTileControlAffinity.leading,
    this.contentPadding,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final bool tristate;
  final bool enabled;
  final ListTileControlAffinity controlAffinity;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: tristate ? value : (value ?? false),
      onChanged: enabled ? onChanged : null,
      title: title,
      subtitle: subtitle,
      tristate: tristate,
      enabled: enabled,
      controlAffinity: controlAffinity,
      contentPadding:
          contentPadding ?? const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
