import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps native copy behavior closer to selectable text than page shortcuts.
class SelectionCopyShortcuts extends StatelessWidget {
  final Widget child;

  const SelectionCopyShortcuts({super.key, required this.child});

  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyC, control: true):
            CopySelectionTextIntent.copy,
        SingleActivator(LogicalKeyboardKey.keyC, meta: true):
            CopySelectionTextIntent.copy,
      };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(shortcuts: _shortcuts, child: child);
  }
}
