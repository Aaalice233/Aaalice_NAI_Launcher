import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/online_gallery/danbooru_post.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../providers/online_gallery_blacklist_provider.dart';
import '../../../../providers/online_gallery_output_filter_provider.dart';
import '../../../../providers/online_gallery_provider.dart';
import '../../../../widgets/online_gallery/blacklist_settings_panel.dart';
import '../../../../widgets/online_gallery/output_filter_settings_panel.dart';
import '../../online_gallery_screen_controller.dart';
import 'online_gallery_toolbar.dart';
import 'online_gallery_toolbar_bindings.dart';
import 'online_gallery_toolbar_search.dart';
import 'online_gallery_toolbar_source_controls.dart';

class OnlineGalleryToolbarDialogs {
  const OnlineGalleryToolbarDialogs(this.bindings);

  static final Map<OnlineGalleryScreenController, LocalHistoryEntry>
  _dateRangeHistoryEntries = {};

  final OnlineGalleryToolbarBindings bindings;

  BuildContext get context => bindings.context;
  OnlineGalleryScreenController get _controller => bindings.controller;
  OnlineGalleryNotifier get _galleryNotifier => bindings.commands.gallery;
  GallerySourceId _activeSource(OnlineGalleryState state) =>
      switch (state.viewMode) {
        GalleryViewMode.search => state.sourceId,
        GalleryViewMode.popular => state.popularSourceId,
        GalleryViewMode.favorites => state.favoritesSourceId,
      };

  Future<void> showSourceFilters({bool includeGlobalPolicy = false}) async {
    await AdaptivePresenter.showPanel<void>(
      context: context,
      initialChildSize: 0.58,
      minChildSize: 0.36,
      maxChildSize: 0.92,
      sideSheetWidth: 480,
      titleBuilder: (panelContext) => Row(
        children: [
          const Icon(Icons.tune_rounded, size: 20),
          const SizedBox(width: 8),
          Text(panelContext.l10n.common_filter),
        ],
      ),
      builder: (panelContext, scrollController) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(onlineGalleryNotifierProvider);
          final blacklist = ref.watch(onlineGalleryBlacklistNotifierProvider);
          final outputFilter = ref.watch(onlineGalleryOutputFilterProvider);
          final theme = Theme.of(context);
          final dialogBindings = bindings.withGallery(state);
          final activeSource = _activeSource(state);
          final sourceName = switch (activeSource) {
            GallerySourceId.quickTagCloud =>
              context.l10n.onlineGallery_sourceQuickTagCloud,
            _ => activeSource.label,
          };
          final isAiTagPromptMode =
              activeSource == GallerySourceId.aiTag &&
              state.viewMode != GalleryViewMode.favorites;
          final promptController = state.viewMode == GalleryViewMode.popular
              ? _controller.popularPromptSearchController
              : _controller.promptSearchController;
          final promptFocusNode = state.viewMode == GalleryViewMode.popular
              ? _controller.popularPromptSearchFocusNode
              : _controller.promptSearchFocusNode;

          return Scrollbar(
            controller: scrollController,
            thumbVisibility:
                context.interactionPolicy.shouldExposeTouchAlternatives,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (includeGlobalPolicy) ...[
                  Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          key: const ValueKey(
                            'online-gallery-mobile-blacklist-filter',
                          ),
                          leading: const Icon(Icons.block_rounded),
                          title: Text(context.l10n.onlineGallery_blacklistTags),
                          subtitle: Text(
                            context.l10n.onlineGallery_blacklistSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            blacklist.tags.length.toString(),
                            style: theme.textTheme.labelLarge,
                          ),
                          onTap: () => showOnlineGalleryBlacklistDialog(
                            context,
                            ref,
                            sourceId: activeSource,
                          ),
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: theme.dividerColor,
                        ),
                        ListTile(
                          key: const ValueKey(
                            'online-gallery-mobile-output-filter',
                          ),
                          leading: const Icon(Icons.filter_alt_off_rounded),
                          title: Text(context.l10n.onlineGallery_outputFilter),
                          subtitle: Text(
                            context.l10n.onlineGallery_outputFilterSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            outputFilter.tags.length.toString(),
                            style: theme.textTheme.labelLarge,
                          ),
                          onTap: () =>
                              showOnlineGalleryOutputFilterDialog(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  sourceName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (isAiTagPromptMode) ...[
                  SizedBox(
                    height: gallerySearchFieldHeightFor(context),
                    child: OnlineGalleryToolbarSearch(dialogBindings)
                        .buildPromptField(
                          theme,
                          controller: promptController,
                          focusNode: promptFocusNode,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
                KeyedSubtree(
                  key: const ValueKey('online-gallery-mobile-source-filters'),
                  child: OnlineGalleryToolbarSourceControls(
                    dialogBindings,
                  ).buildSecondaryControls(theme, wrapControls: true),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void toggleDateRangePopup() {
    final state = bindings.data.gallery;
    if (_controller.dateRangeOverlayEntry != null) {
      _hideDateRangePopup();
      return;
    }
    _showDateRangePopup(state);
  }

  void _showDateRangePopup(OnlineGalleryState state) {
    final overlay = Overlay.of(context);
    final route = ModalRoute.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        final mediaQuery = MediaQuery.of(overlayContext);
        final safePadding = mediaQuery.padding;
        final keyboardInset = mediaQuery.viewInsets.bottom;

        return LayoutBuilder(
          builder: (context, constraints) {
            const edgeInset = 8.0;
            final left = safePadding.left + edgeInset;
            final right = safePadding.right + edgeInset;
            final top = safePadding.top + edgeInset;
            final bottom = safePadding.bottom + keyboardInset + edgeInset;
            final availableHeight = (constraints.maxHeight - top - bottom)
                .clamp(0.0, constraints.maxHeight);
            final availableWidth = (constraints.maxWidth - left - right).clamp(
              0.0,
              constraints.maxWidth,
            );
            final scaledWidth =
                340.0 +
                (mediaQuery.textScaler.scale(100) - 100).clamp(0.0, 340.0);
            final popupContentWidth = mediaQuery.textScaler.scale(1) > 1
                ? scaledWidth
                : availableWidth.clamp(0.0, 340.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _hideDateRangePopup,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: left,
                  right: right,
                  top: top,
                  bottom: bottom,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape):
                          _hideDateRangePopup,
                    },
                    child: Focus(
                      autofocus: true,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 340,
                            maxHeight: availableHeight,
                          ),
                          child: Material(
                            key: const ValueKey(
                              'online-gallery-date-range-popup',
                            ),
                            elevation: 12,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            color: theme.colorScheme.surface,
                            child: SingleChildScrollView(
                              key: const ValueKey(
                                'online-gallery-date-range-popup-scroll',
                              ),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: SingleChildScrollView(
                                key: const ValueKey(
                                  'online-gallery-date-range-popup-horizontal-scroll',
                                ),
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: popupContentWidth,
                                  child: OnlineGalleryDateRangePopup(
                                    initialStart: state.dateRangeStart,
                                    initialEnd: state.dateRangeEnd,
                                    firstDate: DateTime(2005),
                                    lastDate: now,
                                    onApply: (start, end) {
                                      _hideDateRangePopup();
                                      _galleryNotifier.setDateRange(start, end);
                                    },
                                    onClear: () {
                                      _hideDateRangePopup();
                                      _galleryNotifier.clearDateRange();
                                    },
                                    onClose: _hideDateRangePopup,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    _controller.dateRangeOverlayEntry = entry;
    overlay.insert(entry);
    if (route != null) {
      final historyEntry = LocalHistoryEntry(
        onRemove: () {
          _dateRangeHistoryEntries.remove(_controller);
          if (identical(_controller.dateRangeOverlayEntry, entry)) {
            entry.remove();
            _controller.dateRangeOverlayEntry = null;
          }
        },
      );
      _dateRangeHistoryEntries[_controller] = historyEntry;
      route.addLocalHistoryEntry(historyEntry);

      entry.addListener(() {
        if (!entry.mounted) {
          _dateRangeHistoryEntries.remove(_controller)?.remove();
        }
      });
    }
  }

  void _hideDateRangePopup() {
    final entry = _controller.dateRangeOverlayEntry;
    _controller.dateRangeOverlayEntry = null;
    entry?.remove();
    _dateRangeHistoryEntries.remove(_controller)?.remove();
  }
}
