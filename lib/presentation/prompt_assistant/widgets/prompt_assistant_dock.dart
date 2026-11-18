import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prompt_assistant_overlay.dart';

/// Pins an inline assistant to the end of a control strip; the expanded
/// toolbar covers the strip instead of pushing its neighbours.
class PromptAssistantDock extends ConsumerWidget {
  const PromptAssistantDock({
    super.key,
    required this.assistant,
    required this.child,
  });

  static const double gap = 4;

  final PromptAssistantOverlay assistant;
  final Widget child;

  static double reservedWidth(
    BuildContext context,
    WidgetRef ref,
    PromptAssistantOverlay assistant,
  ) => assistant.isVisible(context, ref)
      ? assistant.metrics(context).collapsedWidth + gap
      : 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(assistant.placement == PromptAssistantPlacement.inline);
    // Stack 常驻：可见性切换只改留白，不改树形，避免控件条状态被重建
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            end: reservedWidth(context, ref, assistant),
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            heightFactor: 1,
            child: child,
          ),
        ),
        assistant,
      ],
    );
  }
}
