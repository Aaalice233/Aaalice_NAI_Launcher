import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:path/path.dart' as path;

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/cache/online_gallery_detail_coordinator.dart';
import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../../core/cache/online_gallery_preload_policy.dart';
import '../../../core/services/date_formatting_service.dart';
import '../../../core/utils/file_picker_utils.dart';
import '../../../data/datasources/remote/danbooru_api_service.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../../data/services/gelbooru_auth_service.dart';

import '../../providers/online_gallery_output_filter_provider.dart';
import '../../providers/online_gallery_prompt_tag_settings_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/app_branch_visibility.dart';
import '../../widgets/danbooru_login_dialog.dart';
import '../../widgets/danbooru_post_card.dart';
import '../../widgets/gelbooru_credentials_dialog.dart';
import '../../widgets/online_gallery/post_detail_dialog.dart';
import '../../widgets/online_gallery/ai_tag_detail_dialog.dart';
import '../../widgets/online_gallery/blacklist_settings_panel.dart';
import '../../widgets/online_gallery/online_gallery_hover_controller.dart';
import '../../widgets/online_gallery/output_filter_settings_panel.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _promptSearchFocusNode = FocusNode();
  final FocusNode _popularSearchFocusNode = FocusNode();
  final FocusNode _popularPromptSearchFocusNode = FocusNode();
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
    _searchFocusNode.dispose();
    _promptSearchFocusNode.dispose();
    _popularSearchFocusNode.dispose();
    _popularPromptSearchFocusNode.dispose();
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
            onPressed: _downloadSelected,
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
          final compactActions = constraints.maxWidth < 900;
          final narrowToolbar = constraints.maxWidth < 720;
          final modeSelector = _buildModeSelector(
            theme,
            state,
            authState,
            gelbooruAuthState,
          );
          final primaryActions = _buildPrimaryActions(
            theme,
            state,
            authState,
            gelbooruAuthState,
            compact: compactActions,
          );
          final popularOptionsOnFirstRow =
              state.viewMode == GalleryViewMode.popular && !narrowToolbar;
          final secondaryControls = _buildSecondaryControls(
            theme,
            state,
            includePopularOptions: !popularOptionsOnFirstRow,
          );
          final showQueryFields =
              state.viewMode == GalleryViewMode.search ||
              (state.viewMode == GalleryViewMode.popular &&
                  state.popularSourceId == GallerySourceId.aiTag);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (narrowToolbar)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [modeSelector, primaryActions],
                )
              else
                Row(
                  children: [
                    modeSelector,
                    if (showQueryFields) ...[
                      const SizedBox(width: 12),
                      Expanded(child: _buildSearchFields(theme, state)),
                    ] else if (!popularOptionsOnFirstRow)
                      const Spacer(),
                    if (popularOptionsOnFirstRow) ...[
                      const SizedBox(width: 12),
                      _buildPopularOptions(theme, state),
                      if (!showQueryFields) const Spacer(),
                    ],
                    const SizedBox(width: 12),
                    primaryActions,
                  ],
                ),
              if (narrowToolbar && showQueryFields) ...[
                const SizedBox(height: 8),
                _buildSearchFields(theme, state),
              ],
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: secondaryControls),
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
    GelbooruAuthState gelbooruAuthState,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            icon: Icons.search,
            label: context.l10n.onlineGallery_search,
            isSelected: state.viewMode == GalleryViewMode.search,
            onTap: () {
              _saveScrollOffset();
              _galleryNotifier.switchToSearch();
            },
            isFirst: true,
          ),
          _ModeButton(
            icon: Icons.local_fire_department,
            label: context.l10n.onlineGallery_popular,
            isSelected: state.viewMode == GalleryViewMode.popular,
            onTap: () {
              _saveScrollOffset();
              _galleryNotifier.switchToPopular();
            },
          ),
          _ModeButton(
            icon: Icons.favorite,
            label: context.l10n.onlineGallery_favorites,
            isSelected: state.viewMode == GalleryViewMode.favorites,
            onTap: () {
              _saveScrollOffset();
              _galleryNotifier.switchToFavorites();
            },
            isLast: true,
            showBadge: state.favoritesSourceId == GallerySourceId.gelbooru
                ? !gelbooruAuthState.isAuthenticated
                : !authState.isLoggedIn,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFields(ThemeData theme, OnlineGalleryState state) {
    final isPopular = state.viewMode == GalleryViewMode.popular;
    final activeSource = isPopular ? state.popularSourceId : state.sourceId;
    if (activeSource != GallerySourceId.aiTag) {
      return _buildSearchField(theme);
    }
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 620;
          final query = _buildPlainSearchField(
            theme,
            controller: queryController,
            focusNode: queryFocus,
            hintText: context.l10n.onlineGallery_aiTagQuery,
            icon: Icons.manage_search,
            treatSpacesAsSeparators: true,
            onSubmitted: submit,
          );
          final prompt = _buildPlainSearchField(
            theme,
            controller: promptController,
            focusNode: promptFocus,
            hintText: context.l10n.onlineGallery_aiTagPromptQuery,
            icon: Icons.auto_awesome,
            onSubmitted: submit,
          );
          if (vertical) {
            return Column(children: [query, const SizedBox(height: 8), prompt]);
          }
          return Row(
            children: [
              Expanded(child: query),
              const SizedBox(width: 8),
              Expanded(child: prompt),
            ],
          );
        },
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
          ? IconButton(
              key: const ValueKey('online-gallery-random-toggle'),
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (!state.randomEnabled) _saveScrollOffset();
                      unawaited(
                        _galleryNotifier.setRandomEnabled(!state.randomEnabled),
                      );
                    },
              tooltip: context.l10n.onlineGallery_random,
              icon: const Icon(Icons.shuffle, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: state.randomEnabled
                    ? theme.colorScheme.primaryContainer
                    : null,
                foregroundColor: state.randomEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
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
              ),
            ),
    );
    void refreshAction() {
      final isPopular = state.viewMode == GalleryViewMode.popular;
      final activeSource = isPopular ? state.popularSourceId : state.sourceId;
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
          IconButton.filledTonal(
            key: const ValueKey('online-gallery-refresh'),
            onPressed: state.isLoading ? null : refreshAction,
            tooltip: state.randomEnabled
                ? context.l10n.onlineGallery_randomRedraw
                : context.l10n.onlineGallery_refresh,
            icon: refreshIcon,
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
            ),
          ),
        const SizedBox(width: 4),
        IconButton(
          key: const ValueKey('online-gallery-multi-select'),
          icon: const Icon(Icons.checklist),
          tooltip: context.l10n.common_multiSelect,
          onPressed: _selectionNotifier.enter,
        ),
        const SizedBox(width: 2),
        _buildUserButton(theme, state, authState, gelbooruAuthState),
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

  Widget _buildSecondaryControls(
    ThemeData theme,
    OnlineGalleryState state, {
    bool includePopularOptions = true,
  }) {
    final activeSourceId = switch (state.viewMode) {
      GalleryViewMode.search => state.sourceId,
      GalleryViewMode.popular => state.popularSourceId,
      GalleryViewMode.favorites => state.favoritesSourceId,
    };
    final capabilities = gallerySourceCapabilities[activeSourceId]!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (state.viewMode == GalleryViewMode.search) ...[
          _SourceDropdown(
            selected: state.sourceId,
            sources: const {
              GallerySourceId.danbooru: 'Danbooru',
              GallerySourceId.safebooru: 'Safebooru',
              GallerySourceId.gelbooru: 'Gelbooru',
              GallerySourceId.aiTag: 'AI TAG',
            },
            onChanged: (source) {
              _saveScrollOffset();
              _galleryNotifier.setSource(source);
            },
          ),
          if (capabilities.supportsFuzzySearch)
            _FuzzySearchToggle(
              enabled: state.fuzzySearchEnabled,
              onChanged: _galleryNotifier.setFuzzySearchEnabled,
            ),
        ],
        if (state.viewMode == GalleryViewMode.popular)
          _SourceDropdown(
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
        if (state.viewMode == GalleryViewMode.favorites) ...[
          _SourceDropdown(
            selected: state.favoritesSourceId,
            sources: const {
              GallerySourceId.danbooru: 'Danbooru',
              GallerySourceId.gelbooru: 'Gelbooru',
            },
            onChanged: (source) {
              _saveScrollOffset();
              _galleryNotifier.setFavoritesSource(source);
            },
          ),
          const SizedBox(width: 6),
        ],
        if (capabilities.supportsRatings)
          _RatingDropdown(
            selectedRatings: state.selectedRatings,
            onToggle: _galleryNotifier.toggleRating,
          ),
        if (state.viewMode == GalleryViewMode.search &&
            capabilities.supportsDateRange)
          _buildDateRangeButton(theme, state),
        if (state.viewMode == GalleryViewMode.search &&
            activeSourceId == GallerySourceId.aiTag)
          _buildAiTagTimeRangeDropdown(state),
        Tooltip(
          message: context.l10n.onlineGallery_blacklistTags,
          child: OutlinedButton.icon(
            onPressed: () => showOnlineGalleryBlacklistDialog(context, ref),
            icon: const Icon(Icons.block, size: 17),
            label: Text(context.l10n.onlineGallery_blacklistTags),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        Consumer(
          builder: (context, filterRef, _) {
            final count = filterRef.watch(
              onlineGalleryOutputFilterProvider.select(
                (settings) => settings.tags.length,
              ),
            );
            return Tooltip(
              message: context.l10n.onlineGallery_outputFilterTooltip,
              child: OutlinedButton.icon(
                key: const ValueKey('online-gallery-output-filter'),
                onPressed: () => showOnlineGalleryOutputFilterDialog(context),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                label: Text(
                  '${context.l10n.onlineGallery_outputFilter} · $count',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            );
          },
        ),
        _buildPromptTagCategorySelector(theme),
        if (state.viewMode == GalleryViewMode.popular && includePopularOptions)
          _buildPopularOptions(theme, state),
        if (state.viewMode == GalleryViewMode.favorites &&
            state.favoritesSourceId == GallerySourceId.gelbooru)
          _buildGelbooruFavoritesNotice(theme),
        if (activeSourceId == GallerySourceId.aiTag)
          _buildArtistHuntButton(theme, state),
      ],
    );
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
    GelbooruAuthState gelbooruAuthState,
  ) {
    Widget avatar({
      required IconData icon,
      required Color backgroundColor,
      required Color foregroundColor,
      required Color borderColor,
      IconData? badgeIcon,
      Color? badgeColor,
    }) {
      return Container(
        key: const ValueKey('online-gallery-account-avatar'),
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
            if (badgeIcon != null)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    badgeIcon,
                    size: 9,
                    color: theme.colorScheme.surface,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final sourceId = _activeSource(state);
    if (sourceId == GallerySourceId.safebooru ||
        sourceId == GallerySourceId.aiTag) {
      return Tooltip(
        message: sourceId.label,
        child: Semantics(
          enabled: false,
          child: Opacity(
            opacity: 0.45,
            child: avatar(
              icon: Icons.person_off_outlined,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              borderColor: theme.colorScheme.outlineVariant,
            ),
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
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _showGelbooruCredentialsDialog(context),
            child: avatar(
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
              badgeIcon: invalid
                  ? Icons.priority_high
                  : ready
                  ? Icons.check
                  : Icons.key,
              badgeColor: invalid
                  ? theme.colorScheme.error
                  : ready
                  ? Colors.green.shade600
                  : theme.colorScheme.tertiary,
            ),
          ),
        ),
      );
    }

    if (authState.isLoggedIn) {
      return PopupMenuButton<String>(
        tooltip: authState.credentials?.username,
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
                Text(
                  authState.credentials?.username ?? '',
                  style: theme.textTheme.titleSmall,
                ),
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
        child: avatar(
          icon: Icons.person,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          borderColor: theme.colorScheme.primary.withValues(alpha: 0.45),
          badgeIcon: Icons.check,
          badgeColor: Colors.green.shade600,
        ),
      );
    }

    return Tooltip(
      message: context.l10n.onlineGallery_login,
      child: Semantics(
        button: true,
        label: context.l10n.onlineGallery_login,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _showLoginDialog(context),
          child: avatar(
            icon: Icons.person_outline,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            borderColor: theme.colorScheme.outlineVariant,
            badgeIcon: Icons.login,
            badgeColor: theme.colorScheme.primary,
          ),
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
    return _activeSource(state) == GallerySourceId.danbooru;
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
      case OnlineGalleryErrorCode.requestFailed:
      case OnlineGalleryErrorCode.gelbooruRequestFailed:
      case null:
        return context.l10n.onlineGallery_gelbooruRequestFailed;
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
    final message = isFavorites
        ? context.l10n.onlineGallery_favoritesEmpty
        : artistHuntEmpty
        ? context.l10n.onlineGallery_artistHuntNoExactResults
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
        state.favoritesSourceId == GallerySourceId.gelbooru;
    final canWriteFavorite = post.sourceId == GallerySourceId.danbooru;
    final targetMedia = post.focusedMediaId != null
        ? post.cover
        : detail != null && detail.media.isNotEmpty
        ? detail.media.first
        : null;
    final promptOverride = targetMedia?.prompt ?? detail?.prompt;
    return Consumer(
      builder: (context, cardRef, _) {
        final postKey = onlineGalleryPostKey(post);
        final favoriteState = cardRef.watch(
          onlineGalleryNotifierProvider.select(
            (value) => (
              value.favoritedPostKeys.contains(postKey),
              value.favoriteLoadingPostKeys.contains(postKey),
            ),
          ),
        );
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
        final tagPrompt = promptTagSettings.promptFor(
          post,
          outputFilter: outputFilter,
        );
        final filteredPromptOverride = promptOverride == null
            ? null
            : outputFilter.filterPrompt(promptOverride);
        final filteredCopyText = post.artistChain == null
            ? null
            : outputFilter.filterPrompt(post.artistChain!.formattedText);
        return DanbooruPostCard(
          key: ValueKey(post.stableKey),
          post: post,
          itemWidth: itemWidth,
          layoutAspectRatio: layoutAspectRatio,
          isFavorited: favoriteState.$1,
          isFavoriteLoading: favoriteState.$2,
          showFavoriteAction: canWriteFavorite || favoriteReadOnly,
          favoriteReadOnly: favoriteReadOnly,
          selectionMode: selectionState.$1,
          isSelected: selectionState.$2,
          canSelect: (filteredPromptOverride ?? tagPrompt).isNotEmpty,
          tagPrompt: tagPrompt,
          promptOverride: filteredPromptOverride,
          negativePromptOverride:
              targetMedia?.negativePrompt ?? detail?.negativePrompt,
          copyTextOverride: filteredCopyText,
          copyTooltip: post.artistChain != null
              ? context.l10n.onlineGallery_copyArtistChain
              : null,
          badgeLabel: post.artistChain != null
              ? context.l10n.onlineGallery_artistCount(
                  post.artistChain!.artistCount,
                )
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
              ? () => _handleFavoriteToggle(
                  context,
                  cardRef.read(onlineGalleryNotifierProvider),
                  post,
                )
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
    if (post.sourceId == GallerySourceId.aiTag) {
      showAiTagDetailDialog(context, item: post);
      return;
    }
    showPostDetailDialog(
      context,
      post: post,
      onTagTap: (tag) {
        _searchController.text = tag;
        _galleryNotifier.search(tag);
      },
    );
  }

  /// 处理收藏切换
  Future<void> _handleFavoriteToggle(
    BuildContext context,
    OnlineGalleryState state,
    DanbooruPost post,
  ) async {
    if (post.sourceId != GallerySourceId.danbooru) return;
    final authState = ref.read(danbooruAuthProvider);
    if (!authState.isLoggedIn) {
      _showLoginDialog(context);
      return;
    }

    final wasFavorited = state.favoritedPostKeys.contains(
      onlineGalleryPostKey(post),
    );
    final success = await _galleryNotifier.toggleFavorite(post);

    if (context.mounted && success) {
      AppToast.info(
        context,
        wasFavorited
            ? context.l10n.onlineGallery_unfavorited
            : context.l10n.onlineGallery_favorited,
      );
    }
  }

  /// 批量加入队列
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
    const concurrency = 4;
    for (var start = 0; start < selectedPosts.length; start += concurrency) {
      final batch = selectedPosts.sublist(
        start,
        min(start + concurrency, selectedPosts.length),
      );
      final resolved = await Future.wait(
        batch.map((post) async {
          if (post.sourceId != GallerySourceId.aiTag) {
            final prompt = promptTagSettings.promptFor(
              post,
              outputFilter: outputFilter,
            );
            return prompt.isEmpty
                ? null
                : ReplicationTask.create(
                    prompt: prompt,
                    thumbnailUrl: post.previewUrl,
                    source: ReplicationTaskSource.online,
                  );
          }
          try {
            final detail = await _galleryNotifier.loadDetail(post);
            final focusedIndex = post.focusedMediaId == null
                ? -1
                : detail.media.indexWhere(
                    (media) => media.id == post.focusedMediaId,
                  );
            final media = focusedIndex >= 0
                ? detail.media[focusedIndex]
                : detail.media.first;
            final rawPrompt =
                media.prompt ??
                detail.prompt ??
                promptTagSettings.promptFor(post, outputFilter: outputFilter);
            final prompt = outputFilter.filterPrompt(rawPrompt);
            if (prompt.isEmpty) return null;
            return ReplicationTask.create(
              prompt: prompt,
              negativePrompt:
                  media.negativePrompt ?? detail.negativePrompt ?? '',
              thumbnailUrl: media.previewUrl,
              source: ReplicationTaskSource.online,
              width: media.width > 0 ? media.width : null,
              height: media.height > 0 ? media.height : null,
            );
          } catch (error) {
            debugPrint('Failed to resolve ${post.stableKey} for queue: $error');
            return null;
          }
        }),
      );
      tasks.addAll(resolved.whereType<ReplicationTask>());
    }

    if (!mounted) return;
    if (tasks.isEmpty) {
      AppToast.info(context, context.l10n.onlineGallery_noTagInfo);
      return;
    }

    final addedCount = await ref
        .read(replicationQueueNotifierProvider.notifier)
        .addAll(tasks);

    if (mounted) {
      if (addedCount == 0) {
        AppToast.warning(context, context.l10n.onlineGallery_queueFullMax);
      } else if (addedCount < tasks.length) {
        AppToast.warning(
          context,
          context.l10n.onlineGallery_partiallyAddedTasksToQueue(
            addedCount,
            tasks.length - addedCount,
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
    final authState = ref.read(danbooruAuthProvider);

    if (!authState.isLoggedIn) {
      _showLoginDialog(context);
      return;
    }

    final selectedPosts = galleryState.posts
        .where(
          (post) =>
              post.sourceId == GallerySourceId.danbooru &&
              selectionState.selectedIds.contains(post.stableKey),
        )
        .toList();
    if (selectedPosts.isEmpty) return;

    // 简单的批量收藏实现：逐个调用 toggleFavorite
    // 注意：这可能会触发多次 API 调用，理想情况下应该有批量 API
    // 这里为了简化，我们只对未收藏的进行收藏操作
    int count = 0;
    for (final post in selectedPosts) {
      // 检查widget是否仍然挂载，避免在widget disposed后继续操作
      if (!mounted) return;

      if (!galleryState.favoritedPostKeys.contains(
        onlineGalleryPostKey(post),
      )) {
        await _galleryNotifier.toggleFavorite(post);
        count++;
        await Future.delayed(const Duration(milliseconds: 100));
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

    final (successCount, failCount) = await _downloadPosts(
      selectedPosts,
      result,
    );

    if (mounted) {
      AppToast.success(
        context,
        context.l10n.onlineGallery_downloadSelectedCompleted(
          successCount,
          failCount,
        ),
      );
    }
  }

  /// AI TAG 普通卡按作品下载全部媒体；媒体焦点卡只下载目标图片。
  Future<(int success, int fail)> _downloadPosts(
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
          if (post.sourceId != GallerySourceId.aiTag) {
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
            debugPrint('Failed to resolve AI TAG work ${post.id}: $error');
            return <_GalleryDownloadJob>[];
          }
        }),
      );
      jobs.addAll(resolved.expand((batchJobs) => batchJobs));
    }

    var successCount = 0;
    var failCount = posts
        .where(
          (post) =>
              post.sourceId == GallerySourceId.aiTag &&
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
            final destination = path.join(
              destinationDir,
              '${job.post.sourceId.key}_${job.post.id}_p${job.mediaIndex.toString().padLeft(2, '0')}.${extension.isEmpty ? 'webp' : extension}',
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
    return (successCount, failCount);
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
class _ModeButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;
  final bool showBadge;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.showBadge = false,
  });

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : (_isHovering
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent),
            borderRadius: BorderRadius.horizontal(
              left: widget.isFirst ? const Radius.circular(8) : Radius.zero,
              right: widget.isLast ? const Radius.circular(8) : Radius.zero,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: widget.isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.showBadge)
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
      onSelected: onChanged,
      offset: const Offset(0, 36),
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
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sources[selected] ?? selected.label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
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

  const _RatingDropdown({
    required this.selectedRatings,
    required this.onToggle,
  });

  List<(String, String, Color?)> _getRatings(BuildContext context) => [
    ('all', context.l10n.onlineGallery_all, null),
    ('g', context.l10n.onlineGallery_ratingGeneral, Colors.green),
    ('s', context.l10n.onlineGallery_ratingSensitive, Colors.amber),
    ('q', context.l10n.onlineGallery_ratingQuestionable, Colors.orange),
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
    final isAllSelected =
        selectedRatings.length == kAllRatings.length &&
        selectedRatings.containsAll(kAllRatings);
    final selectedCodesInOrder = [
      'g',
      's',
      'q',
      'e',
    ].where(selectedRatings.contains).toList();
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
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
              buttonText(),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
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
