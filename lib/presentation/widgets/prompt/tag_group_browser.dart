import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../../data/models/tag/tag_suggestion.dart';
import '../../providers/danbooru_suggestion_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../autocomplete/autocomplete.dart';

/// 标签分组浏览器
///
/// 可折叠的标签分组浏览组件，按 TagSubCategory 组织标签
class TagGroupBrowser extends ConsumerStatefulWidget {
  /// 标签变化回调
  final ValueChanged<List<String>> onTagsChanged;

  /// 当前已选择的标签列表（用于高亮显示）
  final List<String> selectedTags;

  /// 是否只读
  final bool readOnly;

  const TagGroupBrowser({
    super.key,
    required this.onTagsChanged,
    this.selectedTags = const [],
    this.readOnly = false,
  });

  @override
  ConsumerState<TagGroupBrowser> createState() => _TagGroupBrowserState();
}

class _TagGroupBrowserState extends ConsumerState<TagGroupBrowser> {
  /// 跟踪每个分类的展开/收起状态
  final Map<TagSubCategory, bool> _expandedCategories = {};

  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 默认展开前3个分类
    _expandedCategories[TagSubCategory.hairColor] = true;
    _expandedCategories[TagSubCategory.clothing] = true;
    _expandedCategories[TagSubCategory.expression] = true;

    // 监听搜索变化，触发 Danbooru 搜索
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
    if (query.isNotEmpty) {
      // 触发 Danbooru 搜索
      ref.read(danbooruSuggestionNotifierProvider.notifier).search(query);
    } else {
      // 清空建议
      ref.read(danbooruSuggestionNotifierProvider.notifier).clear();
    }
  }

  /// 切换分类展开状态
  void _toggleCategory(TagSubCategory category) {
    setState(() {
      _expandedCategories[category] = !(_expandedCategories[category] ?? false);
    });
  }

  /// 处理标签点击
  void _handleTagTap(String tagText) {
    // 添加标签到当前提示词
    widget.onTagsChanged([...widget.selectedTags, tagText]);
  }

  /// 检查标签是否已选择
  bool _isTagSelected(String tagText) {
    return widget.selectedTags.contains(tagText);
  }

  /// 根据搜索过滤标签
  List<String> _filterTags(List<String> tags, String searchQuery) {
    if (searchQuery.isEmpty) return tags;
    final query = searchQuery.toLowerCase();
    return tags.where((tag) => tag.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final library = libraryState.library;
    final categoryFilter = libraryState.categoryFilterConfig;
    final danbooruState = ref.watch(danbooruSuggestionNotifierProvider);

    // 如果没有词库，显示空状态
    if (library == null) {
      return _buildEmptyState(theme);
    }

    // 获取所有启用的分类
    final enabledCategories = TagSubCategory.values
        .where((cat) => categoryFilter.isBuiltinEnabled(cat))
        .toList();

    // 如果没有启用的分类，显示提示
    if (enabledCategories.isEmpty) {
      return _buildNoCategoriesEnabledState(theme);
    }

    final searchQuery = _searchController.text.trim();
    final hasSearch = searchQuery.isNotEmpty;
    final showDanbooruSuggestions = hasSearch &&
        danbooruState.suggestions.isNotEmpty &&
        danbooruState.currentQuery == searchQuery;

    return Column(
      children: [
        // 搜索栏
        _buildSearchBar(theme),

        // Danbooru 建议区域（有搜索且有结果时显示）
        if (showDanbooruSuggestions)
          _buildDanbooruSuggestionsSection(theme, danbooruState.suggestions),

        // 分类列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: enabledCategories.length,
            itemBuilder: (context, index) {
              final category = enabledCategories[index];
              // 根据分类过滤配置获取标签，尊重 Danbooru 补充设置
              final tags = library.getFilteredCategory(
                category,
                includeDanbooruSupplement: categoryFilter.isEnabled(category),
              );
              final tagTexts = tags.map((t) => t.tag).toList();
              final tagCount = tagTexts.length;

              // 如果该分类下没有标签，不显示
              if (tagCount == 0) {
                return const SizedBox.shrink();
              }

              final isExpanded = _expandedCategories[category] ?? false;
              final categoryName = TagSubCategoryHelper.getDisplayName(category);

              return _buildCategoryTile(
                theme: theme,
                category: category,
                categoryName: categoryName,
                tagCount: tagCount,
                isExpanded: isExpanded,
                tags: tagTexts,
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: AutocompleteTextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        enableAutocomplete: true,
        config: const AutocompleteConfig(
          maxSuggestions: 10,
          showTranslation: true,
          autoInsertComma: false,
        ),
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
                    ref.read(danbooruSuggestionNotifierProvider.notifier).clear();
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
          fillColor: theme.colorScheme.surfaceContainerHighest,
        ),
        style: const TextStyle(fontSize: 14),
        onSubmitted: (_) {
          setState(() {});
        },
        onChanged: (_) {
          setState(() {});
        },
      ),
    );
  }

  /// 构建 Danbooru 建议区域
  Widget _buildDanbooruSuggestionsSection(
    ThemeData theme,
    List<TagSuggestion> suggestions,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
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
          const SizedBox(height: 8),
          // 建议列表
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.take(10).map((suggestion) {
              return _buildDanbooruSuggestionChip(theme, suggestion);
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建 Danbooru 建议芯片
  Widget _buildDanbooruSuggestionChip(
    ThemeData theme,
    TagSuggestion suggestion,
  ) {
    final isSelected = _isTagSelected(suggestion.tag);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTagTap(suggestion.tag),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.15)
                : theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                suggestion.tag,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              if (suggestion.count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    suggestion.formattedCount,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建分类卡片
  Widget _buildCategoryTile({
    required ThemeData theme,
    required TagSubCategory category,
    required String categoryName,
    required int tagCount,
    required bool isExpanded,
    required List<String> tags,
  }) {
    // 应用搜索过滤
    final searchQuery = _searchController.text.trim();
    final filteredTags = _filterTags(tags, searchQuery);
    final displayCount = filteredTags.length;

    // 如果搜索后没有结果，不显示该分类
    if (searchQuery.isNotEmpty && displayCount == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头部（可点击展开/收起）
          InkWell(
            onTap: () => _toggleCategory(category),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: isExpanded ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 分类图标（使用 emoji）
                  _buildCategoryIcon(category),

                  const SizedBox(width: 12),

                  // 分类名称和标签数
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          searchQuery.isNotEmpty
                              ? context.l10n.tagGroupBrowser_filteredTagCount(
                                  displayCount.toString(),
                                  tagCount.toString(),
                                )
                              : context.l10n.tagGroupBrowser_tagCount(
                                  tagCount.toString(),
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 展开/收起图标
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 展开内容（收起时不渲染，提升性能）
          if (isExpanded) _buildExpandedContent(theme, filteredTags),
        ],
      ),
    );
  }

  /// 构建分类图标
  Widget _buildCategoryIcon(TagSubCategory category) {
    // 根据 TagSubCategory 返回对应的 emoji
    final emoji = _getCategoryEmoji(category);
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  /// 获取分类对应的 emoji
  String _getCategoryEmoji(TagSubCategory category) {
    return switch (category) {
      TagSubCategory.hairColor => '💇',
      TagSubCategory.eyeColor => '👁️',
      TagSubCategory.hairStyle => '💇‍♀️',
      TagSubCategory.clothing => '👔',
      TagSubCategory.clothingFemale => '👗',
      TagSubCategory.clothingMale => '👔',
      TagSubCategory.clothingGeneral => '👕',
      TagSubCategory.expression => '😊',
      TagSubCategory.pose => '🧍',
      TagSubCategory.background => '🖼️',
      TagSubCategory.scene => '🏞️',
      TagSubCategory.style => '🎨',
      TagSubCategory.bodyFeature => '💪',
      TagSubCategory.bodyFeatureFemale => '♀️',
      TagSubCategory.bodyFeatureMale => '♂️',
      TagSubCategory.bodyFeatureGeneral => '🧍',
      TagSubCategory.accessory => '👒',
      TagSubCategory.characterCount => '👥',
      TagSubCategory.other => '📦',
    };
  }

  /// 构建展开内容
  Widget _buildExpandedContent(ThemeData theme, List<String> tags) {
    if (tags.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            context.l10n.tagGroupBrowser_noTags,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tagText) {
              final isSelected = _isTagSelected(tagText);
              return _buildTagChip(theme, tagText, isSelected);
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 构建标签芯片
  Widget _buildTagChip(ThemeData theme, String tagText, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTagTap(tagText),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.15)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Text(
            tagText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.tagGroupBrowser_noLibrary,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tagGroupBrowser_importLibraryHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建没有启用分类的状态
  Widget _buildNoCategoriesEnabledState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.tagGroupBrowser_noCategories,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tagGroupBrowser_enableCategoriesHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
