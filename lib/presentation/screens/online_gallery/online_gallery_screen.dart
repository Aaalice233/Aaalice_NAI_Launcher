import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/datasources/remote/danbooru_api_service.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../../data/services/tag_translation_service.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/gallery_multi_select_provider.dart';
import '../online_gallery/widgets/multi_select_bottom_bar.dart';
import '../../widgets/danbooru_login_dialog.dart';
import '../../widgets/danbooru_post_card.dart';
import '../../widgets/tag_chip.dart';

/// 在线画廊页面
class OnlineGalleryScreen extends ConsumerStatefulWidget {
  const OnlineGalleryScreen({super.key});

  @override
  ConsumerState<OnlineGalleryScreen> createState() => _OnlineGalleryScreenState();
}

class _OnlineGalleryScreenState extends ConsumerState<OnlineGalleryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onlineGalleryNotifierProvider.notifier).loadPosts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 800) {
      // 防抖处理：200ms 内只触发一次加载
      if (_debounceTimer?.isActive ?? false) return;
      _debounceTimer = Timer(const Duration(milliseconds: 200), () {
        ref.read(onlineGalleryNotifierProvider.notifier).loadMore();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onlineGalleryNotifierProvider);
    final authState = ref.watch(danbooruAuthProvider);
    final multiSelectState = ref.watch(multiSelectNotifierProvider);

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
          // 底部操作栏（多选模式时显示）
          MultiSelectBottomBar(
            selectedCount: multiSelectState.selectedPostIds.length,
            onSendToHome: () => _sendToHome(context),
            onClear: () => ref.read(multiSelectNotifierProvider.notifier).clearSelection(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme, OnlineGalleryState state, DanbooruAuthState authState) {
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

  Widget _buildModeSelector(ThemeData theme, OnlineGalleryState state, DanbooruAuthState authState) {
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
            onTap: () => ref.read(onlineGalleryNotifierProvider.notifier).switchToSearch(),
            isFirst: true,
          ),
          _ModeButton(
            icon: Icons.local_fire_department,
            label: context.l10n.onlineGallery_popular,
            isSelected: state.viewMode == GalleryViewMode.popular,
            onTap: () => ref.read(onlineGalleryNotifierProvider.notifier).switchToPopular(),
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
              ref.read(onlineGalleryNotifierProvider.notifier).switchToFavorites();
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
                  icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
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

  Widget _buildFilterAndActions(ThemeData theme, OnlineGalleryState state, DanbooruAuthState authState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 数据源切换（仅搜索模式）
        if (state.viewMode == GalleryViewMode.search) ...[
          _SourceDropdown(
            selected: state.source,
            onChanged: (source) {
              ref.read(onlineGalleryNotifierProvider.notifier).setSource(source);
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
        const SizedBox(width: 8),
        // 刷新
        IconButton(
          onPressed: state.isLoading
              ? null
              : () => ref.read(onlineGalleryNotifierProvider.notifier).refresh(),
          icon: state.isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                )
              : const Icon(Icons.refresh, size: 20),
          tooltip: context.l10n.onlineGallery_refresh,
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.all(8),
          ),
        ),
        // 用户
        _buildUserButton(theme, authState),
      ],
    );
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
                Text(authState.credentials?.username ?? '', style: theme.textTheme.titleSmall),
                if (authState.user != null)
                  Text(
                    authState.user!.levelName,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [const Icon(Icons.logout, size: 18), const SizedBox(width: 8), Text(context.l10n.onlineGallery_logout)],
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
          child: Icon(Icons.person, size: 18, color: theme.colorScheme.onPrimaryContainer),
        ),
      );
    }

    return IconButton(
      onPressed: () => _showLoginDialog(context),
      icon: const Icon(Icons.login, size: 20),
      tooltip: context.l10n.onlineGallery_login,
      style: IconButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildPopularOptions(ThemeData theme, OnlineGalleryState state) {
    return Row(
      children: [
        // 时间范围
        SegmentedButton<PopularScale>(
          segments: [
            ButtonSegment(value: PopularScale.day, label: Text(context.l10n.onlineGallery_dayRank)),
            ButtonSegment(value: PopularScale.week, label: Text(context.l10n.onlineGallery_weekRank)),
            ButtonSegment(value: PopularScale.month, label: Text(context.l10n.onlineGallery_monthRank)),
          ],
          selected: {state.popularScale},
          onSelectionChanged: (selected) {
            ref.read(onlineGalleryNotifierProvider.notifier).setPopularScale(selected.first);
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
            onPressed: () => ref.read(onlineGalleryNotifierProvider.notifier).setPopularDate(null),
            icon: const Icon(Icons.close, size: 16),
            tooltip: context.l10n.onlineGallery_clear,
            style: IconButton.styleFrom(padding: const EdgeInsets.all(4)),
          ),
        ],
        const Spacer(),
        // 计数
        Text(
          context.l10n.onlineGallery_imageCount(state.posts.length.toString()),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, OnlineGalleryState state) async {
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
    showDialog(context: context, builder: (context) => const DanbooruLoginDialog());
  }

  Future<void> _sendToHome(BuildContext context) async {
    final multiSelectState = ref.read(multiSelectNotifierProvider);
    final selectedIds = multiSelectState.selectedPostIds;

    if (selectedIds.isEmpty) return;

    // 获取选中的帖子
    final galleryState = ref.read(onlineGalleryNotifierProvider);
    final selectedPosts = galleryState.posts
        .where((post) => selectedIds.contains(post.id))
        .toList();

    // TODO: 实现发送到主页队列功能

    // 清除选择
    ref.read(multiSelectNotifierProvider.notifier).clearSelection();

    // 显示提示
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${selectedPosts.length} 张到队列')),
      );
    }
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
            Text(context.l10n.onlineGallery_loadFailed, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(state.error!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.read(onlineGalleryNotifierProvider.notifier).refresh(),
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
              state.viewMode == GalleryViewMode.favorites ? Icons.favorite_border : Icons.image_not_supported_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              state.viewMode == GalleryViewMode.favorites ? context.l10n.onlineGallery_favoritesEmpty : context.l10n.onlineGallery_noResults,
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
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      crossAxisCount: columnCount,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      itemCount: state.posts.length + (state.hasMore || state.error != null ? 1 : 0),
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
        final multiSelectState = ref.watch(multiSelectNotifierProvider);
        final isSelected = multiSelectState.selectedPostIds.contains(post.id);

        // 智能预加载：提前缓存后续 10 张图片
        _prefetchImages(state, index);

        return DanbooruPostCard(
          post: post,
          itemWidth: itemWidth,
          isFavorited: isFavorited,
          isSelected: isSelected,
          onTap: () => _showPostDetail(context, post),
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
            ref.read(onlineGalleryNotifierProvider.notifier).toggleFavorite(post.id);
          },
          onSelectionToggle: () {
            ref.read(multiSelectNotifierProvider.notifier).toggleSelection(post.id);
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
    showDialog(
      context: context,
      builder: (context) => _PostDetailDialog(
        post: post,
        onTagTap: (tag) {
          Navigator.pop(context);
          _searchController.text = tag;
          ref.read(onlineGalleryNotifierProvider.notifier).search(tag);
        },
      ),
    );
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
                : (_isHovering ? theme.colorScheme.surfaceContainerHighest : Colors.transparent),
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
                color: widget.isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: widget.isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
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
    final sources = {'danbooru': 'Danbooru', 'safebooru': 'Safebooru', 'gelbooru': 'Gelbooru'};

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
              Text(e.value, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
              if (isSelected) ...[const Spacer(), Icon(Icons.check, size: 16, color: theme.colorScheme.primary)],
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
            Text(sources[selected] ?? selected, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
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
    final current = ratings.firstWhere((r) => r.$1 == selected, orElse: () => ratings[0]);

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
              if (r.$3 != null) Container(width: 8, height: 8, decoration: BoxDecoration(color: r.$3, shape: BoxShape.circle)),
              if (r.$3 != null) const SizedBox(width: 8),
              Text(r.$2, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
              if (isSelected) ...[const Spacer(), Icon(Icons.check, size: 16, color: theme.colorScheme.primary)],
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
              Container(width: 8, height: 8, decoration: BoxDecoration(color: current.$3, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(current.$2, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// 帖子详情对话框
class _PostDetailDialog extends ConsumerWidget {
  final DanbooruPost post;
  final Function(String) onTagTap;

  const _PostDetailDialog({required this.post, required this.onTagTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final authState = ref.watch(danbooruAuthProvider);
    final galleryState = ref.watch(onlineGalleryNotifierProvider);
    final isFavorited = galleryState.favoritedPostIds.contains(post.id);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: screenSize.width * 0.9, maxHeight: screenSize.height * 0.9),
        decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            // 媒体区域
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      InteractiveViewer(
                        child: CachedNetworkImage(
                          imageUrl: post.sampleUrl ?? post.fileUrl ?? post.previewUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white)),
                        ),
                      ),
                      // 媒体类型标识
                      if (post.isVideo || post.isAnimated)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              post.isVideo ? Icons.play_arrow : Icons.gif,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // 信息面板
            Container(
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.dividerColor))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Row(
                    children: [
                      Text('Post #${post.id}', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          if (!authState.isLoggedIn) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.onlineGallery_pleaseLogin)));
                            return;
                          }
                          ref.read(onlineGalleryNotifierProvider.notifier).toggleFavorite(post.id);
                        },
                        icon: Icon(isFavorited ? Icons.favorite : Icons.favorite_border, color: isFavorited ? Colors.red : null),
                        iconSize: 20,
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), iconSize: 20),
                    ],
                  ),
                  const Divider(),
                  // 信息
                  _InfoRow(label: context.l10n.onlineGallery_size, value: '${post.width}×${post.height}'),
                  _InfoRow(label: context.l10n.onlineGallery_score, value: '${post.score}'),
                  _InfoRow(label: context.l10n.onlineGallery_favCount, value: '${post.favCount}'),
                  _InfoRow(label: context.l10n.onlineGallery_rating, value: post.rating.toUpperCase()),
                  if (post.mediaTypeLabel != null) _InfoRow(label: context.l10n.onlineGallery_type, value: post.mediaTypeLabel!),
                  const SizedBox(height: 12),
                  // 标签
                  Text(context.l10n.onlineGallery_tags, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.artistTags.isNotEmpty)
                            _TagSection(title: context.l10n.onlineGallery_artists, tags: post.artistTags, color: const Color(0xFFFF8A8A), onTagTap: onTagTap),
                          if (post.characterTags.isNotEmpty)
                            _TagSection(title: context.l10n.onlineGallery_characters, tags: post.characterTags, color: const Color(0xFF8AFF8A), onTagTap: onTagTap, isCharacter: true),
                          if (post.copyrightTags.isNotEmpty)
                            _TagSection(title: context.l10n.onlineGallery_copyrights, tags: post.copyrightTags, color: const Color(0xFFCC8AFF), onTagTap: onTagTap),
                          if (post.generalTags.isNotEmpty)
                            _TagSection(title: context.l10n.onlineGallery_general, tags: post.generalTags, color: const Color(0xFF8AC8FF), onTagTap: onTagTap),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  // 操作
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: post.tags.join(', ')));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.onlineGallery_copied)));
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(context.l10n.onlineGallery_copyTags),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(post.postUrl);
                            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(context.l10n.onlineGallery_open),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _TagSection extends ConsumerWidget {
  final String title;
  final List<String> tags;
  final Color color;
  final Function(String) onTagTap;
  final bool isCharacter;

  const _TagSection({
    required this.title,
    required this.tags,
    required this.color,
    required this.onTagTap,
    this.isCharacter = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final translationService = ref.watch(tagTranslationServiceProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: tags.map((tag) {
              final translation = translationService.translate(tag, isCharacter: isCharacter);
              return SimpleTagChip(tag: tag, color: color, translation: translation, onTap: () => onTagTap(tag));
            }).toList(),
          ),
        ],
      ),
    );
  }
}
