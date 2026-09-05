import 'package:flutter/material.dart';

import '../../../core/utils/prompt_edit_document.dart';
import '../../../core/utils/localization_extension.dart';
import 'tag_editor_weight_style.dart';
import '../../adaptive/interaction_policy.dart';

/// Displays the existing wrapper without rewriting or distributing its weight.
class TagEditorWeightLabel extends StatefulWidget {
  const TagEditorWeightLabel({
    super.key,
    required this.span,
    this.emphasisColor,
    this.expandable = false,
  });

  final PromptEditSpan span;
  final Color? emphasisColor;
  final bool expandable;

  @override
  State<TagEditorWeightLabel> createState() => _TagEditorWeightLabelState();
}

class _TagEditorWeightLabelState extends State<TagEditorWeightLabel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final span = widget.span;
    final prefix = span.prefix;
    final numeric = prefix.endsWith('::') && span.suffix == '::'
        ? prefix.substring(0, prefix.length - 2).trim()
        : null;
    final label = numeric != null && double.tryParse(numeric) != null
        ? '×$numeric'
        : '${span.prefix}…${span.suffix}';
    final color = widget.emphasisColor;
    final weightStyle = color == null ? null : TagEditorWeightStyle(color);
    final accent =
        weightStyle?.accent(theme) ?? theme.colorScheme.onSurfaceVariant;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: weightStyle?.surface(theme.colorScheme.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (!widget.expandable) {
      return Tooltip(
        message: '${context.l10n.weight_title}: ${span.prefix}…${span.suffix}',
        child: badge,
      );
    }
    return _buildGroup(context, badge, accent);
  }

  Widget _buildGroup(BuildContext context, Widget badge, Color accent) {
    final theme = Theme.of(context);
    final span = widget.span;
    final touch = InteractionPolicyScope.of(context).touchAvailable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          expanded: _expanded,
          child: Tooltip(
            message:
                '${context.l10n.weight_title}: ${span.prefix}…${span.suffix}',
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(4),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 44,
                  minHeight: touch ? 44 : 24,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      badge,
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: span.prefix,
                    style: TextStyle(color: accent),
                  ),
                  TextSpan(text: span.label),
                  TextSpan(
                    text: span.suffix,
                    style: TextStyle(color: accent),
                  ),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
