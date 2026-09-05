import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
import '../../themes/core/layered_surface_style.dart';

/// Geometry is shared by every mounting surface and both expansion states.
class PromptAssistantToolbarMetrics {
  const PromptAssistantToolbarMetrics({
    required this.extent,
    required this.collapsedWidth,
    required this.expandedWidth,
  });

  final double extent;
  final double collapsedWidth;
  final double expandedWidth;

  static double controlExtent(BuildContext context, InteractionPolicy policy) {
    final style = labelStyle(context, policy);
    final textHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1.4);
    return (textHeight + 8).clamp(
      policy.minimumControlExtent.clamp(44.0, double.infinity),
      double.infinity,
    );
  }

  static double contentBottomClearance(
    BuildContext context,
    InteractionPolicy policy,
  ) => controlExtent(context, policy) + (policy.touchAvailable ? 20 : 12);

  factory PromptAssistantToolbarMetrics.resolve(
    BuildContext context, {
    required InteractionPolicy policy,
    required String? collapsedLabel,
    required int actionCount,
  }) {
    final extent = controlExtent(context, policy);
    var collapsedWidth = extent;
    if (collapsedLabel != null) {
      final painter = TextPainter(
        text: TextSpan(
          text: collapsedLabel,
          style: labelStyle(context, policy),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      collapsedWidth = painter.width + extent + 12;
      painter.dispose();
    }
    return PromptAssistantToolbarMetrics(
      extent: extent,
      collapsedWidth: collapsedWidth,
      expandedWidth: actionCount * extent,
    );
  }

  static TextStyle labelStyle(BuildContext context, InteractionPolicy policy) =>
      Theme.of(context).textTheme.labelLarge!.copyWith(
        fontSize: policy.shouldExposeTouchAlternatives ? 14 : 12,
      );
}

class PromptAssistantToolbarAction {
  const PromptAssistantToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? label;
}

/// Owns the surface, clipping and hit areas; callers only supply actions.
class PromptAssistantToolbar extends StatelessWidget {
  const PromptAssistantToolbar({
    super.key,
    required this.sessionId,
    required this.metrics,
    required this.policy,
    required this.expanded,
    required this.actions,
  });

  final String sessionId;
  final PromptAssistantToolbarMetrics metrics;
  final InteractionPolicy policy;
  final bool expanded;
  final List<PromptAssistantToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      key: ValueKey('prompt_assistant_toolbar_$sessionId'),
      height: metrics.extent,
      width: expanded ? metrics.expandedWidth : metrics.collapsedWidth,
      child: Material(
        color: expanded
            ? overlaySurfaceColor(colors)
            : controlSurfaceColor(colors),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          key: ValueKey('prompt_assistant_action_scroll_$sessionId'),
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions) _actionButton(context, action),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    PromptAssistantToolbarAction action,
  ) {
    final icon = Icon(
      action.icon,
      size: policy.shouldExposeTouchAlternatives ? 20 : 17,
    );
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
    return Tooltip(
      message: action.tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 180),
      child: SizedBox(
        height: metrics.extent,
        width: action.label == null ? metrics.extent : metrics.collapsedWidth,
        child: action.label == null
            ? IconButton(onPressed: action.onPressed, icon: icon, style: style)
            : TextButton.icon(
                key: const ValueKey('prompt_assistant_collapsed_button'),
                onPressed: action.onPressed,
                icon: icon,
                label: Text(action.label!, maxLines: 1),
                style: style.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    PromptAssistantToolbarMetrics.labelStyle(context, policy),
                  ),
                ),
              ),
      ),
    );
  }
}
