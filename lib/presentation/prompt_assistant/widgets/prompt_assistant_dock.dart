import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/prompt_assistant_state_provider.dart';
import 'prompt_assistant_overlay.dart';

/// A header/footer mount. Expansion covers the leading content without resizing
/// the row; the toolbar itself owns all dimensions and surface styling.
class PromptAssistantDock extends ConsumerWidget {
  const PromptAssistantDock({
    super.key,
    required this.assistant,
    required this.leading,
    this.leadingAction,
    this.minimumLeadingWidth = 0,
  });

  final PromptAssistantOverlay assistant;
  final Widget leading;
  final Widget? leadingAction;
  final double minimumLeadingWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(assistant.placement == PromptAssistantPlacement.inline);
    final visible = assistant.isVisible(context, ref);
    final metrics = assistant.metrics(context);
    final expanded =
        visible &&
        assistant.expandInPlace &&
        ref.watch(
          promptAssistantStateProvider.select(
            (states) => states[assistant.sessionId]?.expanded ?? false,
          ),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = visible
            ? (expanded ? metrics.expandedWidth : metrics.collapsedWidth).clamp(
                0.0,
                constraints.maxWidth,
              )
            : 0.0;
        final showLeadingAction =
            leadingAction != null &&
            constraints.maxWidth - width - 8 >=
                minimumLeadingWidth + metrics.extent + 6;
        final reservedWidth = visible ? width + 8 : 0.0;
        final actionWidth = showLeadingAction ? metrics.extent + 6 : 0.0;
        return SizedBox(
          height: metrics.extent,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              Positioned.fill(
                right: expanded ? 0 : reservedWidth + actionWidth,
                child: Align(alignment: Alignment.centerLeft, child: leading),
              ),
              if (showLeadingAction)
                Positioned(
                  right: visible ? width + 6 : 0,
                  width: metrics.extent,
                  height: metrics.extent,
                  child: leadingAction!,
                ),
              if (visible)
                Positioned(
                  right: 0,
                  width: width,
                  height: metrics.extent,
                  child: assistant,
                ),
            ],
          ),
        );
      },
    );
  }
}
