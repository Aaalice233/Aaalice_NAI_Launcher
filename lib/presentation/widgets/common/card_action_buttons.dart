import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'image_card_action.dart';
import 'image_card_action_dispatch.dart';
import 'image_card_action_region.dart';
import 'image_card_context_menu.dart';

import '../../../l10n/app_localizations.dart';
import '../../adaptive/interaction_policy.dart';

/// 图像明暗不可预测，覆盖操作统一使用半透明暗色面与亮色前景，避免主题色
/// 在浅色图片上失去边界。
abstract final class ImageOverlayControlStyle {
  static const foreground = Colors.white;
  static const surface = Color(0x8F000000);
  static const hoveredSurface = Color(0xB8000000);
  static const disabledSurface = Color(0x66000000);
  static const border = Color(0x33FFFFFF);
  static const hoveredBorder = Color(0x52FFFFFF);
  static const toolbarSurface = Color(0x99000000);

  static ButtonStyle iconButton(
    BuildContext context, {
    required double extent,
    Color? foregroundColor,
  }) {
    final resolvedForeground = foregroundColor ?? foreground;
    final interaction = context.interactionPolicy;
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.square(extent)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      shape: const WidgetStatePropertyAll(CircleBorder()),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledSurface;
        if (interaction.isControlHighlighted(states)) {
          return hoveredSurface;
        }
        return surface;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled)
            ? resolvedForeground.withValues(alpha: 0.55)
            : resolvedForeground;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final emphasized = interaction.isControlHighlighted(states);
        return BorderSide(color: emphasized ? hoveredBorder : border);
      }),
    );
  }
}

/// 卡片操作按钮组。高频悬浮操作必须即时响应，不做延迟或出现动画。
class CardActionButtons extends StatelessWidget {
  final List<ImageCardAction> buttons;
  final bool visible;
  final Axis direction;
  final Size? availableSize;
  final Set<ImageCardActionId> touchShortcuts;
  final Axis touchDirection;
  final Key? menuKey;
  final double pointerExtent;
  final Map<ImageCardActionGroup, ({IconData icon, String label})> groupMenus;

  const CardActionButtons({
    super.key,
    required this.buttons,
    required this.visible,
    this.direction = Axis.horizontal,
    this.availableSize,
    this.touchShortcuts = const {},
    this.touchDirection = Axis.vertical,
    this.menuKey,
    this.pointerExtent = 32,
    this.groupMenus = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (this.buttons.isEmpty) return const SizedBox.shrink();

    final buttons = this.buttons
        .where((a) => a.visible && a.showOnHover)
        .toList();
    final interactionPolicy = context.interactionPolicy;
    final loadingLabel =
        AppLocalizations.of(context)?.common_loading ?? 'Loading…';

    if (interactionPolicy.usesTouchActionMenu) {
      final extent = interactionPolicy.minimumControlExtent;
      final more = IconButton(
        key: menuKey,
        tooltip:
            AppLocalizations.of(context)?.common_moreActions ??
            MaterialLocalizations.of(context).showMenuTooltip,
        onPressed: () => _showTouchActions(context, loadingLabel),
        constraints: BoxConstraints.tightFor(width: extent, height: extent),
        style: ImageOverlayControlStyle.iconButton(context, extent: extent),
        icon: const Icon(Icons.more_vert_rounded),
      );
      final shortcuts = this.buttons.where(
        (a) => a.visible && touchShortcuts.contains(a.id),
      );
      if (shortcuts.isEmpty) return more;
      return Flex(
        direction: touchDirection,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in shortcuts)
            _CardActionButton(config: action, extent: extent),
          more,
        ],
      );
    }

    // Remove hidden tooltips from the overlay together with their card. Keeping
    // transparent buttons mounted lets a tooltip linger while the pointer has
    // already moved to another card, producing duplicate labels.
    if (!visible) return const SizedBox.shrink();

    // Dense image overlays use compact pointer targets while retaining the
    // stable touch target once a touch device has been observed.
    final extent = interactionPolicy.touchAvailable
        ? interactionPolicy.minimumControlExtent
        : pointerExtent;
    final size = availableSize;
    final columns = size == null
        ? 2
        : ((size.width + 4) / (extent + 4)).floor().clamp(1, 2).toInt();
    final allWidgets = <Widget>[
      for (final button in buttons.where((a) => !a.isDanger))
        _CardActionButton(config: button, extent: extent),
      for (final group in groupMenus.entries)
        if (this.buttons.any((a) => a.visible && a.group == group.key))
          _CardOverflowButton(
            buttons: this.buttons
                .where((a) => a.visible && a.group == group.key)
                .toList(),
            extent: extent,
            icon: group.value.icon,
            label: group.value.label,
          ),
      for (final button in buttons.where((a) => a.isDanger))
        _CardActionButton(config: button, extent: extent),
    ];
    final capacity = size == null
        ? allWidgets.length
        : columns *
              math.max(1, ((size.height + 4) / (extent + 4)).floor()).toInt();
    final actionWidgets =
        direction == Axis.vertical && allWidgets.length > capacity
        ? <Widget>[
            ...allWidgets.take(capacity - 1),
            _CardOverflowButton(buttons: this.buttons, extent: extent),
          ]
        : allWidgets;

    // Keep pointer actions along the edge in at most two balanced columns,
    // instead of extending more columns over the image subject.
    final needsColumns =
        actionWidgets.length > 3 ||
        (size != null && actionWidgets.length * (extent + 4) - 4 > size.height);
    if (direction == Axis.vertical && needsColumns && columns > 1) {
      final rows = (actionWidgets.length / columns).ceil();
      return SizedBox(
        height: extent * rows + 4 * (rows - 1),
        child: Wrap(
          direction: Axis.vertical,
          spacing: 4,
          runSpacing: 4,
          children: actionWidgets,
        ),
      );
    }

    // Landscape cards can be narrower than the combined pointer shortcuts.
    // Wrap within the card's bounded width instead of clipping trailing actions.
    if (direction == Axis.horizontal) {
      return Wrap(spacing: 4, runSpacing: 4, children: actionWidgets);
    }

    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var index = 0; index < actionWidgets.length; index++)
          Padding(
            padding: EdgeInsets.only(
              left: direction == Axis.horizontal && index > 0 ? 4 : 0,
              top: direction == Axis.vertical && index > 0 ? 4 : 0,
            ),
            child: actionWidgets[index],
          ),
      ],
    );
  }

  Future<void> _showTouchActions(BuildContext context, String loadingLabel) {
    final scope = ImageCardActionPresentationScope.maybeOf(context);
    scope?.onMenuOpened?.call();
    return ImageCardContextMenu.show(
      context: context,
      position: Offset.zero,
      actions: scope?.menuActions ?? buttons,
      title: scope?.menuTitle,
      listenable: scope?.menuRunner ?? scope?.runner,
    );
  }
}

class _CardOverflowButton extends StatelessWidget {
  const _CardOverflowButton({
    required this.buttons,
    required this.extent,
    this.icon,
    this.label,
  });
  final List<ImageCardAction> buttons;
  final double extent;
  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: extent,
    child: IconButton(
      tooltip:
          label ??
          AppLocalizations.of(context)?.common_moreActions ??
          MaterialLocalizations.of(context).showMenuTooltip,
      padding: EdgeInsets.zero,
      style: ImageOverlayControlStyle.iconButton(context, extent: extent),
      icon: Icon(icon ?? Icons.more_horiz_rounded, size: 16),
      onPressed: () => _showMenu(context),
    ),
  );

  Future<void> _showMenu(BuildContext context) async {
    final anchor = context.findRenderObject()! as RenderBox;
    final scope = ImageCardActionPresentationScope.maybeOf(context);
    scope?.onMenuOpened?.call();
    await ImageCardContextMenu.show(
      context: context,
      position: anchor.localToGlobal(Offset.zero),
      actions: scope?.menuActions ?? buttons,
      title: scope?.menuTitle,
      listenable: scope?.menuRunner ?? scope?.runner,
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({required this.config, required this.extent});

  final ImageCardAction config;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final canActivate = config.enabled && !config.isLoading;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: canActivate,
      liveRegion: config.isLoading,
      label: config.isLoading
          ? '${config.semanticLabel ?? config.label}, '
                '${AppLocalizations.of(context)?.common_loading ?? 'Loading…'}'
          : config.semanticLabel ?? config.label,
      child: ExcludeSemantics(
        child: IconButton(
          key: config.key,
          tooltip: config.label,
          onPressed: canActivate
              ? () => unawaited(dispatchImageCardAction(context, config))
              : null,
          constraints: BoxConstraints.tightFor(width: extent, height: extent),
          style: ImageOverlayControlStyle.iconButton(
            context,
            extent: extent,
            foregroundColor: config.iconColor,
          ),
          icon: config.isLoading
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: reducedMotion ? 0.72 : null,
                    color:
                        config.iconColor ?? ImageOverlayControlStyle.foreground,
                  ),
                )
              : Icon(config.icon, size: 16),
        ),
      ),
    );
  }
}
