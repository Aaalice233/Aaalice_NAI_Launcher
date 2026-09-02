import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';

/// 卡片操作按钮配置
class CardActionButtonConfig {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;
  final String? semanticLabel;
  final bool enabled;
  final bool isLoading;

  const CardActionButtonConfig({
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

  const CardActionButtons({
    super.key,
    required this.buttons,
    required this.visible,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();

    final interactionPolicy = context.interactionPolicy;
    final loadingLabel =
        AppLocalizations.of(context)?.common_loading ?? 'Loading…';

    // Once touch capability is observed, the explicit alternative remains
    // available when the user later switches to keyboard or mouse input.
    if (interactionPolicy.shouldExposeTouchAlternatives) {
      final colorScheme = Theme.of(context).colorScheme;
      final extent = interactionPolicy.minimumControlExtent;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.82),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          tooltip:
              AppLocalizations.of(context)?.common_moreActions ??
              MaterialLocalizations.of(context).showMenuTooltip,
          onPressed: () => _showTouchActions(context, loadingLabel),
          constraints: BoxConstraints.tightFor(width: extent, height: extent),
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size.square(extent)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: WidgetStatePropertyAll(
              colorScheme.onInverseSurface,
            ),
          ),
          icon: const Icon(Icons.more_vert_rounded),
        ),
      );
    }

    // Remove hidden tooltips from the overlay together with their card. Keeping
    // transparent buttons mounted lets a tooltip linger while the pointer has
    // already moved to another card, producing duplicate labels.
    if (!visible) return const SizedBox.shrink();

    final extent = interactionPolicy.minimumControlExtent;
    final actionWidgets = [
      for (final button in buttons)
        _CardActionButton(config: button, extent: extent),
    ];

    // Tall cards can expose many pointer accelerators. Pack long vertical
    // groups into columns so every 40/48dp target remains inside the card
    // instead of being painted into a clipped, non-hit-testable area.
    if (direction == Axis.vertical && actionWidgets.length > 3) {
      return SizedBox(
        height: extent * 3 + 8,
        child: Wrap(
          direction: Axis.vertical,
          spacing: 4,
          runSpacing: 4,
          children: actionWidgets,
        ),
      );
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
      initialChildSize: 0.48,
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

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({required this.config, required this.extent});

  final CardActionButtonConfig config;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final canActivate = config.enabled && !config.isLoading;
    final colorScheme = Theme.of(context).colorScheme;
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
          tooltip: config.tooltip,
          onPressed: canActivate ? config.onPressed : null,
          constraints: BoxConstraints.tightFor(width: extent, height: extent),
          padding: EdgeInsets.zero,
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size.square(extent)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return colorScheme.inverseSurface.withValues(alpha: 0.92);
              }
              return colorScheme.inverseSurface.withValues(alpha: 0.82);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              final color = config.iconColor ?? colorScheme.onInverseSurface;
              return states.contains(WidgetState.disabled)
                  ? color.withValues(alpha: 0.65)
                  : color;
            }),
          ),
          icon: config.isLoading
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: reducedMotion ? 0.72 : null,
                    color: colorScheme.onInverseSurface,
                  ),
                )
              : Icon(config.icon, size: 16),
        ),
      ),
    );
  }
}
