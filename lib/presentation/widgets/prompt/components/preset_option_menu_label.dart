import 'package:flutter/material.dart';

import '../../common/menu_action_label.dart';

/// 质量词与 UC 预设菜单的单选项：前导勾选槽常驻，选中项强调。
class PresetOptionMenuLabel extends StatelessWidget {
  const PresetOptionMenuLabel({
    super.key,
    required this.label,
    required this.selected,
  });

  static const _slotSize = 16.0;

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return MenuActionLabel(
      leading: selected
          ? const Icon(Icons.check)
          : const SizedBox(width: _slotSize),
      label: label,
      color: selected ? Theme.of(context).colorScheme.primary : null,
      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      iconSize: _slotSize,
    );
  }
}
