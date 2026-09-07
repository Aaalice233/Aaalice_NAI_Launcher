import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../adaptive/adaptive_presenter.dart';
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

/// 卡片操作按钮配置
class CardActionButtonConfig {
  final Key? key;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;
  final String? semanticLabel;
  final bool enabled;
  final bool isLoading;

  const CardActionButtonConfig({
    this.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.semanticLabel,
    this.enabled = true,
    this.isLoading = false,
  });
}

/// 卡片操作按钮组。高频悬浮操作必须即时响应，不做延迟或出现动画。
class CardActionButtons extends StatelessWidget {
  final List<CardActionButtonConfig> buttons;
  final bool visible;
  final Axis direction;
  final Size? availableSize;

  const CardActionButtons({
    super.key,
    required this.buttons,
    required this.visible,
    this.direction = Axis.horizontal,
    this.availableSize,
  });

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();

    final interactionPolicy = context.interactionPolicy;
    final loadingLabel =
        AppLocalizations.of(context)?.common_loading ?? 'Loading…';

    if (interactionPolicy.usesTouchActionMenu) {
      final extent = interactionPolicy.minimumControlExtent;
      return IconButton(
        tooltip:
            AppLocalizations.of(context)?.common_moreActions ??
            MaterialLocalizations.of(context).showMenuTooltip,
        onPressed: () => _showTouchActions(context, loadingLabel),
        constraints: BoxConstraints.tightFor(width: extent, height: extent),
        style: ImageOverlayControlStyle.iconButton(context, extent: extent),
        icon: const Icon(Icons.more_vert_rounded),
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
        : 32.0;
    final size = availableSize;
    final columns = size == null
        ? 2
        : ((size.width + 4) / (extent + 4)).floor().clamp(1, 2).toInt();
    final capacity = size == null
        ? buttons.length
        : columns *
              math.max(1, ((size.height + 4) / (extent + 4)).floor()).toInt();
    final directCount = direction == Axis.vertical && buttons.length > capacity
        ? capacity - 1
        : buttons.length;
    final actionWidgets = [
      for (final button in buttons.take(directCount))
        _CardActionButton(config: button, extent: extent),
      if (directCount < buttons.length)
        _CardOverflowButton(
          buttons: buttons.sublist(directCount),
          extent: extent,
        ),
    ];

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

  Future<void> _showTouchActions(
    BuildContext context,
    String loadingLabel,
  ) async {
    final title =
        AppLocalizations.of(context)?.common_moreActions ??
        MaterialLocalizations.of(context).showMenuTooltip;
    final selection = await AdaptivePresenter.showPanel<CardActionButtonConfig>(
      context: context,
      title: title,
      initialChildSize: 0.66,
      builder: (panelContext, scrollController) {
        final reducedMotion = MediaQuery.disableAnimationsOf(panelContext);
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: buttons.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final button = buttons[index];
            final canActivate = button.enabled && !button.isLoading;
            return ListTile(
              enabled: canActivate,
              leading: button.isLoading
                  ? SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: reducedMotion ? 0.72 : null,
                      ),
                    )
                  : Icon(button.icon, color: button.iconColor),
              title: Text(button.tooltip),
              subtitle: button.isLoading ? Text(loadingLabel) : null,
              onTap: canActivate
                  ? () => Navigator.of(panelContext).pop(button)
                  : null,
            );
          },
        );
      },
    );
    selection?.onPressed();
  }
}

class _CardOverflowButton extends StatelessWidget {
  const _CardOverflowButton({required this.buttons, required this.extent});
  final List<CardActionButtonConfig> buttons;
  final double extent;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: extent,
    child: IconButton(
      tooltip:
          AppLocalizations.of(context)?.common_moreActions ??
          MaterialLocalizations.of(context).showMenuTooltip,
      padding: EdgeInsets.zero,
      style: ImageOverlayControlStyle.iconButton(context, extent: extent),
      icon: const Icon(Icons.more_horiz_rounded, size: 16),
      onPressed: () => _showMenu(context),
    ),
  );

  Future<void> _showMenu(BuildContext context) async {
    final anchor = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    // Hover controls can unmount while the pointer travels into the menu.
    // Keep the selected action independent of the trigger's widget lifetime.
    final selected = await showMenu<CardActionButtonConfig>(
      context: context,
      position: RelativeRect.fromRect(
        anchor.localToGlobal(Offset.zero, ancestor: overlay) & anchor.size,
        Offset.zero & overlay.size,
      ),
      items: [
        for (final button in buttons)
          PopupMenuItem(
            value: button,
            enabled: button.enabled && !button.isLoading,
            child: Row(
              children: [
                Icon(
                  button.icon,
                  color: button.iconColor == Colors.white
                      ? null
                      : button.iconColor,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(button.tooltip)),
              ],
            ),
          ),
      ],
    );
    selected?.onPressed();
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({required this.config, required this.extent});

  final CardActionButtonConfig config;
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
          ? '${config.semanticLabel ?? config.tooltip}, '
                '${AppLocalizations.of(context)?.common_loading ?? 'Loading…'}'
          : config.semanticLabel ?? config.tooltip,
      child: ExcludeSemantics(
        child: IconButton(
          key: config.key,
          tooltip: config.tooltip,
          onPressed: canActivate ? config.onPressed : null,
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
