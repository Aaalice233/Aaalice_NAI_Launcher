import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import 'image_card_action.dart';
import 'image_card_action_dispatch.dart';
import 'image_hover_preview_controller.dart';
import 'pro_context_menu.dart';
import 'context_menu_anchor.dart';

class ImageCardContextMenu {
  const ImageCardContextMenu._();

  static List<ProMenuItem> buildItems(
    BuildContext context,
    List<ImageCardAction> actions, {
    String? title,
  }) {
    final items = <ProMenuItem>[
      if (title != null)
        ProMenuItem(id: '_scope', label: title, enabled: false),
    ];
    ImageCardActionGroup? previousGroup;
    for (final action in orderedImageCardActions(actions)) {
      if (previousGroup != null && previousGroup != action.group) {
        items.add(const ProMenuItem.divider());
      }
      items.add(
        ProMenuItem(
          id: action.id.name,
          label: action.menuLabel,
          icon: action.icon,
          onTap: prepareImageCardDispatch(context, action),
          isDanger: action.isDanger,
          enabled: action.canInvoke,
          disabledReason: action.isLoading
              ? context.l10n.common_loading
              : action.disabledReason,
        ),
      );
      previousGroup = action.group;
    }
    return items;
  }

  static Future<void> show({
    required BuildContext context,
    required Offset position,
    required List<ImageCardAction> actions,
    String? title,
    Listenable? listenable,
  }) async {
    if (!actions.any((a) => a.visible)) return;
    ImageHoverPreviewController.dismissAll();
    final items = buildItems(context, actions, title: title);
    final ProMenuItem? selectedItem;
    if (context.interactionPolicy.prefersTouchPresentation) {
      selectedItem = await AdaptivePresenter.showPanel<ProMenuItem>(
        context: context,
        title: title ?? context.l10n.common_moreActions,
        initialChildSize: 0.72,
        minChildSize: 0.38,
        maxChildSize: 0.94,
        builder: (panelContext, scrollController) {
          Widget content() => ListView(
            controller: scrollController,
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final item in buildItems(context, actions))
                if (item.isDivider)
                  const Divider(height: 1)
                else
                  ListTile(
                    enabled: item.enabled,
                    minVerticalPadding: 12,
                    leading: Icon(
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
                    subtitle: item.disabledReason == null
                        ? null
                        : Text(item.disabledReason!),
                    onTap: item.enabled
                        ? () => Navigator.of(panelContext).pop(item)
                        : null,
                  ),
            ],
          );
          return listenable == null
              ? content()
              : ListenableBuilder(
                  listenable: listenable,
                  builder: (_, _) => content(),
                );
        },
      );
    } else {
      final route = ImageCardContextMenuRoute(
        position: position,
        items: items,
        listenable: listenable,
        itemsBuilder: () => buildItems(context, actions, title: title),
      );
      selectedItem = await Navigator.of(context).push<ProMenuItem>(route);
      await route.completed;
    }
    await selectedItem?.onTap?.call();
  }
}

class ImageCardContextMenuRoute extends PopupRoute<ProMenuItem> {
  ImageCardContextMenuRoute({
    required this.position,
    required this.items,
    this.listenable,
    this.itemsBuilder,
  });

  final Listenable? listenable;
  final List<ProMenuItem> Function()? itemsBuilder;

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
    return Builder(
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final screenSize = contextMenuOverlaySize(context);
        final local = contextMenuLocalPosition(context, position);
        final safeLeft = mediaQuery.padding.left + 16;
        final safeTop = mediaQuery.padding.top + 16;
        final safeRight = screenSize.width - mediaQuery.padding.right - 16;
        final safeBottom =
            screenSize.height -
            math.max(mediaQuery.padding.bottom, mediaQuery.viewInsets.bottom) -
            16;
        final menuWidth = ProContextMenu.widthFor(context, baseWidth: 240);
        final minimumItemExtent =
            context.interactionPolicy.minimumControlExtent;
        final estimatedMenuHeight =
            items.where((item) => !item.isDivider).length * minimumItemExtent +
            items.where((item) => item.isDivider).length;
        final maxMenuHeight = math.max(0.0, safeBottom - safeTop);
        final menuHeight = math.min(estimatedMenuHeight, maxMenuHeight);
        final maxLeft = math.max(safeLeft, safeRight - menuWidth);
        final maxTop = math.max(safeTop, safeBottom - menuHeight);
        final left = local.dx.clamp(safeLeft, maxLeft);
        // Text scaling and localization can make rows much taller than their
        // minimum extent. Near the bottom edge, reserve the full scrollable
        // viewport instead of positioning from an unreliable height guess.
        final top = local.dy + estimatedMenuHeight > safeBottom
            ? safeTop
            : local.dy.clamp(safeTop, maxTop);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            children: [
              if (listenable != null)
                ListenableBuilder(
                  listenable: listenable!,
                  builder: (_, _) => ProContextMenu(
                    position: Offset(left, top),
                    items: itemsBuilder!(),
                    maxHeight: maxMenuHeight,
                    baseWidth: 240,
                    onSelect: (item) => Navigator.of(context).pop(item),
                  ),
                )
              else
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  maxHeight: maxMenuHeight,
                  baseWidth: 240,
                  onSelect: (item) => Navigator.of(context).pop(item),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
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
