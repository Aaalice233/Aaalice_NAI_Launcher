import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/online_gallery/gallery_tag_query.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../../data/models/online_gallery/quick_tag_cloud_codex.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import '../../providers/online_gallery_prompt_tag_settings_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../services/gallery_prompt_projection_service.dart';
import '../../widgets/danbooru_post_card.dart';
import '../../widgets/gelbooru_credentials_dialog.dart';
import 'gallery_grid_item.dart';
import 'online_gallery_screen_commands.dart';
import 'online_gallery_grid.dart';
import 'online_gallery_screen_controller.dart';
import 'online_gallery_scroll_prefetch_coordinator.dart';
import 'online_gallery_utils.dart';

class OnlineGalleryContent extends ConsumerWidget {
  const OnlineGalleryContent({
    super.key,
    required this.state,
    required this.controller,
    required this.scrollCoordinator,
    required this.commands,
  });

  final OnlineGalleryState state;
  final OnlineGalleryScreenController controller;
  final OnlineGalleryScrollPrefetchCoordinator scrollCoordinator;
  final OnlineGalleryScreenCommands commands;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _OnlineGalleryContentPresenter(
      context: context,
      ref: ref,
      controller: controller,
      scrollCoordinator: scrollCoordinator,
      commands: commands,
    ).build(Theme.of(context), state);
  }
}

class _OnlineGalleryContentPresenter {
  const _OnlineGalleryContentPresenter({
    required this.context,
    required this.ref,
    required this.controller,
    required this.scrollCoordinator,
    required this.commands,
  });

  final BuildContext context;
  final WidgetRef ref;
  final OnlineGalleryScreenController controller;
  final OnlineGalleryScrollPrefetchCoordinator scrollCoordinator;
  final OnlineGalleryScreenCommands commands;

  OnlineGalleryScreenController get _controller => controller;
  OnlineGalleryScrollPrefetchCoordinator get _scrollCoordinator =>
      scrollCoordinator;
  OnlineGalleryScreenCommands get _commands => commands;
  OnlineGalleryNotifier get _galleryNotifier =>
      ref.read(onlineGalleryNotifierProvider.notifier);
  OnlineGallerySelectionNotifier get _selectionNotifier =>
      ref.read(onlineGallerySelectionNotifierProvider.notifier);

  GallerySourceId _activeSource(OnlineGalleryState state) =>
      switch (state.viewMode) {
        GalleryViewMode.search => state.sourceId,
        GalleryViewMode.popular => state.popularSourceId,
        GalleryViewMode.favorites => state.favoritesSourceId,
      };

  Future<void> _showGelbooruCredentialsDialog(BuildContext context) {
    return AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.gelbooru_configureTitle,
      initialChildSize: 0.86,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      sideSheetWidth: 480,
      builder: (_, scrollController) => GelbooruCredentialsDialog(
        embedded: true,
        scrollController: scrollController,
      ),
    );
  }

  Widget build(ThemeData theme, OnlineGalleryState state) {
    return _buildPageContent(theme, state);
  }

  Future<void> _refreshFromVisibleDraft(OnlineGalleryState state) {
    final query = switch (state.viewMode) {
      GalleryViewMode.search => _controller.searchController.text,
      GalleryViewMode.popular => _controller.popularSearchController.text,
      GalleryViewMode.favorites => _controller.favoriteSearchController.text,
    };
    final prompt = state.viewMode == GalleryViewMode.popular
        ? _controller.popularPromptSearchController.text
        : _controller.promptSearchController.text;
    return _galleryNotifier.refreshWithDraft(query: query, prompt: prompt);
  }

  /// 构建错误状态
  Widget _buildErrorState(ThemeData theme, OnlineGalleryState state) {
    final message = state.error ?? _localizedError(state.errorCode);
    final needsGelbooruCredentials =
        state.errorCode == OnlineGalleryErrorCode.gelbooruCredentialsRequired ||
        state.errorCode == OnlineGalleryErrorCode.gelbooruCredentialsInvalid;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            context.l10n.onlineGallery_loadFailed,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: needsGelbooruCredentials
                ? () => _showGelbooruCredentialsDialog(context)
                : () => _refreshFromVisibleDraft(state),
            icon: Icon(
              needsGelbooruCredentials ? Icons.key_outlined : Icons.refresh,
              size: 18,
            ),
            label: Text(
              needsGelbooruCredentials
                  ? context.l10n.onlineGallery_configureGelbooruApi
                  : context.l10n.common_retry,
            ),
          ),
        ],
      ),
    );
  }

  String _localizedError(OnlineGalleryErrorCode? errorCode) {
    switch (errorCode) {
      case OnlineGalleryErrorCode.tooManySearchTags:
        return context.l10n.onlineGallery_maxTagsExceeded(maxGallerySearchTags);
      case OnlineGalleryErrorCode.tagDetailsIncomplete:
        return context.l10n.onlineGallery_tagDetailsIncomplete;
      case OnlineGalleryErrorCode.unsupportedMetatag:
        return context.l10n.onlineGallery_unsupportedMetatag;
      case OnlineGalleryErrorCode.gelbooruCredentialsRequired:
        return context.l10n.onlineGallery_gelbooruCredentialsRequired;
      case OnlineGalleryErrorCode.gelbooruCredentialsInvalid:
        return context.l10n.onlineGallery_gelbooruCredentialsInvalid;
      case OnlineGalleryErrorCode.gelbooruRateLimited:
        return context.l10n.onlineGallery_gelbooruRateLimited;
      case OnlineGalleryErrorCode.gelbooruTimeout:
        return context.l10n.onlineGallery_gelbooruTimeout;
      case OnlineGalleryErrorCode.gelbooruServer:
        return context.l10n.onlineGallery_gelbooruServerError;
      case OnlineGalleryErrorCode.gelbooruNetwork:
        return context.l10n.onlineGallery_gelbooruNetworkError;
      case OnlineGalleryErrorCode.gelbooruMalformedResponse:
        return context.l10n.onlineGallery_gelbooruMalformedResponse;
      case OnlineGalleryErrorCode.credentialsRequired:
        return context.l10n.onlineGallery_pleaseLogin;
      case OnlineGalleryErrorCode.credentialsInvalid:
        return context.l10n.onlineGallery_pleaseLogin;
      case OnlineGalleryErrorCode.rateLimited:
        return context.l10n.onlineGallery_sourceRateLimited;
      case OnlineGalleryErrorCode.timeout:
        return context.l10n.onlineGallery_sourceTimeout;
      case OnlineGalleryErrorCode.server:
      case OnlineGalleryErrorCode.network:
        return context.l10n.onlineGallery_sourceNetworkError;
      case OnlineGalleryErrorCode.malformedResponse:
        return context.l10n.onlineGallery_sourceMalformedResponse;
      case OnlineGalleryErrorCode.detailNotFound:
        return context.l10n.onlineGallery_detailNotFound;
      case OnlineGalleryErrorCode.imageUnavailable:
        return context.l10n.onlineGallery_imageUnavailable;
      case OnlineGalleryErrorCode.rankingProcessing:
        return context.l10n.onlineGallery_aiTagRankingProcessing;
      case OnlineGalleryErrorCode.configurationUnavailable:
        return context.l10n.onlineGallery_sourceConfigUnavailable;
      case OnlineGalleryErrorCode.artistHuntDetailFailed:
        return context.l10n.onlineGallery_artistHuntDetailFailed;
      case OnlineGalleryErrorCode.gelbooruRequestFailed:
        return context.l10n.onlineGallery_gelbooruRequestFailed;
      case OnlineGalleryErrorCode.requestFailed:
      case null:
        return context.l10n.onlineGallery_sourceRequestFailed;
    }
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme, OnlineGalleryState state) {
    final isFavorites = state.viewMode == GalleryViewMode.favorites;
    final icon = isFavorites
        ? Icons.favorite_border
        : Icons.image_not_supported_outlined;
    final activeCache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    final artistHuntEmpty =
        state.isArtistHuntActive && activeCache.artistHuntCandidateCount > 0;
    final isQuickTagCloud =
        _activeSource(state) == GallerySourceId.quickTagCloud;
    final message = isFavorites
        ? context.l10n.onlineGallery_favoritesEmpty
        : artistHuntEmpty
        ? context.l10n.onlineGallery_artistHuntNoExactResults
        : isQuickTagCloud
        ? context.l10n.onlineGallery_codexNoData
        : context.l10n.onlineGallery_noResults;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(message, style: theme.textTheme.titleMedium),
          if (activeCache.queryScanPaused) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.onlineGallery_scanPaused,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _galleryNotifier.loadMore,
              icon: const Icon(Icons.manage_search, size: 18),
              label: Text(context.l10n.onlineGallery_continueScanning),
            ),
          ] else if (activeCache.queryDetailFailureCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.onlineGallery_tagDetailsIncomplete,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _refreshFromVisibleDraft(state),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.common_retry),
            ),
          ] else if (artistHuntEmpty &&
              activeCache.artistHuntFailureCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.onlineGallery_artistHuntPartialFailure(
                activeCache.artistHuntFailureCount,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _refreshFromVisibleDraft(state),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.common_retry),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建图片网格
  Widget _buildImageGrid(ThemeData theme, OnlineGalleryState state) {
    return OnlineGalleryGrid(
      state: state,
      controller: _controller,
      itemBuilder: (context, index, itemWidth, columnCount) =>
          _buildGridItem(theme, state, index, itemWidth, columnCount),
      footerBuilder: (context, itemWidth, columnCount) =>
          _buildLoadMoreIndicator(theme, state),
    );
  }

  /// 构建网格项
  Widget _buildGridItem(
    ThemeData theme,
    OnlineGalleryState state,
    int index,
    double itemWidth,
    int columnCount,
  ) {
    final post = state.posts[index];
    return GalleryGridItem(
      key: ValueKey('grid-item:${post.stableKey}'),
      post: post,
      index: index,
      itemWidth: itemWidth,
      columnCount: columnCount,
      scrolling: _controller.scrolling,
      initiallyLoadMedia: _controller.hasViewedItem(post.stableKey),
      anchorKey:
          (state.randomEnabled ? state.randomSession.cache : state.currentCache)
              .isPageBoundaryStart(index)
          ? _controller.pageAnchorKey(post.stableKey)
          : null,
      onVisibilityChanged: _scrollCoordinator.handleCardVisibility,
      onGeometryMeasured: _controller.recordGeometryRead,
      onTileBuild: _controller.recordTileBuild,
      onVisibilityTransition: _controller.recordVisibilityTransition,
      onVisibilityDrivenRebuild: _controller.recordVisibilityDrivenRebuild,
      scheduleReveal: _controller.scheduleCardReveal,
      viewportGeneration: _controller.viewportGeneration,
      detailRequestScope: (
        state.currentCacheKey,
        _galleryNotifier.detailRequestScopeRevision,
      ),
      loadDetail: (item, {required priority, forceRefresh = false}) =>
          _galleryNotifier.loadDetail(
            item,
            priority: priority,
            forceRefresh: forceRefresh,
          ),
      buildCard:
          (
            context,
            item,
            width, {
            required layoutAspectRatio,
            required loadMedia,
            required mediaRequestActive,
            detail,
          }) => _buildResolvedPostCard(
            state,
            item,
            width,
            layoutAspectRatio: layoutAspectRatio,
            loadMedia: loadMedia,
            mediaRequestActive: mediaRequestActive,
            detail: detail,
          ),
    );
  }

  Widget _buildResolvedPostCard(
    OnlineGalleryState state,
    GalleryItem post,
    double itemWidth, {
    required double layoutAspectRatio,
    required bool loadMedia,
    required bool mediaRequestActive,
    GalleryDetail? detail,
  }) {
    final capabilities = gallerySourceCapabilities[post.sourceId]!;
    final canWriteFavorite =
        capabilities.supportsWritableFavorites ||
        capabilities.supportsLocalFavorites;
    final targetMedia = post.focusedMediaId != null
        ? post.cover
        : detail != null && detail.media.isNotEmpty
        ? detail.media.first
        : null;
    final isQuickTagCloud = post.sourceId == GallerySourceId.quickTagCloud;
    return Consumer(
      builder: (context, cardRef, _) {
        final postKey = onlineGalleryPostKey(post);
        final favoriteState = cardRef.watch(
          onlineGalleryNotifierProvider.select(
            (value) => (
              value.localFavoritedPostKeys.contains(postKey),
              value.remoteFavoritedPostKeys.contains(postKey),
              value.favoriteLoadingPostKeys.contains(postKey),
            ),
          ),
        );
        final localFavorited = favoriteState.$1;
        final remoteFavorited = favoriteState.$2;
        final writesRemotely =
            post.sourceId == GallerySourceId.danbooru &&
            cardRef.watch(
              danbooruAuthProvider.select((value) => value.isLoggedIn),
            );
        final isFavorited = writesRemotely ? remoteFavorited : localFavorited;
        final hasSecondaryFavorite = writesRemotely
            ? localFavorited
            : remoteFavorited;
        final selectionState = cardRef.watch(
          onlineGallerySelectionNotifierProvider.select(
            (value) =>
                (value.isActive, value.selectedIds.contains(post.stableKey)),
          ),
        );
        final promptTagSettings = cardRef.watch(
          onlineGalleryPromptTagSettingsProvider,
        );
        final outputFilter = cardRef.watch(onlineGalleryOutputFilterProvider);
        const projectionService = GalleryPromptProjectionService();
        final projection = projectionService.project(
          item: post,
          detail: detail,
          currentMedia: targetMedia,
          promptTagSettings: promptTagSettings,
          outputFilter: outputFilter,
        );
        final copyText = post.artistChain == null
            ? projection.copyText
            : projectionService.projectPositivePrompt(
                post.artistChain!.formattedText,
                outputFilter: outputFilter,
              );
        final codexTitle = post.rawSourceMetadata['codexTitle']?.toString();
        final categoryLabel = quickTagCloudCategoryLabel(
          post.rawSourceMetadata['categoryPath'],
        );
        final badgeBase = categoryLabel ?? codexTitle;
        final quickTagCloudBadge =
            isQuickTagCloud &&
                badgeBase != null &&
                post.rawSourceMetadata['loadSource'] ==
                    QuickTagCloudCodexLoadSource.previousRelease.name
            ? '$badgeBase · ${context.l10n.onlineGallery_codexCachedBadge}'
            : badgeBase;
        return DanbooruPostCard(
          key: ValueKey(post.stableKey),
          post: post,
          itemWidth: itemWidth,
          layoutAspectRatio: layoutAspectRatio,
          loadMedia: loadMedia,
          mediaRequestActive: mediaRequestActive,
          isFavorited: isFavorited,
          isFavoriteLoading: favoriteState.$3,
          showFavoriteAction: canWriteFavorite,
          favoriteReadOnly: false,
          secondaryFavoriteIcon: hasSecondaryFavorite
              ? writesRemotely
                    ? Icons.download_done
                    : Icons.cloud_done
              : null,
          secondaryFavoriteTooltip: hasSecondaryFavorite
              ? writesRemotely
                    ? context.l10n.onlineGallery_savedLocally
                    : context.l10n.onlineGallery_savedInCloud
              : null,
          selectionMode: selectionState.$1,
          isSelected: selectionState.$2,
          canSelect: projection.hasUsableOutput,
          tagPrompt: projection.positivePrompt,
          promptOverride: projection.positivePrompt,
          negativePromptOverride: projection.negativePrompt.trim().isEmpty
              ? null
              : projection.negativePrompt,
          characterPrompts: projection.characterPrompts,
          copyTextOverride: copyText,
          copyTooltip: post.artistChain != null
              ? context.l10n.onlineGallery_copyArtistChain
              : null,
          badgeLabel: post.artistChain != null
              ? context.l10n.onlineGallery_artistCount(
                  post.artistChain!.artistCount,
                )
              : isQuickTagCloud
              ? quickTagCloudBadge
              : null,
          emptyTitle: isQuickTagCloud
              ? context.l10n.onlineGallery_codexUntitled
              : null,
          hoverController: _controller.hoverController,
          imageCoordinator: _controller.prefetchCoordinator,
          onHoverIntent: () {
            if (post.isVideo ||
                post.isAnimated ||
                !post.mediaCapability.isFlutterImage) {
              return;
            }
            final sampleUrl =
                post.sampleUrl ?? post.largeFileUrl ?? post.cover.displayUrl;
            if (sampleUrl.isEmpty) return;
            unawaited(
              _controller.prefetchCoordinator.submit(
                _imageRequest(
                  post,
                  sampleUrl,
                  GalleryImageTier.sample,
                  itemWidth,
                ),
                priority: GalleryImagePriority.hover,
              ),
            );
          },
          onHoverDismiss: () {
            if (post.isVideo ||
                post.isAnimated ||
                !post.mediaCapability.isFlutterImage) {
              return;
            }
            final sampleUrl =
                post.sampleUrl ?? post.largeFileUrl ?? post.cover.displayUrl;
            if (sampleUrl.isEmpty) return;
            _controller.prefetchCoordinator.cancel(
              _imageRequest(
                post,
                sampleUrl,
                GalleryImageTier.sample,
                itemWidth,
              ),
              priority: GalleryImagePriority.hover,
              reason: 'hover-dismissed',
            );
          },
          onTap: () => unawaited(_commands.showDetail(context, post)),
          onSelectionToggle: () => _selectionNotifier.toggle(post.stableKey),
          onLongPress: () {
            if (!selectionState.$1) {
              _selectionNotifier.enterAndSelect(post.stableKey);
            }
          },
          onTagTap: (tag) {
            _controller.searchController.text = tag;
            _galleryNotifier.search(tag);
          },
          onFavoriteToggle: canWriteFavorite
              ? () => _commands.toggleFavorite(context, post)
              : null,
        );
      },
    );
  }

  /// 构建加载更多指示器
  Widget _buildLoadMoreIndicator(ThemeData theme, OnlineGalleryState state) {
    final activeCache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    if (activeCache.appendErrorCode != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _galleryNotifier.retryAppend,
          icon: Icon(Icons.refresh, color: theme.colorScheme.error),
          label: Text(
            context.l10n.onlineGallery_retryAppend,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      );
    }
    if (activeCache.queryScanPaused) {
      return Center(
        child: TextButton.icon(
          onPressed: _galleryNotifier.loadMore,
          icon: const Icon(Icons.manage_search),
          label: Text(context.l10n.onlineGallery_continueScanning),
        ),
      );
    }
    if (activeCache.queryDetailFailureCount > 0) {
      return Center(
        child: TextButton.icon(
          onPressed: () => _refreshFromVisibleDraft(state),
          icon: Icon(Icons.refresh, color: theme.colorScheme.error),
          label: Text(
            context.l10n.onlineGallery_tagDetailsIncomplete,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      );
    }
    if (!state.hasMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.l10n.onlineGallery_loadedAll,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: state.isLoadingMore
            ? const CircularProgressIndicator()
            : const SizedBox(height: 24),
      ),
    );
  }

  /// 构建页面显示内容（加载中、错误、空状态、网格）
  Widget _buildPageContent(ThemeData theme, OnlineGalleryState state) {
    if (state.isLoading && state.posts.isEmpty) {
      final grid = _buildImageGrid(theme, state);
      final cache = state.currentCache;
      final tagCount = GalleryTagQueryParser.parse(
        state.viewMode == GalleryViewMode.popular
            ? state.popularQuery
            : state.searchQuery,
      ).ordinaryTagCount;
      if (tagCount <= 1 || cache.queryRequestCount <= 0) return grid;
      return Stack(
        children: [
          Positioned.fill(child: grid),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      context.l10n.onlineGallery_multiTagScanning(
                        cache.queryRequestCount,
                        cache.queryCandidateCount,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (state.hasError && state.posts.isEmpty) {
      return _buildErrorState(theme, state);
    }
    if (state.posts.isEmpty) {
      return _buildEmptyState(theme, state);
    }
    final activeCache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    if (state.isArtistHuntActive && activeCache.artistHuntFailureCount > 0) {
      return Column(
        children: [
          Material(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.onlineGallery_artistHuntPartialFailure(
                        activeCache.artistHuntFailureCount,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => _refreshFromVisibleDraft(state),
                    child: Text(context.l10n.common_retry),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildImageGrid(theme, state)),
        ],
      );
    }
    return _buildImageGrid(theme, state);
  }

  GalleryImageRequest _imageRequest(
    GalleryItem item,
    String url,
    GalleryImageTier tier,
    double logicalWidth,
  ) => createGalleryImageRequest(
    context: context,
    item: item,
    url: url,
    tier: tier,
    logicalWidth: logicalWidth,
  );
}
