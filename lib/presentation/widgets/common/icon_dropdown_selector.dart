import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
import 'compact_icon_button.dart';

@immutable
class IconDropdownOption<T> {
  const IconDropdownOption({
    required this.value,
    required this.icon,
    required this.label,
  });

  final T value;
  final IconData icon;
  final String label;
}

/// Compact single-choice menu whose anchor and options retain their icons.
class IconDropdownSelector<T> extends StatelessWidget {
  const IconDropdownSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    this.tooltip,
  }) : assert(options.length > 0);

  final T value;
  final List<IconDropdownOption<T>> options;
  final ValueChanged<T> onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final selected = options.firstWhere((option) => option.value == value);
    return MenuAnchor(
      menuChildren: [
        for (var index = 0; index < options.length; index++)
          MenuItemButton(
            key: ValueKey('icon-dropdown-option-$index'),
            leadingIcon: Icon(options[index].icon, size: 18),
            trailingIcon: options[index].value == value
                ? const Icon(Icons.check_rounded, size: 18)
                : null,
            onPressed: () => onSelected(options[index].value),
            child: Text(options[index].label),
          ),
      ],
      builder: (context, controller, _) => ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: context.interactionPolicy.minimumControlExtent,
        ),
        child: CompactIconButton(
          icon: selected.icon,
          label: selected.label,
          trailingIcon: Icons.arrow_drop_down_rounded,
          tooltip: tooltip ?? selected.label,
          isActive: true,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }
}
