import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/online_gallery_provider.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';

/// 在线画廊页面
///
/// 支持浏览 Danbooru 等图片网站
class OnlineGalleryScreen extends ConsumerStatefulWidget {
  const OnlineGalleryScreen({super.key});

  @override
  ConsumerState<OnlineGalleryScreen> createState() => _OnlineGalleryScreenState();
}

class _OnlineGalleryScreenState extends ConsumerState<OnlineGalleryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 初始加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onlineGalleryNotifierProvider.notifier).loadPosts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      ref.read(onlineGalleryNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onlineGalleryNotifierProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 顶部搜索栏
          _buildSearchBar(theme, state),

          // 图片网格
          Expanded(
            child: _buildContent(theme, state),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, OnlineGalleryState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          // 数据源切换 - 使用分段按钮
          _SourceSelector(
            selected: state.source,
            onChanged: (source) {
              ref.read(onlineGalleryNotifierProvider.notifier).setSource(source);
            },
          ),
          const SizedBox(width: 16),

          // 搜索框 - 更简洁
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: '搜索标签...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(onlineGalleryNotifierProvider.notifier).search('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (value) {
                  ref.read(onlineGalleryNotifierProvider.notifier).search(value);
                },
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 评级筛选
          _RatingFilter(
            selected: state.rating,
            onChanged: (rating) {
              ref.read(onlineGalleryNotifierProvider.notifier).setRating(rating);
            },
          ),
          const SizedBox(width: 4),

          // 刷新按钮
          IconButton(
            onPressed: state.isLoading
                ? null
                : () => ref.read(onlineGalleryNotifierProvider.notifier).refresh(),
            icon: state.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.refresh, size: 22),
            tooltip: '刷新',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, OnlineGalleryState state) {
    if (state.isLoading && state.posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && state.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(onlineGalleryNotifierProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
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
              Icons.image_not_supported_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到图片',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '尝试修改搜索条件',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // 计算列数：根据屏幕宽度动态调整
    final screenWidth = MediaQuery.of(context).size.width - 60; // 减去侧边栏宽度
    final columnCount = (screenWidth / 220).floor().clamp(2, 8);
    // 计算每个 item 的宽度
    final itemWidth = (screenWidth - 32 - (columnCount - 1) * 8) / columnCount;

    return MasonryGridView.count(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      crossAxisCount: columnCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: state.posts.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.posts.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final post = state.posts[index];
        return _PostCard(
          post: post,
          itemWidth: itemWidth,
          onTap: () => _showPostDetail(context, post),
          onTagTap: (tag) {
            _searchController.text = tag;
            ref.read(onlineGalleryNotifierProvider.notifier).search(tag);
          },
        );
      },
    );
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

  String _getSourceName(String source) {
    switch (source) {
      case 'danbooru':
        return 'Danbooru';
      case 'safebooru':
        return 'Safebooru';
      case 'gelbooru':
        return 'Gelbooru';
      default:
        return source;
    }
  }

  String _getRatingName(String rating) {
    switch (rating) {
      case 'all':
        return '全部';
      case 'g':
        return 'General';
      case 's':
        return 'Sensitive';
      case 'q':
        return 'Questionable';
      case 'e':
        return 'Explicit';
      default:
        return rating;
    }
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case 'g':
        return Colors.green;
      case 's':
        return Colors.yellow.shade700;
      case 'q':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// 图片卡片
class _PostCard extends StatefulWidget {
  final DanbooruPost post;
  final double itemWidth;
  final VoidCallback onTap;
  final Function(String) onTagTap;

  const _PostCard({
    required this.post,
    required this.itemWidth,
    required this.onTap,
    required this.onTagTap,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 根据传入的宽度和原始宽高比计算高度
    double itemHeight;
    if (widget.post.width > 0 && widget.post.height > 0) {
      // 使用真实宽高比计算
      itemHeight = widget.itemWidth * (widget.post.height / widget.post.width);
      // 限制最大高度，避免超长图片
      itemHeight = itemHeight.clamp(100.0, widget.itemWidth * 2.5);
    } else {
      // 默认正方形
      itemHeight = widget.itemWidth;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: itemHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 图片
                CachedNetworkImage(
                  imageUrl: widget.post.previewUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                // 悬停时显示信息
                if (_isHovering)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.post.width}x${widget.post.height}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          if (widget.post.score > 0)
                            Text(
                              'Score: ${widget.post.score}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // 评级标签
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getRatingColor(widget.post.rating).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.post.rating.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case 'g':
        return Colors.green;
      case 's':
        return Colors.yellow.shade700;
      case 'q':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// 图片详情对话框
class _PostDetailDialog extends StatelessWidget {
  final DanbooruPost post;
  final Function(String) onTagTap;

  const _PostDetailDialog({
    required this.post,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.9,
          maxHeight: screenSize.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // 图片区域
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                child: Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: post.sampleUrl ?? post.fileUrl ?? post.previewUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.error, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 信息面板
            Container(
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Row(
                    children: [
                      Text(
                        'Post #${post.id}',
                        style: theme.textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),

                  // 基本信息
                  _InfoRow(label: '尺寸', value: '${post.width}x${post.height}'),
                  _InfoRow(label: '评分', value: '${post.score}'),
                  _InfoRow(label: '评级', value: post.rating.toUpperCase()),
                  if (post.source.isNotEmpty)
                    _InfoRow(label: '来源', value: post.source, isUrl: true),
                  const SizedBox(height: 16),

                  // 标签
                  Text(
                    '标签',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: post.tags.map((tag) {
                          return ActionChip(
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => onTagTap(tag),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const Divider(),

                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: post.tags.join(', '),
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('标签已复制')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('复制标签'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openInBrowser(post.postUrl),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('打开原页'),
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

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isUrl;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isUrl = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: isUrl
                ? GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(value);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text(
                    value,
                    style: theme.textTheme.bodySmall,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 数据源选择器 - 使用分段按钮风格
class _SourceSelector extends StatelessWidget {
  final String selected;
  final Function(String) onChanged;

  const _SourceSelector({
    required this.selected,
    required this.onChanged,
  });

  static const _sources = [
    ('danbooru', 'Danbooru'),
    ('safebooru', 'Safebooru'),
    ('gelbooru', 'Gelbooru'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _sources.map((source) {
          final isSelected = selected == source.$1;
          return _SourceChip(
            label: source.$2,
            isSelected: isSelected,
            onTap: () => onChanged(source.$1),
            isFirst: source == _sources.first,
            isLast: source == _sources.last,
          );
        }).toList(),
      ),
    );
  }
}

class _SourceChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _SourceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  @override
  State<_SourceChip> createState() => _SourceChipState();
}

class _SourceChipState extends State<_SourceChip> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : (_isHovering ? theme.colorScheme.surfaceContainerHighest : Colors.transparent),
            borderRadius: BorderRadius.horizontal(
              left: widget.isFirst ? const Radius.circular(8) : Radius.zero,
              right: widget.isLast ? const Radius.circular(8) : Radius.zero,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                color: widget.isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 评级筛选器 - 下拉菜单风格
class _RatingFilter extends StatelessWidget {
  final String selected;
  final Function(String) onChanged;

  const _RatingFilter({
    required this.selected,
    required this.onChanged,
  });

  static const _ratings = [
    ('all', '全部', Icons.filter_list, null),
    ('g', 'General', Icons.check_circle, Colors.green),
    ('s', 'Sensitive', Icons.warning, Colors.amber),
    ('q', 'Questionable', Icons.help, Colors.orange),
    ('e', 'Explicit', Icons.block, Colors.red),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentRating = _ratings.firstWhere((r) => r.$1 == selected, orElse: () => _ratings[0]);

    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => _ratings.map((rating) {
        final isSelected = selected == rating.$1;
        return PopupMenuItem<String>(
          value: rating.$1,
          child: Row(
            children: [
              Icon(
                rating.$3,
                size: 18,
                color: rating.$4 ?? theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                rating.$2,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
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
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentRating.$3,
              size: 18,
              color: currentRating.$4 ?? theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              currentRating.$2,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
