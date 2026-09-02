import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import 'image_card_actions.dart';
import 'pro_context_menu.dart';
import 'context_menu_anchor.dart';

class ImageCardContextMenu {
  const ImageCardContextMenu._();

  static Future<void> show({
    required BuildContext context,
    required Offset position,
    required List<ImageCardAction> actions,
  }) async {
    if (actions.isEmpty) return;
    final items = <ProMenuItem>[];
    int? previousGroup;
    for (final action in actions) {
      if (previousGroup != null && previousGroup != action.group) {
        items.add(const ProMenuItem.divider());
      }
      items.add(
        ProMenuItem(
          id: action.id.name,
          label: action.menuLabel,
          icon: action.icon,
          onTap: action.invoke,
          isDanger: action.isDanger,
        ),
      );
      previousGroup = action.group;
    }

    final ProMenuItem? selectedItem;
    if (PlatformCapabilities.current.hasTouchInput) {
      selectedItem = await AdaptivePresenter.showPanel<ProMenuItem>(
        context: context,
        title: context.l10n.common_moreActions,
        initialChildSize: 0.72,
        minChildSize: 0.38,
        maxChildSize: 0.94,
        builder: (panelContext, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final item in items)
              if (item.isDivider)
                const Divider(height: 1)
              else
                ListTile(
                  minVerticalPadding: 12,
                  leading: item.icon == null
                      ? null
                      : Icon(
                          item.icon,
                          color: item.isDanger
                              ? Theme.of(panelContext).colorScheme.error
                              : null,
                        ),
                  title: Text(
                    item.label,
                    style: item.isDanger
                        ? TextStyle(
                            color: Theme.of(panelContext).colorScheme.error,
                          )
                        : null,
                  ),
                  onTap: () => Navigator.of(panelContext).pop(item),
                ),
          ],
        ),
      );
    } else {
      final route = ImageCardContextMenuRoute(position: position, items: items);
      selectedItem = await Navigator.of(context).push<ProMenuItem>(route);
      await route.completed;
    }
    selectedItem?.onTap?.call();
  }
}

class ImageCardContextMenuRoute extends PopupRoute<ProMenuItem> {
  ImageCardContextMenuRoute({required this.position, required this.items});

  final Offset position;
  final List<ProMenuItem> items;

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);
  @override
  Duration get reverseTransitionDuration => Duration.zero;

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
          final screenSize = contextMenuOverlaySize(context);
          final local = contextMenuLocalPosition(context, position);
          const menuWidth = 180.0;
          final estimatedMenuHeight =
              items.where((item) => !item.isDivider).length * 36.0 +
              items.where((item) => item.isDivider).length;
          const viewportMargin = 16.0;
          final maxMenuHeight = math.max(
            0.0,
            screenSize.height - viewportMargin * 2,
          );
          final menuHeight = math.min(estimatedMenuHeight, maxMenuHeight);
          var left = local.dx;
          var top = local.dy;
          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - viewportMargin;
          }
          if (top + menuHeight > screenSize.height - viewportMargin) {
            top = screenSize.height - menuHeight - viewportMargin;
          }
          top = math.max(viewportMargin, top);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  maxHeight: maxMenuHeight,
                  onSelect: (item) => Navigator.of(context).pop(item),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}
