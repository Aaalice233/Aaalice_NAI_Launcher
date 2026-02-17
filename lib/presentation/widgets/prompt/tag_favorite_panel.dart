import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/nai_prompt_parser.dart';
import '../../../data/models/prompt/prompt_tag.dart';
import '../../../data/models/prompt/tag_favorite.dart';
import '../../../data/models/tag/tag_suggestion.dart';
import '../../providers/danbooru_suggestion_provider.dart';
import '../../providers/tag_favorite_provider.dart';
import '../common/themed_container.dart';
import '../../widgets/common/themed_divider.dart';
import '../../widgets/common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 标签收藏面板
///
/// 显示用户收藏的常用标签，支持点击添加到提示词、长按移除收藏
class TagFavoritePanel extends ConsumerStatefulWidget {
  /// 当前标签列表
  final List<PromptTag> currentTags;

  /// 标签变化回调
  final ValueChanged<List<PromptTag>> onTagsChanged;

  /// 是否只读
  final bool readOnly;

  /// 是否紧凑模式
  final bool compact;

  const TagFavoritePanel({
    super.key,
    required this.currentTags,
    required this.onTagsChanged,
    this.readOnly = false,
    this.compact = false,
  });

  @override
  ConsumerState<TagFavoritePanel> createState() => _TagFavoritePanelState();
}

class _TagFavoritePanelState extends ConsumerState<TagFavoritePanel> {
  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// 是否显示搜索结果
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 搜索变化处理
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _showSearchResults = query.isNotEmpty;
    });

    if (query.isNotEmpty) {
      // 触发 Danbooru 搜索
      ref.read(danbooruSuggestionNotifierProvider.notifier).search(query);
    } else {
      // 清空建议
      ref.read(danbooruSuggestionNotifierProvider.notifier).clear();
    }
  }

  /// 检查标签是否已在当前提示词中
  bool _isTagInCurrentTags(PromptTag tag) {
    return widget.currentTags.any((t) => t.text == tag.text);
  }

  /// 检查标签文本是否已在当前提示词中
  bool _isTagTextInCurrentTags(String tagText) {
    return widget.currentTags.any((t) => t.text == tagText);
  }

  /// 添加收藏标签到当前提示词
  void _addToCurrentTags(TagFavorite favorite) {
    if (widget.readOnly) return;

    final tag = favorite.tag;

    // 检查是否已存在
    if (_isTagInCurrentTags(tag)) {
      // 已存在，显示提示
      AppToast.info(context, context.l10n.tag_alreadyAdded);
      return;
    }

    // 添加到当前标签列表
    final newTags = NaiPromptParser.insertTag(
      widget.currentTags,
      widget.currentTags.length,
      tag.toSyntaxString(),
    );

    widget.onTagsChanged(newTags);

    // 触觉反馈
    HapticFeedback.lightImpact();
  }

  /// 添加 Danbooru 建议标签到当前提示词
  void _addSuggestionToCurrentTags(TagSuggestion suggestion) {
    if (widget.readOnly) return;

    // 检查是否已存在
    if (_isTagTextInCurrentTags(suggestion.tag)) {
      // 已存在，显示提示
      AppToast.info(context, context.l10n.tag_alreadyAdded);
      return;
    }

    // 添加到当前标签列表
    final newTags = NaiPromptParser.insertTag(
      widget.currentTags,
      widget.currentTags.length,
      suggestion.tag,
    );

    widget.onTagsChanged(newTags);

    // 触觉反馈
    HapticFeedback.lightImpact();
  }

  /// 从收藏中移除
  void _removeFromFavorites(TagFavorite favorite) {
    if (widget.readOnly) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tag_removeFavoriteTitle),
        content: Text(
          context.l10n.tag_removeFavoriteMessage(favorite.tag.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(tagFavoriteNotifierProvider.notifier)
                  .removeFavorite(favorite.id);
            },
            child: Text(
              context.l10n.common_delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoritesState = ref.watch(tagFavoriteNotifierProvider);
    final favorites = favoritesState.favorites;
    final isLoading = favoritesState.isLoading;
    final danbooruState = ref.watch(danbooruSuggestionNotifierProvider);

    final showDanbooruSuggestions = _showSearchResults &&
        danbooruState.suggestions.isNotEmpty &&
        danbooruState.currentQuery == _searchController.text.trim();

    return ThemedContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          _buildHeader(context, favorites.length),

          const SizedBox(height: 16),

          // 搜索栏
          _buildSearchBar(context),

          const SizedBox(height: 12),

          // Danbooru 建议或收藏列表
          Expanded(
            child: showDanbooruSuggestions
                ? _buildDanbooruSuggestions(context, danbooruState.suggestions)
                : isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : favorites.isEmpty
                        ? _buildEmptyState(context)
                        : _buildFavoritesList(context, favorites),
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(BuildContext context, int count) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.favorite_border,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.tag_favoritesTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    return ThemedInput(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: context.l10n.tagGroupBrowser_searchHint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        prefixIcon: Icon(
          Icons.search,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  /// 构建 Danbooru 建议列表
  Widget _buildDanbooruSuggestions(
    BuildContext context,
    List<TagSuggestion> suggestions,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 建议标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.tagGroupBrowser_danbooruSuggestions,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${suggestions.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const ThemedDivider(height: 1),
        // 建议列表
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              final isInCurrent = _isTagTextInCurrentTags(suggestion.tag);
              return _buildSuggestionItem(context, suggestion, isInCurrent);
            },
          ),
        ),
      ],
    );
  }

  /// 构建单个建议项
  Widget _buildSuggestionItem(
    BuildContext context,
    TagSuggestion suggestion,
    bool isInCurrent,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addSuggestionToCurrentTags(suggestion),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isInCurrent
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.3),
            ),
            color: isInCurrent
                ? theme.colorScheme.primary.withOpacity(0.08)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          child: Row(
            children: [
              // 建议图标
              Icon(
                Icons.cloud_outlined,
                size: 16,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(width: 12),

              // 标签信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标签文本
                    Text(
                      suggestion.tag,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isInCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    // 分类和计数
                    if (suggestion.count > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${suggestion.categoryEnum.displayName} • ${suggestion.formattedCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 已添加标识
              if (isInCurrent) ...[
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ],

              // 添加图标
              Icon(
                Icons.add_circle_outline,
                size: 18,
                color: isInCurrent
                    ? theme.colorScheme.onSurface.withOpacity(0.3)
                    : theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 48,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.tag_favoritesEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tag_favoritesEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建收藏列表
  Widget _buildFavoritesList(
    BuildContext context,
    List<TagFavorite> favorites,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: favorites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        final isInCurrent = _isTagInCurrentTags(favorite.tag);

        return _buildFavoriteItem(context, favorite, isInCurrent);
      },
    );
  }

  /// 构建单个收藏项
  Widget _buildFavoriteItem(
    BuildContext context,
    TagFavorite favorite,
    bool isInCurrent,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addToCurrentTags(favorite),
        onLongPress: () => _removeFromFavorites(favorite),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isInCurrent
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.3),
            ),
            color: isInCurrent
                ? theme.colorScheme.primary.withOpacity(0.08)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          child: Row(
            children: [
              // 收藏图标
              Icon(
                Icons.favorite,
                size: 16,
                color: isInCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error.withOpacity(0.7),
              ),
              const SizedBox(width: 12),

              // 标签信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标签文本（显示权重）
                    Text(
                      favorite.tag.toSyntaxString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isInCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    // 如果有备注，显示备注
                    if (favorite.hasNotes) ...[
                      const SizedBox(height: 2),
                      Text(
                        favorite.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 已添加标识
              if (isInCurrent) ...[
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ],

              // 更多操作提示
              Icon(
                Icons.more_vert,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
