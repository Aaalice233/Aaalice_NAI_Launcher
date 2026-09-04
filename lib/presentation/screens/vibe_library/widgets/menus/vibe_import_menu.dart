import 'package:flutter/material.dart';

import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../widgets/common/pro_context_menu.dart';
import '../../../../widgets/common/context_menu_anchor.dart';

/// Import menu route that displays import options as a popup
class ImportMenu extends PopupRoute<void> {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem)? onSelect;

  ImportMenu({required this.position, required this.items, this.onSelect});

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
          // position 是窗口全局坐标；路由页面铺在最近 Overlay 上，
          // 需换算到 overlay 局部坐标并按 overlay 尺寸收拢
          final overlaySize = contextMenuOverlaySize(context);
          final local = contextMenuLocalPosition(context, position);
          const menuWidth = 180.0;
          final menuHeight =
              items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = local.dx;
          double top = local.dy;

          // Adjust horizontal position
          if (left + menuWidth > overlaySize.width) {
            left = overlaySize.width - menuWidth - 16;
          }

          // Adjust vertical position
          if (top + menuHeight > overlaySize.height) {
            top = overlaySize.height - menuHeight - 16;
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
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      item.onTap?.call();
                    });
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
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: child,
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
    if (interactionPolicy.usesAnchoredMenus) {
      await Navigator.of(
        this,
      ).push(ImportMenu(position: position, items: items, onSelect: onSelect));
      return;
    }

    final selected = await AdaptivePresenter.showPanel<ProMenuItem>(
      context: this,
      title: MaterialLocalizations.of(this).moreButtonTooltip,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.72,
      builder: (panelContext, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final item in items)
            if (item.isDivider)
              const Divider(height: 1)
            else
              ListTile(
                minTileHeight: 48,
                leading: item.icon == null ? null : Icon(item.icon),
                title: Text(item.label),
                onTap: () => Navigator.of(panelContext).pop(item),
              ),
        ],
      ),
    );
    if (selected == null) return;
    onSelect?.call(selected);
    selected.onTap?.call();
  }
}
