import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../../data/services/gelbooru_auth_service.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/app_branch_visibility.dart';
import '../../widgets/common/app_toast.dart';
import 'online_gallery_screen_commands.dart';
import 'online_gallery_content.dart';
import 'online_gallery_detail_launcher.dart';
import 'online_gallery_pagination.dart';
import 'online_gallery_screen_controller.dart';
import 'online_gallery_scroll_prefetch_coordinator.dart';
import 'online_gallery_selection_actions.dart';
import 'online_gallery_view_model.dart';
import 'widgets/online_gallery_toolbar/online_gallery_toolbar_bindings.dart';
import 'widgets/online_gallery_toolbar/online_gallery_toolbar_feature.dart';

/// 在线画廊页面
class OnlineGalleryScreen extends ConsumerStatefulWidget {
  const OnlineGalleryScreen({super.key});

  @override
  ConsumerState<OnlineGalleryScreen> createState() =>
      _OnlineGalleryScreenState();
}

class _OnlineGalleryScreenState extends ConsumerState<OnlineGalleryScreen>
    with AutomaticKeepAliveClientMixin {
  late final OnlineGalleryScreenController _controller;
  late final OnlineGalleryScrollPrefetchCoordinator _scrollCoordinator;
  late final OnlineGalleryDetailLauncher _detailLauncher;
  late final OnlineGallerySelectionActions _selectionActions;
  late final OnlineGalleryScreenCommands _commands;
  late final ProviderSubscription<OnlineGalleryState> _gallerySubscription;

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
    _controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (request) => precacheImage(
          request.createImageProvider(OnlineGalleryImageCacheManager.instance),
          context,
        ),
      ),
    );
    _detailLauncher = OnlineGalleryDetailLauncher(
      context: context,
      ref: ref,
      controller: _controller,
    );
    _selectionActions = OnlineGallerySelectionActions(
      context: context,
      ref: ref,
    );
    _scrollCoordinator = OnlineGalleryScrollPrefetchCoordinator(
      context: context,
      ref: ref,
      controller: _controller,
      notifier: _galleryNotifier,
    );
    _commands = OnlineGalleryScreenCommands(
      detailLauncher: _detailLauncher,
      selectionActions: _selectionActions,
    );
    _gallerySubscription = ref.listenManual<OnlineGalleryState>(
      onlineGalleryNotifierProvider,
      (_, next) => _handleGalleryStateChanged(next),
    );
    _controller.scrollController.addListener(_scrollCoordinator.onScroll);
    // 添加页码焦点监听
    _controller.pageFocusNode.addListener(
      _controller.cancelPageEditingWhenUnfocused,
    );

    // 只在首次进入（无数据）时加载，切换Tab回来时不再重新加载
    // 用户需要刷新时可点击刷新按钮
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(onlineGalleryNotifierProvider);
      _controller.synchronizeQueries(state);
      final initialCache = state.randomEnabled
          ? state.randomSession.cache
          : state.currentCache;
      _controller.restoreInitialPositionPending =
          initialCache.scrollOffset > 0 || initialCache.anchorStableKey != null;
      // 首次加载
      if (state.posts.isEmpty && !state.isLoading) {
        _galleryNotifier.loadPosts();
      }
      // 记录当前查询，用于切换来源或筛选后恢复独立滚动位置。
      _controller.lastViewMode = state.viewMode;
      _controller.lastFavoritesSource = state.favoritesSourceId;
      _controller.lastCacheKey = state.currentCacheKey;
      _controller.lastRandomEnabled = state.randomEnabled;
      _controller.lastRandomDrawRevision = state.randomSession.drawRevision;
      _scrollCoordinator.scheduleAutoLoadIfUnderfilled(state);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = AppBranchVisibility.of(context);
    if (_controller.branchVisible == visible) return;
    _controller.branchVisible = visible;
    if (!visible) {
      _controller.hoverController.dismiss();
      _controller.scheduledAutoLoadCacheKey = null;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollCoordinator.scheduleAutoLoadIfUnderfilled(
          ref.read(onlineGalleryNotifierProvider),
        );
      });
    }
  }

  void _handleGalleryStateChanged(OnlineGalleryState state) {
    final browsingContextChanged =
        (_controller.lastViewMode != null &&
            _controller.lastViewMode != state.viewMode) ||
        (_controller.lastCacheKey != null &&
            _controller.lastCacheKey != state.currentCacheKey) ||
        (state.viewMode == GalleryViewMode.favorites &&
            _controller.lastFavoritesSource != null &&
            _controller.lastFavoritesSource != state.favoritesSourceId) ||
        (_controller.lastRandomEnabled != null &&
            _controller.lastRandomEnabled != state.randomEnabled);
    final randomDrawChanged =
        state.randomEnabled &&
        _controller.lastRandomDrawRevision != null &&
        _controller.lastRandomDrawRevision != state.randomSession.drawRevision;
    final initialPositionReady =
        _controller.restoreInitialPositionPending &&
        state.posts.isNotEmpty &&
        !state.isLoading;
    if (browsingContextChanged || randomDrawChanged || initialPositionReady) {
      _controller.hoverController.dismiss();
      _controller.visibleItems.clear();
      _controller.prefetchCoordinator.rotateGeneration();
      if (browsingContextChanged || initialPositionReady) {
        _scrollCoordinator.restoreScrollOffset(
          state.randomEnabled ? state.randomSession.cache : state.currentCache,
        );
        _controller.restoreInitialPositionPending = false;
      }
    }
    _controller.lastViewMode = state.viewMode;
    _controller.lastFavoritesSource = state.favoritesSourceId;
    _controller.lastCacheKey = state.currentCacheKey;
    _controller.lastRandomEnabled = state.randomEnabled;
    _controller.lastRandomDrawRevision = state.randomSession.drawRevision;
    _scrollCoordinator.scheduleAutoLoadIfUnderfilled(state);
  }

  @override
  void dispose() {
    _scrollCoordinator.saveScrollOffset();
    _gallerySubscription.close();
    _controller.scrollController.removeListener(_scrollCoordinator.onScroll);
    _controller.pageFocusNode.removeListener(
      _controller.cancelPageEditingWhenUnfocused,
    );
    _controller.dispose();
    super.dispose();
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
    final selectionState = ref.watch(onlineGallerySelectionNotifierProvider);
    final viewModel = OnlineGalleryViewModel.from(
      gallery: state,
      selection: selectionState,
    );

    ref.listen<OnlineGalleryNotice?>(
      onlineGalleryNotifierProvider.select((value) => value.notice),
      (previous, next) {
        if (next == null || next == previous) return;
        if (next == OnlineGalleryNotice.gelbooruCredentialsInvalid) {
          AppToast.warning(
            context,
            context.l10n.onlineGallery_gelbooruCredentialsInvalid,
          );
        } else if (next == OnlineGalleryNotice.tagDetailsIncomplete) {
          AppToast.warning(
            context,
            context.l10n.onlineGallery_tagDetailsIncomplete,
          );
        } else if (next == OnlineGalleryNotice.randomDrawNoMatch) {
          AppToast.info(context, context.l10n.onlineGallery_randomDrawNoMatch);
        }
        _galleryNotifier.clearNotice();
      },
    );
    return PopScope<void>(
      canPop: !viewModel.isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && viewModel.isSelectionMode) {
          _selectionNotifier.exit();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            OnlineGalleryToolbarFeature(
              controller: _controller,
              data: OnlineGalleryToolbarViewData(
                gallery: state,
                danbooruAuth: authState,
                gelbooruAuth: gelbooruAuthState,
                selection: selectionState,
              ),
              commands: OnlineGalleryToolbarCommands(
                gallery: _galleryNotifier,
                selection: _selectionNotifier,
                actions: _commands,
                saveScrollOffset: _scrollCoordinator.saveScrollOffset,
              ),
            ),
            // 图片网格
            Expanded(
              child: OnlineGalleryContent(
                state: state,
                controller: _controller,
                scrollCoordinator: _scrollCoordinator,
                commands: _commands,
              ),
            ),
            // 底部分页条
            OnlineGalleryPagination(
              state: state,
              controller: _controller,
              notifier: _galleryNotifier,
            ),
          ],
        ),
      ),
    );
  }
}
