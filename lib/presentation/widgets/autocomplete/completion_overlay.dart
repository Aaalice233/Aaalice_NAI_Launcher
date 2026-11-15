import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../../core/autocomplete/autocomplete_settings.dart';
import '../../../core/autocomplete/cooccurrence_data_pack_service.dart';
import '../../../core/autocomplete/completion_models.dart';
import '../../../core/autocomplete/zh_dictionary_service.dart';
import '../../adaptive/interaction_policy.dart';
import 'completion_candidate_tile.dart';
import 'completion_empty_body.dart';
import 'completion_overlay_footer.dart';
import 'completion_overlay_header.dart';
import 'completion_overlay_metrics.dart';

export 'completion_overlay_metrics.dart'
    show autocompleteCandidateExtent, effectiveAutocompleteCandidateExtent;

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
    final interactionPolicy = context.interactionPolicy;
    final touchInput = interactionPolicy.touchAvailable;
    final candidateExtent = effectiveAutocompleteCandidateExtent(context);
    final scaledHeader = MediaQuery.textScalerOf(context).scale(14) * 1.35 + 14;
    final headerExtent = scaledHeader > (touchInput ? 56.0 : 36.0)
        ? scaledHeader
        : (touchInput ? 56.0 : 36.0);
    final scaledFooter = MediaQuery.textScalerOf(context).scale(11) * 1.35 + 16;
    final footerExtent = scaledFooter > (touchInput ? 48.0 : 31.0)
        ? scaledFooter
        : (touchInput ? 48.0 : 31.0);
    final showFooter =
        maxHeight >= headerExtent + candidateExtent + footerExtent;
    final scrollHeader = maxHeight < headerExtent + candidateExtent;
    final header = CompletionOverlayHeader(
      query: _displayQuery(state.query),
      resultCount: state.candidates.length,
      related: state.query?.relatedTag != null,
      isRelatedPinned: isRelatedPinned,
      onToggleRelatedPin: onToggleRelatedPin,
      onOpenSettings: showFooter ? null : onOpenSettings,
      onClose: onClose,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final touchCompact = touchInput && constraints.maxWidth < 600;
        final popupSurface = Color.alphaBlend(
          theme.colorScheme.onSurface.withValues(alpha: dark ? 0.075 : 0.012),
          theme.colorScheme.surface,
        );
        final radius = BorderRadius.all(
          Radius.circular(touchCompact ? 12 : 10),
        );
        return DecoratedBox(
          key: const ValueKey('autocomplete-popup-surface'),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: touchCompact
                ? Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.7,
                    ),
                  )
                : null,
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
                    if (!scrollHeader) header,
                    Flexible(
                      child: state.candidates.isEmpty
                          ? SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CompletionEmptyBody(state: state),
                                  if (scrollHeader) header,
                                ],
                              ),
                            )
                          : Scrollbar(
                              key: const ValueKey(
                                'autocomplete-popup-scrollbar',
                              ),
                              controller: scrollController,
                              thumbVisibility: state.candidates.length > 9,
                              trackVisibility: state.candidates.length > 9,
                              interactive: !touchCompact,
                              thickness: touchCompact ? 4 : 8,
                              radius: const Radius.circular(8),
                              child: CustomScrollView(
                                key: const ValueKey('autocomplete-popup-list'),
                                controller: scrollController,
                                shrinkWrap: true,
                                scrollCacheExtent: ScrollCacheExtent.pixels(
                                  candidateExtent * 10,
                                ),
                                slivers: [
                                  SliverPadding(
                                    padding: EdgeInsets.only(
                                      right: touchCompact ? 6 : 14,
                                    ),
                                    sliver: SliverFixedExtentList(
                                      itemExtent: candidateExtent,
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final candidate =
                                              state.candidates[index];
                                          return CompletionCandidateTile(
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
                                        childCount: state.candidates.length,
                                        addAutomaticKeepAlives: false,
                                      ),
                                    ),
                                  ),
                                  // When the keyboard leaves very little room,
                                  // candidates stay first; header actions remain
                                  // reachable in the same scrollable surface.
                                  if (scrollHeader)
                                    SliverToBoxAdapter(child: header),
                                ],
                              ),
                            ),
                    ),
                    if (showFooter)
                      CompletionOverlayFooter(
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
      },
    );
  }

  static String _displayQuery(CompletionQuery? query) {
    if (query == null) return '';
    if (query.token.isNotEmpty) return query.token;
    return query.relatedTag ?? '';
  }
}
