import 'package:flutter/material.dart';

import '../../themes/core/layered_surface_style.dart';
import 'tag_editor_session.dart';

/// Shows the moving selection without mounting another editable capsule.
class TagDragPreview extends StatelessWidget {
  const TagDragPreview({
    super.key,
    required this.tags,
    required this.maxWidth,
    this.placeholder = false,
  });
  final List<PromptEditorTag> tags;
  final double maxWidth;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ConstrainedBox(
      key: ValueKey(placeholder ? 'tag-drag-placeholder' : 'tag-drag-feedback'),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (placeholder) ...[
            Container(
              key: const ValueKey('tag-drop-indicator'),
              width: 3,
              height: 44,
              color: colors.primary,
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Material(
              color: placeholder
                  ? controlSurfaceColor(colors)
                  : overlaySurfaceColor(colors),
              elevation: placeholder ? 0 : 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: placeholder ? colors.primary : colors.outline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        tags.firstOrNull?.span.label ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (tags.length > 1) ...[
                      const SizedBox(width: 8),
                      Text(
                        '+${tags.length - 1}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
