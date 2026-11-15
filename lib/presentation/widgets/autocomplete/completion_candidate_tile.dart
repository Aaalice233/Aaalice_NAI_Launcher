import 'package:flutter/material.dart';

import '../../../core/autocomplete/completion_models.dart';
import '../../../core/utils/localization_extension.dart';
import 'completion_overlay_metrics.dart';
import 'completion_source_badges.dart';
import 'completion_tag_style.dart';

class CompletionCandidateTile extends StatelessWidget {
  const CompletionCandidateTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.showAliases,
    required this.showTranslations,
    required this.showCategory,
    required this.showCount,
    required this.onTap,
  });

  final CompletionCandidate candidate;
  final bool selected;
  final bool showAliases;
  final bool showTranslations;
  final bool showCategory;
  final bool showCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = autocompleteCategoryColor(
      context,
      candidate.category,
    );
    final secondary = <String>[
      if (showTranslations && candidate.translation?.isNotEmpty == true)
        candidate.translation!,
      if (!showTranslations &&
          showAliases &&
          candidate.matchedAlias?.isNotEmpty == true)
        context.l10n.autocomplete_aliasMatch(candidate.matchedAlias!),
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: candidate.isExisting ? null : onTap,
        child: Container(
          height: effectiveAutocompleteCandidateExtent(context),
          decoration: BoxDecoration(
            color: selected
                ? categoryColor.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.27 : 0.13,
                  )
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              left: BorderSide(
                color: selected ? categoryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: 7, right: 8),
          child: Opacity(
            opacity: candidate.isExisting ? 0.46 : 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 480) {
                  return _buildCompactContent(
                    context,
                    theme,
                    categoryColor,
                    secondary,
                  );
                }
                return _buildWideContent(
                  context,
                  theme,
                  categoryColor,
                  secondary,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactContent(
    BuildContext context,
    ThemeData theme,
    Color categoryColor,
    List<String> secondary,
  ) {
    final hasSecondary =
        secondary.isNotEmpty || (showTranslations && candidate.isTranslating);
    return Row(
      children: [
        if (showCategory) ...[
          _buildCategoryIcon(context, categoryColor, size: 16),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      candidate.canonicalTag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ),
                    ),
                  ),
                  if (showCount) ...[
                    const SizedBox(width: 8),
                    _buildMetric(context, theme, width: 52),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: hasSecondary
                        ? _CandidateSecondary(
                            values: secondary,
                            isTranslating:
                                showTranslations && candidate.isTranslating,
                            translationMissing: false,
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 6),
                  CompletionSourceBadges(
                    sources: candidate.sources,
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideContent(
    BuildContext context,
    ThemeData theme,
    Color categoryColor,
    List<String> secondary,
  ) {
    return Row(
      children: [
        if (showCategory) ...[
          _buildCategoryIcon(context, categoryColor),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: showTranslations ? 5 : 8,
          child: Text(
            candidate.canonicalTag,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: categoryColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05,
            ),
          ),
        ),
        if (showTranslations) ...[
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: _CandidateSecondary(
              values: secondary,
              isTranslating: candidate.isTranslating,
              translationMissing: candidate.translation?.isNotEmpty != true,
            ),
          ),
        ],
        if (showCount) ...[
          const SizedBox(width: 8),
          _buildMetric(context, theme),
        ],
        const SizedBox(width: 8),
        CompletionSourceBadges(sources: candidate.sources),
      ],
    );
  }

  Widget _buildCategoryIcon(
    BuildContext context,
    Color categoryColor, {
    double size = 15,
  }) {
    return Tooltip(
      message: autocompleteCategoryLabel(context, candidate.category),
      child: Icon(
        autocompleteCategoryIcon(candidate.category),
        key: ValueKey('autocomplete-category-${candidate.category.name}'),
        size: size,
        color: categoryColor,
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context,
    ThemeData theme, {
    double width = 54,
  }) {
    return Tooltip(
      message: autocompleteMetricTooltip(context, candidate),
      child: SizedBox(
        width: width,
        child: Text(
          autocompleteMetricLabel(candidate),
          maxLines: 1,
          textAlign: TextAlign.right,
          style: theme.textTheme.labelMedium?.copyWith(
            color: autocompleteMetricColor(context),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _CandidateSecondary extends StatelessWidget {
  const _CandidateSecondary({
    required this.values,
    required this.isTranslating,
    required this.translationMissing,
  });

  final List<String> values;
  final bool isTranslating;
  final bool translationMissing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValues = <String>[
      if (translationMissing && !isTranslating)
        context.l10n.autocomplete_missingTranslation,
      ...values,
    ];
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: Center(
            child: isTranslating
                ? SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      value: MediaQuery.disableAnimationsOf(context)
                          ? 0.75
                          : null,
                      strokeWidth: 1.5,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    translationMissing
                        ? Icons.translate_rounded
                        : Icons.menu_book_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: translationMissing ? 0.48 : 0.82,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            isTranslating && values.isEmpty
                ? context.l10n.autocomplete_translating
                : displayValues.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(
                alpha: translationMissing ? 0.62 : 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
