import 'package:flutter/material.dart';

import 'prompt_tag_mode_toggle.dart';

/// Reserves a stable trailing mode switch beside each editor's own controls.
class PromptEditorControlRow extends StatelessWidget {
  const PromptEditorControlRow({
    super.key,
    required this.sessionId,
    required this.leading,
    this.action,
  });

  final Object sessionId;
  final Widget leading;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: leading),
      const SizedBox(width: 4),
      PromptTagModeToggle(sessionId: sessionId),
      if (action != null) ...[const SizedBox(width: 4), action!],
    ],
  );
}
