import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/services/date_formatting_service.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/online_gallery/danbooru_post.dart';
import '../../../../../data/services/gelbooru_auth_service.dart';
import '../../../../../data/services/online_gallery/quick_tag_cloud_access.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../providers/online_gallery_blacklist_provider.dart';
import '../../../../providers/online_gallery_output_filter_provider.dart';
import '../../../../providers/online_gallery_prompt_tag_settings_provider.dart';
import '../../../../providers/online_gallery_provider.dart';
import '../../../../providers/quick_tag_cloud_gallery_provider.dart';
import '../../../../widgets/common/app_toast.dart';
import '../../../../widgets/online_gallery/blacklist_settings_panel.dart';
import '../../../../widgets/online_gallery/output_filter_settings_panel.dart';
import '../../../../widgets/online_gallery/quick_tag_cloud_toolbar.dart';
import 'online_gallery_toolbar.dart';
import '../../online_gallery_screen_controller.dart';
import 'online_gallery_toolbar_auth.dart';
import 'online_gallery_toolbar_bindings.dart';
import 'online_gallery_toolbar_dialogs.dart';

class OnlineGalleryToolbarSourceControls {
  OnlineGalleryToolbarSourceControls(this.bindings);

  final OnlineGalleryToolbarBindings bindings;
  final DateFormattingService _dateFormattingService = DateFormattingService();

  BuildContext get context => bindings.context;
  WidgetRef get ref => bindings.ref;
  OnlineGalleryState get state => bindings.data.gallery;
  OnlineGalleryScreenController get _controller => bindings.controller;
  OnlineGalleryNotifier get _galleryNotifier => bindings.commands.gallery;

  GallerySourceId _activeSource(OnlineGalleryState state) =>
      switch (state.viewMode) {
        GalleryViewMode.search => state.sourceId,
        GalleryViewMode.popular => state.popularSourceId,
        GalleryViewMode.favorites => state.favoritesSourceId,
      };

  Widget buildSourceSelector({
    String? selectedLabel,
    double maxLabelWidth = 150,
    bool expandLabel = false,
  }) => _buildSourceSelector(
    state,
    selectedLabel: selectedLabel,
    maxLabelWidth: maxLabelWidth,
    expandLabel: expandLabel,
  );

  Widget buildRatingControl(ThemeData theme, {required bool compact}) =>
      _buildRatingControl(theme, state, compact: compact);

  Widget buildGalleryPolicyControls(
    ThemeData theme, {
    required GallerySourceId sourceId,
    required bool compact,
  }) =>
      _buildGalleryPolicyControls(theme, sourceId: sourceId, compact: compact);

  Future<void> showSourceFilters({bool includeGlobalPolicy = false}) =>
      _showSourceFilters(includeGlobalPolicy: includeGlobalPolicy);

  void showBlacklist() => showOnlineGalleryBlacklistDialog(
    context,
    ref,
    sourceId: _activeSource(state),
  );

  void showOutputFilter() => showOnlineGalleryOutputFilterDialog(context);

  Widget buildSecondaryControls(ThemeData theme, {bool wrapControls = false}) =>
      _buildSecondaryControls(theme, state, wrapControls: wrapControls);

  Widget _buildArtistHuntButton(ThemeData theme, OnlineGalleryState state) {
    return Tooltip(
      message: context.l10n.onlineGallery_artistHuntTooltip,
      child: Semantics(
        button: true,
        toggled: state.artistHuntEnabled,
        label: context.l10n.onlineGallery_artistHunt,
        child: TextButton.icon(
          key: const ValueKey('online-gallery-artist-hunt-toggle'),
          onPressed: () {
            bindings.commands.saveScrollOffset();
            unawaited(
              _galleryNotifier.setArtistHuntEnabled(!state.artistHuntEnabled),
            );
          },
          icon: const Icon(Icons.brush_outlined, size: 17),
          label: Text(context.l10n.onlineGallery_artistHunt),
          style: TextButton.styleFrom(
            backgroundColor: state.artistHuntEnabled
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            foregroundColor: state.artistHuntEnabled
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            visualDensity: context.interactionPolicy.prefersTouchPresentation
                ? VisualDensity.standard
                : VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  Set<String> _quickTagCloudDisplayRatings(Set<String> ratings) {
    final selected = ratings
        .where(QuickTagCloudAccess.galleryRatings.contains)
        .toSet();
    if (selected.isEmpty && ratings.contains('s')) selected.add('g');
    return selected;
  }

  Future<void> _toggleQuickTagCloudRating(
    Set<String> currentRatings,
    String rating,
  ) async {
    final next = _quickTagCloudDisplayRatings(currentRatings);
    if (rating == 'all') {
      next
        ..clear()
        ..addAll(QuickTagCloudAccess.galleryRatings);
    } else if (QuickTagCloudAccess.galleryRatings.contains(rating)) {
      if (next.contains(rating)) {
        if (next.length == 1) return;
        next.remove(rating);
      } else {
        next.add(rating);
      }
    } else {
      return;
    }
    if (rating != 'g' && currentRatings.contains('s')) next.add('s');

    final allowNsfw = QuickTagCloudAccess.allowsNsfw(next);
    final filterNotifier = ref.read(quickTagCloudFilterProvider.notifier);
    final query = ref.read(quickTagCloudFilterProvider);
    final catalog = ref.read(quickTagCloudCatalogProvider).valueOrNull;
    if (!allowNsfw && catalog?.findCodex(query.codexId)?.nsfw == true) {
      filterNotifier.selectCodex('all');
    }
    await filterNotifier.setContentAccess(
      allowNsfw: allowNsfw,
      allowR18g: QuickTagCloudAccess.allowsR18g(next),
    );
    _galleryNotifier.syncQuickTagCloudFilterKey();
    await _galleryNotifier.setRatings(next);
  }

  Widget _buildSourceSelector(
    OnlineGalleryState state, {
    String? selectedLabel,
    double maxLabelWidth = 150,
    bool expandLabel = false,
  }) {
    return switch (state.viewMode) {
      GalleryViewMode.search => OnlineGallerySourceDropdown(
        selected: state.sourceId,
        sources: {
          GallerySourceId.danbooru: 'Danbooru',
          GallerySourceId.safebooru: 'Safebooru',
          GallerySourceId.gelbooru: 'Gelbooru',
          GallerySourceId.aiTag: 'AI TAG',
          GallerySourceId.quickTagCloud:
              context.l10n.onlineGallery_sourceQuickTagCloud,
        },
        selectedLabel: selectedLabel,
        maxLabelWidth: maxLabelWidth,
        expandLabel: expandLabel,
        onChanged: (source) {
          bindings.commands.saveScrollOffset();
          _galleryNotifier.setSource(
            source,
            draftQuery: _controller.searchController.text,
            draftPrompt: _controller.promptSearchController.text,
          );
        },
      ),
      GalleryViewMode.popular => OnlineGallerySourceDropdown(
        selected: state.popularSourceId,
        sources: const {
          GallerySourceId.danbooru: 'Danbooru',
          GallerySourceId.safebooru: 'Safebooru',
          GallerySourceId.aiTag: 'AI TAG',
        },
        selectedLabel: selectedLabel,
        maxLabelWidth: maxLabelWidth,
        expandLabel: expandLabel,
        onChanged: (source) {
          bindings.commands.saveScrollOffset();
          _galleryNotifier.setPopularSource(
            source,
            draftQuery: _controller.popularSearchController.text,
            draftPrompt: _controller.popularPromptSearchController.text,
          );
        },
      ),
      GalleryViewMode.favorites => OnlineGallerySourceDropdown(
        selected: state.favoritesSourceId,
        sources: {
          GallerySourceId.danbooru: 'Danbooru',
          GallerySourceId.safebooru: 'Safebooru',
          GallerySourceId.gelbooru: 'Gelbooru',
          GallerySourceId.aiTag: 'AI TAG',
          GallerySourceId.quickTagCloud:
              context.l10n.onlineGallery_sourceQuickTagCloud,
        },
        selectedLabel: selectedLabel,
        maxLabelWidth: maxLabelWidth,
        expandLabel: expandLabel,
        onChanged: (source) {
          bindings.commands.saveScrollOffset();
          _galleryNotifier.setFavoritesSource(
            source,
            draftQuery: _controller.favoriteSearchController.text,
          );
        },
      ),
    };
  }

  Widget _buildRatingControl(
    ThemeData theme,
    OnlineGalleryState state, {
    required bool compact,
  }) {
    Widget sourceRatingStatus({
      required IconData icon,
      required String label,
      required String tooltip,
    }) {
      if (!compact) {
        return Tooltip(
          message: tooltip,
          child: Chip(
            avatar: Icon(icon, size: 16),
            label: Text(label),
            visualDensity: context.interactionPolicy.prefersTouchPresentation
                ? VisualDensity.standard
                : VisualDensity.compact,
          ),
        );
      }
      return Tooltip(
        message: '$label · $tooltip',
        child: Semantics(
          label: '$label. $tooltip',
          child: Container(
            width: galleryToolbarControlHeightFor(context),
            height: galleryToolbarControlHeightFor(context),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 19,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final sourceId = _activeSource(state);
    if (sourceId == GallerySourceId.safebooru) {
      return sourceRatingStatus(
        icon: Icons.shield_outlined,
        label: context.l10n.onlineGallery_ratingGeneral,
        tooltip: context.l10n.onlineGallery_sourceGeneralOnly,
      );
    }
    if (sourceId == GallerySourceId.aiTag) {
      return sourceRatingStatus(
        icon: Icons.help_outline,
        label: context.l10n.onlineGallery_sourceUnrated,
        tooltip: context.l10n.onlineGallery_sourceUnratedTooltip,
      );
    }
    if (sourceId == GallerySourceId.quickTagCloud) {
      return OnlineGalleryRatingDropdown(
        selectedRatings: _quickTagCloudDisplayRatings(state.selectedRatings),
        availableRatings: QuickTagCloudAccess.galleryRatings,
        compact: compact,
        onToggle: (rating) => unawaited(
          _toggleQuickTagCloudRating(state.selectedRatings, rating),
        ),
      );
    }
    return OnlineGalleryRatingDropdown(
      selectedRatings: state.selectedRatings,
      compact: compact,
      onToggle: _galleryNotifier.toggleRating,
    );
  }

  Widget _buildGalleryPolicyControls(
    ThemeData theme, {
    required GallerySourceId sourceId,
    required bool compact,
  }) {
    final blacklist = ref.watch(onlineGalleryBlacklistNotifierProvider);
    final outputFilterCount = ref.watch(
      onlineGalleryOutputFilterProvider.select((value) => value.tags.length),
    );
    Widget policyButton({
      required Key key,
      required IconData icon,
      required String label,
      required String tooltip,
      required VoidCallback onPressed,
    }) {
      final style = TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        visualDensity: context.interactionPolicy.prefersTouchPresentation
            ? VisualDensity.standard
            : VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      );
      final button = compact
          ? TextButton(
              key: key,
              onPressed: onPressed,
              style: style,
              child: Text(label),
            )
          : TextButton.icon(
              key: key,
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: style,
            );
      return Tooltip(message: tooltip, child: button);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        policyButton(
          key: const ValueKey('online-gallery-blacklist'),
          icon: Icons.block,
          label:
              '${context.l10n.onlineGallery_blacklistShort} · ${blacklist.tags.length}',
          tooltip: context.l10n.onlineGallery_blacklistTags,
          onPressed: () => showOnlineGalleryBlacklistDialog(
            context,
            ref,
            sourceId: sourceId,
          ),
        ),
        const SizedBox(width: 6),
        policyButton(
          key: const ValueKey('online-gallery-output-filter'),
          icon: Icons.filter_alt_off_outlined,
          label:
              '${compact ? context.l10n.onlineGallery_outputFilterShort : context.l10n.onlineGallery_outputFilter} · $outputFilterCount',
          tooltip: context.l10n.onlineGallery_outputFilterTooltip,
          onPressed: () => showOnlineGalleryOutputFilterDialog(context),
        ),
      ],
    );
  }

  Future<void> _showSourceFilters({required bool includeGlobalPolicy}) =>
      OnlineGalleryToolbarDialogs(
        bindings,
      ).showSourceFilters(includeGlobalPolicy: includeGlobalPolicy);

  Widget _buildSecondaryControls(
    ThemeData theme,
    OnlineGalleryState state, {
    bool wrapControls = false,
  }) {
    final activeSourceId = switch (state.viewMode) {
      GalleryViewMode.search => state.sourceId,
      GalleryViewMode.popular => state.popularSourceId,
      GalleryViewMode.favorites => state.favoritesSourceId,
    };
    final capabilities = gallerySourceCapabilities[activeSourceId]!;
    final controls = <Widget>[];

    if (state.viewMode == GalleryViewMode.favorites &&
        state.currentCache.hasFavoritesPartialFailure) {
      controls.add(_buildFavoritesPartialFailureNotice(theme, state));
    }
    if (activeSourceId == GallerySourceId.quickTagCloud) {
      controls.add(
        QuickTagCloudToolbar(
          favoritesMode: state.viewMode == GalleryViewMode.favorites,
          selectedRatings: state.selectedRatings,
          wrapControls: wrapControls,
          onFiltersChanged: () async {
            bindings.commands.saveScrollOffset();
            _galleryNotifier.syncQuickTagCloudFilterKey();
            await _galleryNotifier.refresh();
            if (context.mounted && _controller.scrollController.hasClients) {
              _controller.scrollController.jumpTo(0);
            }
          },
        ),
      );
    } else {
      if (state.viewMode == GalleryViewMode.search &&
          capabilities.supportsFuzzySearch) {
        controls.add(
          OnlineGalleryFuzzySearchToggle(
            enabled: state.fuzzySearchEnabled,
            onChanged: _galleryNotifier.setFuzzySearchEnabled,
          ),
        );
      }
      if (state.viewMode == GalleryViewMode.search &&
          capabilities.supportsDateRange) {
        controls.add(_buildDateRangeButton(theme, state));
      }
      if (state.viewMode == GalleryViewMode.search &&
          activeSourceId == GallerySourceId.aiTag) {
        controls.add(_buildAiTagTimeRangeDropdown(state));
      }
      if (capabilities.supportsCategorizedTags) {
        controls.add(_buildPromptTagCategorySelector(theme));
      }
      if (state.viewMode == GalleryViewMode.popular) {
        controls.add(
          OnlineGalleryToolbarAuthControls(bindings).buildPopularOptions(theme),
        );
      }
      if (state.viewMode == GalleryViewMode.favorites &&
          state.favoritesSourceId == GallerySourceId.gelbooru &&
          ref.watch(gelbooruAuthProvider).isAuthenticated) {
        controls
          ..add(
            OnlineGalleryToolbarAuthControls(
              bindings,
            ).buildGelbooruFavoritesNotice(theme),
          )
          ..add(
            TextButton.icon(
              onPressed: state.isLoading ? null : _saveVisibleFavoritesLocally,
              icon: const Icon(Icons.download_done_rounded, size: 17),
              label: Text(context.l10n.onlineGallery_saveVisibleLocally),
            ),
          );
      }
      if (activeSourceId == GallerySourceId.aiTag &&
          state.viewMode != GalleryViewMode.favorites) {
        controls.add(_buildArtistHuntButton(theme, state));
      }
    }

    if (wrapControls) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: controls,
      );
    }
    return Row(
      key: const ValueKey('online-gallery-secondary-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < controls.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          controls[index],
        ],
      ],
    );
  }

  Widget _buildFavoritesPartialFailureNotice(
    ThemeData theme,
    OnlineGalleryState state,
  ) {
    final localFailed = state.currentCache.localFavoritesErrorCode != null;
    final message = localFailed
        ? context.l10n.onlineGallery_localFavoritesPartialFailure
        : context.l10n.onlineGallery_cloudFavoritesPartialFailure;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 6),
          Text(message),
          IconButton(
            tooltip: context.l10n.common_retry,
            onPressed: state.isLoading
                ? null
                : () => _galleryNotifier.refreshWithDraft(
                    query: _controller.favoriteSearchController.text,
                    prompt: '',
                  ),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            visualDensity: context.interactionPolicy.prefersTouchPresentation
                ? VisualDensity.standard
                : VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _saveVisibleFavoritesLocally() async {
    try {
      final count = await _galleryNotifier.saveVisiblePostsToLocalFavorites();
      if (!context.mounted) return;
      if (count == 0) {
        AppToast.info(
          context,
          context.l10n.onlineGallery_visibleFavoritesAlreadySaved,
        );
      } else {
        AppToast.success(
          context,
          context.l10n.onlineGallery_visibleFavoritesSaved(count),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      AppToast.error(
        context,
        context.l10n.onlineGallery_saveFavoritesFailed(error.toString()),
      );
    }
  }

  Widget _buildPromptTagCategorySelector(ThemeData theme) =>
      _PromptTagCategorySelector(theme: theme);

  Widget _buildAiTagTimeRangeDropdown(OnlineGalleryState state) {
    final ranges = state.aiTagConfig?.timeRanges ?? const {'all': 'All'};
    final selected = ranges.containsKey(state.aiTagTimeRange)
        ? state.aiTagTimeRange
        : ranges.keys.first;
    return Tooltip(
      message: context.l10n.onlineGallery_aiTagTimeRange,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          items: ranges.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    entry.key == 'all'
                        ? context.l10n.onlineGallery_aiTagAllTime
                        : entry.key == 'older'
                        ? context.l10n.onlineGallery_aiTagOlderMonthly
                        : entry.value,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) _galleryNotifier.setAiTagTimeRange(value);
          },
        ),
      ),
    );
  }

  /// 构建日期范围筛选按钮
  Widget _buildDateRangeButton(ThemeData theme, OnlineGalleryState state) {
    final hasDateRange =
        state.dateRangeStart != null || state.dateRangeEnd != null;

    return CompositedTransformTarget(
      link: _controller.dateRangeLayerLink,
      child: TextButton.icon(
        onPressed: () => _toggleDateRangePopup(state),
        icon: Icon(
          Icons.date_range,
          size: 16,
          color: hasDateRange ? theme.colorScheme.primary : null,
        ),
        label: Text(
          hasDateRange
              ? _dateFormattingService.formatDateRange(
                  state.dateRangeStart,
                  state.dateRangeEnd,
                )
              : context.l10n.onlineGallery_dateRange,
          style: TextStyle(
            fontSize: 12,
            color: hasDateRange ? theme.colorScheme.primary : null,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: hasDateRange
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          visualDensity: context.interactionPolicy.prefersTouchPresentation
              ? VisualDensity.standard
              : VisualDensity.compact,
        ),
      ),
    );
  }

  void _toggleDateRangePopup(OnlineGalleryState state) =>
      OnlineGalleryToolbarDialogs(bindings).toggleDateRangePopup();
}

class _PromptTagCategorySelector extends ConsumerStatefulWidget {
  const _PromptTagCategorySelector({required this.theme});

  final ThemeData theme;

  @override
  ConsumerState<_PromptTagCategorySelector> createState() =>
      _PromptTagCategorySelectorState();
}

class _PromptTagCategorySelectorState
    extends ConsumerState<_PromptTagCategorySelector> {
  final MenuController _menuController = MenuController();

  String _labelFor(OnlineGalleryPromptTagCategory category) {
    return switch (category) {
      OnlineGalleryPromptTagCategory.general =>
        context.l10n.tagCategory_general,
      OnlineGalleryPromptTagCategory.character =>
        context.l10n.tagCategory_character,
      OnlineGalleryPromptTagCategory.copyright =>
        context.l10n.tagCategory_copyright,
      OnlineGalleryPromptTagCategory.artist => context.l10n.tagCategory_artist,
      OnlineGalleryPromptTagCategory.meta => context.l10n.tagCategory_meta,
    };
  }

  Future<void> _setCategory(
    OnlineGalleryPromptTagCategory category,
    bool? selected,
  ) async {
    if (selected == null) return;
    final changed = await ref
        .read(onlineGalleryPromptTagSettingsProvider.notifier)
        .setCategory(category, selected);
    if (!mounted) return;
    if (!changed) {
      AppToast.info(
        context,
        context.l10n.onlineGallery_keepOnePromptTagCategory,
      );
      return;
    }
    if (_menuController.isOpen) {
      // MenuAnchor caches an opened menu's children. Recreate the overlay after
      // the provider rebuild so its checkboxes display the new values at once.
      _menuController.close();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _menuController.open();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(onlineGalleryPromptTagSettingsProvider);
    final theme = widget.theme;
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        MenuItemButton(
          onPressed: null,
          leadingIcon: const Icon(Icons.sell_outlined, size: 18),
          child: Text(context.l10n.onlineGallery_promptTagCategories),
        ),
        const Divider(height: 1),
        for (final category in OnlineGalleryPromptTagCategory.values)
          CheckboxMenuButton(
            key: ValueKey(
              'online-gallery-prompt-tag-category-${category.name}',
            ),
            value: settings.categories.contains(category),
            closeOnActivate: false,
            onChanged: (selected) => _setCategory(category, selected),
            child: Text(_labelFor(category)),
          ),
      ],
      builder: (context, controller, child) {
        return Tooltip(
          message: context.l10n.onlineGallery_promptTagCategoriesTooltip,
          child: TextButton.icon(
            key: const ValueKey('online-gallery-prompt-tag-categories'),
            onPressed: () {
              controller.isOpen ? controller.close() : controller.open();
            },
            icon: const Icon(Icons.sell_outlined, size: 17),
            label: Text(
              '${context.l10n.onlineGallery_promptTagCategories} · ${settings.categories.length}',
            ),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              visualDensity: context.interactionPolicy.prefersTouchPresentation
                  ? VisualDensity.standard
                  : VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }
}
