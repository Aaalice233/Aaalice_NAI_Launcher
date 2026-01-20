import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../../data/services/tag_translation_service.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/pending_prompt_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../tag_chip.dart';

/// 在线画廊帖子详情弹窗
///
/// 全屏弹窗，包含：
/// - 大图预览（支持缩放平移）
/// - 标签分类展示
/// - 图片信息（尺寸、分数、收藏数等）
/// - 操作按钮（复制、下载、收藏、发送）
class PostDetailDialog extends ConsumerStatefulWidget {
  final DanbooruPost post;
  final Function(String)? onTagTap;

  const PostDetailDialog({
    super.key,
    required this.post,
    this.onTagTap,
  });

  @override
  ConsumerState<PostDetailDialog> createState() => _PostDetailDialogState();
}

class _PostDetailDialogState extends ConsumerState<PostDetailDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width > 800;
    final authState = ref.watch(danbooruAuthProvider);
    final galleryState = ref.watch(onlineGalleryNotifierProvider);
    final isFavorited = galleryState.favoritedPostIds.contains(widget.post.id);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: child,
        ),
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isWide ? 24 : 8),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.95,
            maxHeight: screenSize.height * 0.95,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: isWide
                ? _buildWideLayout(theme, authState, isFavorited)
                : _buildNarrowLayout(theme, authState, isFavorited),
          ),
        ),
      ),
    );
  }

  /// 宽屏布局（左图右信息）
  Widget _buildWideLayout(ThemeData theme, DanbooruAuthState authState, bool isFavorited) {
    return Row(
      children: [
        // 媒体区域
        Expanded(
          flex: 3,
          child: _buildMediaSection(theme),
        ),
        // 信息面板
        Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: theme.dividerColor)),
          ),
          child: _buildInfoPanel(theme, authState, isFavorited),
        ),
      ],
    );
  }

  /// 窄屏布局（上图下信息）
  Widget _buildNarrowLayout(ThemeData theme, DanbooruAuthState authState, bool isFavorited) {
    return Column(
      children: [
        // 媒体区域
        Expanded(
          flex: 2,
          child: _buildMediaSection(theme),
        ),
        // 信息面板
        Expanded(
          flex: 3,
          child: _buildInfoPanel(theme, authState, isFavorited),
        ),
      ],
    );
  }

  /// 媒体区域
  Widget _buildMediaSection(ThemeData theme) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 可交互图片查看器
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: widget.post.sampleUrl ?? widget.post.fileUrl ?? widget.post.previewUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error, color: Colors.white54, size: 48),
                    SizedBox(height: 8),
                    Text(
                      '加载失败',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 媒体类型标识
          if (widget.post.isVideo || widget.post.isAnimated)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.post.isVideo ? Icons.play_arrow : Icons.gif,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
          // 关闭按钮
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              onPressed: _close,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          // 缩放提示
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white54, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '双指缩放',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 信息面板
  Widget _buildInfoPanel(ThemeData theme, DanbooruAuthState authState, bool isFavorited) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        _buildTitleBar(theme, authState, isFavorited),
        const Divider(height: 1),
        // 图片信息
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildInfoSection(theme),
        ),
        const Divider(height: 1),
        // 标签区域
        Expanded(
          child: _buildTagsSection(theme),
        ),
        const Divider(height: 1),
        // 操作按钮
        _buildActionButtons(theme),
      ],
    );
  }

  /// 标题栏
  Widget _buildTitleBar(ThemeData theme, DanbooruAuthState authState, bool isFavorited) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Text(
            'Post #${widget.post.id}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          // 评级徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getRatingColor(widget.post.rating),
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
          const Spacer(),
          // 收藏按钮
          IconButton(
            onPressed: () {
              if (!authState.isLoggedIn) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.onlineGallery_pleaseLogin)),
                );
                return;
              }
              ref.read(onlineGalleryNotifierProvider.notifier).toggleFavorite(widget.post.id);
            },
            icon: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              color: isFavorited ? Colors.red : null,
            ),
            iconSize: 22,
            tooltip: isFavorited ? '取消收藏' : '收藏',
          ),
        ],
      ),
    );
  }

  /// 图片信息区域
  Widget _buildInfoSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          icon: Icons.photo_size_select_actual,
          label: context.l10n.onlineGallery_size,
          value: '${widget.post.width} × ${widget.post.height}',
        ),
        const SizedBox(height: 6),
        _InfoRow(
          icon: Icons.star,
          label: context.l10n.onlineGallery_score,
          value: '${widget.post.score}',
          valueColor: widget.post.score > 0 ? Colors.green : 
                      widget.post.score < 0 ? Colors.red : null,
        ),
        const SizedBox(height: 6),
        _InfoRow(
          icon: Icons.favorite,
          label: context.l10n.onlineGallery_favCount,
          value: '${widget.post.favCount}',
          valueColor: Colors.red.shade300,
        ),
        if (widget.post.mediaTypeLabel != null) ...[
          const SizedBox(height: 6),
          _InfoRow(
            icon: widget.post.isVideo ? Icons.videocam : Icons.gif,
            label: context.l10n.onlineGallery_type,
            value: widget.post.mediaTypeLabel!,
          ),
        ],
      ],
    );
  }

  /// 标签区域
  Widget _buildTagsSection(ThemeData theme) {
    final translationService = ref.watch(tagTranslationServiceProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.onlineGallery_tags,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // 艺术家标签
          if (widget.post.artistTags.isNotEmpty)
            _TagSection(
              title: context.l10n.onlineGallery_artists,
              tags: widget.post.artistTags,
              color: TagColors.artist,
              translationService: translationService,
              onTagTap: _handleTagTap,
            ),
          // 角色标签
          if (widget.post.characterTags.isNotEmpty)
            _TagSection(
              title: context.l10n.onlineGallery_characters,
              tags: widget.post.characterTags,
              color: TagColors.character,
              translationService: translationService,
              onTagTap: _handleTagTap,
              isCharacter: true,
            ),
          // 版权标签
          if (widget.post.copyrightTags.isNotEmpty)
            _TagSection(
              title: context.l10n.onlineGallery_copyrights,
              tags: widget.post.copyrightTags,
              color: TagColors.copyright,
              translationService: translationService,
              onTagTap: _handleTagTap,
            ),
          // 通用标签
          if (widget.post.generalTags.isNotEmpty)
            _TagSection(
              title: context.l10n.onlineGallery_general,
              tags: widget.post.generalTags,
              color: TagColors.general,
              translationService: translationService,
              onTagTap: _handleTagTap,
            ),
          // 元标签
          if (widget.post.metaTags.isNotEmpty)
            _TagSection(
              title: '元数据',
              tags: widget.post.metaTags,
              color: TagColors.meta,
              translationService: translationService,
              onTagTap: _handleTagTap,
            ),
        ],
      ),
    );
  }

  void _handleTagTap(String tag) {
    _close();
    widget.onTagTap?.call(tag);
  }

  /// 操作按钮区域
  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 第一行：复制和发送
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyTags,
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(context.l10n.onlineGallery_copyTags),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sendToGenerate,
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('发送'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：加入队列和打开链接
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addToQueue,
                  icon: const Icon(Icons.queue, size: 16),
                  label: const Text('加入队列'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(context.l10n.onlineGallery_open),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 复制标签
  void _copyTags() {
    final tags = widget.post.tags.join(', ');
    Clipboard.setData(ClipboardData(text: tags));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.onlineGallery_copied)),
    );
  }

  /// 发送到生成页面
  void _sendToGenerate() {
    if (widget.post.tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此图片没有标签信息')),
      );
      return;
    }

    // 清空角色提示词
    ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
    
    // 设置待填充提示词
    ref.read(pendingPromptNotifierProvider.notifier).set(
      prompt: widget.post.tags.join(', '),
    );

    // 关闭弹窗并导航到生成页面
    Navigator.pop(context);
    context.go('/generate');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('提示词已发送到生成页面')),
    );
  }

  /// 加入队列
  Future<void> _addToQueue() async {
    if (widget.post.tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此图片没有标签信息')),
      );
      return;
    }

    final task = ReplicationTask.create(
      prompt: widget.post.tags.join(', '),
      thumbnailUrl: widget.post.previewUrl,
      source: ReplicationTaskSource.online,
    );

    final added = await ref.read(replicationQueueNotifierProvider.notifier).add(task);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(added ? '已加入队列' : '队列已满（最多50项）')),
      );
    }
  }

  /// 在浏览器中打开
  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.post.postUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _getRatingColor(String rating) {
    switch (rating.toLowerCase()) {
      case 'g':
        return Colors.green;
      case 's':
        return Colors.amber.shade700;
      case 'q':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// 信息行组件
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
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
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// 标签分类组件
class _TagSection extends StatelessWidget {
  final String title;
  final List<String> tags;
  final Color color;
  final TagTranslationService translationService;
  final Function(String) onTagTap;
  final bool isCharacter;

  const _TagSection({
    required this.title,
    required this.tags,
    required this.color,
    required this.translationService,
    required this.onTagTap,
    this.isCharacter = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$title (${tags.length})',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: tags.map((tag) {
              final translation = translationService.translate(
                tag,
                isCharacter: isCharacter,
              );
              return SimpleTagChip(
                tag: tag,
                color: color,
                translation: translation,
                onTap: () => onTagTap(tag),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 显示帖子详情弹窗
void showPostDetailDialog(
  BuildContext context, {
  required DanbooruPost post,
  Function(String)? onTagTap,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => PostDetailDialog(
      post: post,
      onTagTap: onTagTap,
    ),
  );
}
