import 'package:flutter/material.dart';

import '../common/translated_tag_text.dart';

class GalleryDetailTextSection extends StatelessWidget {
  const GalleryDetailTextSection({
    super.key,
    required this.title,
    required this.content,
    required this.accentColor,
    this.monospace = false,
    this.translateTags = false,
    this.trailing,
    this.maxLines,
  });

  final String title;
  final String content;
  final Color accentColor;
  final bool monospace;
  final bool translateTags;
  final Widget? trailing;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 7),
            if (translateTags)
              TranslatedPromptText(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                  fontFamily: monospace ? 'monospace' : null,
                ),
              )
            else
              SelectableText(
                content,
                maxLines: maxLines,
                // The containing details panel owns vertical scrolling. This
                // prevents a collapsed preview from swallowing wheel events.
                scrollPhysics: const NeverScrollableScrollPhysics(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                  fontFamily: monospace ? 'monospace' : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
