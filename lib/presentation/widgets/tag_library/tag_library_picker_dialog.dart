import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/tag_library/tag_library_category.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/tag_library_page_provider.dart';

/// 词库条目选择对话框
///
/// 用于从词库中选择一个条目，返回选中的 [TagLibraryEntry]
class TagLibraryPickerDialog extends ConsumerStatefulWidget {
  /// 对话框标题
  final String? title;

  const TagLibraryPickerDialog({
    super.key,
    this.title,
  });

  @override
  ConsumerState<TagLibraryPickerDialog> createState() =>
      _TagLibraryPickerDialogState();
}

class _TagLibraryPickerDialogState
    extends ConsumerState<TagLibraryPickerDialog> {
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tagLibraryPageNotifierProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(theme),
            const SizedBox(height: 16),

            // 搜索和筛选栏
            _buildFilterBar(theme, state),
            const SizedBox(height: 16),

            // 条目网格
            Expanded(
              child: _buildEntryGrid(theme, state),
            ),

            const SizedBox(height: 16),

            // 底部按钮
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.library_books_outlined,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          widget.title ?? context.l10n.tagLibraryPicker_title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: context.l10n.common_close,
        ),
      ],
    );
  }

  Widget _buildFilterBar(ThemeData theme, TagLibraryPageState state) {
    return Row(
      children: [
        // 搜索框
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: context.l10n.tagLibraryPicker_searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        const SizedBox(width: 12),

        // 分类筛选
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String?>(
            value: _selectedCategoryId,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              isDense: true,
            ),
            hint: Text(context.l10n.tagLibraryPicker_allCategories),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(context.l10n.tagLibraryPicker_allCategories),
              ),
              ...state.categories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category.id,
                  child: Text(
                    category.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedCategoryId = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntryGrid(ThemeData theme, TagLibraryPageState state) {
    // 过滤条目
    var entries = state.entries.toList();

    // 按分类筛选
    if (_selectedCategoryId != null) {
      final categoryIds = {
        _selectedCategoryId!,
        ...state.categories.getDescendantIds(_selectedCategoryId!),
      };
      entries =
          entries.where((e) => categoryIds.contains(e.categoryId)).toList();
    }

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      entries = entries.search(_searchQuery);
    }

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? context.l10n.tagLibrary_noSearchResults
                  : context.l10n.tagLibrary_empty,
              style: TextStyle(
                color: theme.colorScheme.outline,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _EntrySelectCard(
          entry: entry,
          onTap: () => Navigator.of(context).pop(entry),
        );
      },
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
      ],
    );
  }
}

/// 条目选择卡片
class _EntrySelectCard extends StatefulWidget {
  final TagLibraryEntry entry;
  final VoidCallback onTap;

  const _EntrySelectCard({
    required this.entry,
    required this.onTap,
  });

  @override
  State<_EntrySelectCard> createState() => _EntrySelectCardState();
}

class _EntrySelectCardState extends State<_EntrySelectCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovering
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outlineVariant.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 预览图区域
              Expanded(
                flex: 3,
                child: _buildThumbnail(theme, entry),
              ),

              // 信息区域
              Expanded(
                flex: 2,
                child: _buildInfo(theme, entry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme, TagLibraryEntry entry) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          child: entry.hasThumbnail
              ? Image.file(
                  File(entry.thumbnail!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      _buildPlaceholder(theme),
                )
              : _buildPlaceholder(theme),
        ),

        // 悬停遮罩
        if (_isHovering)
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              child: Container(
                color: theme.colorScheme.primary.withOpacity(0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.common_select,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 收藏标识
        if (entry.isFavorite)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.favorite,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildInfo(ThemeData theme, TagLibraryEntry entry) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称
          Text(
            entry.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // 内容预览
          Expanded(
            child: Text(
              entry.contentPreview,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
