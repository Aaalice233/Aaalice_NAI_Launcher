import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/keyboard_modifier_utils.dart';
import '../widgets/common/image_hover_preview_controller.dart';
import 'card_selection.dart';

/// Each page supplies its own state owner and currently presented ordering.
class CardSelectionScope extends InheritedWidget {
  const CardSelectionScope({
    super.key,
    required this.selection,
    required this.commands,
    required this.orderedIds,
    required super.child,
  });

  final SelectionModeState selection;
  final CardSelectionCommands commands;
  final List<String> orderedIds;

  static CardSelectionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardSelectionScope>();

  static bool handleTap(BuildContext context, String id) {
    final scope = maybeOf(context);
    if (scope == null || !scope.orderedIds.contains(id)) return false;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed) {
      scope.commands.enter();
      scope.commands.selectRange(id, scope.orderedIds);
    } else if (isPrimarySelectionModifierPressed(keyboard: keyboard) ||
        scope.selection.isActive) {
      scope.commands.enter();
      scope.commands.toggle(id);
    } else {
      return false;
    }
    ImageHoverPreviewController.dismissAll();
    return true;
  }

  @override
  bool updateShouldNotify(CardSelectionScope oldWidget) =>
      selection != oldWidget.selection || orderedIds != oldWidget.orderedIds;
}

class CardSelectionShortcuts extends StatelessWidget {
  const CardSelectionShortcuts({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    skipTraversal: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext?.widget is EditableText ||
          focusedContext?.findAncestorWidgetOfExactType<EditableText>() !=
              null) {
        return KeyEventResult.ignored;
      }
      final scope = CardSelectionScope.maybeOf(context);
      if (scope == null) return KeyEventResult.ignored;
      final keyboard = HardwareKeyboard.instance;
      if (event.logicalKey == LogicalKeyboardKey.keyA &&
          isPrimarySelectionModifierPressed(keyboard: keyboard)) {
        scope.commands.enter();
        scope.commands.selectAll(scope.orderedIds);
      } else if (event.logicalKey == LogicalKeyboardKey.escape &&
          scope.selection.isActive) {
        scope.commands.exit();
      } else {
        return KeyEventResult.ignored;
      }
      ImageHoverPreviewController.dismissAll();
      return KeyEventResult.handled;
    },
    child: child,
  );
}
