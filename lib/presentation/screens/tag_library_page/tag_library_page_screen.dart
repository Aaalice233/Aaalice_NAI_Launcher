import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/sliding_toggle.dart';
import 'widgets/category_tree_view.dart';
import 'widgets/entry_card.dart';
import 'widgets/entry_list_item.dart';
import 'widgets/entry_add_dialog.dart';
import 'widgets/export_dialog.dart';
import 'widgets/import_dialog.dart';
import '../../widgets/common/themed_divider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 词库页面
class TagLibraryPageScreen extends ConsumerStatefulWidget {
  const TagLibraryPageScreen({super.key});

  @override
  ConsumerState<TagLibraryPageScreen> createState() =>
      _TagLibraryPageScreenState();
}

class _TagLibraryPageScreenState extends ConsumerState<TagLibraryPageScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tagLibraryPageNotifierProvider);

    return Scaffold(
      body: Row(
        children: [
          // 左侧分类树
          _buildCategorySidebar(theme, state),

          // 主内容区
          Expanded(
            child: Column(
              children: [
                // 顶部工具栏
                _buildToolbar(theme, state),

                // 内容列表
                Expanded(
                  child: _buildContent(theme, state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分类侧边栏
  Widget _buildCategorySidebar(ThemeData theme, TagLibraryPageState state) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // 分类标题
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: const BoxConstraints(minHeight: 62),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.tagLibrary_categories,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showAddCategoryDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    context.l10n.tagLibrary_newCategory,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const ThemedDivider(height: 1),

          // 分类树
          Expanded(
            child: CategoryTreeView(
              categories: state.categories,
              entries: state.entries,
              selectedCategoryId: state.selectedCategoryId,
              onCategorySelected: (id) {
                ref
                    .read(tagLibraryPageNotifierProvider.notifier)
                    .selectCategory(id);
              },
              onCategoryRename: (id, name) {
                ref
                    .read(tagLibraryPageNotifierProvider.notifier)
                    .renameCategory(id, name);
              },
              onCategoryDelete: (id) {
                _showDeleteCategoryConfirmation(id);
              },
              onAddSubCategory: (parentId) {
                _showAddCategoryDialog(parentId: parentId);
              },
              // 分类移动到新父级（跨层级拖拽）
              onCategoryMove: (categoryId, newParentId) {
                ref
                    .read(tagLibraryPageNotifierProvider.notifier)
                    .moveCategory(categoryId, newParentId);
              },
              // 分类同级重排序
              onCategoryReorder: (parentId, oldIndex, newIndex) {
                ref
                    .read(tagLibraryPageNotifierProvider.notifier)
                    .reorderCategories(parentId, oldIndex, newIndex);
              },
              // 词条拖拽到分类
              onEntryDrop: (entryId, categoryId) {
                ref
                    .read(tagLibraryPageNotifierProvider.notifier)
                    .moveEntryToCategory(entryId, categoryId);
                AppToast.success(context, context.l10n.tagLibrary_entryMoved);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建顶部工具栏
  Widget _buildToolbar(ThemeData theme, TagLibraryPageState state) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.9),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              // 添加条目按钮
              FilledButton.icon(
                onPressed: () => _showAddEntryDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.tagLibrary_addEntry),
              ),
              const SizedBox(width: 12),

              // 搜索框
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ThemedInput(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: context.l10n.tagLibrary_searchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: state.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(
                                      tagLibraryPageNotifierProvider.notifier,
                                    )
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (value) {
                      ref
                          .read(tagLibraryPageNotifierProvider.notifier)
                          .setSearchQuery(value);
                    },
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 视图切换
              SlidingToggle<TagLibraryViewMode>(
                value: state.viewMode,
                options: const [
                  SlidingToggleOption(
                    value: TagLibraryViewMode.list,
                    icon: Icons.view_list_rounded,
                  ),
                  SlidingToggleOption(
                    value: TagLibraryViewMode.card,
                    icon: Icons.grid_view_rounded,
                  ),
                ],
                onChanged: (mode) => ref
                    .read(tagLibraryPageNotifierProvider.notifier)
                    .setViewMode(mode),
              ),

              const SizedBox(width: 8),

              // 导入按钮
              OutlinedButton.icon(
                onPressed: () => _showImportDialog(),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(context.l10n.tagLibrary_import),
              ),
              const SizedBox(width: 8),

              // 导出按钮
              OutlinedButton.icon(
                onPressed:
                    state.entries.isEmpty ? null : () => _showExportDialog(),
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(context.l10n.tagLibrary_export),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent(ThemeData theme, TagLibraryPageState state) {
    final entries = state.filteredEntries;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (entries.isEmpty) {
      return _buildEmptyState(theme, state);
    }

    if (state.viewMode == TagLibraryViewMode.card) {
      return _buildCardGrid(theme, entries);
    } else {
      return _buildListView(theme, entries);
    }
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme, TagLibraryPageState state) {
    final hasSearch = state.searchQuery.isNotEmpty;
    final hasCategory = state.selectedCategoryId != null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.library_books_outlined,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? context.l10n.tagLibrary_noSearchResults
                : (hasCategory
                    ? context.l10n.tagLibrary_categoryEmpty
                    : context.l10n.tagLibrary_empty),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? context.l10n.tagLibrary_tryDifferentSearch
                : context.l10n.tagLibrary_addFirstEntry,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showAddEntryDialog(),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.tagLibrary_addEntry),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建卡片网格
  Widget _buildCardGrid(ThemeData theme, List entries) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        childAspectRatio: 0.85,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return EntryCard(
          key: ValueKey(entry.id),
          entry: entry,
          enableDrag: true,
          onTap: () => _showEntryDetail(entry),
          onAddToFixed: () => _addToFixedTags(entry),
          onDelete: () => _showDeleteEntryConfirmation(entry.id),
          onEdit: () => _showEditDialog(entry),
          onToggleFavorite: () {
            ref
                .read(tagLibraryPageNotifierProvider.notifier)
                .toggleFavorite(entry.id);
          },
        );
      },
    );
  }

  /// 构建列表视图
  Widget _buildListView(ThemeData theme, List entries) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: EntryListItem(
            key: ValueKey(entry.id),
            entry: entry,
            enableDrag: true,
            onTap: () => _showEntryDetail(entry),
            onAddToFixed: () => _addToFixedTags(entry),
            onDelete: () => _showDeleteEntryConfirmation(entry.id),
            onEdit: () => _showEditDialog(entry),
            onToggleFavorite: () {
              ref
                  .read(tagLibraryPageNotifierProvider.notifier)
                  .toggleFavorite(entry.id);
            },
          ),
        );
      },
    );
  }

  // ==================== 对话框方法 ====================

  void _showAddEntryDialog() {
    final state = ref.read(tagLibraryPageNotifierProvider);
    showDialog(
      context: context,
      builder: (context) => EntryAddDialog(
        categories: state.categories,
        initialCategoryId: state.selectedCategoryId,
      ),
    );
  }

  void _showAddCategoryDialog({String? parentId}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.tagLibrary_newCategory),
        content: ThemedInput(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: dialogContext.l10n.tagLibrary_categoryNameHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              final result = await ref
                  .read(tagLibraryPageNotifierProvider.notifier)
                  .addCategory(
                    name: value.trim(),
                    parentId: parentId,
                  );
              if (!dialogContext.mounted) return;
              if (result != null) {
                Navigator.of(dialogContext).pop();
              } else {
                AppToast.error(
                  dialogContext,
                  dialogContext.l10n.tagLibrary_categoryNameExists,
                );
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final result = await ref
                    .read(tagLibraryPageNotifierProvider.notifier)
                    .addCategory(
                      name: name,
                      parentId: parentId,
                    );
                if (!dialogContext.mounted) return;
                if (result != null) {
                  Navigator.of(dialogContext).pop();
                } else {
                  AppToast.error(
                    dialogContext,
                    dialogContext.l10n.tagLibrary_categoryNameExists,
                  );
                }
              }
            },
            child: Text(dialogContext.l10n.common_create),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryConfirmation(String categoryId) {
    final state = ref.read(tagLibraryPageNotifierProvider);
    final category = state.categories.firstWhere((c) => c.id == categoryId);
    final entryCount = state.getCategoryEntryCount(categoryId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tagLibrary_deleteCategoryTitle),
        content: Text(
          context.l10n.tagLibrary_deleteCategoryConfirm(
            category.displayName,
            entryCount.toString(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(tagLibraryPageNotifierProvider.notifier)
                  .deleteCategory(categoryId);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
  }

  void _showDeleteEntryConfirmation(String entryId) {
    final state = ref.read(tagLibraryPageNotifierProvider);
    final entry = state.entries.firstWhere((e) => e.id == entryId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tagLibrary_deleteEntryTitle),
        content:
            Text(context.l10n.tagLibrary_deleteEntryConfirm(entry.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(tagLibraryPageNotifierProvider.notifier)
                  .deleteEntry(entryId);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
  }

  void _showEntryDetail(dynamic entry) {
    // 点击卡片同样打开编辑对话框
    _showEditDialog(entry);
  }

  void _showEditDialog(dynamic entry) {
    final state = ref.read(tagLibraryPageNotifierProvider);
    showDialog(
      context: context,
      builder: (context) => EntryAddDialog(
        categories: state.categories,
        entry: entry,
      ),
    );
  }

  void _addToFixedTags(dynamic entry) {
    // 添加到固定词
    ref.read(fixedTagsNotifierProvider.notifier).addEntry(
          name: entry.name.isNotEmpty ? entry.name : entry.displayName,
          content: entry.content,
          weight: 1.0,
          position: FixedTagPosition.prefix,
          enabled: true,
        );

    // 记录使用
    ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);

    // 显示提示
    AppToast.success(context, context.l10n.tagLibrary_addedToFixed);
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => const ImportDialog(),
    );
  }

  void _showExportDialog() {
    final state = ref.read(tagLibraryPageNotifierProvider);
    showDialog(
      context: context,
      builder: (context) => ExportDialog(
        entries: state.entries,
        categories: state.categories,
      ),
    );
  }
}
