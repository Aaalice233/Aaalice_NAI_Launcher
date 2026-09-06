import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../data/models/tag_library/tag_library_category.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/tag_library_page_provider.dart';
import '../common/thumbnail_display.dart';
import '../common/translated_tag_text.dart';
import 'tag_library_entry_hover_preview.dart';

/// 词库条目选择对话框
///
/// 用于从词库中选择一个条目，返回选中的 [TagLibraryEntry]
class TagLibraryPickerDialog extends ConsumerStatefulWidget {
  const TagLibraryPickerDialog({super.key});

  /// 统一使用自适应选择面呈现词库：紧凑宽度全屏，其他宽度保持有界。
  static Future<TagLibraryEntry?> show(BuildContext context, {String? title}) {
    final resolvedTitle = title ?? context.l10n.tagLibraryPicker_title;
    return AdaptivePresenter.showForm<TagLibraryEntry>(
      context: context,
      titleBuilder: (context) => Row(
        children: [
          Icon(
            Icons.library_books_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              resolvedTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      dialogWidth: 800,
      builder: (context, scrollController) => const TagLibraryPickerDialog(),
    );
  }

  @override
  ConsumerState<TagLibraryPickerDialog> createState() =>
      _TagLibraryPickerDialogState();
}

class _TagLibraryPickerDialogState
    extends ConsumerState<TagLibraryPickerDialog> {
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    final savedCategoryId = ref
        .read(localStorageServiceProvider)
        .getSetting<String>(StorageKeys.tagLibraryPickerCategoryId);
    if (savedCategoryId != null && savedCategoryId.isNotEmpty) {
      _selectedCategoryId = savedCategoryId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tagLibraryPageNotifierProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(theme, state),
          const SizedBox(height: 16),
          Expanded(child: _buildEntryGrid(theme, state)),
          const SizedBox(height: 12),
          _buildFooter(theme),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, TagLibraryPageState state) {
    final selectedCategoryId = _effectiveSelectedCategoryId(state);
    final searchField = TextField(
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: context.l10n.tagLibraryPicker_searchHint,
        prefixIcon: const Icon(Icons.search, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        isDense: true,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
    final categoryField = DropdownButtonFormField<String?>(
      initialValue: selectedCategoryId,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            child: Text(category.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: _setSelectedCategory,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [searchField, const SizedBox(height: 10), categoryField],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: searchField),
            const SizedBox(width: 12),
            Expanded(child: categoryField),
          ],
        );
      },
    );
  }

  Widget _buildEntryGrid(ThemeData theme, TagLibraryPageState state) {
    // 过滤条目
    var entries = state.entries.toList();
    final selectedCategoryId = _effectiveSelectedCategoryId(state);

    // 按分类筛选
    if (selectedCategoryId != null) {
      final categoryIds = {
        selectedCategoryId,
        ...state.categories.getDescendantIds(selectedCategoryId),
      };
      entries = entries
          .where((e) => categoryIds.contains(e.categoryId))
          .toList();
    }

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      entries = entries.search(_searchQuery);
    }
    entries = _sortFavoritesFirst(entries);

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
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const minimumCardWidth = 150.0;
        final crossAxisCount =
            ((constraints.maxWidth + spacing) / (minimumCardWidth + spacing))
                .floor()
                .clamp(1, 4);
        // A lazy row sizes itself from its actual text, including translations
        // that arrive later. Fixed-aspect tiles cannot reserve that height.
        return ListView.separated(
          itemCount: (entries.length / crossAxisCount).ceil(),
          separatorBuilder: (context, index) => const SizedBox(height: spacing),
          itemBuilder: (context, rowIndex) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < crossAxisCount; column++) ...[
                if (column > 0) const SizedBox(width: spacing),
                Expanded(
                  child: rowIndex * crossAxisCount + column < entries.length
                      ? _EntrySelectCard(
                          key: ValueKey(
                            'tag-library-picker-entry-${entries[rowIndex * crossAxisCount + column].id}',
                          ),
                          entry: entries[rowIndex * crossAxisCount + column],
                          onTap: () => Navigator.of(
                            context,
                          ).pop(entries[rowIndex * crossAxisCount + column]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
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

  String? _effectiveSelectedCategoryId(TagLibraryPageState state) {
    final selected = _selectedCategoryId;
    if (selected == null) return null;
    return state.categories.any((category) => category.id == selected)
        ? selected
        : null;
  }

  void _setSelectedCategory(String? value) {
    setState(() => _selectedCategoryId = value);
    final storage = ref.read(localStorageServiceProvider);
    if (value == null) {
      unawaited(storage.deleteSetting(StorageKeys.tagLibraryPickerCategoryId));
    } else {
      unawaited(
        storage.setSetting(StorageKeys.tagLibraryPickerCategoryId, value),
      );
    }
  }

  List<TagLibraryEntry> _sortFavoritesFirst(List<TagLibraryEntry> entries) {
    if (!entries.any((entry) => entry.isFavorite)) {
      return entries;
    }
    final favorites = <TagLibraryEntry>[];
    final others = <TagLibraryEntry>[];
    for (final entry in entries) {
      if (entry.isFavorite) {
        favorites.add(entry);
      } else {
        others.add(entry);
      }
    }
    return [...favorites, ...others];
  }
}

/// 条目选择卡片
class _EntrySelectCard extends StatefulWidget {
  final TagLibraryEntry entry;
  final VoidCallback onTap;

  const _EntrySelectCard({super.key, required this.entry, required this.onTap});

  @override
  State<_EntrySelectCard> createState() => _EntrySelectCardState();
}

class _EntrySelectCardState extends State<_EntrySelectCard> {
  bool _isHovering = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return TagLibraryEntryHoverPreview(
      entry: entry,
      child: Semantics(
        label: entry.displayName,
        button: true,
        child: FocusableActionDetector(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          onFocusChange: (focused) {
            if (_isFocused != focused) setState(() => _isFocused = focused);
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: _isHovering
                      ? theme.colorScheme.surfaceContainerHigh
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      _isFocused &&
                          context.interactionPolicy.keyboardNavigationActive
                      ? Border.all(color: theme.colorScheme.primary)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.4,
                      child: _buildThumbnail(theme, entry),
                    ),
                    _buildInfo(theme, entry),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme, TagLibraryEntry entry) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (entry.hasThumbnail && entry.thumbnail != null)
          LayoutBuilder(
            builder: (context, constraints) {
              // 使用 LayoutBuilder 获取实际尺寸
              // 参考尺寸保持 200x80 以确保与裁剪对话框一致
              return ThumbnailDisplay(
                imagePath: entry.thumbnail!,
                offsetX: entry.thumbnailOffsetX,
                offsetY: entry.thumbnailOffsetY,
                scale: entry.thumbnailScale,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
              );
            },
          )
        else
          _buildPlaceholder(theme),

        // 悬停遮罩
        if (_isHovering)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                        Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.common_select,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
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
              child: const Icon(Icons.favorite, size: 12, color: Colors.white),
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
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
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
          TranslatedPromptText(
            entry.contentPreview,
            selectable: false,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
