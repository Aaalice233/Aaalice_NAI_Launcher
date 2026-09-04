import 'package:flutter/material.dart';

/// Lets non-interactive space dismiss the current text input without taking
/// gestures away from fields, buttons, menus, or other interactive children.
class KeyboardDismissRegion extends StatelessWidget {
  const KeyboardDismissRegion({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: enabled
          ? () => FocusManager.instance.primaryFocus?.unfocus()
          : null,
      child: child,
    );
  }
}
