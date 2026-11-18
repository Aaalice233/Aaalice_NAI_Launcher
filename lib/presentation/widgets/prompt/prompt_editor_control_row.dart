import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prompt_assistant/widgets/prompt_assistant_dock.dart';
import '../../prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'prompt_tag_mode_toggle.dart';

/// Reserves a stable trailing mode switch beside each editor's own controls.
class PromptEditorControlRow extends ConsumerWidget {
  const PromptEditorControlRow({
    super.key,
    required this.sessionId,
    required this.leading,
    this.minimumLeadingWidth,
    this.action,
    this.assistant,
  });

  final Object sessionId;
  final Widget leading;
  final double? minimumLeadingWidth;
  final Widget? action;

  /// Inline assistant docked at the row end; expanding takes over the row.
  final PromptAssistantOverlay? assistant;

  static const double _gap = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistant = this.assistant;
    Widget buildRow(Widget leading) {
      final row = Row(
        children: [
          Expanded(child: leading),
          const SizedBox(width: _gap),
          PromptTagModeToggle(sessionId: sessionId),
          if (action != null) ...[const SizedBox(width: _gap), action!],
        ],
      );
      return assistant == null
          ? row
          : PromptAssistantDock(assistant: assistant, child: row);
    }

    final minimumLeadingWidth = this.minimumLeadingWidth;
    if (minimumLeadingWidth == null) return buildRow(leading);
    final minimumRowWidth =
        minimumLeadingWidth +
        _gap +
        PromptTagModeToggle.width +
        (action == null ? 0 : kMinInteractiveDimension + _gap) +
        (assistant == null
            ? 0
            : PromptAssistantDock.reservedWidth(context, ref, assistant));

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < minimumRowWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stacked) ...[leading, const SizedBox(height: _gap)],
            buildRow(stacked ? const SizedBox.shrink() : leading),
          ],
        );
      },
    );
  }
}
