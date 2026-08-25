import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/cache/online_gallery_detail_coordinator.dart';
import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../../core/cache/online_gallery_preload_policy.dart';
import '../../../core/services/date_formatting_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/file_picker_utils.dart';
import '../../../data/datasources/remote/danbooru_api_service.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../../data/models/online_gallery/gallery_prompt_projection.dart';
import '../../../data/models/online_gallery/quick_tag_cloud_codex.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../../data/services/gelbooru_auth_service.dart';
import '../../../data/services/online_gallery/artist_chain_parser.dart';
import '../../../data/services/online_gallery/quick_tag_cloud_access.dart';

import '../../providers/character_prompt_provider.dart';
import '../../providers/online_gallery_blacklist_provider.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import '../../providers/online_gallery_prompt_tag_settings_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/pending_prompt_provider.dart';
import '../../providers/quick_tag_cloud_gallery_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../services/gallery_prompt_projection_service.dart';
import '../../widgets/app_branch_visibility.dart';
import '../../widgets/danbooru_login_dialog.dart';
import '../../widgets/danbooru_post_card.dart';
import '../../widgets/gelbooru_credentials_dialog.dart';
import '../../widgets/online_gallery/gallery_detail_dialog.dart';
import '../../widgets/online_gallery/blacklist_settings_panel.dart';
import '../../widgets/online_gallery/online_gallery_hover_controller.dart';
import '../../widgets/online_gallery/output_filter_settings_panel.dart';
import '../../widgets/online_gallery/quick_tag_cloud_toolbar.dart';

import '../../widgets/common/app_toast.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/common/themed_input.dart';
import '../../widgets/autocomplete/autocomplete_config.dart';
import '../../widgets/autocomplete/autocomplete_wrapper.dart';

/// 在线画廊页面
class OnlineGalleryScreen extends ConsumerStatefulWidget {
  const OnlineGalleryScreen({super.key});

  @override
  ConsumerState<OnlineGalleryScreen> createState() =>
      _OnlineGalleryScreenState();
}

class _OnlineGalleryScreenState extends ConsumerState<OnlineGalleryScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _promptSearchController = TextEditingController();
  final TextEditingController _popularSearchController =
      TextEditingController();
  final TextEditingController _popularPromptSearchController =
      TextEditingController();
  final TextEditingController _favoriteSearchController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _promptSearchFocusNode = FocusNode();
  final FocusNode _popularSearchFocusNode = FocusNode();
  final FocusNode _popularPromptSearchFocusNode = FocusNode();
  final FocusNode _favoriteSearchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final OnlineGalleryHoverController _hoverController =
      OnlineGalleryHoverController();
  late final OnlineGalleryPrefetchCoordinator _prefetchCoordinator;
  final TextEditingController _pageController = TextEditingController();
  final FocusNode _pageFocusNode = FocusNode();
  final _dateFormattingService = DateFormattingService();
  final LayerLink _dateRangeLayerLink = LayerLink();

  Timer? _searchDebounceTimer;
  Timer? _scrollStopTimer;
  Timer? _idlePrefetchTimer;
  OverlayEntry? _dateRangeOverlayEntry;
  final Map<int, ({GalleryItem item, double itemWidth, double visibleTop})>
  _visibleItems = {};
  final GlobalKey _anchorRestoreKey = GlobalKey();
  String? _pendingAnchorStableKey;
  double _pendingAnchorLocalOffset = 0;
  double _lastScrollOffset = 0;
  int _scrollDirection = 1;
  int _lookaheadItemCount = 12;
  bool _isScrolling = false;
  bool _isEditingPage = false;
  GalleryViewMode? _lastViewMode;
  GallerySourceId? _lastFavoritesSource;
  String? _lastCacheKey;
  bool? _lastRandomEnabled;
  int? _lastRandomDrawRevision;
  String? _scheduledAutoLoadCacheKey;
  bool _restoreInitialPositionPending = false;
  bool _branchVisible = true;
  final Set<String> _pendingGalleryDetails = <String>{};

  @override
  bool get wantKeepAlive => true;

  /// 获取 Gallery Notifier（简化重复代码）
  OnlineGalleryNotifier get _galleryNotifier =>
      ref.read(onlineGalleryNotifierProvider.notifier);

  /// 获取 Selection Notifier（简化重复代码）
  OnlineGallerySelectionNotifier get _selectionNotifier =>
      ref.read(onlineGallerySelectionNotifierProvider.notifier);

  @override
  void initState() {
    super.initState();
    _prefetchCoordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (request) => precacheImage(
        request.createImageProvider(OnlineGalleryImageCacheManager.instance),
        context,
      ),
    );
    // 添加滚动监听 - 无限滚动
    _scrollController.addListener(_onScroll);
    // 添加页码焦点监听
    _pageFocusNode.addListener(_onPageFocusChange);

    // 只在首次进入（无数据）时加载，切换Tab回来时不再重新加载
    // 用户需要刷新时可点击刷新按钮
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(onlineGalleryNotifierProvider);
      // 同步搜索框文本
      if (_searchController.text != state.searchQuery) {
        _searchController.text = state.searchQuery;
      }
      if (_promptSearchController.text != state.promptQuery) {
        _promptSearchController.text = state.promptQuery;
      }
      if (_popularSearchController.text != state.popularQuery) {
        _popularSearchController.text = state.popularQuery;
      }
      if (_popularPromptSearchController.text != state.popularPromptQuery) {
        _popularPromptSearchController.text = state.popularPromptQuery;
      }
      if (_favoriteSearchController.text != state.favoriteSearchQuery) {
        _favoriteSearchController.text = state.favoriteSearchQuery;
      }
      final initialCache = state.randomEnabled
          ? state.randomSession.cache
          : state.currentCache;
      _restoreInitialPositionPending =
          initialCache.scrollOffset > 0 || initialCache.anchorStableKey != null;
      // 首次加载
      if (state.posts.isEmpty && !state.isLoading) {
        _galleryNotifier.loadPosts();
      }
      // 记录当前查询，用于切换来源或筛选后恢复独立滚动位置。
      _lastViewMode = state.viewMode;
      _lastFavoritesSource = state.favoritesSourceId;
      _lastCacheKey = state.currentCacheKey;
      _lastRandomEnabled = state.randomEnabled;
      _lastRandomDrawRevision = state.randomSession.drawRevision;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = AppBranchVisibility.of(context);
    if (_branchVisible == visible) return;
    _branchVisible = visible;
    if (!visible) {
      _hoverController.dismiss();
      _scheduledAutoLoadCacheKey = null;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleAutoLoadIfUnderfilled(ref.read(onlineGalleryNotifierProvider));
      });
    }
  }

  /// 滚动监听 - 无限滚动加载更多
  void _onScroll() {
    _hoverController.dismiss();
    if (!_branchVisible) return;
    final offset = _scrollController.offset;
    if (offset != _lastScrollOffset) {
      _scrollDirection = offset >= _lastScrollOffset ? 1 : -1;
      _lastScrollOffset = offset;
      if (!_isScrolling) setState(() => _isScrolling = true);
      _prefetchCoordinator.setScrolling(true);
      _scrollStopTimer?.cancel();
      _scrollStopTimer = Timer(const Duration(milliseconds: 150), () {
        if (!mounted || !_branchVisible) return;
        setState(() => _isScrolling = false);
        _prefetchCoordinator.setScrolling(false);
        _saveScrollOffset();
        _scheduleVisiblePrefetch();
      });
    }
    if (_isWithinLoadAhead(_scrollController.position)) {
      _galleryNotifier.loadMore();
    }
  }

  bool _isWithinLoadAhead(ScrollMetrics metrics) =>
      metrics.extentAfter <=
      OnlineGalleryPreloadPolicy.loadAheadDistance(metrics.viewportDimension);

  void _scheduleAutoLoadIfUnderfilled(OnlineGalleryState state) {
    final activeCache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    if (!_branchVisible ||
        state.isLoading ||
        state.isLoadingMore ||
        state.hasError ||
        !state.hasMore ||
        activeCache.appendErrorCode != null ||
        _scheduledAutoLoadCacheKey == state.currentCacheKey) {
      return;
    }

    final cacheKey = state.currentCacheKey;
    _scheduledAutoLoadCacheKey = cacheKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_branchVisible) return;
      if (_scheduledAutoLoadCacheKey == cacheKey) {
        _scheduledAutoLoadCacheKey = null;
      }

      final latest = ref.read(onlineGalleryNotifierProvider);
      final latestCache = latest.randomEnabled
          ? latest.randomSession.cache
          : latest.currentCache;
      if (latest.currentCacheKey != cacheKey ||
          latest.isLoading ||
          latest.isLoadingMore ||
          latest.hasError ||
          !latest.hasMore ||
          latestCache.appendErrorCode != null) {
        return;
      }

      final needsMore =
          latest.posts.isEmpty ||
          (_scrollController.hasClients &&
              _isWithinLoadAhead(_scrollController.position));
      if (needsMore) {
        unawaited(_galleryNotifier.loadMore());
      }
    });
  }

  /// 保存当前滚动位置
  void _saveScrollOffset() {
    if (!_scrollController.hasClients) return;
    final visible = _visibleItems.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final anchor = visible.isEmpty ? null : visible.first.value;
    _galleryNotifier.saveScrollOffset(
      _scrollController.offset,
      anchorStableKey: anchor?.item.stableKey,
      anchorLocalOffset: anchor?.visibleTop ?? 0,
    );
  }

  /// 优先按帖子锚点恢复；卡片尚未构建时退回像素位置。
  void _restoreScrollOffset(ModeCache cache) {
    _pendingAnchorStableKey = cache.anchorStableKey;
    _pendingAnchorLocalOffset = cache.anchorLocalOffset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      _scrollController.jumpTo(
        cache.scrollOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final anchorContext = _anchorRestoreKey.currentContext;
        if (!mounted || anchorContext == null) return;
        await Scrollable.ensureVisible(anchorContext, duration: Duration.zero);
        if (!mounted || !_scrollController.hasClients) return;
        final current = _scrollController.offset;
        final anchorOffset = (current + _pendingAnchorLocalOffset).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(anchorOffset);
      });
    });
  }

  @override
  void dispose() {
    _saveScrollOffset();
    _searchDebounceTimer?.cancel();
    _scrollStopTimer?.cancel();
    _idlePrefetchTimer?.cancel();
    _hideDateRangePopup();
    _scrollController.removeListener(_onScroll);
    _hoverController.dispose();
    _prefetchCoordinator.dispose();
    _pageFocusNode.removeListener(_onPageFocusChange);
    _searchController.dispose();
    _promptSearchController.dispose();
    _popularSearchController.dispose();
    _popularPromptSearchController.dispose();
    _favoriteSearchController.dispose();
    _searchFocusNode.dispose();
    _promptSearchFocusNode.dispose();
    _popularSearchFocusNode.dispose();
    _popularPromptSearchFocusNode.dispose();
    _favoriteSearchFocusNode.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  /// 页码焦点变化处理
  void _onPageFocusChange() {
    if (!_pageFocusNode.hasFocus && _isEditingPage) {
      setState(() {
        _isEditingPage = false;
      });
    }
  }

  /// 开始编辑页码
  void _startEditingPage(int currentPage) {
    setState(() {
      _isEditingPage = true;
      _pageController.text = currentPage.toString();
      _pageController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _pageController.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageFocusNode.requestFocus();
    });
  }

  /// 提交页码跳转
  void _submitPage() {
    final input = _pageController.text.trim();
    final parsed = int.tryParse(input);

    setState(() => _isEditingPage = false);

    if (parsed == null || parsed < 1) return;

    final state = ref.read(onlineGalleryNotifierProvider);
    if (parsed != state.page) {
      _galleryNotifier.goToPage(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    ref.watch(
      onlineGalleryNotifierProvider.select(
        (value) => (
          loading: (value.isLoading, value.isLoadingMore),
          error: (value.error, value.errorCode, value.notice),
          queries: (
            value.searchQuery,
            value.promptQuery,
            value.popularQuery,
            value.popularPromptQuery,
            value.fuzzySearchEnabled,
          ),
          sources: (
            value.sourceId,
            value.popularSourceId,
            value.favoritesSourceId,
            value.viewMode,
          ),
          filters: (
            value.selectedRatings,
            value.popularScale,
            value.popularDate,
            value.aiTagTimeRange,
            value.aiTagPopularPeriod,
            value.dateRangeStart,
            value.dateRangeEnd,
          ),
          cache: value.currentCache,
          aiTagConfig: value.aiTagConfig,
          random: (value.randomEnabled, value.randomSession),
          artistHunt: value.artistHuntEnabled,
        ),
      ),
    );
    final state = ref.read(onlineGalleryNotifierProvider);
    final authState = ref.watch(danbooruAuthProvider);
    final gelbooruAuthState = ref.watch(gelbooruAuthProvider);

    ref.listen<OnlineGalleryNotice?>(
      onlineGalleryNotifierProvider.select((value) => value.notice),
      (previous, next) {
        if (next == null || next == previous) return;
        if (next == OnlineGalleryNotice.gelbooruCredentialsInvalid) {
          AppToast.warning(
            context,
            context.l10n.onlineGallery_gelbooruCredentialsInvalid,
          );
        }
        _galleryNotifier.clearNotice();
      },
    );

    final browsingContextChanged =
        (_lastViewMode != null && _lastViewMode != state.viewMode) ||
        (_lastCacheKey != null && _lastCacheKey != state.currentCacheKey) ||
        (state.viewMode == GalleryViewMode.favorites &&
            _lastFavoritesSource != null &&
            _lastFavoritesSource != state.favoritesSourceId) ||
        (_lastRandomEnabled != null &&
            _lastRandomEnabled != state.randomEnabled);
    final randomDrawChanged =
        state.randomEnabled &&
        _lastRandomDrawRevision != null &&
        _lastRandomDrawRevision != state.randomSession.drawRevision;
    final initialPositionReady =
        _restoreInitialPositionPending &&
        state.posts.isNotEmpty &&
        !state.isLoading;
    if (browsingContextChanged || randomDrawChanged || initialPositionReady) {
      _hoverController.dismiss();
      _visibleItems.clear();
      _prefetchCoordinator.rotateGeneration();
      if (browsingContextChanged || initialPositionReady) {
        _restoreScrollOffset(
          state.randomEnabled ? state.randomSession.cache : state.currentCache,
        );
        _restoreInitialPositionPending = false;
      }
    }
    _lastViewMode = state.viewMode;
    _lastFavoritesSource = state.favoritesSourceId;
    _lastCacheKey = state.currentCacheKey;
    _lastRandomEnabled = state.randomEnabled;
    _lastRandomDrawRevision = state.randomSession.drawRevision;
    _scheduleAutoLoadIfUnderfilled(state);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 顶部工具栏
          Consumer(
            builder: (context, toolbarRef, _) {
              final selectionState = toolbarRef.watch(
                onlineGallerySelectionNotifierProvider,
              );
              return _buildToolbar(
                theme,
                state,
                authState,
                gelbooruAuthState,
                selectionState,
              );
            },
          ),
          // 图片网格
          Expanded(child: _buildContent(theme, state)),
          // 底部分页条
          _buildPaginationBar(theme, state),
        ],
      ),
    );
  }

  /// 构建底部分页条
  Widget _buildPaginationBar(ThemeData theme, OnlineGalleryState state) {
    if (state.randomEnabled) {
      return Container(
        key: const ValueKey('online-gallery-random-status-bar'),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.isLoading || state.isLoadingMore) ...[
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(context.l10n.onlineGallery_randomDrawing),
            ] else if (state.randomSession.exhausted) ...[
              Text(context.l10n.onlineGallery_randomExhausted),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _galleryNotifier.restartRandom,
                icon: const Icon(Icons.replay, size: 18),
                label: Text(context.l10n.onlineGallery_randomRestart),
              ),
            ] else
              Text(context.l10n.onlineGallery_imageCount(state.posts.length)),
          ],
        ),
      );
    }
    if (state.posts.isEmpty && !state.isLoading && !state.hasMore) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const ValueKey('online-gallery-pagination-bar'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一页
          IconButton(
            onPressed: state.page > 1 && !state.isLoading
                ? () => _galleryNotifier.goToPage(state.page - 1)
                : null,
            icon: const Icon(Icons.chevron_left, size: 24),
            tooltip: context.l10n.onlineGallery_previousPage,
          ),
          const SizedBox(width: 8),
          // 页码显示/输入
          _isEditingPage
              ? _buildPageInput(theme, state)
              : _buildPageDisplay(theme, state),
          const SizedBox(width: 8),
          // 下一页
          IconButton(
            onPressed: state.hasMore && !state.isLoading
                ? () => _galleryNotifier.goToPage(state.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right, size: 24),
            tooltip: context.l10n.onlineGallery_nextPage,
          ),
          const SizedBox(width: 24),
          // 图片计数
          Text(
            context.l10n.onlineGallery_imageCount(
              state.posts.length.toString(),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 可点击的页码显示
  Widget _buildPageDisplay(ThemeData theme, OnlineGalleryState state) {
    return InkWell(
      onTap: !state.isLoading ? () => _startEditingPage(state.page) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: state.isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.onlineGallery_pageN(state.page.toString()),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit,
                    size: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
      ),
    );
  }

  /// 页码输入框
  Widget _buildPageInput(ThemeData theme, OnlineGalleryState state) {
    return SizedBox(
      width: 80,
      child: ThemedInput(
        controller: _pageController,
        focusNode: _pageFocusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        onSubmitted: (_) => _submitPage(),
      ),
    );
  }

  Widget _buildToolbar(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
    GelbooruAuthState gelbooruAuthState,
    SelectionModeState selectionState,
  ) {
    if (selectionState.isActive) {
      final allPostIds = state.posts.map((p) => p.stableKey).toList();
      final isAllSelected =
          allPostIds.isNotEmpty &&
          allPostIds.every((id) => selectionState.selectedIds.contains(id));
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
            _selectionNotifier.selectAll(allPostIds);
          }
        },
        actions: [
          BulkActionItem(
            icon: Icons.playlist_add,
            label: context.l10n.onlineGallery_addToQueue,
            onPressed: _addSelectedToQueue,
            color: theme.colorScheme.primary,
          ),
          if (_canWriteFavorites(state))
            BulkActionItem(
              icon: Icons.favorite_border,
              label: context.l10n.onlineGallery_bulkFavorite,
              onPressed: _favoriteSelected,
              color: theme.colorScheme.secondary,
            ),
          BulkActionItem(
            icon: Icons.download,
            label: context.l10n.onlineGallery_bulkDownload,
            onPressed: canDownloadSelected ? _downloadSelected : null,
            color: theme.colorScheme.tertiary,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final forceCompactForText =
              MediaQuery.textScalerOf(context).scale(1) > 1.2;
          // 桌面宽度足够时优先保留文字。过早退化成一排纯图标会让工具栏
          // 看似简洁，却迫使用户逐个悬停才能知道操作含义。
          final useScrollablePrimary = constraints.maxWidth < 1400;
          final keepsDetailedLabels =
              Localizations.localeOf(context).languageCode == 'zh';
          final compactPrimaryActions =
              forceCompactForText ||
              useScrollablePrimary ||
              !keepsDetailedLabels;
          final compactRating = compactPrimaryActions;
          final compactModes = compactPrimaryActions;
          final collapseSecondaryControls = constraints.maxWidth < 1100;
          final showQueryFields =
              state.viewMode == GalleryViewMode.search ||
              state.viewMode == GalleryViewMode.favorites ||
              (state.viewMode == GalleryViewMode.popular &&
                  state.popularSourceId == GallerySourceId.aiTag);
          final queryFieldWidth = _activeSource(state) == GallerySourceId.aiTag
              ? 520.0
              : 280.0;
          final secondaryControls = _buildSecondaryControls(theme, state);
          final leadingControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSourceSelector(state),
              const SizedBox(width: 8),
              _buildModeSelector(
                theme,
                state,
                authState,
                gelbooruAuthState,
                compact: compactModes,
              ),
              const SizedBox(width: 8),
              _buildRatingControl(theme, state, compact: compactRating),
            ],
          );
          final trailingControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGalleryPolicyControls(theme, compact: true),
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
          final primaryControls = useScrollablePrimary
              ? SingleChildScrollView(
                  key: const ValueKey('online-gallery-primary-controls-scroll'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      leadingControls,
                      if (showQueryFields) ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          key: const ValueKey('online-gallery-primary-search'),
                          width: queryFieldWidth,
                          child: _buildSearchFields(theme, state),
                        ),
                      ],
                      const SizedBox(width: 8),
                      trailingControls,
                    ],
                  ),
                )
              : Row(
                  children: [
                    leadingControls,
                    if (showQueryFields) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          key: const ValueKey('online-gallery-primary-search'),
                          child: _buildSearchFields(theme, state),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    const SizedBox(width: 8),
                    trailingControls,
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const ValueKey('online-gallery-toolbar-primary-row'),
                height: 40,
                child: primaryControls,
              ),
              const SizedBox(height: 8),
              SizedBox(
                key: const ValueKey('online-gallery-toolbar-secondary-row'),
                height: 40,
                child: Row(
                  children: [
                    if (collapseSecondaryControls) ...[
                      const Spacer(),
                      FilledButton.tonalIcon(
                        key: const ValueKey('online-gallery-source-filters'),
                        onPressed: _showSourceFilters,
                        icon: const Icon(Icons.tune_rounded, size: 17),
                        label: Text(context.l10n.common_filter),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ] else ...[
                      Flexible(
                        flex: 6,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: secondaryControls,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeSelector(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
    GelbooruAuthState gelbooruAuthState, {
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
          _ModeButton(
            key: const ValueKey('online-gallery-mode-search'),
            icon: Icons.search,
            label: context.l10n.onlineGallery_search,
            isSelected: state.viewMode == GalleryViewMode.search,
            compact: compact,
            onTap: () {
              _saveScrollOffset();
              _galleryNotifier.switchToSearch();
            },
            selectedBackgroundColor: const Color(0xFF2563EB),
            selectedForegroundColor: Colors.white,
            isFirst: true,
          ),
          _ModeButton(
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
                    _saveScrollOffset();
                    _galleryNotifier.switchToPopular();
                  }
                : null,
            selectedBackgroundColor: const Color(0xFFC2410C),
            selectedForegroundColor: Colors.white,
          ),
          _ModeButton(
            key: const ValueKey('online-gallery-mode-favorites'),
            icon: Icons.favorite,
            label: context.l10n.onlineGallery_favorites,
            isSelected: state.viewMode == GalleryViewMode.favorites,
            compact: compact,
            onTap: () {
              _saveScrollOffset();
              _galleryNotifier.switchToFavorites();
            },
            isLast: true,
            showBadge:
                state.favoritesScope == GalleryFavoritesScope.remote &&
                switch (state.favoritesSourceId) {
                  GallerySourceId.gelbooru =>
                    !gelbooruAuthState.isAuthenticated,
                  GallerySourceId.danbooru => !authState.isLoggedIn,
                  _ => false,
                },
            badgeHint: context.l10n.onlineGallery_loginForCloudFavorites,
            selectedBackgroundColor: const Color(0xFFBE185D),
            selectedForegroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFields(ThemeData theme, OnlineGalleryState state) {
    final isPopular = state.viewMode == GalleryViewMode.popular;
    final isFavorites = state.viewMode == GalleryViewMode.favorites;
    final activeSource = switch (state.viewMode) {
      GalleryViewMode.search => state.sourceId,
      GalleryViewMode.popular => state.popularSourceId,
      GalleryViewMode.favorites => state.favoritesSourceId,
    };
    if (isFavorites) {
      return _buildPlainSearchField(
        theme,
        controller: _favoriteSearchController,
        focusNode: _favoriteSearchFocusNode,
        hintText: context.l10n.onlineGallery_searchFavorites,
        icon: Icons.search_rounded,
        treatSpacesAsSeparators: true,
        onSubmitted: () =>
            _galleryNotifier.searchFavorites(_favoriteSearchController.text),
      );
    }
    if (activeSource == GallerySourceId.quickTagCloud) {
      return _buildCodexSearchField(theme);
    }
    if (activeSource != GallerySourceId.aiTag) return _buildSearchField(theme);
    final queryController = isPopular
        ? _popularSearchController
        : _searchController;
    final promptController = isPopular
        ? _popularPromptSearchController
        : _promptSearchController;
    final queryFocus = isPopular ? _popularSearchFocusNode : _searchFocusNode;
    final promptFocus = isPopular
        ? _popularPromptSearchFocusNode
        : _promptSearchFocusNode;
    void submit() {
      if (isPopular) {
        _galleryNotifier.searchPopular(
          query: queryController.text,
          prompt: promptController.text,
        );
      } else {
        _galleryNotifier.searchWithPrompt(
          queryController.text,
          prompt: promptController.text,
        );
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Row(
        children: [
          Expanded(
            child: _buildPlainSearchField(
              theme,
              controller: queryController,
              focusNode: queryFocus,
              hintText: context.l10n.onlineGallery_aiTagQuery,
              icon: Icons.manage_search,
              treatSpacesAsSeparators: true,
              onSubmitted: submit,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPlainSearchField(
              theme,
              controller: promptController,
              focusNode: promptFocus,
              hintText: context.l10n.onlineGallery_aiTagPromptQuery,
              icon: Icons.auto_awesome,
              onSubmitted: submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainSearchField(
    ThemeData theme, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required VoidCallback onSubmitted,
    bool treatSpacesAsSeparators = false,
  }) {
    return AutocompleteWrapper(
      controller: controller,
      focusNode: focusNode,
      config: AutocompleteConfig(
        autoInsertComma: false,
        treatSpacesAsSeparators: treatSpacesAsSeparators,
      ),
      onSuggestionSelected: (_) => onSubmitted(),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            focusNode: focusNode,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                fontSize: 13,
              ),
              prefixIcon: Icon(icon, size: 18),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.common_clear,
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                      onPressed: () {
                        controller.clear();
                        focusNode.requestFocus();
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
      ),
    );
  }

  Widget _buildCodexSearchField(ThemeData theme) {
    return Container(
      height: 36,
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, _) => TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: theme.textTheme.bodyMedium,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.l10n.onlineGallery_codexSearchHint,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: context.l10n.common_clear,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      _galleryNotifier.search('');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onSubmitted: _galleryNotifier.search,
        ),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return AutocompleteWrapper(
      controller: _searchController,
      focusNode: _searchFocusNode,
      config: const AutocompleteConfig(
        autoInsertComma: false,
        treatSpacesAsSeparators: true,
      ),
      onSuggestionSelected: (value) {
        // 选择补全建议后立即触发搜索
        _searchDebounceTimer?.cancel();
        _galleryNotifier.search(value);
      },
      child: Container(
        height: 36,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: context.l10n.onlineGallery_searchTags,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    tooltip: context.l10n.common_clear,
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _galleryNotifier.search('');
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onChanged: (value) {
            setState(() {}); // 仅更新清除按钮可见性，不触发搜索
          },
          onSubmitted: _galleryNotifier.search,
        ),
      ),
    );
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
          ? OutlinedButton(
              key: const ValueKey('online-gallery-random-toggle'),
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (!state.randomEnabled) _saveScrollOffset();
                      unawaited(
                        _galleryNotifier.setRandomEnabled(!state.randomEnabled),
                      );
                    },
              style: OutlinedButton.styleFrom(
                backgroundColor: state.randomEnabled
                    ? theme.colorScheme.primaryContainer
                    : null,
                foregroundColor: state.randomEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(context.l10n.onlineGallery_random),
            )
          : OutlinedButton.icon(
              key: const ValueKey('online-gallery-random-toggle'),
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (!state.randomEnabled) _saveScrollOffset();
                      unawaited(
                        _galleryNotifier.setRandomEnabled(!state.randomEnabled),
                      );
                    },
              icon: const Icon(Icons.shuffle, size: 17),
              label: Text(context.l10n.onlineGallery_random),
              style: OutlinedButton.styleFrom(
                backgroundColor: state.randomEnabled
                    ? theme.colorScheme.primaryContainer
                    : null,
                foregroundColor: state.randomEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
    );
    void refreshAction() {
      final isPopular = state.viewMode == GalleryViewMode.popular;
      final activeSource = switch (state.viewMode) {
        GalleryViewMode.search => state.sourceId,
        GalleryViewMode.popular => state.popularSourceId,
        GalleryViewMode.favorites => state.favoritesSourceId,
      };
      if (activeSource == GallerySourceId.quickTagCloud) {
        _galleryNotifier.clearDetailCache();
        ref.read(quickTagCloudGallerySourceAdapterProvider).invalidateCatalog();
        ref.invalidate(quickTagCloudCatalogProvider);
        final query = ref.read(quickTagCloudFilterProvider);
        if (query.codexId != 'all') {
          ref.invalidate(quickTagCloudCodexProvider(query.codexId));
        }
      }
      if (activeSource == GallerySourceId.aiTag &&
          state.viewMode == GalleryViewMode.search) {
        unawaited(
          _galleryNotifier.searchWithPrompt(
            _searchController.text,
            prompt: _promptSearchController.text,
          ),
        );
      } else if (activeSource == GallerySourceId.aiTag && isPopular) {
        unawaited(
          _galleryNotifier.searchPopular(
            query: _popularSearchController.text,
            prompt: _popularPromptSearchController.text,
          ),
        );
      } else {
        unawaited(_galleryNotifier.refresh());
      }
      if (state.randomEnabled && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

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
            onPressed: state.isLoading ? null : refreshAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
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
            onPressed: state.isLoading ? null : refreshAction,
            icon: refreshIcon,
            label: Text(
              state.randomEnabled
                  ? context.l10n.onlineGallery_randomRedraw
                  : context.l10n.onlineGallery_refresh,
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
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
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
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
              visualDensity: VisualDensity.compact,
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

  Widget _buildArtistHuntButton(ThemeData theme, OnlineGalleryState state) {
    return Tooltip(
      message: context.l10n.onlineGallery_artistHuntTooltip,
      child: Semantics(
        button: true,
        toggled: state.artistHuntEnabled,
        label: context.l10n.onlineGallery_artistHunt,
        child: OutlinedButton.icon(
          key: const ValueKey('online-gallery-artist-hunt-toggle'),
          onPressed: state.isLoading
              ? null
              : () {
                  _saveScrollOffset();
                  unawaited(
                    _galleryNotifier.setArtistHuntEnabled(
                      !state.artistHuntEnabled,
                    ),
                  );
                },
          icon: const Icon(Icons.brush_outlined, size: 17),
          label: Text(context.l10n.onlineGallery_artistHunt),
          style: OutlinedButton.styleFrom(
            backgroundColor: state.artistHuntEnabled
                ? theme.colorScheme.primaryContainer
                : null,
            foregroundColor: state.artistHuntEnabled
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            visualDensity: VisualDensity.compact,
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

  Widget _buildSourceSelector(OnlineGalleryState state) {
    return switch (state.viewMode) {
      GalleryViewMode.search => _SourceDropdown(
        selected: state.sourceId,
        sources: {
          GallerySourceId.danbooru: 'Danbooru',
          GallerySourceId.safebooru: 'Safebooru',
          GallerySourceId.gelbooru: 'Gelbooru',
          GallerySourceId.aiTag: 'AI TAG',
          GallerySourceId.quickTagCloud:
              context.l10n.onlineGallery_sourceQuickTagCloud,
        },
        onChanged: (source) {
          _saveScrollOffset();
          _galleryNotifier.setSource(source);
        },
      ),
      GalleryViewMode.popular => _SourceDropdown(
        selected: state.popularSourceId,
        sources: const {
          GallerySourceId.danbooru: 'Danbooru',
          GallerySourceId.safebooru: 'Safebooru',
          GallerySourceId.aiTag: 'AI TAG',
        },
        onChanged: (source) {
          _saveScrollOffset();
          _galleryNotifier.setPopularSource(source);
        },
      ),
      GalleryViewMode.favorites => _SourceDropdown(
        selected: state.favoritesSourceId,
        sources: {
          GallerySourceId.danbooru: 'Danbooru',
          GallerySourceId.safebooru: 'Safebooru',
          GallerySourceId.gelbooru: 'Gelbooru',
          GallerySourceId.aiTag: 'AI TAG',
          GallerySourceId.quickTagCloud:
              context.l10n.onlineGallery_sourceQuickTagCloud,
        },
        onChanged: (source) {
          _saveScrollOffset();
          _galleryNotifier.setFavoritesSource(source);
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
            visualDensity: VisualDensity.compact,
          ),
        );
      }
      return Tooltip(
        message: '$label · $tooltip',
        child: Semantics(
          label: '$label. $tooltip',
          child: Container(
            width: 40,
            height: 40,
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
      return _RatingDropdown(
        selectedRatings: _quickTagCloudDisplayRatings(state.selectedRatings),
        availableRatings: QuickTagCloudAccess.galleryRatings,
        compact: compact,
        onToggle: (rating) => unawaited(
          _toggleQuickTagCloudRating(state.selectedRatings, rating),
        ),
      );
    }
    return _RatingDropdown(
      selectedRatings: state.selectedRatings,
      compact: compact,
      onToggle: _galleryNotifier.toggleRating,
    );
  }

  Widget _buildGalleryPolicyControls(ThemeData theme, {required bool compact}) {
    final blacklist = ref.watch(onlineGalleryBlacklistNotifierProvider);
    final outputFilterCount = ref.watch(
      onlineGalleryOutputFilterProvider.select((value) => value.tags.length),
    );
    final blacklistLabel =
        blacklist.effectiveSource == OnlineGalleryBlacklistSource.cloud
        ? context.l10n.onlineGallery_blacklistSourceCloud
        : context.l10n.onlineGallery_blacklistSourceLocal;

    Widget policyButton({
      required Key key,
      required IconData icon,
      required String label,
      required String tooltip,
      required VoidCallback onPressed,
    }) {
      final style = OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      );
      if (compact) {
        return OutlinedButton(
          key: key,
          onPressed: onPressed,
          style: style,
          child: Text(label),
        );
      }
      return OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: style,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        policyButton(
          key: const ValueKey('online-gallery-blacklist'),
          icon: Icons.block,
          label:
              '${context.l10n.onlineGallery_blacklistShort} · ${blacklist.effectiveTags.length}',
          tooltip:
              '${context.l10n.onlineGallery_blacklistTags} · $blacklistLabel',
          onPressed: () => showOnlineGalleryBlacklistDialog(context, ref),
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

  Future<void> _showSourceFilters() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 20),
            const SizedBox(width: 8),
            Text(context.l10n.common_filter),
          ],
        ),
        content: SizedBox(
          width: min(720, MediaQuery.sizeOf(dialogContext).width - 80),
          child: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(onlineGalleryNotifierProvider);
                return _buildSecondaryControls(
                  Theme.of(context),
                  state,
                  wrapControls: true,
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.common_close),
          ),
        ],
      ),
    );
  }

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

    if (state.viewMode == GalleryViewMode.favorites) {
      controls.add(_buildFavoritesScopeControl(theme, state));
    }
    if (activeSourceId == GallerySourceId.quickTagCloud) {
      controls.add(
        QuickTagCloudToolbar(
          favoritesMode: state.viewMode == GalleryViewMode.favorites,
          selectedRatings: state.selectedRatings,
          wrapControls: wrapControls,
          onFiltersChanged: () async {
            _saveScrollOffset();
            _galleryNotifier.syncQuickTagCloudFilterKey();
            await _galleryNotifier.refresh();
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          },
        ),
      );
    } else {
      if (state.viewMode == GalleryViewMode.search &&
          capabilities.supportsFuzzySearch) {
        controls.add(
          _FuzzySearchToggle(
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
        controls.add(_buildPopularOptions(theme, state));
      }
      if (state.viewMode == GalleryViewMode.favorites &&
          state.favoritesSourceId == GallerySourceId.gelbooru &&
          state.favoritesScope == GalleryFavoritesScope.remote) {
        controls
          ..add(_buildGelbooruFavoritesNotice(theme))
          ..add(
            OutlinedButton.icon(
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

  Widget _buildFavoritesScopeControl(
    ThemeData theme,
    OnlineGalleryState state,
  ) {
    final capabilities = state.favoritesSourceId.capabilities;
    if (capabilities.remoteFavorites == GalleryRemoteFavoritesCapability.none) {
      return Tooltip(
        message: context.l10n.onlineGallery_localFavoritesDescription,
        child: Chip(
          avatar: const Icon(Icons.devices_rounded, size: 16),
          label: Text(context.l10n.onlineGallery_localFavorites),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    final remoteAuthenticated = switch (state.favoritesSourceId) {
      GallerySourceId.danbooru => ref.watch(danbooruAuthProvider).isLoggedIn,
      GallerySourceId.gelbooru =>
        ref.watch(gelbooruAuthProvider).isAuthenticated,
      _ => false,
    };
    return SegmentedButton<GalleryFavoritesScope>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: GalleryFavoritesScope.local,
          icon: const Icon(Icons.devices_rounded, size: 16),
          label: Text(context.l10n.onlineGallery_localFavorites),
        ),
        ButtonSegment(
          value: GalleryFavoritesScope.remote,
          enabled: remoteAuthenticated,
          icon: Icon(
            capabilities.remoteFavorites ==
                    GalleryRemoteFavoritesCapability.readOnly
                ? Icons.cloud_download_outlined
                : Icons.cloud_outlined,
            size: 16,
          ),
          label: Text(context.l10n.onlineGallery_cloudFavorites),
          tooltip: remoteAuthenticated
              ? null
              : context.l10n.onlineGallery_loginForCloudFavorites,
        ),
      ],
      selected: {state.favoritesScope},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          _galleryNotifier.setFavoritesScope(selection.first);
        }
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _saveVisibleFavoritesLocally() async {
    try {
      final count = await _galleryNotifier.saveVisiblePostsToLocalFavorites();
      if (!mounted) return;
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
      if (!mounted) return;
      AppToast.error(
        context,
        context.l10n.onlineGallery_saveFavoritesFailed(error.toString()),
      );
    }
  }

  Widget _buildPromptTagCategorySelector(ThemeData theme) {
    final settings = ref.watch(onlineGalleryPromptTagSettingsProvider);
    final selectedCount = settings.categories.length;

    String labelFor(OnlineGalleryPromptTagCategory category) {
      return switch (category) {
        OnlineGalleryPromptTagCategory.general =>
          context.l10n.tagCategory_general,
        OnlineGalleryPromptTagCategory.character =>
          context.l10n.tagCategory_character,
        OnlineGalleryPromptTagCategory.copyright =>
          context.l10n.tagCategory_copyright,
        OnlineGalleryPromptTagCategory.artist =>
          context.l10n.tagCategory_artist,
        OnlineGalleryPromptTagCategory.meta => context.l10n.tagCategory_meta,
      };
    }

    return MenuAnchor(
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
            value: settings.categories.contains(category),
            closeOnActivate: false,
            onChanged: (selected) async {
              if (selected == null) return;
              final changed = await ref
                  .read(onlineGalleryPromptTagSettingsProvider.notifier)
                  .setCategory(category, selected);
              if (!changed && mounted) {
                AppToast.info(
                  context,
                  context.l10n.onlineGallery_keepOnePromptTagCategory,
                );
              }
            },
            child: Text(labelFor(category)),
          ),
      ],
      builder: (context, controller, child) {
        return Tooltip(
          message: context.l10n.onlineGallery_promptTagCategoriesTooltip,
          child: OutlinedButton.icon(
            onPressed: () {
              controller.isOpen ? controller.close() : controller.open();
            },
            icon: const Icon(Icons.sell_outlined, size: 17),
            label: Text(
              '${context.l10n.onlineGallery_promptTagCategories} · $selectedCount',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }

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
      link: _dateRangeLayerLink,
      child: OutlinedButton.icon(
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
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          visualDensity: VisualDensity.compact,
          side: hasDateRange
              ? BorderSide(color: theme.colorScheme.primary)
              : null,
        ),
      ),
    );
  }

  void _toggleDateRangePopup(OnlineGalleryState state) {
    if (_dateRangeOverlayEntry != null) {
      _hideDateRangePopup();
      return;
    }
    _showDateRangePopup(state);
  }

  void _showDateRangePopup(OnlineGalleryState state) {
    final overlay = Overlay.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();

    _dateRangeOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideDateRangePopup,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _dateRangeLayerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                color: theme.colorScheme.surface,
                child: _DateRangePopup(
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
          ],
        );
      },
    );

    overlay.insert(_dateRangeOverlayEntry!);
  }

  void _hideDateRangePopup() {
    _dateRangeOverlayEntry?.remove();
    _dateRangeOverlayEntry = null;
  }

  Widget _buildUserButton(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
    GelbooruAuthState gelbooruAuthState, {
    required bool compact,
  }) {
    Widget accountControl({
      required String label,
      required IconData icon,
      required Color backgroundColor,
      required Color foregroundColor,
      required Color borderColor,
      IconData? statusIcon,
      Color? statusColor,
      VoidCallback? onTap,
      bool enabled = true,
    }) {
      final content = SizedBox(
        key: const ValueKey('online-gallery-account-avatar'),
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, size: 18, color: foregroundColor)),
                if (statusIcon != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: statusColor ?? foregroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        statusIcon,
                        size: 9,
                        color: theme.colorScheme.surface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (onTap == null) {
        return Opacity(opacity: enabled ? 1 : 0.55, child: content);
      }
      return Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: content,
        ),
      );
    }

    final sourceId = _activeSource(state);
    if (sourceId == GallerySourceId.safebooru ||
        sourceId == GallerySourceId.aiTag ||
        sourceId == GallerySourceId.quickTagCloud) {
      final label = sourceId == GallerySourceId.quickTagCloud
          ? context.l10n.onlineGallery_sourceQuickTagCloud
          : sourceId.label;
      return Tooltip(
        message: label,
        child: Semantics(
          enabled: false,
          child: accountControl(
            label: label,
            icon: Icons.person_off_outlined,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            borderColor: theme.colorScheme.outlineVariant,
            enabled: false,
          ),
        ),
      );
    }
    if (sourceId == GallerySourceId.gelbooru) {
      final invalid = gelbooruAuthState.status == GelbooruAuthStatus.invalid;
      final ready = gelbooruAuthState.isAuthenticated;
      final message = invalid
          ? context.l10n.onlineGallery_gelbooruApiInvalid
          : ready
          ? context.l10n.onlineGallery_gelbooruApiReady
          : context.l10n.onlineGallery_configureGelbooruApi;
      return Tooltip(
        message: message,
        child: Semantics(
          button: true,
          label: message,
          child: accountControl(
            label: compact ? 'API' : message,
            icon: invalid
                ? Icons.person_off_outlined
                : ready
                ? Icons.person
                : Icons.person_outline,
            backgroundColor: invalid
                ? theme.colorScheme.errorContainer
                : ready
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            foregroundColor: invalid
                ? theme.colorScheme.onErrorContainer
                : ready
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            borderColor: invalid
                ? theme.colorScheme.error
                : ready
                ? theme.colorScheme.primary.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant,
            statusIcon: invalid
                ? Icons.priority_high
                : ready
                ? Icons.check
                : Icons.key,
            statusColor: invalid
                ? theme.colorScheme.error
                : ready
                ? Colors.green.shade600
                : theme.colorScheme.tertiary,
            onTap: () => _showGelbooruCredentialsDialog(context),
          ),
        ),
      );
    }

    if (authState.isLoggedIn) {
      final username = authState.credentials?.username ?? 'Danbooru';
      return PopupMenuButton<String>(
        tooltip: username,
        onSelected: (value) {
          if (value == 'logout') {
            ref.read(danbooruAuthProvider.notifier).logout();
          }
        },
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username, style: theme.textTheme.titleSmall),
                if (authState.user != null)
                  Text(
                    authState.user!.levelName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                const Icon(Icons.logout, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.onlineGallery_logout),
              ],
            ),
          ),
        ],
        child: accountControl(
          label: username,
          icon: Icons.person,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          borderColor: theme.colorScheme.primary.withValues(alpha: 0.45),
          statusIcon: Icons.check,
          statusColor: Colors.green.shade600,
        ),
      );
    }

    return Tooltip(
      message: context.l10n.onlineGallery_login,
      child: Semantics(
        button: true,
        label: context.l10n.onlineGallery_login,
        child: accountControl(
          label: context.l10n.onlineGallery_login,
          icon: Icons.person_outline,
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          borderColor: theme.colorScheme.outlineVariant,
          statusIcon: Icons.login,
          statusColor: theme.colorScheme.primary,
          onTap: () => _showLoginDialog(context),
        ),
      ),
    );
  }

  Widget _buildPopularOptions(ThemeData theme, OnlineGalleryState state) {
    if (state.popularSourceId == GallerySourceId.aiTag) {
      final months = state.aiTagConfig?.rankMonths ?? const <String>[];
      final values = ['current', ...months, 'older'];
      final selected = values.contains(state.aiTagPopularPeriod)
          ? state.aiTagPopularPeriod
          : 'current';
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              items: values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        value == 'current'
                            ? context.l10n.onlineGallery_aiTagCurrentMonthly
                            : value == 'older'
                            ? context.l10n.onlineGallery_aiTagOlderMonthly
                            : value,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  _galleryNotifier.setAiTagPopularPeriod(value);
                }
              },
            ),
          ),
          Text(
            context.l10n.onlineGallery_imageCount(
              state.posts.length.toString(),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<PopularScale>(
          segments: [
            ButtonSegment(
              value: PopularScale.day,
              label: Text(context.l10n.onlineGallery_dayRank),
            ),
            ButtonSegment(
              value: PopularScale.week,
              label: Text(context.l10n.onlineGallery_weekRank),
            ),
            ButtonSegment(
              value: PopularScale.month,
              label: Text(context.l10n.onlineGallery_monthRank),
            ),
          ],
          selected: {state.popularScale},
          onSelectionChanged: (selected) {
            _galleryNotifier.setPopularScale(selected.first);
          },
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _selectDate(context, state),
          icon: const Icon(Icons.calendar_today, size: 14),
          label: Text(
            state.popularDate != null
                ? _dateFormattingService.formatWithPattern(
                    state.popularDate!,
                    'yyyy-MM-dd',
                  )
                : context.l10n.onlineGallery_today,
            style: const TextStyle(fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (state.popularDate != null)
          IconButton(
            onPressed: () => _galleryNotifier.setPopularDate(null),
            icon: const Icon(Icons.close, size: 16),
            tooltip: context.l10n.onlineGallery_clear,
          ),
        Text(
          context.l10n.onlineGallery_imageCount(state.posts.length.toString()),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    OnlineGalleryState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.popularDate ?? now,
      firstDate: DateTime(2005),
      lastDate: now,
    );
    if (picked != null) {
      _galleryNotifier.setPopularDate(picked);
    }
  }

  Future<void> _showLoginDialog(BuildContext context) async {
    final loggedIn = await showDialog<bool>(
      context: context,
      builder: (context) => const DanbooruLoginDialog(),
    );
    if (loggedIn != true || !mounted) return;

    final state = ref.read(onlineGalleryNotifierProvider);
    if (state.viewMode == GalleryViewMode.favorites &&
        state.favoritesSourceId == GallerySourceId.danbooru) {
      await _galleryNotifier.refresh();
    }
  }

  void _showGelbooruCredentialsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const GelbooruCredentialsDialog(),
    );
  }

  GallerySourceId _activeSource(OnlineGalleryState state) {
    return switch (state.viewMode) {
      GalleryViewMode.search => state.sourceId,
      GalleryViewMode.favorites => state.favoritesSourceId,
      GalleryViewMode.popular => state.popularSourceId,
    };
  }

  bool _canWriteFavorites(OnlineGalleryState state) {
    final sourceId = _activeSource(state);
    if (sourceId == GallerySourceId.gelbooru &&
        state.viewMode == GalleryViewMode.favorites &&
        state.favoritesScope == GalleryFavoritesScope.remote) {
      return false;
    }
    final capabilities = gallerySourceCapabilities[sourceId]!;
    return capabilities.supportsWritableFavorites ||
        capabilities.supportsLocalFavorites;
  }

  Widget _buildGelbooruFavoritesNotice(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 15,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.onlineGallery_gelbooruReadOnly,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.l10n.onlineGallery_gelbooruFavoritesSortHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, OnlineGalleryState state) {
    return _buildPageContent(theme, state);
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
                : _galleryNotifier.refresh,
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
          if (artistHuntEmpty && activeCache.artistHuntFailureCount > 0) ...[
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
              onPressed: _galleryNotifier.refresh,
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
    final screenWidth = MediaQuery.of(context).size.width - 60;
    final columnCount = (screenWidth / 200).floor().clamp(2, 8);
    final itemWidth = (screenWidth - 24 - (columnCount - 1) * 6) / columnCount;
    final viewportHeight = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : MediaQuery.sizeOf(context).height;
    _lookaheadItemCount = OnlineGalleryPreloadPolicy.lookaheadItemCount(
      viewportHeight: viewportHeight,
      itemWidth: itemWidth,
      columnCount: columnCount,
    );

    final storageScope = state.randomEnabled
        ? 'random:${state.randomSession.scopeKey}'
        : 'normal';
    return MasonryGridView.count(
      key: PageStorageKey<String>(
        'online_gallery_$storageScope:${state.currentCacheKey}',
      ),
      controller: _scrollController,
      cacheExtent: OnlineGalleryPreloadPolicy.cacheExtent(viewportHeight),
      padding: const EdgeInsets.all(12),
      crossAxisCount: columnCount,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      itemCount: state.posts.length + 1,
      itemBuilder: (context, index) =>
          _buildGridItem(theme, state, index, itemWidth),
    );
  }

  /// 构建网格项
  Widget _buildGridItem(
    ThemeData theme,
    OnlineGalleryState state,
    int index,
    double itemWidth,
  ) {
    // 加载更多指示器/错误重试
    if (index >= state.posts.length) {
      return _buildLoadMoreIndicator(theme, state);
    }

    final post = state.posts[index];
    final layoutAspectRatio = post.width > 0 && post.height > 0
        ? post.width / post.height
        : 1.0;
    return KeyedSubtree(
      key: post.stableKey == _pendingAnchorStableKey ? _anchorRestoreKey : null,
      child: _VisibilityDrivenGalleryItem(
        key: ValueKey('visible:${post.stableKey}'),
        visibilityKey: post.stableKey,
        onVisibilityChanged: (visible, visibleTop) =>
            _handleCardVisibility(index, post, itemWidth, visible, visibleTop),
        builder: (context, hasBeenVisible) {
          if (!hasBeenVisible &&
              _isScrolling &&
              !(post.sourceId == GallerySourceId.aiTag &&
                  !post.hasValidPreview)) {
            final aspectRatio = post.width > 0 && post.height > 0
                ? post.width / post.height
                : 1.0;
            return SizedBox(
              height: (itemWidth / aspectRatio).clamp(80.0, itemWidth * 2.5),
              child: const Card(child: SizedBox.shrink()),
            );
          }
          if (post.sourceId == GallerySourceId.aiTag && !post.hasValidPreview) {
            if (!hasBeenVisible) {
              return const AspectRatio(
                aspectRatio: 1,
                child: Card(child: SizedBox.shrink()),
              );
            }
            return AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: FutureBuilder<GalleryDetail>(
                key: ValueKey('detail:${post.stableKey}'),
                future: _galleryNotifier.loadDetail(
                  post,
                  priority: GalleryDetailPriority.visible,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return AspectRatio(
                      aspectRatio: 1,
                      child: Card(
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              _galleryNotifier.loadDetail(
                                post,
                                forceRefresh: true,
                              );
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(context.l10n.common_retry),
                          ),
                        ),
                      ),
                    );
                  }
                  final resolved = snapshot.data?.item;
                  if (resolved == null) {
                    return const AspectRatio(
                      aspectRatio: 1,
                      child: Card(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  return _buildResolvedPostCard(
                    state,
                    resolved,
                    itemWidth,
                    layoutAspectRatio: layoutAspectRatio,
                    detail: snapshot.data,
                  );
                },
              ),
            );
          }
          return _buildResolvedPostCard(
            state,
            post,
            itemWidth,
            layoutAspectRatio: layoutAspectRatio,
          );
        },
      ),
    );
  }

  Widget _buildResolvedPostCard(
    OnlineGalleryState state,
    GalleryItem post,
    double itemWidth, {
    required double layoutAspectRatio,
    GalleryDetail? detail,
  }) {
    final favoriteReadOnly =
        post.sourceId == GallerySourceId.gelbooru &&
        state.viewMode == GalleryViewMode.favorites &&
        state.favoritesScope == GalleryFavoritesScope.remote;
    final capabilities = gallerySourceCapabilities[post.sourceId]!;
    final canWriteFavorite =
        !favoriteReadOnly &&
        (capabilities.supportsWritableFavorites ||
            capabilities.supportsLocalFavorites);
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
              value.favoritedPostKeys,
              value.favoriteLoadingPostKeys.contains(postKey),
              value.favoritesScope,
              value.viewMode,
            ),
          ),
        );
        final isFavorited = cardRef
            .read(onlineGalleryNotifierProvider.notifier)
            .isFavorited(post);
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
        final categoryLabel = _quickTagCloudCategoryLabel(
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
          isFavorited: isFavorited,
          isFavoriteLoading: favoriteState.$2,
          showFavoriteAction: canWriteFavorite || favoriteReadOnly,
          favoriteReadOnly: favoriteReadOnly,
          selectionMode: selectionState.$1,
          isSelected: selectionState.$2,
          canSelect:
              projection.positivePrompt.trim().isNotEmpty ||
              projection.negativePrompt.trim().isNotEmpty ||
              projection.characterPrompts.any(
                (character) =>
                    character.prompt.trim().isNotEmpty ||
                    character.negativePrompt.trim().isNotEmpty,
              ),
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
          hoverController: _hoverController,
          imageCoordinator: _prefetchCoordinator,
          onHoverIntent: () {
            if (post.isVideo || post.isAnimated) return;
            final sampleUrl =
                post.sampleUrl ?? post.largeFileUrl ?? post.cover.displayUrl;
            if (sampleUrl.isEmpty) return;
            unawaited(
              _prefetchCoordinator.submit(
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
          onTap: () => _showPostDetail(context, post),
          onSelectionToggle: () => _selectionNotifier.toggle(post.stableKey),
          onLongPress: () {
            if (!selectionState.$1) {
              _selectionNotifier.enterAndSelect(post.stableKey);
            }
          },
          onTagTap: (tag) {
            _searchController.text = tag;
            _galleryNotifier.search(tag);
          },
          onFavoriteToggle: canWriteFavorite
              ? () => _handleFavoriteToggle(context, post)
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
      return const Center(child: CircularProgressIndicator());
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
                        : _galleryNotifier.refresh,
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
  ) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = switch (tier) {
      GalleryImageTier.thumbnail => GalleryImageSizing.gridTargetWidth(
        layoutWidth: logicalWidth,
        devicePixelRatio: dpr,
        naturalWidth: item.width,
        naturalHeight: item.height,
      ),
      GalleryImageTier.sample => GalleryImageSizing.hoverTargetWidth(
        dpr,
        naturalWidth: item.width,
        naturalHeight: item.height,
      ),
      GalleryImageTier.original => GalleryImageSizing.originalTargetWidth(
        dpr,
        logicalWidth,
        naturalWidth: item.width,
        naturalHeight: item.height,
      ),
    };
    return GalleryImageRequest.forUrl(
      sourceId: item.sourceId,
      url: url,
      tier: tier,
      targetDecodeWidth: decodeWidth,
    );
  }

  void _handleCardVisibility(
    int index,
    GalleryItem item,
    double itemWidth,
    bool visible,
    double visibleTop,
  ) {
    if (!mounted || !_branchVisible) return;
    if (!visible) {
      final current = _visibleItems[index];
      if (current?.item.stableKey == item.stableKey) {
        _visibleItems.remove(index);
      }
      return;
    }
    _visibleItems[index] = (
      item: item,
      itemWidth: itemWidth,
      visibleTop: visibleTop,
    );
    if (item.previewUrl.isNotEmpty) {
      unawaited(
        _prefetchCoordinator.submit(
          _imageRequest(
            item,
            item.previewUrl,
            GalleryImageTier.thumbnail,
            itemWidth,
          ),
          priority: GalleryImagePriority.visible,
        ),
      );
    }
    if (!_isScrolling) {
      _idlePrefetchTimer?.cancel();
      _idlePrefetchTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted && _branchVisible && !_isScrolling) {
          _scheduleVisiblePrefetch();
        }
      });
    }
  }

  void _scheduleVisiblePrefetch() {
    if (_visibleItems.isEmpty || !_branchVisible) return;
    final state = ref.read(onlineGalleryNotifierProvider);
    final visible = _visibleItems.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final itemWidth = visible.first.value.itemWidth;
    final edge = _scrollDirection >= 0 ? visible.last.key : visible.first.key;
    var aiDetailsQueued = 0;

    // 先把下一段网格缩略图放入队列，避免悬浮大图占满并发槽后，
    // 用户滚到下一屏时仍要等待缩略图下载和解码。
    for (var step = 1; step <= _lookaheadItemCount; step++) {
      final index = edge + step * _scrollDirection;
      if (index < 0 || index >= state.posts.length) continue;
      final item = state.posts[index];
      if (item.previewUrl.isNotEmpty) {
        unawaited(
          _prefetchCoordinator.submit(
            _imageRequest(
              item,
              item.previewUrl,
              GalleryImageTier.thumbnail,
              itemWidth,
            ),
            priority: GalleryImagePriority.lookahead,
          ),
        );
      } else if (item.sourceId == GallerySourceId.aiTag &&
          aiDetailsQueued < 4) {
        aiDetailsQueued++;
        unawaited(
          _galleryNotifier
              .loadDetail(item, priority: GalleryDetailPriority.visible)
              .then<void>((_) {})
              .catchError((_) {}),
        );
      }
    }

    // 与 ComfyUI 画廊一致，只预取真正独立的 Sample。AI TAG 的预览通常
    // 就是原图；重复以更大尺寸解码只会挤占滚动所需的 IO 和解码时间。
    for (final entry in visible.take(12)) {
      final item = entry.value.item;
      if (item.isVideo ||
          item.isAnimated ||
          item.sourceId == GallerySourceId.aiTag) {
        continue;
      }
      final sampleUrl = item.sampleUrl ?? item.largeFileUrl;
      if (sampleUrl == null ||
          sampleUrl.isEmpty ||
          sampleUrl == item.previewUrl) {
        continue;
      }
      unawaited(
        _prefetchCoordinator.submit(
          _imageRequest(
            item,
            sampleUrl,
            GalleryImageTier.sample,
            entry.value.itemWidth,
          ),
          priority: GalleryImagePriority.lookahead,
        ),
      );
    }
  }

  void _showPostDetail(BuildContext context, DanbooruPost post) {
    unawaited(_showGalleryDetail(context, post));
  }

  Future<void> _showGalleryDetail(
    BuildContext context,
    GalleryItem item,
  ) async {
    if (!_pendingGalleryDetails.add(item.stableKey)) return;
    try {
      final detail = await _loadGalleryDetailWithProgress(context, item);
      if (detail == null) return;
      if (item.sourceId == GallerySourceId.quickTagCloud) {
        try {
          await ref
              .read(onlineGalleryNotifierProvider.notifier)
              .recordQuickTagCloudViewed(item);
        } catch (error, stack) {
          AppLogger.e(
            'Failed to record QuickTagCloud history',
            error,
            stack,
            'OnlineGallery',
          );
        }
      }
      if (!context.mounted) return;
      final l10n = context.l10n;
      final galleryState = ref.read(onlineGalleryNotifierProvider);
      final projection = const GalleryPromptProjectionService().project(
        item: item,
        detail: detail,
        promptTagSettings: ref.read(onlineGalleryPromptTagSettingsProvider),
        outputFilter: ref.read(onlineGalleryOutputFilterProvider),
      );
      final stableKey = item.stableKey;
      final isFavorited = ref
          .read(onlineGalleryNotifierProvider.notifier)
          .isFavorited(item);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => GalleryDetailDialog(
          item: item,
          detail: detail,
          isFavorited: isFavorited,
          favoriteLoading: galleryState.favoriteLoadingPostKeys.contains(
            stableKey,
          ),
          canToggleFavorite:
              !(item.sourceId == GallerySourceId.gelbooru &&
                  galleryState.viewMode == GalleryViewMode.favorites &&
                  galleryState.favoritesScope == GalleryFavoritesScope.remote),
          labels: GalleryDetailDialogLabels(
            sourceName: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_sourceQuickTagCloud
                : item.sourceId.label,
            untitled: l10n.onlineGallery_codexUntitled,
            codex: l10n.onlineGallery_codexLabel,
            category: l10n.common_category,
            positivePrompt: l10n.onlineGallery_codexPrompt,
            negativePrompt: l10n.onlineGallery_codexNegativePrompt,
            characterPrompts: l10n.onlineGallery_codexCharacterPrompts,
            note: l10n.onlineGallery_codexNote,
            rawTags: l10n.onlineGallery_tags,
            artists: l10n.onlineGallery_artists,
            characters: l10n.onlineGallery_characters,
            copyrights: l10n.onlineGallery_copyrights,
            general: l10n.onlineGallery_general,
            metadata: l10n.onlineGallery_metadata,
            tagContextMenuTooltip: l10n.onlineGallery_tagContextMenuTooltip,
            outputFilteredTagTooltip:
                l10n.onlineGallery_outputFilteredTagTooltip,
            author: l10n.onlineGallery_codexAuthor,
            imageFile: l10n.onlineGallery_codexImageFile,
            originalFile: l10n.onlineGallery_codexOriginalFile,
            declaredSource: l10n.onlineGallery_codexDeclaredSource,
            contributors: l10n.onlineGallery_codexContributors,
            noImage: l10n.onlineGallery_codexNoImage,
            noImageDescription: l10n.onlineGallery_codexNoImageDescription,
            imageLoadFailed: l10n.detail_imageLoadFailed,
            retry: l10n.common_retry,
            zoomHint: l10n.onlineGallery_pinchToZoom,
            copyActions: l10n.common_copy,
            copyPositive: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexCopyPositive
                : l10n.localGallery_copyPrompt,
            copyNegative: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexCopyNegative
                : l10n.prompt_negativePrompt,
            copyCharacter: l10n.onlineGallery_codexCopyCharacter,
            copyAll: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexCopyAll
                : l10n.onlineGallery_copyFullPrompt,
            addFavorite: l10n.common_favorite,
            removeFavorite: l10n.common_unfavorite,
            openSource: l10n.onlineGallery_codexOpenSource,
            sendToGenerate: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexSendToGeneration
                : l10n.onlineGallery_sendToTextToImage,
            addToQueue: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexAddToQueue
                : l10n.onlineGallery_addToQueue,
            downloadOriginal: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexDownloadOriginal
                : l10n.common_download,
            previousImage: l10n.onlineGallery_previousPage,
            nextImage: l10n.onlineGallery_nextPage,
            close: l10n.common_close,
            emptyValue: l10n.common_emptyValue,
            imageCounter: (current, total) => '$current / $total',
            multipleImages: l10n.onlineGallery_multipleImages,
            views: l10n.onlineGallery_views,
            favoriteCount: l10n.onlineGallery_favCount,
            rating: l10n.onlineGallery_ratingLabel,
            score: l10n.onlineGallery_score,
            copyMetadata: l10n.onlineGallery_copyFullMetadata,
            downloadAll: l10n.onlineGallery_downloadAllMedia,
            sendToReverse: l10n.onlineGallery_sendToReversePrompt,
            copyArtistChain: l10n.onlineGallery_copyArtistChain,
            copyFullPrompt: l10n.onlineGallery_copyFullPrompt,
            copyRawArtistFragments: l10n.onlineGallery_copyRawArtistFragments,
            noArtistChain: l10n.onlineGallery_noArtistChain,
          ),
          onCopyPrompt: () => unawaited(
            _copyCodexText(
              projection.positivePrompt,
              l10n.onlineGallery_codexCopyPositive,
            ),
          ),
          onCopyNegativePrompt: () => unawaited(
            _copyCodexText(
              projection.negativePrompt,
              l10n.onlineGallery_codexCopyNegative,
            ),
          ),
          onCopyCharacter: (character) {
            final index = detail.characterPrompts.indexOf(character);
            final projected =
                index >= 0 && index < projection.characterPrompts.length
                ? projection.characterPrompts[index]
                : character;
            unawaited(
              _copyCodexText(
                _buildCharacterCodexCopyText(projected),
                l10n.onlineGallery_codexCopyCharacter,
              ),
            );
          },
          onCopyAll: () => unawaited(
            _copyCodexText(
              _buildCodexCopyText(projection),
              l10n.onlineGallery_codexCopyAll,
            ),
          ),
          onToggleFavorite: () => _handleFavoriteToggle(context, item),
          onOpenSource: () => unawaited(
            _openCodexSource(
              context,
              detail.sourceUrl?.trim().isNotEmpty == true
                  ? detail.sourceUrl
                  : item.postUrl,
            ),
          ),
          onSendToGenerate: () {
            _sendCodexDetailToGeneration(context, item, projection);
          },
          onAddToQueue: () => _addCodexDetailToQueue(context, item, projection),
          onDownloadCurrentOriginal: (media) =>
              _downloadCodexMedia(context, item, media),
          onTagSearch: (tag) {
            _searchController.text = tag;
            _galleryNotifier.search(tag);
          },
          onBlacklistChanged: () => _galleryNotifier.refresh(),
          onCopyMetadata: (media) => unawaited(
            _copyCodexText(
              _galleryMediaMetadata(media),
              l10n.onlineGallery_copyFullMetadata,
            ),
          ),
          onDownloadAll: (media) =>
              _downloadGalleryMediaBatch(context, item, media),
          onSendToReverse: (media) =>
              _sendGalleryMediaToReverse(context, item, media),
          onCopyArtistChain:
              item.sourceId == GallerySourceId.aiTag &&
                  item.focusedMediaId != null
              ? (media) => unawaited(
                  _copyCodexText(
                    ArtistChainParser.parse(media.prompt).formattedText,
                    l10n.onlineGallery_copyArtistChain,
                  ),
                )
              : null,
          onCopyFullPrompt:
              item.sourceId == GallerySourceId.aiTag &&
                  item.focusedMediaId != null
              ? (media) => unawaited(
                  _copyCodexText(
                    _buildCodexCopyText(
                      const GalleryPromptProjectionService().project(
                        item: item,
                        detail: detail,
                        currentMedia: media,
                        promptTagSettings: ref.read(
                          onlineGalleryPromptTagSettingsProvider,
                        ),
                        outputFilter: ref.read(
                          onlineGalleryOutputFilterProvider,
                        ),
                      ),
                      negativeLabel:
                          l10n.onlineGallery_negativePromptCopyHeading,
                    ),
                    l10n.onlineGallery_copyFullPrompt,
                  ),
                )
              : null,
          onCopyRawArtistFragments:
              item.sourceId == GallerySourceId.aiTag &&
                  item.focusedMediaId != null
              ? (media) => unawaited(
                  _copyCodexText(
                    ArtistChainParser.parse(media.prompt).rawText,
                    l10n.onlineGallery_copyRawArtistFragments,
                  ),
                )
              : null,
          hasArtistChain:
              item.sourceId == GallerySourceId.aiTag &&
                  item.focusedMediaId != null
              ? (media) => ArtistChainParser.parse(media.prompt).isNotEmpty
              : null,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        AppToast.error(
          context,
          '${context.l10n.onlineGallery_loadFailed}: $error',
        );
      }
    } finally {
      _pendingGalleryDetails.remove(item.stableKey);
    }
  }

  Future<GalleryDetail?> _loadGalleryDetailWithProgress(
    BuildContext context,
    GalleryItem item,
  ) async {
    final shown = Completer<BuildContext>();
    final cancelled = Completer<void>();
    var dismissRequested = false;
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!shown.isCompleted) shown.complete(dialogContext);
        return AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Text(context.l10n.common_loading),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!cancelled.isCompleted) cancelled.complete();
                dismissRequested = true;
                Navigator.of(dialogContext, rootNavigator: true).pop();
              },
              child: Text(context.l10n.common_cancel),
            ),
          ],
        );
      },
    );
    unawaited(
      dialogFuture.whenComplete(() {
        if (!cancelled.isCompleted) cancelled.complete();
      }),
    );

    final dialogContext = await shown.future;
    try {
      final detail = await Future.any<GalleryDetail?>([
        _galleryNotifier.loadDetail(item),
        cancelled.future.then<GalleryDetail?>((_) => null),
      ]);
      if (detail == null) _galleryNotifier.cancelDetail(item);
      return detail;
    } finally {
      if (!dismissRequested && dialogContext.mounted) {
        dismissRequested = true;
        Navigator.of(dialogContext, rootNavigator: true).pop();
      }
      await dialogFuture;
    }
  }

  String _galleryMediaMetadata(GalleryMedia media) {
    final raw = media.rawMetadata?.trim() ?? '';
    if (raw.isNotEmpty) return raw;
    return const JsonEncoder.withIndent('  ').convert(media.metadata);
  }

  Future<void> _sendGalleryMediaToReverse(
    BuildContext dialogContext,
    GalleryItem item,
    GalleryMedia media,
  ) async {
    final url = media.displayUrl.isNotEmpty
        ? media.displayUrl
        : (media.downloadUrl.isNotEmpty ? media.downloadUrl : media.previewUrl);
    if (url.isEmpty) {
      AppToast.info(dialogContext, dialogContext.l10n.onlineGallery_noImageUrl);
      return;
    }
    try {
      final file = await OnlineGalleryImageCacheManager.instance.getSingleFile(
        url,
        key: onlineGalleryImageCacheKeyForUrl(url),
        headers: onlineGalleryImageHeadersForUrl(url),
      );
      await ref
          .read(reversePromptProvider.notifier)
          .addImage(
            await file.readAsBytes(),
            name: '${item.sourceId.key}_${item.sourceWorkId}',
          );
      if (!mounted || !dialogContext.mounted) return;
      Navigator.of(dialogContext, rootNavigator: true).pop();
      context.go('/');
      AppToast.success(context, context.l10n.onlineGallery_sentToReversePrompt);
    } catch (error) {
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_reversePromptSendFailed('$error'),
        );
      }
    }
  }

  Future<void> _downloadGalleryMediaBatch(
    BuildContext dialogContext,
    GalleryItem item,
    List<GalleryMedia> mediaItems,
  ) async {
    final directory = await FilePickerUtils.pickDirectoryModal(
      dialogTitle: dialogContext.l10n.onlineGallery_chooseDownloadDirectory,
    );
    if (directory == null) return;
    try {
      for (final media in mediaItems) {
        final url = media.downloadUrl.isNotEmpty
            ? media.downloadUrl
            : (media.displayUrl.isNotEmpty
                  ? media.displayUrl
                  : media.previewUrl);
        if (url.isEmpty) continue;
        final file = await OnlineGalleryImageCacheManager.instance
            .getSingleFile(
              url,
              key: onlineGalleryImageCacheKeyForUrl(url),
              headers: onlineGalleryImageHeadersForUrl(url),
            );
        final safeWorkId = item.sourceWorkId.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]+'),
          '_',
        );
        final safeMediaId = media.id.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]+'),
          '_',
        );
        final extensionCandidate =
            media.extension ??
            path.extension(Uri.parse(url).path).replaceFirst('.', '');
        final extension =
            RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(extensionCandidate)
            ? extensionCandidate.toLowerCase()
            : 'webp';
        await file.copy(
          path.join(
            directory,
            '${item.sourceId.key}_${safeWorkId}_$safeMediaId.$extension',
          ),
        );
      }
      if (dialogContext.mounted) {
        AppToast.success(
          dialogContext,
          dialogContext.l10n.onlineGallery_savedToPath(directory),
        );
      }
    } catch (error) {
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_downloadFailed('$error'),
        );
      }
    }
  }

  Future<void> _copyCodexText(String text, String label) async {
    final value = text.trim();
    if (value.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) AppToast.success(context, '$label ✓');
    } catch (error) {
      if (mounted) {
        AppToast.error(context, context.l10n.gallery_copyFailed('$error'));
      }
    }
  }

  String _buildCharacterCodexCopyText(GalleryCharacterPrompt character) {
    final blocks = <String>[];
    final prompt = character.prompt.trim();
    final negative = character.negativePrompt.trim();
    if (prompt.isNotEmpty) blocks.add(prompt);
    if (negative.isNotEmpty) {
      blocks.add(
        '${context.l10n.onlineGallery_codexNegativePrompt}:\n$negative',
      );
    }
    return blocks.join('\n\n');
  }

  Future<void> _openCodexSource(
    BuildContext dialogContext,
    String? rawUrl,
  ) async {
    final url = rawUrl == null ? null : Uri.tryParse(rawUrl.trim());
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_codexOpenSourceFailed,
        );
      }
      return;
    }
    try {
      final opened = await launchUrl(url);
      if (!opened && dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_codexOpenSourceFailed,
        );
      }
    } catch (error, stack) {
      AppLogger.e(
        'Failed to open QuickTagCloud source',
        error,
        stack,
        'OnlineGallery',
      );
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_actionFailed('$error'),
        );
      }
    }
  }

  String _buildCodexCopyText(
    GalleryPromptProjection projection, {
    String? negativeLabel,
  }) {
    final blocks = <String>[];
    final prompt = projection.positivePrompt.trim();
    final negative = projection.negativePrompt.trim();
    if (prompt.isNotEmpty) blocks.add(prompt);
    final l10n = context.l10n;
    final resolvedNegativeLabel =
        negativeLabel ?? l10n.onlineGallery_codexNegativePrompt;
    if (negative.isNotEmpty) {
      blocks.add('$resolvedNegativeLabel:\n$negative');
    }
    for (var index = 0; index < projection.characterPrompts.length; index++) {
      final character = projection.characterPrompts[index];
      final content = <String>[
        if (character.prompt.trim().isNotEmpty) character.prompt.trim(),
        if (character.negativePrompt.trim().isNotEmpty)
          '$resolvedNegativeLabel: ${character.negativePrompt.trim()}',
      ].join('\n');
      if (content.isNotEmpty) {
        blocks.add(
          '${character.label.isEmpty ? '${l10n.onlineGallery_codexCharacterPrompts} ${index + 1}' : character.label}:\n$content',
        );
      }
    }
    return blocks.join('\n\n');
  }

  List<CharacterPrompt> _codexCharacters(
    GalleryItem item,
    GalleryPromptProjection projection,
  ) {
    return [
      for (var index = 0; index < projection.characterPrompts.length; index++)
        CharacterPrompt(
          id: 'codex-${item.stableKey}-$index',
          name: projection.characterPrompts[index].label,
          prompt: projection.characterPrompts[index].prompt,
          negativePrompt: projection.characterPrompts[index].negativePrompt,
          positionMode: CharacterPositionMode.aiChoice,
        ),
    ];
  }

  void _sendCodexDetailToGeneration(
    BuildContext dialogContext,
    GalleryItem item,
    GalleryPromptProjection projection,
  ) {
    ref
        .read(characterPromptNotifierProvider.notifier)
        .replaceAll(_codexCharacters(item, projection));
    ref
        .read(pendingPromptNotifierProvider.notifier)
        .set(
          prompt: projection.positivePrompt,
          negativePrompt: projection.negativePrompt,
        );
    Navigator.of(dialogContext, rootNavigator: true).pop();
    context.go('/');
    AppToast.info(context, context.l10n.onlineGallery_sentToTextToImage);
  }

  Future<void> _addCodexDetailToQueue(
    BuildContext dialogContext,
    GalleryItem item,
    GalleryPromptProjection projection,
  ) async {
    final prompt = projection.positivePrompt.trim();
    final negativePrompt = projection.negativePrompt.trim();
    final hasCharacterPrompt = projection.characterPrompts.any(
      (character) =>
          character.prompt.trim().isNotEmpty ||
          character.negativePrompt.trim().isNotEmpty,
    );
    if (prompt.isEmpty && negativePrompt.isEmpty && !hasCharacterPrompt) return;
    try {
      final success = await ref
          .read(replicationQueueNotifierProvider.notifier)
          .add(
            ReplicationTask.create(
              prompt: prompt,
              negativePrompt: negativePrompt,
              applyNegativePrompt: negativePrompt.isNotEmpty,
              thumbnailUrl: item.previewUrl,
              source: ReplicationTaskSource.online,
              characterPrompts: [
                for (final character in projection.characterPrompts)
                  ReplicationCharacterPromptSnapshot(
                    prompt: character.prompt,
                    negativePrompt: character.negativePrompt,
                  ),
              ],
            ),
          );
      if (!dialogContext.mounted) return;
      if (success) {
        final count = ref.read(
          replicationQueueNotifierProvider.select((state) => state.count),
        );
        AppToast.success(
          dialogContext,
          dialogContext.l10n.onlineGallery_addedToQueueWithCount(count),
        );
      } else {
        AppToast.warning(
          dialogContext,
          dialogContext.l10n.onlineGallery_queueFullMax,
        );
      }
    } catch (error, stack) {
      AppLogger.e(
        'Failed to add QuickTagCloud entry to queue',
        error,
        stack,
        'OnlineGallery',
      );
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_actionFailed('$error'),
        );
      }
    }
  }

  Future<void> _downloadCodexMedia(
    BuildContext dialogContext,
    GalleryItem item,
    GalleryMedia media,
  ) async {
    final directory = await FilePickerUtils.pickDirectoryModal(
      dialogTitle: dialogContext.l10n.onlineGallery_chooseDownloadDirectory,
    );
    if (directory == null) return;
    final url = media.downloadUrl;
    try {
      final file = await OnlineGalleryImageCacheManager.instance.getSingleFile(
        url,
        key: onlineGalleryImageCacheKeyForUrl(url),
        headers: onlineGalleryImageHeadersForUrl(url),
      );
      final safeWorkId = item.sourceWorkId.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]+'),
        '_',
      );
      final extensionCandidate =
          media.extension ??
          path.extension(Uri.parse(url).path).replaceFirst('.', '');
      final extension =
          RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(extensionCandidate)
          ? extensionCandidate.toLowerCase()
          : 'webp';
      final safeMediaId = media.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final destination = path.join(
        directory,
        '${item.sourceId.key}_${safeWorkId}_$safeMediaId.$extension',
      );
      await file.copy(destination);
      if (dialogContext.mounted) {
        AppToast.success(
          dialogContext,
          dialogContext.l10n.onlineGallery_savedToPath(destination),
        );
      }
    } catch (error) {
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_downloadFailed(error.toString()),
        );
      }
    }
  }

  /// 处理收藏切换
  Future<bool> _handleFavoriteToggle(
    BuildContext context,
    DanbooruPost post,
  ) async {
    final wasFavorited = _galleryNotifier.isFavorited(post);
    try {
      final success = await _galleryNotifier.toggleFavorite(post);
      if (context.mounted) {
        if (success) {
          AppToast.info(
            context,
            wasFavorited
                ? context.l10n.onlineGallery_unfavorited
                : context.l10n.onlineGallery_favorited,
          );
        } else {
          AppToast.error(
            context,
            context.l10n.onlineGallery_actionFailed(
              context.l10n.onlineGallery_sourceRequestFailed,
            ),
          );
        }
      }
      return success;
    } catch (error, stack) {
      AppLogger.e(
        'Failed to toggle online gallery favorite',
        error,
        stack,
        'OnlineGallery',
      );
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.onlineGallery_actionFailed('$error'),
        );
      }
      return false;
    }
  }

  /// 批量加入队列
  Future<String?> _queueThumbnailPath(String previewUrl) async {
    if (previewUrl.isEmpty) return null;
    try {
      final file = await OnlineGalleryImageCacheManager.instance.getSingleFile(
        previewUrl,
        key: onlineGalleryImageCacheKeyForUrl(previewUrl),
        headers: onlineGalleryImageHeadersForUrl(previewUrl),
      );
      return file.path;
    } catch (error) {
      debugPrint('Failed to cache queue thumbnail $previewUrl: $error');
      return null;
    }
  }

  Future<({ReplicationTask? task, bool failed})> _buildReplicationTask(
    GalleryItem post,
    OnlineGalleryPromptTagSettings promptTagSettings,
    OnlineGalleryOutputFilterSettings outputFilter,
  ) async {
    try {
      GalleryDetail? detail;
      if (post.sourceId == GallerySourceId.aiTag ||
          post.sourceId == GallerySourceId.quickTagCloud ||
          post.focusedMediaId != null) {
        detail = await _galleryNotifier.loadDetail(post);
      }
      GalleryMedia? media;
      if (detail != null && detail.media.isNotEmpty) {
        final focusedIndex = post.focusedMediaId == null
            ? -1
            : detail.media.indexWhere(
                (candidate) => candidate.id == post.focusedMediaId,
              );
        media = focusedIndex >= 0
            ? detail.media[focusedIndex]
            : detail.media.first;
      }
      final projection = const GalleryPromptProjectionService().project(
        item: post,
        detail: detail,
        currentMedia: media,
        promptTagSettings: promptTagSettings,
        outputFilter: outputFilter,
      );
      final hasCharacterPrompt = projection.characterPrompts.any(
        (character) =>
            character.prompt.trim().isNotEmpty ||
            character.negativePrompt.trim().isNotEmpty,
      );
      if (projection.positivePrompt.isEmpty &&
          projection.negativePrompt.isEmpty &&
          !hasCharacterPrompt) {
        return (task: null, failed: true);
      }
      final thumbnailPath = await _queueThumbnailPath(
        media?.previewUrl ?? post.previewUrl,
      );
      return (
        task: ReplicationTask.create(
          prompt: projection.positivePrompt,
          negativePrompt: projection.negativePrompt,
          applyNegativePrompt: projection.negativePrompt.isNotEmpty,
          thumbnailUrl: thumbnailPath,
          source: ReplicationTaskSource.online,
          width: media != null && media.width > 0 ? media.width : null,
          height: media != null && media.height > 0 ? media.height : null,
          characterPrompts: [
            for (final character in projection.characterPrompts)
              ReplicationCharacterPromptSnapshot(
                prompt: character.prompt,
                negativePrompt: character.negativePrompt,
              ),
          ],
        ),
        failed: false,
      );
    } catch (error) {
      debugPrint('Failed to resolve ${post.stableKey} for queue: $error');
      return (task: null, failed: true);
    }
  }

  Future<void> _addSelectedToQueue() async {
    final selectionState = ref.read(onlineGallerySelectionNotifierProvider);
    final galleryState = ref.read(onlineGalleryNotifierProvider);
    final promptTagSettings = ref.read(onlineGalleryPromptTagSettingsProvider);
    final outputFilter = ref.read(onlineGalleryOutputFilterProvider);

    final selectedPosts = galleryState.posts
        .where((p) => selectionState.selectedIds.contains(p.stableKey))
        .toList();

    if (selectedPosts.isEmpty) return;

    final tasks = <ReplicationTask>[];
    var preparationFailureCount = 0;
    const concurrency = 4;
    for (var start = 0; start < selectedPosts.length; start += concurrency) {
      final batch = selectedPosts.sublist(
        start,
        min(start + concurrency, selectedPosts.length),
      );
      final resolved = await Future.wait(
        batch.map(
          (post) =>
              _buildReplicationTask(post, promptTagSettings, outputFilter),
        ),
      );
      tasks.addAll(resolved.map((result) => result.task).whereType());
      preparationFailureCount += resolved
          .where((result) => result.failed)
          .length;
    }

    if (!mounted) return;
    if (tasks.isEmpty) {
      AppToast.warning(
        context,
        context.l10n.onlineGallery_queueBatchCompleted(
          0,
          preparationFailureCount,
          0,
        ),
      );
      _selectionNotifier.exit();
      return;
    }

    final addedCount = await ref
        .read(replicationQueueNotifierProvider.notifier)
        .addAll(tasks);

    if (mounted) {
      final queueSkippedCount = tasks.length - addedCount;
      if (preparationFailureCount > 0 || queueSkippedCount > 0) {
        AppToast.warning(
          context,
          context.l10n.onlineGallery_queueBatchCompleted(
            addedCount,
            preparationFailureCount,
            queueSkippedCount,
          ),
        );
      } else {
        AppToast.success(
          context,
          context.l10n.onlineGallery_addedTasksToQueue(addedCount),
        );
      }
      _selectionNotifier.exit();
    }
  }

  /// 批量收藏
  Future<void> _favoriteSelected() async {
    final selectionState = ref.read(onlineGallerySelectionNotifierProvider);
    final galleryState = ref.read(onlineGalleryNotifierProvider);
    final source = _activeSource(galleryState);
    final selectedPosts = galleryState.posts
        .where(
          (post) =>
              post.sourceId == source &&
              selectionState.selectedIds.contains(post.stableKey),
        )
        .toList();
    if (selectedPosts.isEmpty) return;

    var count = 0;
    for (final post in selectedPosts) {
      // 检查widget是否仍然挂载，避免在widget disposed后继续操作
      if (!mounted) return;

      if (!_galleryNotifier.isFavorited(post)) {
        final success = await _galleryNotifier.toggleFavorite(post);
        if (success) count++;
        if (success && source == GallerySourceId.danbooru) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    if (mounted) {
      AppToast.info(context, context.l10n.onlineGallery_favoritedImages(count));
      _selectionNotifier.exit();
    }
  }

  /// 批量下载
  Future<void> _downloadSelected() async {
    final selectionState = ref.read(onlineGallerySelectionNotifierProvider);
    final galleryState = ref.read(onlineGalleryNotifierProvider);

    final selectedPosts = galleryState.posts
        .where((p) => selectionState.selectedIds.contains(p.stableKey))
        .toList();

    if (selectedPosts.isEmpty) return;

    String? result;
    try {
      result = await FilePickerUtils.pickDirectoryModal(
        dialogTitle: context.l10n.onlineGallery_chooseDownloadDirectory,
      );
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.onlineGallery_selectDownloadDirectoryFailed('$e'),
        );
      }
      return;
    }
    if (result == null) return;

    if (mounted) {
      AppToast.info(
        context,
        context.l10n.onlineGallery_downloadSelectedStarted(
          selectedPosts.length,
        ),
      );
      _selectionNotifier.exit();
    }

    final (successCount, failCount, skippedCount) = await _downloadPosts(
      selectedPosts,
      result,
    );

    if (mounted) {
      final message = context.l10n
          .onlineGallery_downloadSelectedCompletedWithSkipped(
            successCount,
            failCount,
            skippedCount,
          );
      if (failCount > 0) {
        AppToast.warning(context, message);
      } else if (successCount > 0) {
        AppToast.success(context, message);
      } else {
        AppToast.info(context, message);
      }
    }
  }

  /// AI TAG 普通卡按作品下载全部媒体；媒体焦点卡只下载目标图片。
  Future<(int success, int fail, int skipped)> _downloadPosts(
    List<DanbooruPost> posts,
    String destinationDir,
  ) async {
    final jobs = <_GalleryDownloadJob>[];
    const concurrency = 4;
    for (var start = 0; start < posts.length; start += concurrency) {
      final batch = posts.sublist(
        start,
        min(start + concurrency, posts.length),
      );
      final resolved = await Future.wait(
        batch.map((post) async {
          if (!post.hasValidPreview) return <_GalleryDownloadJob>[];
          if (!post.sourceId.capabilities.supportsMultipleMedia ||
              post.mediaCount <= 1) {
            return [
              _GalleryDownloadJob(post: post, media: post.cover, mediaIndex: 1),
            ];
          }
          if (post.focusedMediaId != null) {
            return [
              _GalleryDownloadJob(
                post: post,
                media: post.cover,
                mediaIndex: (post.focusedMediaIndex ?? 0) + 1,
              ),
            ];
          }
          try {
            final detail = await _galleryNotifier.loadDetail(post);
            return [
              for (var index = 0; index < detail.media.length; index++)
                _GalleryDownloadJob(
                  post: detail.item,
                  media: detail.media[index],
                  mediaIndex: index + 1,
                ),
            ];
          } catch (error) {
            debugPrint(
              'Failed to resolve gallery work ${post.sourceWorkId}: $error',
            );
            return <_GalleryDownloadJob>[];
          }
        }),
      );
      jobs.addAll(resolved.expand((batchJobs) => batchJobs));
    }

    var successCount = 0;
    final skippedCount = posts.where((post) => !post.hasValidPreview).length;
    var failCount = posts
        .where(
          (post) =>
              post.hasValidPreview &&
              post.sourceId.capabilities.supportsMultipleMedia &&
              !jobs.any((job) => job.post.stableKey == post.stableKey),
        )
        .length;
    final progress = ValueNotifier<int>(0);
    BuildContext? progressDialogContext;
    if (mounted && jobs.isNotEmpty) {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            progressDialogContext = dialogContext;
            return AlertDialog(
              content: ValueListenableBuilder<int>(
                valueListenable: progress,
                builder: (_, completed, __) => SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: completed / jobs.length),
                      const SizedBox(height: 12),
                      Text('$completed / ${jobs.length}'),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    for (var start = 0; start < jobs.length; start += concurrency) {
      final batch = jobs.sublist(start, min(start + concurrency, jobs.length));
      await Future.wait(
        batch.map((job) async {
          try {
            final url = job.media.downloadUrl;
            if (url.isEmpty) throw StateError('Image URL is empty');
            final file = await OnlineGalleryImageCacheManager.instance
                .getSingleFile(
                  url,
                  key: onlineGalleryImageCacheKeyForUrl(url),
                  headers: onlineGalleryImageHeadersForUrl(url),
                );
            final extension =
                job.media.extension ??
                path.extension(Uri.parse(url).path).replaceFirst('.', '');
            final safeWorkId = job.post.sourceWorkId.replaceAll(
              RegExp(r'[^A-Za-z0-9._-]+'),
              '_',
            );
            final destination = path.join(
              destinationDir,
              '${job.post.sourceId.key}_${safeWorkId}_p${job.mediaIndex.toString().padLeft(2, '0')}.${extension.isEmpty ? 'webp' : extension}',
            );
            await file.copy(destination);
            successCount++;
          } catch (error) {
            failCount++;
            debugPrint(
              'Download failed for ${job.post.stableKey} media ${job.mediaIndex}: $error',
            );
          } finally {
            progress.value++;
          }
        }),
      );
    }
    if (progressDialogContext?.mounted == true) {
      Navigator.of(progressDialogContext!).pop();
    }
    progress.dispose();
    return (successCount, failCount, skippedCount);
  }
}

class _GalleryDownloadJob {
  const _GalleryDownloadJob({
    required this.post,
    required this.media,
    required this.mediaIndex,
  });

  final GalleryItem post;
  final GalleryMedia media;
  final int mediaIndex;
}

/// 模式切换按钮
class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;
  final bool showBadge;
  final bool compact;
  final String? badgeHint;
  final String? disabledHint;
  final Color selectedBackgroundColor;
  final Color selectedForegroundColor;

  const _ModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.showBadge = false,
    this.compact = false,
    this.badgeHint,
    this.disabledHint,
    required this.selectedBackgroundColor,
    required this.selectedForegroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(8) : Radius.zero,
      right: isLast ? const Radius.circular(8) : Radius.zero,
    );
    final enabled = onTap != null;
    final foregroundColor = !enabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
        : isSelected
        ? selectedForegroundColor
        : theme.colorScheme.onSurfaceVariant;

    final tooltip =
        disabledHint ??
        (showBadge && badgeHint != null ? '$label · $badgeHint' : label);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: isSelected,
        hint: showBadge ? badgeHint : null,
        child: Material(
          color: isSelected ? selectedBackgroundColor : Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            hoverColor: isSelected
                ? Colors.transparent
                : selectedBackgroundColor.withValues(alpha: 0.08),
            focusColor: selectedBackgroundColor.withValues(alpha: 0.14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compact) ...[
                      Icon(icon, size: 18, color: foregroundColor),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: foregroundColor,
                      ),
                    ),
                    if (showBadge)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 数据源下拉
class _SourceDropdown extends StatelessWidget {
  final GallerySourceId selected;
  final Map<GallerySourceId, String> sources;
  final ValueChanged<GallerySourceId> onChanged;

  const _SourceDropdown({
    required this.selected,
    required this.sources,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<GallerySourceId>(
      key: const ValueKey('online-gallery-source-selector'),
      onSelected: onChanged,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => sources.entries.map((e) {
        final isSelected = selected == e.key;
        return PopupMenuItem<GallerySourceId>(
          value: e.key,
          child: Row(
            children: [
              Text(
                e.value,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                sources[selected] ?? selected.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 模糊匹配开关
class _FuzzySearchToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _FuzzySearchToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterChip(
      selected: enabled,
      showCheckmark: false,
      label: Text(
        context.l10n.onlineGallery_fuzzySearch,
        style: const TextStyle(fontSize: 12),
      ),
      tooltip: context.l10n.onlineGallery_fuzzySearchTooltip,
      onSelected: onChanged,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      selectedColor: theme.colorScheme.secondaryContainer,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.4,
      ),
      side: BorderSide(
        color: enabled
            ? theme.colorScheme.secondary.withValues(alpha: 0.7)
            : Colors.transparent,
      ),
    );
  }
}

class _DateRangePopup extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  final void Function(DateTime start, DateTime end) onApply;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const _DateRangePopup({
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    required this.onApply,
    required this.onClear,
    required this.onClose,
  });

  @override
  State<_DateRangePopup> createState() => _DateRangePopupState();
}

class _DateRangePopupState extends State<_DateRangePopup> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = _clampDate(
      widget.initialStart ?? widget.lastDate.subtract(const Duration(days: 30)),
    );
    _end = _clampDate(widget.initialEnd ?? widget.lastDate);
    _normalizeRange();
  }

  DateTime _clampDate(DateTime date) {
    if (date.isBefore(widget.firstDate)) return widget.firstDate;
    if (date.isAfter(widget.lastDate)) return widget.lastDate;
    return DateTime(date.year, date.month, date.day);
  }

  void _normalizeRange() {
    if (_start.isAfter(_end)) {
      final previousStart = _start;
      _start = _end;
      _end = previousStart;
    }
  }

  void _setLast30Days() {
    setState(() {
      _start = _clampDate(widget.lastDate.subtract(const Duration(days: 30)));
      _end = _clampDate(widget.lastDate);
    });
  }

  void _apply() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    form.save();
    _normalizeRange();
    widget.onApply(_start, _end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 340,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.onlineGallery_dateRange,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: context.l10n.common_close,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InputDatePickerFormField(
                key: ValueKey('start_${_start.toIso8601String()}'),
                initialDate: _start,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                fieldLabelText: context.l10n.onlineGallery_startDate,
                fieldHintText: 'yyyy-mm-dd',
                errorFormatText: context.l10n.onlineGallery_invalidDateFormat,
                errorInvalidText: context.l10n.onlineGallery_dateOutOfRange,
                onDateSaved: (date) => _start = _clampDate(date),
              ),
              const SizedBox(height: 10),
              InputDatePickerFormField(
                key: ValueKey('end_${_end.toIso8601String()}'),
                initialDate: _end,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                fieldLabelText: context.l10n.onlineGallery_endDate,
                fieldHintText: 'yyyy-mm-dd',
                errorFormatText: context.l10n.onlineGallery_invalidDateFormat,
                errorInvalidText: context.l10n.onlineGallery_dateOutOfRange,
                onDateSaved: (date) => _end = _clampDate(date),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: _setLast30Days,
                      child: Text(context.l10n.onlineGallery_last30Days),
                    ),
                    TextButton(
                      onPressed: widget.onClear,
                      child: Text(context.l10n.onlineGallery_clear),
                    ),
                    FilledButton(
                      onPressed: _apply,
                      child: Text(context.l10n.common_apply),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 评级下拉
class _RatingDropdown extends StatelessWidget {
  final Set<String> selectedRatings;
  final ValueChanged<String> onToggle;
  final Set<String> availableRatings;
  final bool compact;

  const _RatingDropdown({
    required this.selectedRatings,
    required this.onToggle,
    this.availableRatings = kAllRatings,
    this.compact = false,
  });

  List<(String, String, Color?)> _getRatings(BuildContext context) => [
    ('all', context.l10n.onlineGallery_all, null),
    if (availableRatings.contains('g'))
      ('g', context.l10n.onlineGallery_ratingGeneral, Colors.green),
    if (availableRatings.contains('s'))
      ('s', context.l10n.onlineGallery_ratingSensitive, Colors.amber),
    if (availableRatings.contains('q'))
      ('q', context.l10n.onlineGallery_ratingQuestionable, Colors.orange),
    if (availableRatings.contains('e'))
      ('e', context.l10n.onlineGallery_ratingExplicit, Colors.red),
  ];

  Color _ratingColor(String ratingCode) {
    switch (ratingCode) {
      case 'g':
        return Colors.green;
      case 's':
        return Colors.amber;
      case 'q':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRatingIndicator(ThemeData theme, List<String> selectedCodes) {
    if (selectedCodes.isEmpty) return const SizedBox.shrink();

    final visibleCount = min(3, selectedCodes.length);
    final hasMore = selectedCodes.length > visibleCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(visibleCount, (index) {
          final code = selectedCodes[index];
          return Padding(
            padding: EdgeInsets.only(right: index == visibleCount - 1 ? 0 : 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _ratingColor(code),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
        if (hasMore) ...[
          const SizedBox(width: 4),
          Text(
            '+${selectedCodes.length - visibleCount}',
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratings = _getRatings(context);
    final isAllSelected = selectedRatings.containsAll(availableRatings);
    final selectedCodesInOrder = [
      'g',
      's',
      'q',
      'e',
    ].where(availableRatings.contains).where(selectedRatings.contains).toList();
    final selectedSpecific = ratings
        .where((r) => r.$1 != 'all' && selectedRatings.contains(r.$1))
        .toList();
    final current = isAllSelected
        ? ratings.first
        : (selectedSpecific.isNotEmpty
              ? selectedSpecific.first
              : ratings.first);

    String buttonText() {
      if (isAllSelected) return current.$2;
      if (selectedSpecific.length == 1) return selectedSpecific.first.$2;
      if (selectedSpecific.length > 1) {
        return '${selectedSpecific.first.$2} +${selectedSpecific.length - 1}';
      }
      return current.$2;
    }

    return PopupMenuButton<String>(
      key: const ValueKey('online-gallery-rating-filter'),
      onSelected: onToggle,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (menuContext) => ratings.map((r) {
        final isSelected = r.$1 == 'all'
            ? isAllSelected
            : selectedRatings.contains(r.$1);
        return PopupMenuItem<String>(
          value: r.$1,
          child: Row(
            children: [
              if (r.$3 != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: r.$3,
                    shape: BoxShape.circle,
                  ),
                ),
              if (r.$3 != null) const SizedBox(width: 8),
              Text(
                r.$2,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
      tooltip: buttonText(),
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current.$3 != null) ...[
              _buildRatingIndicator(theme, selectedCodesInOrder),
              const SizedBox(width: 6),
            ],
            Text(
              compact
                  ? (isAllSelected || selectedCodesInOrder.isEmpty
                        ? current.$2
                        : selectedCodesInOrder
                              .map((code) => code.toUpperCase())
                              .join('/'))
                  : buttonText(),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: compact ? 2 : 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

String? _quickTagCloudCategoryLabel(Object? rawPath) {
  final parts = switch (rawPath) {
    final Iterable<dynamic> values => values,
    final String value => value.split('/'),
    _ => const <dynamic>[],
  };
  for (final part in parts.toList().reversed) {
    final label = part.toString().trim();
    if (label.isNotEmpty) return label;
  }
  return null;
}

class _VisibilityDrivenGalleryItem extends StatefulWidget {
  const _VisibilityDrivenGalleryItem({
    super.key,
    required this.visibilityKey,
    required this.onVisibilityChanged,
    required this.builder,
  });

  final String visibilityKey;
  final void Function(bool visible, double visibleTop) onVisibilityChanged;
  final Widget Function(BuildContext context, bool hasBeenVisible) builder;

  @override
  State<_VisibilityDrivenGalleryItem> createState() =>
      _VisibilityDrivenGalleryItemState();
}

class _VisibilityDrivenGalleryItemState
    extends State<_VisibilityDrivenGalleryItem> {
  bool _hasBeenVisible = false;
  bool _isVisible = false;

  @override
  void dispose() {
    if (_isVisible) widget.onVisibilityChanged(false, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('gallery-visibility:${widget.visibilityKey}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0;
        if (visible) {
          widget.onVisibilityChanged(true, info.visibleBounds.top);
        } else if (_isVisible) {
          widget.onVisibilityChanged(false, 0);
        }
        if (_isVisible == visible) return;
        _isVisible = visible;
        if (visible && !_hasBeenVisible && mounted) {
          setState(() => _hasBeenVisible = true);
        }
      },
      child: widget.builder(context, _hasBeenVisible),
    );
  }
}
