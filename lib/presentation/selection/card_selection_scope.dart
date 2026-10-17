import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/keyboard_modifier_utils.dart';
import '../widgets/common/image_hover_preview_controller.dart';
import '../widgets/shortcuts/editable_text_focus.dart';
import '../widgets/shortcuts/fallback_focus_home.dart';
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

class CardSelectionShortcuts extends StatefulWidget {
  const CardSelectionShortcuts({
    super.key,
    required this.child,
    this.reclaimFallbackFocus = false,
  });
  final Widget child;

  /// Pages whose search box sits beside the grid take focus back here
  /// once it falls back to the route scope.
  final bool reclaimFallbackFocus;

  @override
  State<CardSelectionShortcuts> createState() => _CardSelectionShortcutsState();
}

class _CardSelectionShortcutsState extends State<CardSelectionShortcuts> {
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'CardSelectionShortcuts',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || isEditableTextFocused()) {
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
  }

  @override
  Widget build(BuildContext context) => FallbackFocusHome(
    focusNode: _focusNode,
    enabled: widget.reclaimFallbackFocus,
    child: Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    ),
  );
}
