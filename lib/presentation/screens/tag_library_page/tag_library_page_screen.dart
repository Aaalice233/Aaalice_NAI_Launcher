import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/comfyui_prompt_parser/pipe_parser.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/pending_prompt_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../providers/tag_library_selection_provider.dart';
import '../../router/app_router.dart';

import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/shortcuts/shortcut_aware_widget.dart';
import 'widgets/category_tree_view.dart';
import 'widgets/entry_card.dart';
import 'widgets/entry_list_item.dart';
import 'widgets/entry_add_dialog.dart';
import 'widgets/send_to_home_dialog.dart';
import 'widgets/tag_library_toolbar.dart';
import 'widgets/bulk_move_category_dialog.dart';
import 'widgets/export_dialog.dart';
import 'widgets/import_dialog.dart';


/// 词库页面
class TagLibraryPageScreen extends ConsumerStatefulWidget {
  const TagLibraryPageScreen({super.key});

  @override
  ConsumerState<TagLibraryPageScreen> createState() =>
      _TagLibraryPageScreenState();
}

class _TagLibraryPageScreenState extends ConsumerState<TagLibraryPageScreen> {
  /// 搜索框焦点节点
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tagLibraryPageNotifierProvider);

    // 定义快捷键映射
    final shortcuts = <String, VoidCallback>{
      // 全选（选择模式下）
      ShortcutIds.selectAllTags: () {
        final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
        if (selectionState.isActive) {
          final allIds = state.filteredEntries.map((e) => e.id).toList();
          ref
              .read(tagLibrarySelectionNotifierProvider.notifier)
              .selectAll(allIds);
        }
      },
      // 退出选择模式
      ShortcutIds.exitSelectionMode: () {
        final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
        if (selectionState.isActive) {
          ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();
        }
      },
      // 取消全选
      ShortcutIds.deselectAllTags: () {
        final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
        if (selectionState.isActive) {
          ref
              .read(tagLibrarySelectionNotifierProvider.notifier)
              .clearSelection();
        }
      },
      // 新建分类
      ShortcutIds.newCategory: () {
        _showAddCategoryDialog();
      },
      // 新建标签
      ShortcutIds.newTag: () {
        _showAddEntryDialog();
      },
      // 搜索标签
      ShortcutIds.searchTags: () {
        _searchFocusNode.requestFocus();
      },
      // 批量删除
      ShortcutIds.batchDeleteTags: () {
        final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
        if (selectionState.isActive && selectionState.hasSelection) {
          _handleBulkDelete();
        }
      },
      // 批量复制
      ShortcutIds.batchCopyTags: () {
        final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
        if (selectionState.isActive && selectionState.hasSelection) {
          _handleBulkCopy();
        }
      },
      // 发送到首页
      ShortcutIds.sendToHome: () {
        final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
        if (selectionState.isActive && selectionState.hasSelection) {
          _sendSelectedToHome();
        }
      },
    };

    return PageShortcuts(
      contextType: ShortcutContext.tagLibrary,
      shortcuts: shortcuts,
      child: Scaffold(
        body: Row(
          children: [
            // 左侧分类树
            _buildCategorySidebar(theme, state),

            // 主内容区
            Expanded(
              child: Column(
                children: [
                  // 顶部工具栏（集成批量操作）
                  TagLibraryToolbar(
                    onEnterSelectionMode: () => ref
                        .read(tagLibrarySelectionNotifierProvider.notifier)
                        .enter(),
                    onBulkDelete: _handleBulkDelete,
                    onBulkMoveCategory: _handleBulkMoveCategory,
                    onBulkToggleFavorite: _handleBulkToggleFavorite,
                    onBulkCopy: _handleBulkCopy,
                    onImport: _handleImport,
                    onExport: _handleExport,
                    onAddEntry: _showAddEntryDialog,
                  ),

                  // 内容列表
                  Expanded(
                    child: _buildContent(theme, state),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 发送选中的标签到首页
  Future<void> _sendSelectedToHome() async {
    final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    final pageState = ref.read(tagLibraryPageNotifierProvider);
    final selectedEntries =
        pageState.entries.where((e) => selectedIds.contains(e.id)).toList();

    if (selectedEntries.isEmpty) return;

    // 如果只有一个选中项，使用现有的对话框
    if (selectedEntries.length == 1) {
      _showEntryDetail(selectedEntries.first);
      return;
    }

    // 多个选中项：直接拼接内容发送到主提示词
    final content = selectedEntries.map((e) => e.content).join(', ');

    // 设置待填充提示词
    ref.read(pendingPromptNotifierProvider.notifier).set(
          prompt: content,
          targetType: SendTargetType.mainPrompt,
          clearOnConsume: true,
        );

    // 记录所有选中项的使用
    for (final entry in selectedEntries) {
      await ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .recordUsage(entry.id);
    }

    // 退出选择模式
    ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();

    if (mounted) {
      AppToast.success(context, '已发送 ${selectedEntries.length} 个词条到主提示词');
      // 导航到主页
      context.go(AppRoutes.home);
    }
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

          const Divider(height: 1),

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
              onCategoryMove: (categoryId, newParentId) {
                ref
                    .read(tagLibraryPageNotifierProvider.notifier)
                    .moveCategory(categoryId, newParentId);
              },
              onCategoryReorder: (parentId, oldIndex, newIndex) {
                ref
                    .read(tagLibraryPageNotifierProvider.notifier)
                    .reorderCategories(parentId, oldIndex, newIndex);
              },
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
  Widget _buildCardGrid(ThemeData theme, List<TagLibraryEntry> entries) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        childAspectRatio: 0.85,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildEntryItem(entries[index], true),
    );
  }

  /// 构建列表视图
  Widget _buildListView(ThemeData theme, List<TagLibraryEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildEntryItem(entries[index], false),
      ),
    );
  }

  /// 构建条目组件（卡片或列表项）
  Widget _buildEntryItem(TagLibraryEntry entry, bool isCard) {
    final state = ref.read(tagLibraryPageNotifierProvider);
    final selectionState = ref.watch(tagLibrarySelectionNotifierProvider);
    final allIds = state.filteredEntries.map((e) => e.id).toList();
    final categoryName = _getCategoryName(state.categories, entry.categoryId);
    final isSelected = selectionState.isSelected(entry.id);

    void toggleSelection() {
      final notifier = ref.read(tagLibrarySelectionNotifierProvider.notifier);
      if (HardwareKeyboard.instance.isShiftPressed) {
        notifier.selectRange(entry.id, allIds);
      } else if (!selectionState.isActive) {
        notifier.enterAndSelect(entry.id);
      } else {
        notifier.toggle(entry.id);
      }
    }

    final commonProps = (
      enableDrag: !selectionState.isActive,
      isSelectionMode: selectionState.isActive,
      isSelected: isSelected,
      onToggleSelection: toggleSelection,
      onDelete: () => _showDeleteEntryConfirmation(entry.id),
      onEdit: () => _showEditDialog(entry),
      onToggleFavorite: () => ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .toggleFavorite(entry.id),
    );

    if (isCard) {
      return EntryCard(
        key: ValueKey(entry.id),
        entry: entry,
        categoryName: categoryName,
        enableDrag: commonProps.enableDrag,
        isSelectionMode: commonProps.isSelectionMode,
        isSelected: commonProps.isSelected,
        onToggleSelection: commonProps.onToggleSelection,
        onTap: commonProps.onEdit,
        onDelete: commonProps.onDelete,
        onEdit: commonProps.onEdit,
        onSend: () => _showEntryDetail(entry),
        onToggleFavorite: commonProps.onToggleFavorite,
      );
    }

    return EntryListItem(
      key: ValueKey(entry.id),
      entry: entry,
      categoryName: categoryName,
      enableDrag: commonProps.enableDrag,
      isSelectionMode: commonProps.isSelectionMode,
      isSelected: commonProps.isSelected,
      onToggleSelection: commonProps.onToggleSelection,
      onTap: () => _showEntryDetail(entry),
      onDelete: commonProps.onDelete,
      onEdit: commonProps.onEdit,
      onToggleFavorite: commonProps.onToggleFavorite,
    );
  }

  /// 获取分类名称
  String _getCategoryName(List categories, String? categoryId) {
    if (categoryId == null) return '';
    final category = categories.cast().firstWhere(
          (c) => c?.id == categoryId,
          orElse: () => null,
        );
    return category?.displayName ?? '';
  }

  // ==================== 批量操作处理 ====================

  /// 批量删除
  Future<void> _handleBulkDelete() async {
    final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '确认删除',
      content: '确定要删除选中的 ${selectedIds.length} 个词条吗？此操作不可撤销。',
      confirmText: '删除',
      cancelText: '取消',
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (!confirmed || !mounted) return;

    await ref
        .read(tagLibraryPageNotifierProvider.notifier)
        .deleteEntries(selectedIds);

    ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();

    if (mounted) {
      AppToast.success(context, '已删除 ${selectedIds.length} 个词条');
    }
  }

  /// 批量转移分类
  Future<void> _handleBulkMoveCategory() async {
    final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    final state = ref.read(tagLibraryPageNotifierProvider);

    // 显示分类选择对话框
    final targetCategoryId = await showDialog<String?>(
      context: context,
      builder: (context) => BulkMoveCategoryDialog(
        categories: state.categories,
        currentCategoryId: state.selectedCategoryId,
      ),
    );

    if (targetCategoryId == null || !mounted) return;

    // 执行批量移动
    for (final entryId in selectedIds) {
      await ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .moveEntryToCategory(entryId, targetCategoryId);
    }

    ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();

    if (mounted) {
      AppToast.success(context, '已移动 ${selectedIds.length} 个词条');
    }
  }

  /// 批量切换收藏
  Future<void> _handleBulkToggleFavorite() async {
    final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    // 检查是否全部已收藏
    final state = ref.read(tagLibraryPageNotifierProvider);
    final selectedEntries =
        state.entries.where((e) => selectedIds.contains(e.id));
    final allFavorited = selectedEntries.every((e) => e.isFavorite);

    // 如果全部已收藏，则取消收藏；否则全部收藏
    for (final entryId in selectedIds) {
      final entry = state.entries.firstWhere((e) => e.id == entryId);
      if (entry.isFavorite != !allFavorited) {
        await ref
            .read(tagLibraryPageNotifierProvider.notifier)
            .toggleFavorite(entryId);
      }
    }

    ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();

    if (mounted) {
      AppToast.success(
        context,
        allFavorited
            ? '已取消收藏 ${selectedIds.length} 个词条'
            : '已收藏 ${selectedIds.length} 个词条',
      );
    }
  }

  /// 批量复制内容
  Future<void> _handleBulkCopy() async {
    final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    final state = ref.read(tagLibraryPageNotifierProvider);
    final selectedEntries =
        state.entries.where((e) => selectedIds.contains(e.id)).toList();

    // 按当前排序拼接内容
    final content = selectedEntries.map((e) => e.content).join(', ');

    await Clipboard.setData(ClipboardData(text: content));

    ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();

    if (mounted) {
      AppToast.success(context, '已复制 ${selectedEntries.length} 个词条的内容');
    }
  }

  /// 导入词库
  void _handleImport() {
    showDialog(
      context: context,
      builder: (context) => const ImportDialog(),
    );
  }

  /// 导出词库
  void _handleExport() {
    final state = ref.read(tagLibraryPageNotifierProvider);
    showDialog(
      context: context,
      builder: (context) => ExportDialog(
        entries: state.entries,
        categories: state.categories,
      ),
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
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: dialogContext.l10n.tagLibrary_categoryNameHint,
            border: const OutlineInputBorder(),
          ),
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

  void _showEntryDetail(TagLibraryEntry entry) async {
    final sendOptions = await SendToHomeDialog.show(context, entry: entry);
    if (sendOptions == null || !mounted) return;

    // 处理发送到固定词的情况
    if (sendOptions.targetType == SendTargetType.fixedTag) {
      await _handleSendToFixedTag(entry, sendOptions.sendAsAlias);
      return;
    }

    // 处理发送到主页的情况
    await _handleSendToHome(entry, sendOptions);
  }

  /// 处理发送到固定词
  Future<void> _handleSendToFixedTag(
    TagLibraryEntry entry,
    bool sendAsAlias,
  ) async {
    final content = sendAsAlias
        ? '<${entry.name}>'
        : SdToNaiConverter.convert(entry.content);

    await ref.read(fixedTagsNotifierProvider.notifier).addEntry(
          name: entry.name,
          content: content,
        );

    if (!mounted) return;
    AppToast.success(context, '已添加到固定词');
  }

  /// 处理发送到主页
  Future<void> _handleSendToHome(
    TagLibraryEntry entry,
    SendOptions sendOptions,
  ) async {
    final content = _prepareContentForHome(entry, sendOptions);

    ref.read(pendingPromptNotifierProvider.notifier).set(
          prompt: content,
          targetType: sendOptions.targetType,
          clearOnConsume: true,
        );

    await ref
        .read(tagLibraryPageNotifierProvider.notifier)
        .recordUsage(entry.id);

    if (!mounted) return;

    final message = _getSendSuccessMessage(sendOptions.targetType);
    AppToast.success(context, message);
    context.go(AppRoutes.home);
  }

  /// 准备发送到主页的内容
  String _prepareContentForHome(TagLibraryEntry entry, SendOptions options) {
    // 作为别名发送
    if (options.sendAsAlias) {
      return '<${entry.name}>';
    }

    // 检查是否为竖线格式且需要提取角色部分
    final isPipeFormat = PipeParser.isPipeFormat(entry.content);
    final needsCharacterExtract =
        isPipeFormat &&
        (options.targetType == SendTargetType.replaceCharacter ||
            options.targetType == SendTargetType.appendCharacter);

    if (needsCharacterExtract) {
      final result = PipeParser.parse(entry.content);
      if (result.characters.isNotEmpty) {
        return result.characters.map((c) => c.prompt).join('\n| ');
      }
    }

    return entry.content;
  }

  /// 获取发送成功提示消息
  String _getSendSuccessMessage(SendTargetType targetType) {
    return switch (targetType) {
      SendTargetType.mainPrompt => context.l10n.sendToHome_successMainPrompt,
      SendTargetType.smartDecompose => '已智能分解并发送',
      SendTargetType.replaceCharacter =>
        context.l10n.sendToHome_successReplaceCharacter,
      SendTargetType.appendCharacter =>
        context.l10n.sendToHome_successAppendCharacter,
      SendTargetType.fixedTag => '已添加到固定词',
    };
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
}
