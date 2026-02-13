import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:path/path.dart' as path;

import '../../../core/cache/danbooru_image_cache_manager.dart';
import '../../../core/services/date_formatting_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/datasources/remote/danbooru_api_service.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/services/danbooru_auth_service.dart';

import '../../providers/online_gallery_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/danbooru_login_dialog.dart';
import '../../widgets/danbooru_post_card.dart';
import '../../widgets/online_gallery/post_detail_dialog.dart';

import '../../widgets/common/app_toast.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/common/themed_input.dart';
import '../../widgets/autocomplete/autocomplete_wrapper.dart';
import '../../widgets/autocomplete/strategies/danbooru_strategy.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _pageController = TextEditingController();
  final FocusNode _pageFocusNode = FocusNode();
  final _dateFormattingService = DateFormattingService();

  Timer? _searchDebounceTimer;
  bool _isEditingPage = false;
  GalleryViewMode? _lastViewMode;

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
      // 首次加载
      if (state.posts.isEmpty && !state.isLoading) {
        _galleryNotifier.loadPosts();
      }
      // 记录当前模式
      _lastViewMode = state.viewMode;
    });
  }

  /// 滚动监听 - 无限滚动加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _galleryNotifier.loadMore();
    }
  }

  /// 保存当前滚动位置
  void _saveScrollOffset() {
    if (_scrollController.hasClients) {
      _galleryNotifier.saveScrollOffset(_scrollController.offset);
    }
  }

  /// 恢复滚动位置
  void _restoreScrollOffset(double offset) {
    if (_scrollController.hasClients && offset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(offset);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _pageFocusNode.removeListener(_onPageFocusChange);
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    final state = ref.watch(onlineGalleryNotifierProvider);
    final authState = ref.watch(danbooruAuthProvider);

    // 检测模式切换，保存旧模式滚动位置，恢复新模式滚动位置
    if (_lastViewMode != null && _lastViewMode != state.viewMode) {
      // 模式已切换，恢复目标模式的滚动位置
      _restoreScrollOffset(state.scrollOffset);
    }
    _lastViewMode = state.viewMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 顶部工具栏
          _buildToolbar(theme, state, authState),
          // 图片网格
          Expanded(
            child: _buildContent(theme, state),
          ),
          // 底部分页条
          _buildPaginationBar(theme, state),
        ],
      ),
    );
  }

  /// 构建底部分页条
  Widget _buildPaginationBar(ThemeData theme, OnlineGalleryState state) {
    if (state.posts.isEmpty && !state.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
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
            context.l10n
                .onlineGallery_imageCount(state.posts.length.toString()),
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
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
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
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
  ) {
    final selectionState = ref.watch(onlineGallerySelectionNotifierProvider);

    if (selectionState.isActive) {
      final allPostIds = state.posts.map((p) => p.id.toString()).toList();
      final isAllSelected = allPostIds.isNotEmpty &&
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
            label: '加入队列',
            onPressed: _addSelectedToQueue,
            color: theme.colorScheme.primary,
          ),
          BulkActionItem(
            icon: Icons.favorite_border,
            label: '批量收藏',
            onPressed: _favoriteSelected,
            color: theme.colorScheme.secondary,
          ),
          BulkActionItem(
            icon: Icons.download,
            label: '批量下载',
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
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // 第一行：模式切换 + 搜索框 + 用户
          Row(
            children: [
              // 模式切换（紧凑设计）
              _buildModeSelector(theme, state, authState),
              const SizedBox(width: 16),
              // 搜索框
              if (state.viewMode == GalleryViewMode.search)
                Expanded(child: _buildSearchField(theme))
              else
                const Spacer(),
              const SizedBox(width: 12),
              // 筛选和操作
              _buildFilterAndActions(theme, state, authState),
            ],
          ),
          // 第二行：排行榜选项（仅排行榜模式）
          if (state.viewMode == GalleryViewMode.popular) ...[
            const SizedBox(height: 8),
            _buildPopularOptions(theme, state),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
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
              if (!authState.isLoggedIn) {
                _showLoginDialog(context);
                return;
              }
              _saveScrollOffset();
              _galleryNotifier.switchToFavorites();
            },
            isLast: true,
            showBadge: !authState.isLoggedIn,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return AutocompleteWrapper(
      controller: _searchController,
      focusNode: _searchFocusNode,
      strategy: DanbooruStrategy.create(
        ref,
        replaceAll: false,
        separator: ',',
        appendSeparator: false,
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
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: context.l10n.onlineGallery_searchTags,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
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

  Widget _buildFilterAndActions(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 数据源切换（仅搜索模式）
        if (state.viewMode == GalleryViewMode.search) ...[
          _SourceDropdown(
            selected: state.source,
            onChanged: _galleryNotifier.setSource,
          ),
          const SizedBox(width: 8),
        ],
        // 评级筛选
        _RatingDropdown(
          selected: state.rating,
          onChanged: _galleryNotifier.setRating,
        ),
        // 日期范围筛选（仅搜索模式）
        if (state.viewMode == GalleryViewMode.search) ...[
          const SizedBox(width: 8),
          _buildDateRangeButton(theme, state),
        ],
        const SizedBox(width: 8),
        // 刷新按钮 (FilledButton.tonal)
        FilledButton.tonalIcon(
          onPressed: state.isLoading ? null : _galleryNotifier.refresh,
          icon: state.isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(context.l10n.onlineGallery_refresh),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        // 多选模式切换
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '多选模式',
          onPressed: _selectionNotifier.enter,
        ),
        const SizedBox(width: 8),
        // 用户
        _buildUserButton(theme, authState),
      ],
    );
  }

  /// 构建日期范围筛选按钮
  Widget _buildDateRangeButton(ThemeData theme, OnlineGalleryState state) {
    final hasDateRange =
        state.dateRangeStart != null || state.dateRangeEnd != null;

    return OutlinedButton.icon(
      onPressed: () => _selectDateRange(context, state),
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
        side:
            hasDateRange ? BorderSide(color: theme.colorScheme.primary) : null,
      ),
    );
  }

  /// 选择日期范围
  Future<void> _selectDateRange(
    BuildContext context,
    OnlineGalleryState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2005),
      lastDate: now,
      initialDateRange:
          state.dateRangeStart != null && state.dateRangeEnd != null
              ? DateTimeRange(
                  start: state.dateRangeStart!,
                  end: state.dateRangeEnd!,
                )
              : DateTimeRange(
                  start: now.subtract(const Duration(days: 30)),
                  end: now,
                ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _galleryNotifier.setDateRange(picked.start, picked.end);
    }
  }

  Widget _buildUserButton(ThemeData theme, DanbooruAuthState authState) {
    if (authState.isLoggedIn) {
      return PopupMenuButton<String>(
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
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            size: 18,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: () => _showLoginDialog(context),
      icon: const Icon(Icons.login, size: 18),
      label: Text(context.l10n.onlineGallery_login),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildPopularOptions(ThemeData theme, OnlineGalleryState state) {
    return Row(
      children: [
        // 时间范围
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
        const SizedBox(width: 12),
        // 日期
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
        if (state.popularDate != null) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _galleryNotifier.setPopularDate(null),
            icon: const Icon(Icons.close, size: 16),
            tooltip: context.l10n.onlineGallery_clear,
            style: IconButton.styleFrom(padding: const EdgeInsets.all(4)),
          ),
        ],
        const Spacer(),
        // 计数
        Text(
          context.l10n.onlineGallery_imageCount(state.posts.length.toString()),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DanbooruLoginDialog(),
    );
  }

  Widget _buildContent(ThemeData theme, OnlineGalleryState state) {
    // 加载中状态
    if (state.isLoading && state.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 错误状态
    if (state.error != null && state.posts.isEmpty) {
      return _buildErrorState(theme, state);
    }

    // 空状态
    if (state.posts.isEmpty) {
      return _buildEmptyState(theme, state);
    }

    return _buildImageGrid(theme, state);
  }

  /// 构建错误状态
  Widget _buildErrorState(ThemeData theme, OnlineGalleryState state) {
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
            state.error!,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _galleryNotifier.refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(context.l10n.common_retry),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme, OnlineGalleryState state) {
    final isFavorites = state.viewMode == GalleryViewMode.favorites;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFavorites ? Icons.favorite_border : Icons.image_not_supported_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            isFavorites
                ? context.l10n.onlineGallery_favoritesEmpty
                : context.l10n.onlineGallery_noResults,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  /// 构建图片网格
  Widget _buildImageGrid(ThemeData theme, OnlineGalleryState state) {
    final screenWidth = MediaQuery.of(context).size.width - 60;
    final columnCount = (screenWidth / 200).floor().clamp(2, 8);
    final itemWidth = (screenWidth - 24 - (columnCount - 1) * 6) / columnCount;

    return MasonryGridView.count(
      key: PageStorageKey<String>('online_gallery_${state.viewMode.name}'),
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      crossAxisCount: columnCount,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      itemCount: state.posts.length + (state.hasMore || state.error != null ? 1 : 0),
      itemBuilder: (context, index) => _buildGridItem(theme, state, index, itemWidth),
    );
  }

  /// 构建网格项
  Widget _buildGridItem(ThemeData theme, OnlineGalleryState state, int index, double itemWidth) {
    // 加载更多指示器/错误重试
    if (index >= state.posts.length) {
      return _buildLoadMoreIndicator(theme, state);
    }

    final post = state.posts[index];
    final selectionState = ref.watch(onlineGallerySelectionNotifierProvider);

    _prefetchImages(state, index);

    return DanbooruPostCard(
      post: post,
      itemWidth: itemWidth,
      isFavorited: state.favoritedPostIds.contains(post.id),
      isFavoriteLoading: state.favoriteLoadingPostIds.contains(post.id),
      selectionMode: selectionState.isActive,
      isSelected: selectionState.selectedIds.contains(post.id.toString()),
      canSelect: post.tags.isNotEmpty,
      onTap: () => _showPostDetail(context, post),
      onSelectionToggle: () => _selectionNotifier.toggle(post.id.toString()),
      onLongPress: () {
        if (!selectionState.isActive) {
          _selectionNotifier.enterAndSelect(post.id.toString());
        }
      },
      onTagTap: (tag) {
        _searchController.text = tag;
        _galleryNotifier.search(tag);
      },
      onFavoriteToggle: () => _handleFavoriteToggle(context, state, post),
    );
  }

  /// 构建加载更多指示器
  Widget _buildLoadMoreIndicator(ThemeData theme, OnlineGalleryState state) {
    if (state.error != null) {
      return Center(
        child: TextButton(
          onPressed: _galleryNotifier.loadMore,
          child: Text(
            '加载失败，点击重试',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// 智能预加载图片
  void _prefetchImages(OnlineGalleryState state, int currentIndex) {
    const prefetchCount = 10;
    for (var i = 1; i <= prefetchCount; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < state.posts.length) {
        final nextPost = state.posts[nextIndex];
        if (nextPost.previewUrl.isNotEmpty) {
          precacheImage(
            CachedNetworkImageProvider(nextPost.previewUrl),
            context,
          );
        }
      }
    }
  }

  void _showPostDetail(BuildContext context, DanbooruPost post) {
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
    final authState = ref.read(danbooruAuthProvider);
    if (!authState.isLoggedIn) {
      _showLoginDialog(context);
      return;
    }

    final wasFavorited = state.favoritedPostIds.contains(post.id);
    final success = await _galleryNotifier.toggleFavorite(post.id);

    if (context.mounted && success) {
      AppToast.info(context, wasFavorited ? '已取消收藏' : '已收藏');
    }
  }

  /// 批量加入队列
  Future<void> _addSelectedToQueue() async {
    final selectionState = ref.read(onlineGallerySelectionNotifierProvider);
    final galleryState = ref.read(onlineGalleryNotifierProvider);

    final selectedPosts = galleryState.posts
        .where((p) => selectionState.selectedIds.contains(p.id.toString()))
        .toList();

    if (selectedPosts.isEmpty) return;

    final tasks = selectedPosts
        .where((p) => p.tags.isNotEmpty)
        .map(
          (p) => ReplicationTask.create(
            prompt: p.tags.join(', '),
            thumbnailUrl: p.previewUrl,
            source: ReplicationTaskSource.online,
          ),
        )
        .toList();

    if (tasks.isEmpty) {
      AppToast.info(context, '选中的图片没有标签信息');
      return;
    }

    final addedCount =
        await ref.read(replicationQueueNotifierProvider.notifier).addAll(tasks);

    if (mounted) {
      AppToast.success(context, '已添加 $addedCount 个任务到队列');
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

    final selectedIds = selectionState.selectedIds.toList();
    if (selectedIds.isEmpty) return;

    // 简单的批量收藏实现：逐个调用 toggleFavorite
    // 注意：这可能会触发多次 API 调用，理想情况下应该有批量 API
    // 这里为了简化，我们只对未收藏的进行收藏操作
    int count = 0;
    for (final idStr in selectedIds) {
      final id = int.tryParse(idStr);
      if (id != null && !galleryState.favoritedPostIds.contains(id)) {
        await _galleryNotifier.toggleFavorite(id);
        count++;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (mounted) {
      AppToast.info(context, '已收藏 $count 张图片');
      _selectionNotifier.exit();
    }
  }

  /// 批量下载
  Future<void> _downloadSelected() async {
    final selectionState = ref.read(onlineGallerySelectionNotifierProvider);
    final galleryState = ref.read(onlineGalleryNotifierProvider);

    final selectedPosts = galleryState.posts
        .where((p) => selectionState.selectedIds.contains(p.id.toString()))
        .toList();

    if (selectedPosts.isEmpty) return;

    // 选择保存目录
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    if (mounted) {
      AppToast.info(context, '开始下载 ${selectedPosts.length} 张图片...');
      _selectionNotifier.exit();
    }

    int successCount = 0;
    int failCount = 0;

    // 并行下载
    await Future.wait(
      selectedPosts.map(
        (post) async {
          try {
            final url = post.largeFileUrl ?? post.sampleUrl ?? post.previewUrl;
            if (url.isEmpty) return;

            final file =
                await DanbooruImageCacheManager.instance.getSingleFile(url);
            final fileName = path.basename(Uri.parse(url).path);
            final destination = path.join(result, fileName);

            await file.copy(destination);
            successCount++;
          } catch (e) {
            failCount++;
            debugPrint('Download failed for post ${post.id}: $e');
          }
        },
      ),
    );

    if (mounted) {
      AppToast.success(context, '下载完成: 成功 $successCount, 失败 $failCount');
    }
  }
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
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.normal,
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
  final String selected;
  final Function(String) onChanged;

  const _SourceDropdown({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = {
      'danbooru': 'Danbooru',
      'safebooru': 'Safebooru',
      'gelbooru': 'Gelbooru',
    };

    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => sources.entries.map((e) {
        final isSelected = selected == e.key;
        return PopupMenuItem<String>(
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
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sources[selected] ?? selected,
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

/// 评级下拉
class _RatingDropdown extends StatelessWidget {
  final String selected;
  final Function(String) onChanged;

  const _RatingDropdown({required this.selected, required this.onChanged});

  List<(String, String, Color?)> _getRatings(BuildContext context) => [
        ('all', context.l10n.onlineGallery_all, null),
        ('g', context.l10n.onlineGallery_ratingGeneral, Colors.green),
        ('s', context.l10n.onlineGallery_ratingSensitive, Colors.amber),
        ('q', context.l10n.onlineGallery_ratingQuestionable, Colors.orange),
        ('e', context.l10n.onlineGallery_ratingExplicit, Colors.red),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratings = _getRatings(context);
    final current =
        ratings.firstWhere((r) => r.$1 == selected, orElse: () => ratings[0]);

    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (menuContext) => ratings.map((r) {
        final isSelected = selected == r.$1;
        return PopupMenuItem<String>(
          value: r.$1,
          child: Row(
            children: [
              if (r.$3 != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: r.$3, shape: BoxShape.circle),
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
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current.$3 != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: current.$3, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              current.$2,
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
