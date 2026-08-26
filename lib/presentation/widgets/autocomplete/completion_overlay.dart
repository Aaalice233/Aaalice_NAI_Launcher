import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../../core/autocomplete/autocomplete_settings.dart';
import '../../../core/autocomplete/cooccurrence_data_pack_service.dart';
import '../../../core/autocomplete/completion_models.dart';
import '../../../core/autocomplete/zh_dictionary_service.dart';
import '../../../core/utils/localization_extension.dart';

const double autocompleteCandidateExtent = 35;

/// Compact completion popup inspired by editor command palettes.
///
/// The header is reserved for query context and actual keyboard commands. The
/// footer reports source health, while the middle remains a dense, scannable
/// table of candidates.
class CompletionOverlay extends StatelessWidget {
  const CompletionOverlay({
    super.key,
    required this.state,
    required this.selectedIndex,
    required this.maxHeight,
    required this.scrollController,
    required this.settings,
    required this.dictionaryState,
    this.cooccurrenceDataPackState = const CooccurrenceDataPackState(),
    required this.showAliases,
    required this.showTranslations,
    required this.showCategory,
    required this.showCount,
    required this.onSelected,
    required this.onClose,
    required this.onOpenSettings,
    this.isRelatedPinned = false,
    this.onToggleRelatedPin,
  });

  final CompletionState state;
  final int selectedIndex;
  final double maxHeight;
  final ScrollController scrollController;
  final AutocompleteSettings settings;
  final ZhDictionaryState dictionaryState;
  final CooccurrenceDataPackState cooccurrenceDataPackState;
  final bool showAliases;
  final bool showTranslations;
  final bool showCategory;
  final bool showCount;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;
  final bool isRelatedPinned;
  final VoidCallback? onToggleRelatedPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final popupSurface = Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: dark ? 0.075 : 0.012),
      theme.colorScheme.surface,
    );
    const radius = BorderRadius.all(Radius.circular(10));
    return DecoratedBox(
      key: const ValueKey('autocomplete-popup-surface'),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          if (dark)
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              blurRadius: 5,
              spreadRadius: -1,
            ),
          BoxShadow(
            color: theme.colorScheme.primary.withValues(
              alpha: dark ? 0.12 : 0.06,
            ),
            blurRadius: 22,
            spreadRadius: -6,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.68 : 0.2),
            blurRadius: 34,
            spreadRadius: dark ? 3 : 0,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.38 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Material(
          key: const ValueKey('autocomplete-popup-background'),
          color: popupSurface,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CompletionHeader(
                  query: _displayQuery(state.query),
                  resultCount: state.candidates.length,
                  related: state.query?.relatedTag != null,
                  isRelatedPinned: isRelatedPinned,
                  onToggleRelatedPin: onToggleRelatedPin,
                  onClose: onClose,
                ),
                Flexible(
                  child: state.candidates.isEmpty
                      ? _EmptyCompletionBody(state: state)
                      : Scrollbar(
                          key: const ValueKey('autocomplete-popup-scrollbar'),
                          controller: scrollController,
                          thumbVisibility: state.candidates.length > 9,
                          trackVisibility: state.candidates.length > 9,
                          interactive: true,
                          thickness: 8,
                          radius: const Radius.circular(8),
                          child: ListView.builder(
                            key: const ValueKey('autocomplete-popup-list'),
                            controller: scrollController,
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(right: 14),
                            itemExtent: autocompleteCandidateExtent,
                            scrollCacheExtent: const ScrollCacheExtent.pixels(
                              350,
                            ),
                            addAutomaticKeepAlives: false,
                            itemCount: state.candidates.length,
                            itemBuilder: (context, index) {
                              final candidate = state.candidates[index];
                              return _CompletionTile(
                                key: ValueKey(
                                  'autocomplete-candidate-${candidate.stableId}',
                                ),
                                candidate: candidate,
                                selected: index == selectedIndex,
                                showAliases: showAliases,
                                showTranslations: showTranslations,
                                showCategory: showCategory,
                                showCount: showCount,
                                onTap: () => onSelected(index),
                              );
                            },
                          ),
                        ),
                ),
                _CompletionFooter(
                  state: state,
                  settings: settings,
                  dictionaryState: dictionaryState,
                  cooccurrenceDataPackState: cooccurrenceDataPackState,
                  onOpenSettings: onOpenSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _displayQuery(CompletionQuery? query) {
    if (query == null) return '';
    if (query.token.isNotEmpty) return query.token;
    return query.relatedTag ?? '';
  }
}

class _EmptyCompletionBody extends StatelessWidget {
  const _EmptyCompletionBody({required this.state});

  final CompletionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = state.isLocalLoading || state.isRemoteLoading;
    final related = state.query?.relatedTag != null;
    final error = state.localError ?? state.remoteError;
    return SizedBox(
      key: const ValueKey('autocomplete-popup-empty'),
      height: 78,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(
                  error == null
                      ? Icons.manage_search_rounded
                      : Icons.error_outline_rounded,
                  size: 18,
                  color: error == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              const SizedBox(width: 9),
              Flexible(
                child: Tooltip(
                  message: error ?? '',
                  child: Text(
                    loading
                        ? related
                              ? context.l10n.autocomplete_relatedLoading
                              : context.l10n.autocomplete_loading
                        : error == null
                        ? related
                              ? context.l10n.autocomplete_relatedEmpty
                              : context.l10n.autocomplete_empty
                        : context.l10n.autocomplete_statusError,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: error == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionHeader extends StatelessWidget {
  const _CompletionHeader({
    required this.query,
    required this.resultCount,
    required this.related,
    required this.isRelatedPinned,
    required this.onToggleRelatedPin,
    required this.onClose,
  });

  final String query;
  final int resultCount;
  final bool related;
  final bool isRelatedPinned;
  final VoidCallback? onToggleRelatedPin;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('autocomplete-popup-header'),
      height: 36,
      padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showTitle = constraints.maxWidth >= 440;
          final showFullShortcuts = constraints.maxWidth >= 650;
          final showCompactShortcuts = constraints.maxWidth >= 540;
          return Row(
            children: [
              if (showTitle) ...[
                Container(
                  width: 3,
                  height: 17,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  related
                      ? context.l10n.autocomplete_relatedHeaderTitle
                      : context.l10n.autocomplete_headerTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Container(
                  key: const ValueKey('autocomplete-popup-query'),
                  height: 25,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      theme.colorScheme.onSurface.withValues(alpha: 0.07),
                      theme.colorScheme.surfaceContainerHigh,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                context.l10n.autocomplete_resultsCount(resultCount),
                key: const ValueKey('autocomplete-popup-result-count'),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 9),
              if (showFullShortcuts)
                const _KeyboardHints()
              else if (showCompactShortcuts)
                const _KeyboardHints(compact: true)
              else
                Tooltip(
                  message: _shortcutDescription(context),
                  child: Icon(
                    Icons.keyboard_alt_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 2),
              if (related && onToggleRelatedPin != null)
                _NonFocusableIconButton(
                  key: const ValueKey('autocomplete-popup-related-pin'),
                  tooltip: isRelatedPinned
                      ? context.l10n.autocomplete_relatedUnpin
                      : context.l10n.autocomplete_relatedPin,
                  icon: isRelatedPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  active: isRelatedPinned,
                  onPressed: onToggleRelatedPin!,
                ),
              _NonFocusableIconButton(
                key: const ValueKey('autocomplete-popup-close'),
                tooltip: context.l10n.autocomplete_actionClose,
                icon: Icons.close_rounded,
                onPressed: onClose,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _shortcutDescription(BuildContext context) =>
      '↑↓ ${context.l10n.autocomplete_actionSelect} · '
      'Enter/Tab ${context.l10n.autocomplete_actionConfirm} · '
      'Esc ${context.l10n.autocomplete_actionClose}';
}

class _KeyboardHints extends StatelessWidget {
  const _KeyboardHints({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 10.5,
    );
    final keyStyle = mutedStyle?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: compact
          ? [
              Text('↑↓', style: keyStyle),
              Text(' · ', style: mutedStyle),
              Text('Enter/Tab', style: keyStyle),
              Text(' · ', style: mutedStyle),
              Text('Esc', style: keyStyle),
            ]
          : [
              Text('↑↓', style: keyStyle),
              const SizedBox(width: 3),
              Text(context.l10n.autocomplete_actionSelect, style: mutedStyle),
              Text(' · ', style: mutedStyle),
              Text('Enter/Tab', style: keyStyle),
              const SizedBox(width: 3),
              Text(context.l10n.autocomplete_actionConfirm, style: mutedStyle),
              Text(' · ', style: mutedStyle),
              Text('Esc', style: keyStyle),
              const SizedBox(width: 3),
              Text(context.l10n.autocomplete_actionClose, style: mutedStyle),
            ],
    );
    return Tooltip(
      message: _CompletionHeader._shortcutDescription(context),
      child: SizedBox(
        width: compact ? 105 : 218,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: content,
        ),
      ),
    );
  }
}

class _CompletionTile extends StatelessWidget {
  const _CompletionTile({
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
    final categoryColor = _categoryColor(context, candidate.category);
    final secondary = <String>[
      if (showTranslations && candidate.translation?.isNotEmpty == true)
        candidate.translation!,
      if (showAliases && candidate.matchedAlias?.isNotEmpty == true)
        context.l10n.autocomplete_aliasMatch(candidate.matchedAlias!),
    ];
    final sourceTooltip = candidate.sources
        .map((source) => _sourceTooltip(context, source))
        .join(' · ');

    return Tooltip(
      message: sourceTooltip,
      waitDuration: const Duration(milliseconds: 450),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: candidate.isExisting ? null : onTap,
          child: Container(
            height: 35,
            decoration: BoxDecoration(
              color: selected
                  ? categoryColor.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.27 : 0.13,
                    )
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.2,
                  ),
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
              child: Row(
                children: [
                  if (showCategory) ...[
                    Tooltip(
                      message: _categoryLabel(context, candidate.category),
                      child: Icon(
                        _categoryIcon(candidate.category),
                        key: ValueKey(
                          'autocomplete-category-${candidate.category.name}',
                        ),
                        size: 15,
                        color: categoryColor,
                      ),
                    ),
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
                        translationMissing:
                            candidate.translation?.isNotEmpty != true,
                      ),
                    ),
                  ],
                  if (showCount) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: _metricTooltip(context, candidate),
                      child: SizedBox(
                        width: 54,
                        child: Text(
                          _metricLabel(candidate),
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _metricColor(context),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _SourceBadges(sources: candidate.sources),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _categoryIcon(TagCategory category) => switch (category) {
    TagCategory.general => Icons.sell_rounded,
    TagCategory.artist => Icons.brush_rounded,
    TagCategory.copyright => Icons.copyright_rounded,
    TagCategory.character => Icons.person_rounded,
    TagCategory.meta => Icons.tune_rounded,
    TagCategory.contributor => Icons.badge_rounded,
    TagCategory.species => Icons.pets_rounded,
    TagCategory.lore => Icons.auto_stories_rounded,
    TagCategory.library => Icons.collections_bookmark_rounded,
  };

  static String _categoryLabel(BuildContext context, TagCategory category) =>
      switch (category) {
        TagCategory.general => context.l10n.autocomplete_categoryGeneral,
        TagCategory.artist => context.l10n.autocomplete_categoryArtist,
        TagCategory.copyright => context.l10n.autocomplete_categoryCopyright,
        TagCategory.character => context.l10n.autocomplete_categoryCharacter,
        TagCategory.meta => context.l10n.autocomplete_categoryMeta,
        TagCategory.contributor =>
          context.l10n.autocomplete_categoryContributor,
        TagCategory.species => context.l10n.autocomplete_categorySpecies,
        TagCategory.lore => context.l10n.autocomplete_categoryLore,
        TagCategory.library => context.l10n.autocomplete_categoryLibrary,
      };

  static Color _categoryColor(BuildContext context, TagCategory category) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch ((category, dark)) {
      (TagCategory.general, true) => const Color(0xff62b9f0),
      (TagCategory.general, false) => const Color(0xff176d9f),
      (TagCategory.artist, true) => const Color(0xffff7b78),
      (TagCategory.artist, false) => const Color(0xffb52c2a),
      (TagCategory.copyright, true) => const Color(0xffd083e0),
      (TagCategory.copyright, false) => const Color(0xff7b4389),
      (TagCategory.character, true) => const Color(0xff7bd27e),
      (TagCategory.character, false) => const Color(0xff2b7834),
      (TagCategory.meta, true) => const Color(0xffffb85c),
      (TagCategory.meta, false) => const Color(0xff925b08),
      (TagCategory.contributor, true) => const Color(0xffff9d66),
      (TagCategory.contributor, false) => const Color(0xffa84f1d),
      (TagCategory.species, true) => const Color(0xff5ed6c4),
      (TagCategory.species, false) => const Color(0xff167568),
      (TagCategory.lore, true) => const Color(0xff9fa8ff),
      (TagCategory.lore, false) => const Color(0xff4d56a8),
      (TagCategory.library, true) => const Color(0xff64d4c5),
      (TagCategory.library, false) => const Color(0xff167568),
    };
  }

  static Color _metricColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xff66bdf3)
      : const Color(0xff176d9f);

  static String _sourceTooltip(
    BuildContext context,
    CompletionSourceKind source,
  ) => switch (source) {
    CompletionSourceKind.base => context.l10n.autocomplete_sourceBase,
    CompletionSourceKind.zhDictionary => context.l10n.autocomplete_sourceZh,
    CompletionSourceKind.danbooruApi => context.l10n.autocomplete_sourceApi,
    CompletionSourceKind.cooccurrence =>
      context.l10n.autocomplete_sourceRelated,
    CompletionSourceKind.ai => context.l10n.autocomplete_sourceAi,
    CompletionSourceKind.library => context.l10n.autocomplete_categoryLibrary,
  };

  static String _metricLabel(CompletionCandidate candidate) {
    final score = candidate.relatedScore;
    if (score != null) {
      final percent = score * 100;
      return percent >= 10
          ? '${percent.toStringAsFixed(0)}%'
          : '${percent.toStringAsFixed(1)}%';
    }
    return candidate.postCount > 0 ? _compactCount(candidate.postCount) : '';
  }

  static String _metricTooltip(
    BuildContext context,
    CompletionCandidate candidate,
  ) {
    final score = candidate.relatedScore;
    if (score == null) return _compactCount(candidate.postCount);
    return context.l10n.autocomplete_relatedMetric(
      candidate.cooccurrenceCount ?? 0,
      '${(score * 100).toStringAsFixed(2)}%',
    );
  }

  static String _compactCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
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

class _SourceBadges extends StatelessWidget {
  const _SourceBadges({required this.sources});

  final Set<CompletionSourceKind> sources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordered = sources.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    final visible = ordered.take(4).toList();
    return SizedBox(
      width: 112,
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

class _CompletionFooter extends StatelessWidget {
  const _CompletionFooter({
    required this.state,
    required this.settings,
    required this.dictionaryState,
    required this.cooccurrenceDataPackState,
    required this.onOpenSettings,
  });

  final CompletionState state;
  final AutocompleteSettings settings;
  final ZhDictionaryState dictionaryState;
  final CooccurrenceDataPackState cooccurrenceDataPackState;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('autocomplete-popup-footer'),
      height: 31,
      padding: const EdgeInsets.only(left: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final veryCompact = constraints.maxWidth < 430;
          final related = state.query?.relatedTag != null;
          final statuses = <_StatusDescriptor>[
            if (related)
              _relatedStatus(context)
            else if (!veryCompact)
              _baseStatus(context),
            _dictionaryStatus(context),
            _onlineStatus(context),
            if (!compact || settings.llmTranslationEnabled) _aiStatus(context),
          ];
          return Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var index = 0; index < statuses.length; index++) ...[
                      if (index > 0) const SizedBox(width: 13),
                      Flexible(
                        child: _StatusIndicator(
                          key: ValueKey(statuses[index].key),
                          descriptor: statuses[index],
                          compact: compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                height: 19,
                width: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.46),
              ),
              _NonFocusableIconButton(
                key: const ValueKey('autocomplete-popup-settings'),
                tooltip: context.l10n.autocomplete_openSettings,
                icon: Icons.settings_rounded,
                onPressed: onOpenSettings,
              ),
            ],
          );
        },
      ),
    );
  }

  _StatusDescriptor _baseStatus(BuildContext context) => _StatusDescriptor(
    key: 'autocomplete-status-base',
    icon: Icons.storage_rounded,
    label: context.l10n.autocomplete_statusBase,
    value: context.l10n.autocomplete_statusReady,
    tone: _StatusTone.ready,
    tooltip:
        '${context.l10n.autocomplete_baseCatalog}: ${context.l10n.autocomplete_statusReady}',
  );

  _StatusDescriptor _relatedStatus(BuildContext context) {
    if (!settings.relatedTagsEnabled) {
      return _StatusDescriptor(
        key: 'autocomplete-status-related',
        icon: Icons.hub_outlined,
        label: context.l10n.autocomplete_statusRelated,
        value: context.l10n.autocomplete_statusDisabled,
        tone: _StatusTone.inactive,
      );
    }
    if (state.isLocalLoading) {
      return _StatusDescriptor(
        key: 'autocomplete-status-related',
        icon: Icons.hub_outlined,
        label: context.l10n.autocomplete_statusRelated,
        value: context.l10n.autocomplete_statusSearching,
        tone: _StatusTone.loading,
        loading: true,
      );
    }
    if (state.localError?.isNotEmpty == true) {
      return _StatusDescriptor(
        key: 'autocomplete-status-related',
        icon: Icons.hub_outlined,
        label: context.l10n.autocomplete_statusRelated,
        value: context.l10n.autocomplete_statusError,
        tone: _StatusTone.error,
        tooltip: state.localError,
      );
    }
    if (!cooccurrenceDataPackState.hasInstalledData) {
      final downloading =
          cooccurrenceDataPackState.status ==
          CooccurrenceDataPackStatus.downloading;
      return _StatusDescriptor(
        key: 'autocomplete-status-related',
        icon: downloading ? Icons.downloading_rounded : Icons.cloud_outlined,
        label: context.l10n.autocomplete_statusRelated,
        value: context.l10n.autocomplete_statusOnlineOnly,
        tone: downloading ? _StatusTone.loading : _StatusTone.inactive,
        loading: downloading,
        tooltip: context.l10n.autocomplete_statusOnlineOnlyTooltip,
      );
    }
    final localCount = state.candidates
        .where(
          (candidate) =>
              candidate.sources.contains(CompletionSourceKind.cooccurrence),
        )
        .length;
    return _StatusDescriptor(
      key: 'autocomplete-status-related',
      icon: Icons.hub_rounded,
      label: context.l10n.autocomplete_statusRelated,
      value: '$localCount',
      tone: _StatusTone.ready,
      tooltip: context.l10n.autocomplete_sourceRelated,
    );
  }

  _StatusDescriptor _dictionaryStatus(BuildContext context) {
    if (dictionaryState.isBusy) {
      final progress = (dictionaryState.progress * 100).round().clamp(0, 100);
      return _StatusDescriptor(
        key: 'autocomplete-status-dictionary',
        icon: Icons.translate_rounded,
        label: context.l10n.autocomplete_statusDictionary,
        value: context.l10n.autocomplete_statusDownloading(progress),
        tone: _StatusTone.loading,
        loading: true,
      );
    }
    if (dictionaryState.error?.isNotEmpty == true) {
      return _StatusDescriptor(
        key: 'autocomplete-status-dictionary',
        icon: Icons.translate_rounded,
        label: context.l10n.autocomplete_statusDictionary,
        value: context.l10n.autocomplete_statusError,
        tone: _StatusTone.error,
        tooltip: dictionaryState.error,
      );
    }
    if (!dictionaryState.isInstalled) {
      return _StatusDescriptor(
        key: 'autocomplete-status-dictionary',
        icon: Icons.translate_rounded,
        label: context.l10n.autocomplete_statusDictionary,
        value: context.l10n.autocomplete_statusNotInstalled,
        tone: _StatusTone.warning,
        tooltip: context.l10n.autocomplete_zhNotInstalled,
      );
    }
    if (dictionaryState.updateAvailable) {
      return _StatusDescriptor(
        key: 'autocomplete-status-dictionary',
        icon: Icons.translate_rounded,
        label: context.l10n.autocomplete_statusDictionary,
        value: context.l10n.autocomplete_statusUpdateAvailable,
        tone: _StatusTone.warning,
      );
    }
    final translatedCount = state.candidates
        .where((candidate) => candidate.translation?.isNotEmpty == true)
        .length;
    final totalCount = state.candidates.length;
    return _StatusDescriptor(
      key: 'autocomplete-status-dictionary',
      icon: Icons.translate_rounded,
      label: context.l10n.autocomplete_statusDictionary,
      value: totalCount == 0
          ? context.l10n.autocomplete_statusReady
          : '$translatedCount/$totalCount',
      tone: _StatusTone.ready,
      tooltip: totalCount == 0
          ? context.l10n.autocomplete_entryCount(dictionaryState.tagCount)
          : context.l10n.autocomplete_translationCoverage(
              translatedCount,
              totalCount,
            ),
    );
  }

  _StatusDescriptor _onlineStatus(BuildContext context) {
    if (!settings.danbooruEnabled) {
      return _StatusDescriptor(
        key: 'autocomplete-status-online',
        icon: Icons.public_rounded,
        label: context.l10n.autocomplete_statusOnline,
        value: context.l10n.autocomplete_statusDisabled,
        tone: _StatusTone.inactive,
      );
    }
    if (state.isRemoteLoading) {
      return _StatusDescriptor(
        key: 'autocomplete-status-online',
        icon: Icons.public_rounded,
        label: context.l10n.autocomplete_statusOnline,
        value: context.l10n.autocomplete_statusSearching,
        tone: _StatusTone.loading,
        loading: true,
      );
    }
    if (state.remoteError?.isNotEmpty == true) {
      return _StatusDescriptor(
        key: 'autocomplete-status-online',
        icon: Icons.public_off_rounded,
        label: context.l10n.autocomplete_statusOnline,
        value: context.l10n.autocomplete_statusError,
        tone: _StatusTone.error,
        tooltip: state.remoteError,
      );
    }
    return _StatusDescriptor(
      key: 'autocomplete-status-online',
      icon: Icons.public_rounded,
      label: context.l10n.autocomplete_statusOnline,
      value: context.l10n.autocomplete_statusReady,
      tone: _StatusTone.ready,
      tooltip: context.l10n.autocomplete_danbooruPrivacy,
    );
  }

  _StatusDescriptor _aiStatus(BuildContext context) {
    if (!settings.llmTranslationEnabled) {
      return _StatusDescriptor(
        key: 'autocomplete-status-ai',
        icon: Icons.auto_awesome_outlined,
        label: context.l10n.autocomplete_statusAi,
        value: context.l10n.autocomplete_statusDisabled,
        tone: _StatusTone.inactive,
      );
    }
    if (state.candidates.any((candidate) => candidate.isTranslating)) {
      return _StatusDescriptor(
        key: 'autocomplete-status-ai',
        icon: Icons.auto_awesome_rounded,
        label: context.l10n.autocomplete_statusAi,
        value: context.l10n.autocomplete_statusTranslating,
        tone: _StatusTone.loading,
        loading: true,
      );
    }
    if (state.translationError?.isNotEmpty == true) {
      return _StatusDescriptor(
        key: 'autocomplete-status-ai',
        icon: Icons.auto_awesome_outlined,
        label: context.l10n.autocomplete_statusAi,
        value: context.l10n.autocomplete_statusError,
        tone: _StatusTone.error,
        tooltip: state.translationError,
      );
    }
    return _StatusDescriptor(
      key: 'autocomplete-status-ai',
      icon: Icons.auto_awesome_rounded,
      label: context.l10n.autocomplete_statusAi,
      value: context.l10n.autocomplete_statusReady,
      tone: _StatusTone.ready,
    );
  }
}

enum _StatusTone { ready, loading, warning, error, inactive }

class _StatusDescriptor {
  const _StatusDescriptor({
    required this.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.loading = false,
    this.tooltip,
  });

  final String key;
  final IconData icon;
  final String label;
  final String value;
  final _StatusTone tone;
  final bool loading;
  final String? tooltip;
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    super.key,
    required this.descriptor,
    required this.compact,
  });

  final _StatusDescriptor descriptor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toneColor = switch (descriptor.tone) {
      _StatusTone.ready => const Color(0xff4fb77b),
      _StatusTone.loading => theme.colorScheme.primary,
      _StatusTone.warning => const Color(0xffd99a3b),
      _StatusTone.error => theme.colorScheme.error,
      _StatusTone.inactive => theme.colorScheme.outline,
    };
    final tooltip = descriptor.tooltip?.isNotEmpty == true
        ? '${descriptor.label}: ${descriptor.value}\n${descriptor.tooltip}'
        : '${descriptor.label}: ${descriptor.value}';
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: '${descriptor.label}: ${descriptor.value}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (descriptor.loading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.7,
                  color: toneColor,
                ),
              )
            else
              Icon(descriptor.icon, size: 14, color: toneColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (!compact)
                      TextSpan(
                        text: '${descriptor.label} ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    TextSpan(
                      text: descriptor.value,
                      style: TextStyle(
                        color: descriptor.tone == _StatusTone.error
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NonFocusableIconButton extends StatefulWidget {
  const _NonFocusableIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  State<_NonFocusableIconButton> createState() =>
      _NonFocusableIconButtonState();
}

class _NonFocusableIconButtonState extends State<_NonFocusableIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered || widget.active
                ? colors.primary.withValues(alpha: widget.active ? 0.2 : 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            tooltip: widget.tooltip,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            iconSize: 16,
            color: _hovered || widget.active
                ? colors.primary
                : colors.onSurfaceVariant,
            onPressed: widget.onPressed,
            icon: Icon(widget.icon),
          ),
        ),
      ),
    );
  }
}
