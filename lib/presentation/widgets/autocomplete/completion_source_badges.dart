import 'package:flutter/material.dart';

import '../../../core/autocomplete/completion_models.dart';

class CompletionSourceBadges extends StatelessWidget {
  const CompletionSourceBadges({
    super.key,
    required this.sources,
    this.compact = false,
  });

  final Set<CompletionSourceKind> sources;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordered = sources.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    final visible = ordered.take(compact ? 1 : 4).toList();
    final textScale = MediaQuery.textScalerOf(context).scale(8) / 8;
    final compactWidth = 64 * textScale.clamp(1.0, 1.35).toDouble();
    return SizedBox(
      width: compact ? compactWidth : 112,
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < visible.length; index++) ...[
              if (index > 0) const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: _sourceColor(
                    theme,
                    visible[index],
                  ).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _sourceLabel(visible[index]),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _sourceColor(theme, visible[index]),
                    fontSize: 8,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (ordered.length > visible.length) ...[
              const SizedBox(width: 3),
              Text(
                '+${ordered.length - visible.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 8.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _sourceLabel(CompletionSourceKind source) => switch (source) {
    CompletionSourceKind.base => 'BASE',
    CompletionSourceKind.zhDictionary => 'ZH',
    CompletionSourceKind.danbooruApi => 'API',
    CompletionSourceKind.cooccurrence => 'REL',
    CompletionSourceKind.ai => 'AI',
    CompletionSourceKind.library => 'LIB',
  };

  static Color _sourceColor(ThemeData theme, CompletionSourceKind source) {
    final dark = theme.brightness == Brightness.dark;
    return switch (source) {
      CompletionSourceKind.base => theme.colorScheme.onSurfaceVariant,
      CompletionSourceKind.zhDictionary =>
        dark ? const Color(0xff72ca7b) : const Color(0xff2e7d32),
      CompletionSourceKind.danbooruApi =>
        dark ? const Color(0xff64b5f6) : const Color(0xff1565c0),
      CompletionSourceKind.cooccurrence =>
        dark ? const Color(0xffffb75f) : const Color(0xff9a5900),
      CompletionSourceKind.ai =>
        dark ? const Color(0xffce82dc) : const Color(0xff7b1fa2),
      CompletionSourceKind.library =>
        dark ? const Color(0xff64d4c5) : const Color(0xff167568),
    };
  }
}
