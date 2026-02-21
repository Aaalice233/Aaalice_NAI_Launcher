import 'package:flutter/material.dart';
import '../../../../widgets/common/pro_context_menu.dart';

/// Import menu route that displays import options as a popup
class ImportMenu extends PopupRoute<void> {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem)? onSelect;

  ImportMenu({
    required this.position,
    required this.items,
    this.onSelect,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      child: Builder(
        builder: (context) {
          // Calculate menu position to ensure it stays within screen bounds
          final screenSize = MediaQuery.of(context).size;
          const menuWidth = 180.0;
          final menuHeight = items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = position.dx;
          double top = position.dy;

          // Adjust horizontal position
          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - 16;
          }

          // Adjust vertical position
          if (top + menuHeight > screenSize.height) {
            top = screenSize.height - menuHeight - 16;
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  onSelect: (item) {
                    onSelect?.call(item);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
        child: child,
      ),
    );
  }
}

/// Extension method to show ImportMenu easily
extension ImportMenuExtension on BuildContext {
  /// Show import menu at the specified position
  Future<void> showImportMenu({
    required Offset position,
    required List<ProMenuItem> items,
    void Function(ProMenuItem)? onSelect,
  }) async {
    await Navigator.of(this).push(
      ImportMenu(
        position: position,
        items: items,
        onSelect: onSelect,
      ),
    );
  }
}
