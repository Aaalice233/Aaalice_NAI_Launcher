import 'package:flutter/material.dart';

import '../../../core/utils/prompt_edit_document.dart';
import '../../../core/utils/localization_extension.dart';

/// Displays the existing wrapper without rewriting or distributing its weight.
class TagEditorWeightLabel extends StatelessWidget {
  const TagEditorWeightLabel({super.key, required this.span});

  final PromptEditSpan span;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefix = span.prefix;
    final numeric = prefix.endsWith('::') && span.suffix == '::'
        ? prefix.substring(0, prefix.length - 2).trim()
        : null;
    final label = numeric != null && double.tryParse(numeric) != null
        ? '×$numeric'
        : '${span.prefix}…${span.suffix}';
    return Tooltip(
      message: '${context.l10n.weight_title}: ${span.prefix}…${span.suffix}',
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
