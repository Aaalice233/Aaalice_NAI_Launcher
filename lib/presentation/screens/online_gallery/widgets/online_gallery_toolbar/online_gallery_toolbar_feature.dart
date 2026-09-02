import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/online_gallery/danbooru_post.dart';
import '../../../../../data/services/danbooru_auth_service.dart';
import '../../../../../data/services/gelbooru_auth_service.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../adaptive/window_size_class.dart';
import '../../../../providers/online_gallery_blacklist_provider.dart';
import '../../../../providers/online_gallery_output_filter_provider.dart';
import '../../../../providers/online_gallery_prompt_tag_settings_provider.dart';
import '../../../../providers/online_gallery_provider.dart';
import '../../../../providers/quick_tag_cloud_gallery_provider.dart';
import '../../../../providers/selection_mode_provider.dart';
import '../../../../services/gallery_prompt_projection_service.dart';
import '../../../../widgets/bulk_action_bar.dart';
import '../../../online_gallery/online_gallery_screen_commands.dart';
import '../../../online_gallery/online_gallery_screen_controller.dart';
import 'online_gallery_search_reveal.dart';
import 'online_gallery_toolbar.dart';
import 'online_gallery_toolbar_auth.dart';
import 'online_gallery_toolbar_bindings.dart';
import 'online_gallery_toolbar_search.dart';
import 'online_gallery_toolbar_source_controls.dart';

double _galleryToolbarControlHeight(BuildContext context) =>
    galleryToolbarControlHeightFor(context);
double _gallerySearchFieldHeight(BuildContext context) =>
    gallerySearchFieldHeightFor(context);

enum _MobileGalleryAction {
  blacklist,
  outputFilter,
  random,
  refresh,
  multiSelect,
}

class OnlineGalleryToolbarFeature extends ConsumerWidget {
  const OnlineGalleryToolbarFeature({
    super.key,
    required this.controller,
    required this.data,
    required this.commands,
  });

  final OnlineGalleryScreenController controller;
  final OnlineGalleryToolbarViewData data;
  final OnlineGalleryToolbarCommands commands;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _OnlineGalleryToolbarPresenter(
      OnlineGalleryToolbarBindings(
        context: context,
        ref: ref,
        controller: controller,
        data: data,
        commands: commands,
      ),
    ).build();
  }
}

class _OnlineGalleryToolbarPresenter {
  const _OnlineGalleryToolbarPresenter(this._bindings);

  final OnlineGalleryToolbarBindings _bindings;

  BuildContext get context => _bindings.context;
  WidgetRef get ref => _bindings.ref;
  OnlineGalleryScreenController get _controller => _bindings.controller;
  OnlineGalleryState get state => _bindings.data.gallery;
  OnlineGalleryNotifier get _galleryNotifier => _bindings.commands.gallery;
  OnlineGallerySelectionNotifier get _selectionNotifier =>
      _bindings.commands.selection;
  OnlineGalleryScreenCommands get _actions => _bindings.commands.actions;

  Widget build() => _buildToolbar(
    Theme.of(context),
    state,
    _bindings.data.danbooruAuth,
    _bindings.data.gelbooruAuth,
    _bindings.data.selection,
  );

  Widget _buildToolbar(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
    GelbooruAuthState gelbooruAuthState,
    SelectionModeState selectionState,
  ) {
    if (selectionState.isActive) {
      final promptTagSettings = ref.watch(
        onlineGalleryPromptTagSettingsProvider,
      );
      final outputFilter = ref.watch(onlineGalleryOutputFilterProvider);
      const projectionService = GalleryPromptProjectionService();
      final selectablePostIds = projectionService.selectableStableKeys(
        items: state.posts,
        promptTagSettings: promptTagSettings,
        outputFilter: outputFilter,
        detailForItem: _galleryNotifier.peekDetail,
      );
      final isAllSelected =
          selectablePostIds.isNotEmpty &&
          selectablePostIds.every(
            (id) => selectionState.selectedIds.contains(id),
          );
      final canDownloadSelected = state.posts.any(
        (post) =>
            selectionState.selectedIds.contains(post.stableKey) &&
            post.hasValidPreview,
      );

      return BulkActionBar(
        selectedCount: selectionState.selectedIds.length,
        isAllSelected: isAllSelected,
        onExit: () => _selectionNotifier.exit(),
        onSelectAll: () {
          if (isAllSelected) {
            _selectionNotifier.clearSelection();
          } else {
            _selectionNotifier.selectAll(selectablePostIds);
          }
        },
        actions: [
          BulkActionItem(
            icon: Icons.playlist_add,
            label: context.l10n.onlineGallery_addToQueue,
            onPressed: _actions.addSelectedToQueue,
            color: theme.colorScheme.primary,
          ),
          if (_canWriteFavorites(state))
            BulkActionItem(
              icon: Icons.favorite_border,
              label: context.l10n.onlineGallery_bulkFavorite,
              onPressed: _actions.favoriteSelected,
              color: theme.colorScheme.secondary,
            ),
          BulkActionItem(
            icon: Icons.download,
            label: context.l10n.onlineGallery_bulkDownload,
            onPressed: canDownloadSelected ? _actions.downloadSelected : null,
            color: theme.colorScheme.tertiary,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final sizeClass = WindowSizeClass.fromWidth(outerConstraints.maxWidth);
        final useMobileToolbar = sizeClass.isCompact;
        return Container(
          padding: useMobileToolbar
              ? const EdgeInsets.fromLTRB(8, 8, 8, 7)
              : const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (useMobileToolbar) {
                return _buildMobileToolbar(
                  theme,
                  state,
                  authState,
                  gelbooruAuthState,
                  availableWidth: constraints.maxWidth,
                );
              }

              // 第一行空间不足时整体横向滚动，避免通过移除图标或换行破坏
              // 全局控件的固定职责和可辨识性。
              final forceCompactForText =
                  MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final useScrollablePrimary = constraints.maxWidth < 1800;
              final compactPrimaryActions =
                  forceCompactForText || constraints.maxWidth < 1100;
              final compactRating = compactPrimaryActions;
              final compactModes = compactPrimaryActions;
              final collapseSecondaryControls = constraints.maxWidth < 1100;
              final showQueryFields =
                  state.viewMode == GalleryViewMode.search ||
                  state.viewMode == GalleryViewMode.favorites ||
                  (state.viewMode == GalleryViewMode.popular &&
                      state.popularSourceId == GallerySourceId.aiTag);
              final queryFieldWidth = switch (_activeSource(state)) {
                GallerySourceId.aiTag => 520.0,
                GallerySourceId.quickTagCloud => 420.0,
                _ => 280.0,
              };
              final revealSignature = Object.hash(
                _activeSource(state),
                state.viewMode,
                constraints.maxWidth.round(),
              ).toString();
              final secondaryControls = _buildSecondaryControls(theme, state);
              final leadingControls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSourceSelector(state),
                  const SizedBox(width: 8),
                  _buildModeSelector(theme, state, compact: compactModes),
                  const SizedBox(width: 8),
                  _buildRatingControl(theme, state, compact: compactRating),
                ],
              );
              final trailingControls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGalleryPolicyControls(
                    theme,
                    sourceId: state.activeSourceId,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  _buildPrimaryActions(
                    theme,
                    state,
                    authState,
                    gelbooruAuthState,
                    compact: compactPrimaryActions,
                  ),
                ],
              );
              return OnlineGallerySearchReveal(
                enabled: useScrollablePrimary && showQueryFields,
                signature: revealSignature,
                revealKey: _controller.primarySearchRevealKey,
                child: OnlineGalleryToolbar(
                  leading: leadingControls,
                  query: _buildSearchFields(theme, state),
                  trailing: trailingControls,
                  secondary: secondaryControls,
                  showQuery: showQueryFields,
                  scrollPrimary: useScrollablePrimary,
                  collapseSecondary: collapseSecondaryControls,
                  queryWidth: queryFieldWidth,
                  queryRevealKey: _controller.primarySearchRevealKey,
                  onShowSourceFilters: _showSourceFilters,
                  filterLabel: context.l10n.common_filter,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMobileToolbar(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
    GelbooruAuthState gelbooruAuthState, {
    required double availableWidth,
  }) {
    final compact = availableWidth < 350;
    final sourceWidth = compact ? 72.0 : 132.0;
    final modeWidth = compact ? 62.0 : 76.0;
    final filterWidth = compact ? 76.0 : 88.0;
    final activeSource = _activeSource(state);
    final sourceLabel = compact
        ? switch (activeSource) {
            GallerySourceId.danbooru => 'DB',
            GallerySourceId.safebooru => 'SB',
            GallerySourceId.gelbooru => 'GB',
            GallerySourceId.aiTag => 'AI',
            GallerySourceId.quickTagCloud => 'QT',
          }
        : null;

    return Column(
      key: const ValueKey('online-gallery-mobile-toolbar'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: const ValueKey('online-gallery-mobile-scope-row'),
          height: _galleryToolbarControlHeight(context),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              key: const ValueKey('online-gallery-mobile-primary-row'),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: const ValueKey('online-gallery-mobile-source'),
                  width: sourceWidth,
                  child: _buildSourceSelector(
                    state,
                    selectedLabel: sourceLabel,
                    maxLabelWidth: sourceWidth - 34,
                    expandLabel: true,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: modeWidth,
                  child: _buildMobileModeSelector(theme, state),
                ),
                const SizedBox(width: 6),
                _buildRatingControl(theme, state, compact: true),
                const SizedBox(width: 8),
                _buildUserButton(
                  theme,
                  state,
                  authState,
                  gelbooruAuthState,
                  compact: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          key: const ValueKey('online-gallery-mobile-query-row'),
          height: _gallerySearchFieldHeight(context),
          child: Row(
            key: const ValueKey('online-gallery-mobile-search-row'),
            children: [
              Expanded(
                key: const ValueKey('online-gallery-mobile-search'),
                child: _buildMobileSearchFields(theme, state),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: filterWidth,
                height: _gallerySearchFieldHeight(context),
                child: _buildMobileFilterButton(theme, state),
              ),
              const SizedBox(width: 4),
              _buildMobileMoreButton(theme, state),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileModeSelector(ThemeData theme, OnlineGalleryState state) {
    final supportsPopular = state.activeSourceId.capabilities.supportsRanking;
    final current = switch (state.viewMode) {
      GalleryViewMode.search => (
        Icons.search_rounded,
        context.l10n.onlineGallery_search,
      ),
      GalleryViewMode.popular => (
        Icons.local_fire_department_rounded,
        context.l10n.onlineGallery_popular,
      ),
      GalleryViewMode.favorites => (
        Icons.favorite_rounded,
        context.l10n.onlineGallery_favorites,
      ),
    };

    return PopupMenuButton<GalleryViewMode>(
      key: const ValueKey('online-gallery-mobile-mode-selector'),
      tooltip: current.$2,
      offset: Offset(0, _galleryToolbarControlHeight(context) + 4),
      onSelected: (mode) {
        _bindings.commands.saveScrollOffset();
        switch (mode) {
          case GalleryViewMode.search:
            _galleryNotifier.switchToSearch();
          case GalleryViewMode.popular:
            _galleryNotifier.switchToPopular();
          case GalleryViewMode.favorites:
            _galleryNotifier.switchToFavorites();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: GalleryViewMode.search,
          child: ListTile(
            leading: const Icon(Icons.search_rounded),
            title: Text(context.l10n.onlineGallery_search),
            trailing: state.viewMode == GalleryViewMode.search
                ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                : null,
          ),
        ),
        if (supportsPopular)
          PopupMenuItem(
            value: GalleryViewMode.popular,
            child: ListTile(
              leading: const Icon(Icons.local_fire_department_rounded),
              title: Text(context.l10n.onlineGallery_popular),
              trailing: state.viewMode == GalleryViewMode.popular
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
            ),
          ),
        PopupMenuItem(
          value: GalleryViewMode.favorites,
          child: ListTile(
            leading: const Icon(Icons.favorite_rounded),
            title: Text(context.l10n.onlineGallery_favorites),
            trailing: state.viewMode == GalleryViewMode.favorites
                ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                : null,
          ),
        ),
      ],
      child: Container(
        height: _galleryToolbarControlHeight(context),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              current.$1,
              size: 17,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                current.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSearchFields(ThemeData theme, OnlineGalleryState state) =>
      _search.buildMobile(theme);

  Widget _buildMobileFilterButton(ThemeData theme, OnlineGalleryState state) {
    final blacklistCount = ref.watch(
      onlineGalleryBlacklistNotifierProvider.select(
        (value) => value.tags.length,
      ),
    );
    final outputCount = ref.watch(
      onlineGalleryOutputFilterProvider.select((value) => value.tags.length),
    );
    final filterCount = blacklistCount + outputCount;
    final showLabel = MediaQuery.textScalerOf(context).scale(14) <= 20;
    return Semantics(
      button: true,
      label: filterCount > 0
          ? '${context.l10n.common_filter}: $filterCount'
          : context.l10n.common_filter,
      child: TextButton(
        key: const ValueKey('online-gallery-mobile-filter'),
        onPressed: _showCompactFilters,
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.58,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tune_rounded, size: 16),
            if (showLabel) ...[
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  context.l10n.common_filter,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
            ],
            if (showLabel && filterCount > 0) ...[
              const SizedBox(width: 3),
              Text(
                filterCount.toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMoreButton(ThemeData theme, OnlineGalleryState state) {
    final blacklistCount = ref.watch(
      onlineGalleryBlacklistNotifierProvider.select(
        (value) => value.tags.length,
      ),
    );
    final outputFilterCount = ref.watch(
      onlineGalleryOutputFilterProvider.select((value) => value.tags.length),
    );
    return PopupMenuButton<_MobileGalleryAction>(
      key: const ValueKey('online-gallery-mobile-more'),
      tooltip: context.l10n.nav_more,
      onSelected: (action) {
        switch (action) {
          case _MobileGalleryAction.blacklist:
            _sourceControls.showBlacklist();
          case _MobileGalleryAction.outputFilter:
            _sourceControls.showOutputFilter();
          case _MobileGalleryAction.random:
            _toggleRandomGallery(state);
          case _MobileGalleryAction.refresh:
            _refreshGallery(state);
          case _MobileGalleryAction.multiSelect:
            _selectionNotifier.enter();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const ValueKey('online-gallery-mobile-blacklist-action'),
          value: _MobileGalleryAction.blacklist,
          child: ListTile(
            leading: const Icon(Icons.block_rounded),
            title: Text(context.l10n.onlineGallery_blacklistTags),
            trailing: Text('$blacklistCount'),
          ),
        ),
        PopupMenuItem(
          key: const ValueKey('online-gallery-mobile-output-filter-action'),
          value: _MobileGalleryAction.outputFilter,
          child: ListTile(
            leading: const Icon(Icons.filter_alt_off_outlined),
            title: Text(context.l10n.onlineGallery_outputFilter),
            trailing: Text('$outputFilterCount'),
          ),
        ),
        if (state.supportsRandom)
          PopupMenuItem(
            value: _MobileGalleryAction.random,
            child: ListTile(
              leading: Icon(
                Icons.shuffle_rounded,
                color: state.randomEnabled ? theme.colorScheme.primary : null,
              ),
              title: Text(context.l10n.onlineGallery_random),
              trailing: state.randomEnabled
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
            ),
          ),
        PopupMenuItem(
          value: _MobileGalleryAction.refresh,
          child: ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: Text(
              state.randomEnabled
                  ? context.l10n.onlineGallery_randomRedraw
                  : context.l10n.onlineGallery_refresh,
            ),
          ),
        ),
        PopupMenuItem(
          value: _MobileGalleryAction.multiSelect,
          child: ListTile(
            leading: const Icon(Icons.checklist_rounded),
            title: Text(context.l10n.common_multiSelect),
          ),
        ),
      ],
      child: SizedBox(
        width: _gallerySearchFieldHeight(context),
        height: _gallerySearchFieldHeight(context),
        child: Icon(
          Icons.more_horiz_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildModeSelector(
    ThemeData theme,
    OnlineGalleryState state, {
    required bool compact,
  }) {
    final activeSourceId = state.activeSourceId;
    final supportsPopular = activeSourceId.capabilities.supportsRanking;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnlineGalleryModeButton(
            key: const ValueKey('online-gallery-mode-search'),
            icon: Icons.search,
            label: context.l10n.onlineGallery_search,
            isSelected: state.viewMode == GalleryViewMode.search,
            compact: compact,
            onTap: () {
              _bindings.commands.saveScrollOffset();
              _galleryNotifier.switchToSearch();
            },
            selectedBackgroundColor: const Color(0xFF2563EB),
            selectedForegroundColor: Colors.white,
            isFirst: true,
          ),
          OnlineGalleryModeButton(
            key: const ValueKey('online-gallery-mode-popular'),
            icon: Icons.local_fire_department,
            label: context.l10n.onlineGallery_popular,
            isSelected: state.viewMode == GalleryViewMode.popular,
            compact: compact,
            disabledHint: supportsPopular
                ? null
                : context.l10n.onlineGallery_sourceDoesNotSupportPopular,
            onTap: supportsPopular
                ? () {
                    _bindings.commands.saveScrollOffset();
                    _galleryNotifier.switchToPopular();
                  }
                : null,
            selectedBackgroundColor: const Color(0xFFC2410C),
            selectedForegroundColor: Colors.white,
          ),
          OnlineGalleryModeButton(
            key: const ValueKey('online-gallery-mode-favorites'),
            icon: Icons.favorite,
            label: context.l10n.onlineGallery_favorites,
            isSelected: state.viewMode == GalleryViewMode.favorites,
            compact: compact,
            onTap: () {
              _bindings.commands.saveScrollOffset();
              _galleryNotifier.switchToFavorites();
            },
            isLast: true,
            selectedBackgroundColor: const Color(0xFFBE185D),
            selectedForegroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  OnlineGalleryToolbarSearch get _search =>
      OnlineGalleryToolbarSearch(_bindings);

  Widget _buildSearchFields(ThemeData theme, OnlineGalleryState state) =>
      _search.buildDesktop(theme);

  void _toggleRandomGallery(OnlineGalleryState state) {
    if (!state.randomEnabled) _bindings.commands.saveScrollOffset();
    unawaited(_galleryNotifier.setRandomEnabled(!state.randomEnabled));
  }

  void _refreshGallery(OnlineGalleryState state) {
    final isPopular = state.viewMode == GalleryViewMode.popular;
    final activeSource = _activeSource(state);
    if (activeSource == GallerySourceId.quickTagCloud) {
      _galleryNotifier.clearDetailCache();
      ref.read(quickTagCloudGallerySourceAdapterProvider).invalidateCatalog();
      ref.invalidate(quickTagCloudCatalogProvider);
      final query = ref.read(quickTagCloudFilterProvider);
      if (query.codexId != 'all') {
        ref.invalidate(quickTagCloudCodexProvider(query.codexId));
      }
    }
    final query = switch (state.viewMode) {
      GalleryViewMode.search => _controller.searchController.text,
      GalleryViewMode.popular => _controller.popularSearchController.text,
      GalleryViewMode.favorites => _controller.favoriteSearchController.text,
    };
    final prompt = isPopular
        ? _controller.popularPromptSearchController.text
        : _controller.promptSearchController.text;
    unawaited(_galleryNotifier.refreshWithDraft(query: query, prompt: prompt));
    if (state.randomEnabled && _controller.scrollController.hasClients) {
      _controller.scrollController.jumpTo(0);
    }
  }

  Widget _buildPrimaryActions(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
    GelbooruAuthState gelbooruAuthState, {
    required bool compact,
  }) {
    final randomButton = Semantics(
      button: true,
      toggled: state.randomEnabled,
      label: context.l10n.onlineGallery_random,
      child: compact
          ? TextButton(
              key: const ValueKey('online-gallery-random-toggle'),
              onPressed: () => _toggleRandomGallery(state),
              style: TextButton.styleFrom(
                backgroundColor: state.randomEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                foregroundColor: state.randomEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                minimumSize: Size(0, _galleryToolbarControlHeight(context)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity:
                    context.interactionPolicy.prefersTouchPresentation
                    ? VisualDensity.standard
                    : VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(context.l10n.onlineGallery_random),
            )
          : TextButton.icon(
              key: const ValueKey('online-gallery-random-toggle'),
              onPressed: () => _toggleRandomGallery(state),
              icon: const Icon(Icons.shuffle, size: 17),
              label: Text(context.l10n.onlineGallery_random),
              style: TextButton.styleFrom(
                backgroundColor: state.randomEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                foregroundColor: state.randomEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                visualDensity:
                    context.interactionPolicy.prefersTouchPresentation
                    ? VisualDensity.standard
                    : VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
    );
    final refreshIcon = state.isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          )
        : const Icon(Icons.refresh, size: 18);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.supportsRandom) ...[randomButton, const SizedBox(width: 6)],
        if (compact)
          FilledButton.tonal(
            key: const ValueKey('online-gallery-refresh'),
            onPressed: () => _refreshGallery(state),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, _galleryToolbarControlHeight(context)),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: context.interactionPolicy.prefersTouchPresentation
                  ? VisualDensity.standard
                  : VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: state.isLoading
                ? refreshIcon
                : Text(
                    state.randomEnabled
                        ? context.l10n.onlineGallery_randomRedraw
                        : context.l10n.onlineGallery_refresh,
                  ),
          )
        else
          FilledButton.tonalIcon(
            key: const ValueKey('online-gallery-refresh'),
            onPressed: () => _refreshGallery(state),
            icon: refreshIcon,
            label: Text(
              state.randomEnabled
                  ? context.l10n.onlineGallery_randomRedraw
                  : context.l10n.onlineGallery_refresh,
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: context.interactionPolicy.prefersTouchPresentation
                  ? VisualDensity.standard
                  : VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        const SizedBox(width: 6),
        if (compact)
          TextButton(
            key: const ValueKey('online-gallery-multi-select'),
            onPressed: _selectionNotifier.enter,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              minimumSize: Size(0, _galleryToolbarControlHeight(context)),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: context.interactionPolicy.prefersTouchPresentation
                  ? VisualDensity.standard
                  : VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(context.l10n.common_multiSelect),
          )
        else
          TextButton.icon(
            key: const ValueKey('online-gallery-multi-select'),
            icon: const Icon(Icons.checklist, size: 18),
            label: Text(context.l10n.common_multiSelect),
            onPressed: _selectionNotifier.enter,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              visualDensity: context.interactionPolicy.prefersTouchPresentation
                  ? VisualDensity.standard
                  : VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        const SizedBox(width: 4),
        _buildUserButton(
          theme,
          state,
          authState,
          gelbooruAuthState,
          compact: compact,
        ),
      ],
    );
  }

  OnlineGalleryToolbarSourceControls get _sourceControls =>
      OnlineGalleryToolbarSourceControls(_bindings);

  Widget _buildSourceSelector(
    OnlineGalleryState state, {
    String? selectedLabel,
    double maxLabelWidth = 150,
    bool expandLabel = false,
  }) => _sourceControls.buildSourceSelector(
    selectedLabel: selectedLabel,
    maxLabelWidth: maxLabelWidth,
    expandLabel: expandLabel,
  );

  Widget _buildRatingControl(
    ThemeData theme,
    OnlineGalleryState state, {
    required bool compact,
  }) => _sourceControls.buildRatingControl(theme, compact: compact);

  Widget _buildGalleryPolicyControls(
    ThemeData theme, {
    required GallerySourceId sourceId,
    required bool compact,
  }) => _sourceControls.buildGalleryPolicyControls(
    theme,
    sourceId: sourceId,
    compact: compact,
  );

  Future<void> _showSourceFilters() => _sourceControls.showSourceFilters();

  Future<void> _showCompactFilters() => _sourceControls.showSourceFilters();

  Widget _buildSecondaryControls(ThemeData theme, OnlineGalleryState state) =>
      _sourceControls.buildSecondaryControls(theme);

  OnlineGalleryToolbarAuthControls get _authControls =>
      OnlineGalleryToolbarAuthControls(_bindings);

  Widget _buildUserButton(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
    GelbooruAuthState gelbooruAuthState, {
    required bool compact,
  }) => _authControls.buildUserButton(theme, compact: compact);

  GallerySourceId _activeSource(OnlineGalleryState state) =>
      _authControls.activeSource;

  bool _canWriteFavorites(OnlineGalleryState state) =>
      _authControls.canWriteFavorites;
}
