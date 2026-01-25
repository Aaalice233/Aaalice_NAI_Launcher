import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import '../../../core/cache/danbooru_image_cache_manager.dart';
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
  final ScrollController _scrollController = ScrollController();

  /// 页码输入控制器
  final TextEditingController _pageController = TextEditingController();
  final FocusNode _pageFocusNode = FocusNode();
  bool _isEditingPage = false;

  /// 当前视图模式（用于检测模式切换）
  GalleryViewMode? _lastViewMode;

  @override
  bool get wantKeepAlive => true;

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
        ref.read(onlineGalleryNotifierProvider.notifier).loadPosts();
      }
      // 记录当前模式
      _lastViewMode = state.viewMode;
    });
  }

  /// 滚动监听 - 无限滚动加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(onlineGalleryNotifierProvider.notifier).loadMore();
    }
  }

  /// 保存当前滚动位置
  void _saveScrollOffset() {
    if (_scrollController.hasClients) {
      ref
          .read(onlineGalleryNotifierProvider.notifier)
          .saveScrollOffset(_scrollController.offset);
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
    _scrollController.removeListener(_onScroll);
    _pageFocusNode.removeListener(_onPageFocusChange);
    _searchController.dispose();
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
    if (input.isEmpty) {
      setState(() => _isEditingPage = false);
      return;
    }

    final parsed = int.tryParse(input);
    if (parsed == null || parsed < 1) {
      setState(() => _isEditingPage = false);
      return;
    }

    setState(() => _isEditingPage = false);

    final state = ref.read(onlineGalleryNotifierProvider);
    if (parsed != state.page) {
      ref.read(onlineGalleryNotifierProvider.notifier).goToPage(parsed);
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
                ? () => ref
                    .read(onlineGalleryNotifierProvider.notifier)
                    .goToPage(state.page - 1)
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
                ? () => ref
                    .read(onlineGalleryNotifierProvider.notifier)
                    .goToPage(state.page + 1)
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
      child: TextField(
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
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => ref
                  .read(onlineGallerySelectionNotifierProvider.notifier)
                  .exit(),
              tooltip: '退出多选',
            ),
            const SizedBox(width: 8),
            Text(
              '已选择 ${selectionState.selectedIds.length} 项',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.playlist_add),
              onPressed: selectionState.selectedIds.isNotEmpty
                  ? _addSelectedToQueue
                  : null,
              tooltip: '加入队列',
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: selectionState.selectedIds.isNotEmpty
                  ? _favoriteSelected
                  : null,
              tooltip: '批量收藏',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: selectionState.selectedIds.isNotEmpty
                  ? _downloadSelected
                  : null,
              tooltip: '批量下载',
            ),
          ],
        ),
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
              _saveScrollOffset(); // 保存当前滚动位置
              ref.read(onlineGalleryNotifierProvider.notifier).switchToSearch();
            },
            isFirst: true,
          ),
          _ModeButton(
            icon: Icons.local_fire_department,
            label: context.l10n.onlineGallery_popular,
            isSelected: state.viewMode == GalleryViewMode.popular,
            onTap: () {
              _saveScrollOffset(); // 保存当前滚动位置
              ref
                  .read(onlineGalleryNotifierProvider.notifier)
                  .switchToPopular();
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
              _saveScrollOffset(); // 保存当前滚动位置
              ref
                  .read(onlineGalleryNotifierProvider.notifier)
                  .switchToFavorites();
            },
            isLast: true,
            showBadge: !authState.isLoggedIn,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      height: 36,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _searchController,
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
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(onlineGalleryNotifierProvider.notifier).search('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onSubmitted: (value) {
          ref.read(onlineGalleryNotifierProvider.notifier).search(value);
        },
        onChanged: (value) => setState(() {}),
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
            onChanged: (source) {
              ref
                  .read(onlineGalleryNotifierProvider.notifier)
                  .setSource(source);
            },
          ),
          const SizedBox(width: 8),
        ],
        // 评级筛选
        _RatingDropdown(
          selected: state.rating,
          onChanged: (rating) {
            ref.read(onlineGalleryNotifierProvider.notifier).setRating(rating);
          },
        ),
        // 日期范围筛选（仅搜索模式）
        if (state.viewMode == GalleryViewMode.search) ...[
          const SizedBox(width: 8),
          _buildDateRangeButton(theme, state),
        ],
        const SizedBox(width: 8),
        // 刷新按钮 (FilledButton.tonal)
        FilledButton.tonalIcon(
          onPressed: state.isLoading
              ? null
              : () =>
                  ref.read(onlineGalleryNotifierProvider.notifier).refresh(),
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
          onPressed: () {
            ref.read(onlineGallerySelectionNotifierProvider.notifier).enter();
          },
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
            ? _formatDateRange(state.dateRangeStart, state.dateRangeEnd)
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

  /// 格式化日期范围显示
  String _formatDateRange(DateTime? start, DateTime? end) {
    final format = DateFormat('MM-dd');
    if (start != null && end != null) {
      return '${format.format(start)}~${format.format(end)}';
    } else if (start != null) {
      return '${format.format(start)}~';
    } else if (end != null) {
      return '~${format.format(end)}';
    }
    return '';
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
      ref.read(onlineGalleryNotifierProvider.notifier).setDateRange(
            picked.start,
            picked.end,
          );
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
            ref
                .read(onlineGalleryNotifierProvider.notifier)
                .setPopularScale(selected.first);
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
                ? DateFormat('yyyy-MM-dd').format(state.popularDate!)
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
            onPressed: () => ref
                .read(onlineGalleryNotifierProvider.notifier)
                .setPopularDate(null),
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
      ref.read(onlineGalleryNotifierProvider.notifier).setPopularDate(picked);
    }
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DanbooruLoginDialog(),
    );
  }

  Widget _buildContent(ThemeData theme, OnlineGalleryState state) {
    if (state.isLoading && state.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.posts.isEmpty) {
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
              onPressed: () =>
                  ref.read(onlineGalleryNotifierProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.common_retry),
            ),
          ],
        ),
      );
    }

    if (state.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.viewMode == GalleryViewMode.favorites
                  ? Icons.favorite_border
                  : Icons.image_not_supported_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              state.viewMode == GalleryViewMode.favorites
                  ? context.l10n.onlineGallery_favoritesEmpty
                  : context.l10n.onlineGallery_noResults,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width - 60;
    final columnCount = (screenWidth / 200).floor().clamp(2, 8);
    final itemWidth = (screenWidth - 24 - (columnCount - 1) * 6) / columnCount;

    return MasonryGridView.count(
      // PageStorageKey 让 Flutter 自动保存/恢复滚动位置
      key: PageStorageKey<String>('online_gallery_${state.viewMode.name}'),
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      crossAxisCount: columnCount,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      itemCount:
          state.posts.length + (state.hasMore || state.error != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.posts.length) {
          // 显示错误重试按钮或加载指示器
          if (state.error != null) {
            return Center(
              child: TextButton(
                onPressed: () {
                  ref.read(onlineGalleryNotifierProvider.notifier).loadMore();
                },
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

        final post = state.posts[index];
        final isFavorited = state.favoritedPostIds.contains(post.id);
        final selectionState =
            ref.watch(onlineGallerySelectionNotifierProvider);
        final isSelected =
            selectionState.selectedIds.contains(post.id.toString());
        final canSelect = post.tags.isNotEmpty;

        // 智能预加载：提前缓存后续 10 张图片
        _prefetchImages(state, index);

        return DanbooruPostCard(
          post: post,
          itemWidth: itemWidth,
          isFavorited: isFavorited,
          selectionMode: selectionState.isActive,
          isSelected: isSelected,
          canSelect: canSelect,
          onTap: () => _showPostDetail(context, post),
          onSelectionToggle: () {
            ref
                .read(onlineGallerySelectionNotifierProvider.notifier)
                .toggle(post.id.toString());
          },
          onLongPress: () {
            if (!selectionState.isActive) {
              ref
                  .read(onlineGallerySelectionNotifierProvider.notifier)
                  .enterAndSelect(post.id.toString());
            }
          },
          onTagTap: (tag) {
            _searchController.text = tag;
            ref.read(onlineGalleryNotifierProvider.notifier).search(tag);
          },
          onFavoriteToggle: () {
            final authState = ref.read(danbooruAuthProvider);
            if (!authState.isLoggedIn) {
              _showLoginDialog(context);
              return;
            }
            ref
                .read(onlineGalleryNotifierProvider.notifier)
                .toggleFavorite(post.id);
          },
        );
      },
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
        ref.read(onlineGalleryNotifierProvider.notifier).search(tag);
      },
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选中的图片没有标签信息')),
      );
      return;
    }

    final addedCount =
        await ref.read(replicationQueueNotifierProvider.notifier).addAll(tasks);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 $addedCount 个任务到队列')),
      );
      ref.read(onlineGallerySelectionNotifierProvider.notifier).exit();
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
        await ref
            .read(onlineGalleryNotifierProvider.notifier)
            .toggleFavorite(id);
        count++;
        // 简单的限流
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已收藏 $count 张图片')),
      );
      ref.read(onlineGallerySelectionNotifierProvider.notifier).exit();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始下载 ${selectedPosts.length} 张图片...')),
      );
      ref.read(onlineGallerySelectionNotifierProvider.notifier).exit();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载完成: 成功 $successCount, 失败 $failCount')),
      );
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
        ('g', 'G', Colors.green),
        ('s', 'S', Colors.amber),
        ('q', 'Q', Colors.orange),
        ('e', 'E', Colors.red),
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
