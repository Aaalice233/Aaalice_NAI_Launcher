import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../core/utils/comfyui_prompt_parser/pipe_parser.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/pending_prompt_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../providers/tag_library_selection_provider.dart';
import '../../router/app_routes.dart';

import '../../agent_chat/widgets/agent_resource_drop_region.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/owned_scroll_controller.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/gallery/gallery_album_tree_view.dart';
import '../../widgets/gallery/gallery_sidebar.dart';
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
import 'widgets/grouped_view/grouped_entries_view.dart';

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
  final OwnedScrollController _cardScrollController = OwnedScrollController(
    viewport: OwnedViewportOffset(),
  );
  final OwnedScrollController _listScrollController = OwnedScrollController(
    viewport: OwnedViewportOffset(),
  );
  final OwnedScrollController _groupedScrollController = OwnedScrollController(
    viewport: OwnedViewportOffset(),
  );
  final ValueNotifier<Set<String>> _expandedCategoryIds =
      ValueNotifier<Set<String>>(<String>{});
  bool _categoriesExpanded = true;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _expandedCategoryIds.dispose();
    _cardScrollController.dispose();
    _listScrollController.dispose();
    _groupedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tagLibraryPageNotifierProvider);
    final isSelectionMode = ref.watch(
      tagLibrarySelectionNotifierProvider.select((value) => value.isActive),
    );

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

    return PopScope<void>(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSelectionMode) {
          ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();
        }
      },
      child: PageShortcuts(
        contextType: ShortcutContext.tagLibrary,
        shortcuts: shortcuts,
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final showSidebar = constraints.maxWidth >= 840;
              return GalleryCollectionWorkspace(
                toolbar: TagLibraryToolbar(
                  showPageTitle: true,
                  onShowCategories: showSidebar
                      ? null
                      : () => _showCategoryPanel(state),
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
                sidebar: showSidebar ? _buildCategorySidebar(state) : null,
                body: _buildContent(theme, state),
              );
            },
          ),
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
    final selectedEntries = pageState.entries
        .where((e) => selectedIds.contains(e.id))
        .toList();

    if (selectedEntries.isEmpty) return;

    // 如果只有一个选中项，使用现有的对话框
    if (selectedEntries.length == 1) {
      _showEntryDetail(selectedEntries.first);
      return;
    }

    // 多个选中项：直接拼接内容发送到主提示词
    final content = selectedEntries
        .map((entry) => CharacterPromptBlockParser.parse(entry.content))
        .map((parsed) => parsed.positivePrompt)
        .where((prompt) => prompt.isNotEmpty)
        .join(', ');

    // 设置待填充提示词
    ref
        .read(pendingPromptNotifierProvider.notifier)
        .set(
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
      AppToast.success(
        context,
        context.l10n.tagLibrary_sentEntriesToMainPrompt(selectedEntries.length),
      );
      // 导航到主页
      context.go(AppRoutes.home);
    }
  }

  /// 构建分类侧边栏
  Widget _buildCategorySidebar(
    TagLibraryPageState state, {
    bool forPanel = false,
    VoidCallback? onCategorySelectionComplete,
  }) {
    void selectCategory(String? id) {
      ref.read(tagLibraryPageNotifierProvider.notifier).selectCategory(id);
      onCategorySelectionComplete?.call();
    }

    final allEntriesItem = GalleryAllImagesItem(
      key: const Key('tag-library-all-entries'),
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: context.l10n.tagLibrary_allEntries,
      count: state.entries.length,
      isSelected: state.selectedCategoryId == null,
      onTap: () => selectCategory(null),
    );
    final allEntries = DragTarget<TagLibraryEntry>(
      onWillAcceptWithDetails: (details) => details.data.categoryId != null,
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        ref
            .read(tagLibraryPageNotifierProvider.notifier)
            .moveEntryToCategory(details.data.id, null);
        AppToast.success(context, context.l10n.tagLibrary_entryMoved);
      },
      builder: (context, candidateData, _) => AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: candidateData.isEmpty
              ? null
              : Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(8),
        ),
        child: allEntriesItem,
      ),
    );

    return GallerySidebarSurface(
      key: forPanel ? null : const Key('tag-library-category-sidebar'),
      modal: forPanel,
      child: Column(
        children: [
          if (!forPanel)
            const SizedBox(
              height: GalleryCollectionChrome.navigationTopPadding,
            ),
          allEntries,
          GallerySidebarSectionHeader(
            toggleKey: const Key('tag-library-category-section-toggle'),
            icon: Icons.folder_outlined,
            title: context.l10n.tagLibrary_categories,
            isExpanded: _categoriesExpanded,
            onToggle: () =>
                setState(() => _categoriesExpanded = !_categoriesExpanded),
            onCreate: _showAddCategoryDialog,
          ),
          if (_categoriesExpanded)
            Expanded(
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: _expandedCategoryIds,
                builder: (context, expandedCategoryIds, _) => CategoryTreeView(
                  categories: state.categories,
                  entries: state.entries,
                  selectedCategoryId: state.selectedCategoryId,
                  expandedCategoryIds: expandedCategoryIds,
                  includeAllEntries: false,
                  onExpandedCategoryIdsChanged: (ids) {
                    _expandedCategoryIds.value = ids;
                  },
                  onCategorySelected: selectCategory,
                  onCategoryRename: (id, name) {
                    ref
                        .read(tagLibraryPageNotifierProvider.notifier)
                        .renameCategory(id, name);
                  },
                  onCategoryDelete: _showDeleteCategoryConfirmation,
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
                    AppToast.success(
                      context,
                      context.l10n.tagLibrary_entryMoved,
                    );
                  },
                  onEntryFavoriteDrop: (entryId) {
                    final index = state.entries.indexWhere(
                      (candidate) => candidate.id == entryId,
                    );
                    if (index >= 0 && !state.entries[index].isFavorite) {
                      ref
                          .read(tagLibraryPageNotifierProvider.notifier)
                          .toggleFavorite(entryId);
                    }
                  },
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  Future<void> _showCategoryPanel(TagLibraryPageState state) {
    return AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.tagLibrary_categories,
      initialChildSize: 0.76,
      builder: (panelContext, scrollController) => _buildCategorySidebar(
        state,
        forPanel: true,
        onCategorySelectionComplete: () => Navigator.of(panelContext).pop(),
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent(ThemeData theme, TagLibraryPageState state) {
    final entries = state.filteredEntries;

    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
        ),
      );
    }

    if (entries.isEmpty) {
      return _buildEmptyState(theme, state);
    }

    switch (state.viewMode) {
      case TagLibraryViewMode.card:
        return _buildCardGrid(theme, entries);
      case TagLibraryViewMode.list:
        return _buildListView(theme, entries);
      case TagLibraryViewMode.grouped:
        return GroupedEntriesView(
          scrollController: _groupedScrollController,
          onEdit: _showEditDialog,
          onDelete: _showDeleteEntryConfirmationForEntry,
          onSend: _showEntryDetail,
        );
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
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? context.l10n.tagLibrary_noSearchResults
                : (hasCategory
                      ? context.l10n.tagLibrary_categoryEmpty
                      : context.l10n.tagLibrary_empty),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? context.l10n.tagLibrary_tryDifferentSearch
                : context.l10n.tagLibrary_addFirstEntry,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建卡片网格
  Widget _buildCardGrid(ThemeData theme, List<TagLibraryEntry> entries) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final layout = computeTagLibraryGridLayout(
          constraints.maxWidth,
          textScale,
        );
        return GridView.builder(
          controller: _cardScrollController,
          padding: EdgeInsets.all(layout.padding),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: layout.maxCrossAxisExtent,
            mainAxisExtent: layout.mainAxisExtent,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _buildEntryItem(entries[index], true),
        );
      },
    );
  }

  /// 构建列表视图
  Widget _buildListView(ThemeData theme, List<TagLibraryEntry> entries) {
    return ListView.builder(
      controller: _listScrollController,
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
      return _agentResourceDrag(
        entry,
        EntryCard(
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
          onClassify: () => _classifyEntry(entry),
          onToggleFavorite: commonProps.onToggleFavorite,
        ),
      );
    }

    return _agentResourceDrag(
      entry,
      EntryListItem(
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
        onClassify: () => _classifyEntry(entry),
        onToggleFavorite: commonProps.onToggleFavorite,
      ),
    );
  }

  Widget _agentResourceDrag(TagLibraryEntry entry, Widget child) {
    // Native drag owns the long-press gesture; touch layouts reserve long press
    // for entering the library's selection mode.
    if (context.interactionPolicy.shouldExposeTouchAlternatives) return child;
    return AgentResourceDragSource(
      reference: AgentChatResourceReference(
        kind: AgentChatResourceKind.tagLibraryEntry,
        source: 'tag_library',
        resourceId: entry.id,
        display: {'name': entry.displayName},
      ),
      child: child,
    );
  }

  Future<void> _classifyEntry(TagLibraryEntry entry) async {
    final state = ref.read(tagLibraryPageNotifierProvider);
    final target = await BulkMoveCategoryDialog.show(
      context,
      categories: state.categories,
      currentCategoryId: entry.categoryId,
    );
    if (target == null || !mounted) return;
    await ref
        .read(tagLibraryPageNotifierProvider.notifier)
        .moveEntryToCategory(entry.id, target.isEmpty ? null : target);
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
      title: context.l10n.common_confirmDelete,
      content: context.l10n.tagLibrary_confirmDeleteSelectedEntries(
        selectedIds.length,
      ),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (!confirmed || !mounted) return;

    await ref
        .read(tagLibraryPageNotifierProvider.notifier)
        .deleteEntries(selectedIds);

    ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();

    if (mounted) {
      AppToast.success(
        context,
        context.l10n.tagLibrary_deletedEntries(selectedIds.length),
      );
    }
  }

  /// 批量转移分类
  Future<void> _handleBulkMoveCategory() async {
    final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    final state = ref.read(tagLibraryPageNotifierProvider);

    final targetCategoryId = await BulkMoveCategoryDialog.show(
      context,
      categories: state.categories,
      currentCategoryId: state.selectedCategoryId,
    );

    if (targetCategoryId == null || !mounted) return;

    // 执行批量移动
    for (final entryId in selectedIds) {
      await ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .moveEntryToCategory(
            entryId,
            targetCategoryId.isEmpty ? null : targetCategoryId,
          );
    }

    ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();

    if (mounted) {
      AppToast.success(
        context,
        context.l10n.tagLibrary_movedEntries(selectedIds.length),
      );
    }
  }

  /// 批量切换收藏
  Future<void> _handleBulkToggleFavorite() async {
    final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    // 检查是否全部已收藏
    final state = ref.read(tagLibraryPageNotifierProvider);
    final selectedEntries = state.entries.where(
      (e) => selectedIds.contains(e.id),
    );
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
            ? context.l10n.tagLibrary_unfavoritedEntries(selectedIds.length)
            : context.l10n.tagLibrary_favoritedEntries(selectedIds.length),
      );
    }
  }

  /// 批量复制内容
  Future<void> _handleBulkCopy() async {
    final selectionState = ref.read(tagLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    final state = ref.read(tagLibraryPageNotifierProvider);
    final selectedEntries = state.entries
        .where((e) => selectedIds.contains(e.id))
        .toList();

    // 按当前排序拼接内容
    final content = selectedEntries.map((e) => e.content).join(', ');

    await Clipboard.setData(ClipboardData(text: content));

    ref.read(tagLibrarySelectionNotifierProvider.notifier).exit();

    if (mounted) {
      AppToast.success(
        context,
        context.l10n.tagLibrary_copiedEntriesContent(selectedEntries.length),
      );
    }
  }

  /// 导入词库
  void _handleImport() {
    ImportDialog.show(context);
  }

  /// 导出词库
  void _handleExport() {
    final state = ref.read(tagLibraryPageNotifierProvider);
    ExportDialog.show(
      context,
      entries: state.entries,
      categories: state.categories,
    );
  }

  // ==================== 对话框方法 ====================

  void _showAddEntryDialog() {
    final state = ref.read(tagLibraryPageNotifierProvider);
    EntryAddDialog.show(
      context,
      categories: state.categories,
      initialCategoryId: state.selectedCategoryId,
    );
  }

  Future<void> _showAddCategoryDialog({String? parentId}) async {
    await AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.tagLibrary_newCategory,
      dialogWidth: 440,
      builder: (panelContext, scrollController) => _AddCategoryForm(
        scrollController: scrollController,
        onCreate: (name) async {
          final result = await ref
              .read(tagLibraryPageNotifierProvider.notifier)
              .addCategory(name: name, parentId: parentId);
          if (result != null) return true;
          if (panelContext.mounted) {
            AppToast.error(
              panelContext,
              panelContext.l10n.tagLibrary_categoryNameExists,
            );
          }
          return false;
        },
      ),
    );
  }

  Future<void> _showDeleteCategoryConfirmation(String categoryId) async {
    final state = ref.read(tagLibraryPageNotifierProvider);
    final category = state.categories.firstWhere((c) => c.id == categoryId);
    final entryCount = state.getCategoryEntryCount(categoryId);
    final l10n = context.l10n;

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: l10n.tagLibrary_deleteCategoryTitle,
      content: l10n.tagLibrary_deleteCategoryConfirm(
        category.displayName,
        entryCount.toString(),
      ),
      confirmText: l10n.common_delete,
      cancelText: l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;

    ref
        .read(tagLibraryPageNotifierProvider.notifier)
        .deleteCategory(categoryId);
  }

  void _showDeleteEntryConfirmation(String entryId) {
    final state = ref.read(tagLibraryPageNotifierProvider);
    final entry = state.entries.firstWhere((e) => e.id == entryId);
    _showDeleteEntryConfirmationForEntry(entry);
  }

  Future<void> _showDeleteEntryConfirmationForEntry(
    TagLibraryEntry entry,
  ) async {
    final l10n = context.l10n;
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: l10n.tagLibrary_deleteEntryTitle,
      content: l10n.tagLibrary_deleteEntryConfirm(entry.displayName),
      confirmText: l10n.common_delete,
      cancelText: l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;

    ref.read(tagLibraryPageNotifierProvider.notifier).deleteEntry(entry.id);
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
  ///
  /// 【新增】传入 sourceEntryId 建立双向同步关联
  Future<void> _handleSendToFixedTag(
    TagLibraryEntry entry,
    bool sendAsAlias,
  ) async {
    final parsed = CharacterPromptBlockParser.parse(entry.content);
    final content = sendAsAlias
        ? '<${entry.name}>'
        : SdToNaiConverter.convert(parsed.positivePrompt);

    await ref
        .read(fixedTagsNotifierProvider.notifier)
        .addEntry(
          name: entry.name,
          content: content,
          sourceEntryId: entry.id, // 【新增】建立关联，用于双向同步
          categoryId: entry.categoryId,
        );

    if (!mounted) return;
    AppToast.success(context, context.l10n.tagLibrary_addedToFixed);
  }

  /// 处理发送到主页
  Future<void> _handleSendToHome(
    TagLibraryEntry entry,
    SendOptions sendOptions,
  ) async {
    final content = _prepareContentForHome(entry, sendOptions);
    final parsed = CharacterPromptBlockParser.parse(entry.content);
    final sendsToCharacter =
        sendOptions.targetType == SendTargetType.replaceCharacter ||
        sendOptions.targetType == SendTargetType.appendCharacter ||
        sendOptions.targetType == SendTargetType.smartDecompose;

    ref
        .read(pendingPromptNotifierProvider.notifier)
        .set(
          prompt: content,
          negativePrompt: sendsToCharacter && parsed.hasNegativeBlock
              ? parsed.negativePrompt
              : null,
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
    final positivePrompt = CharacterPromptBlockParser.parse(
      entry.content,
    ).positivePrompt;
    final isPipeFormat = PipeParser.isPipeFormat(positivePrompt);
    final needsCharacterExtract =
        isPipeFormat &&
        (options.targetType == SendTargetType.replaceCharacter ||
            options.targetType == SendTargetType.appendCharacter);

    if (needsCharacterExtract) {
      final result = PipeParser.parse(positivePrompt);
      if (result.characters.isNotEmpty) {
        return result.characters.map((c) => c.prompt).join('\n| ');
      }
    }

    return positivePrompt;
  }

  /// 获取发送成功提示消息
  String _getSendSuccessMessage(SendTargetType targetType) {
    return switch (targetType) {
      SendTargetType.mainPrompt => context.l10n.sendToHome_successMainPrompt,
      SendTargetType.smartDecompose => context.l10n.toast_smartDecomposeSent,
      SendTargetType.replaceCharacter =>
        context.l10n.sendToHome_successReplaceCharacter,
      SendTargetType.appendCharacter =>
        context.l10n.sendToHome_successAppendCharacter,
      SendTargetType.fixedTag => context.l10n.toast_addedToFixedTags,
    };
  }

  void _showEditDialog(TagLibraryEntry entry) {
    final state = ref.read(tagLibraryPageNotifierProvider);
    EntryAddDialog.show(context, categories: state.categories, entry: entry);
  }
}

class _AddCategoryForm extends StatefulWidget {
  const _AddCategoryForm({
    required this.scrollController,
    required this.onCreate,
  });

  final ScrollController scrollController;
  final Future<bool> Function(String name) onCreate;

  @override
  State<_AddCategoryForm> createState() => _AddCategoryFormState();
}

class _AddCategoryFormState extends State<_AddCategoryForm> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final created = await widget.onCreate(name);
    if (!mounted) return;
    if (created) {
      Navigator.of(context).pop();
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('tag-library-add-category-form'),
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          enabled: !_submitting,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.l10n.tagLibrary_categoryNameHint,
            filled: true,
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: MediaQuery.disableAnimationsOf(context)
                            ? 0.72
                            : null,
                      ),
                    )
                  : Text(context.l10n.common_create),
            ),
          ],
        ),
      ],
    );
  }
}

@immutable
class TagLibraryGridLayout {
  const TagLibraryGridLayout({
    required this.maxCrossAxisExtent,
    required this.mainAxisExtent,
    required this.padding,
  });

  final double maxCrossAxisExtent;
  final double mainAxisExtent;
  final double padding;
}

TagLibraryGridLayout computeTagLibraryGridLayout(
  double availableWidth,
  double textScale,
) {
  final compact = availableWidth < 600;
  final effectiveScale = textScale.clamp(1.0, 3.0);
  return TagLibraryGridLayout(
    maxCrossAxisExtent: compact ? 280 : 240,
    mainAxisExtent: 80 + (effectiveScale - 1) * 12,
    padding: compact ? 12 : 16,
  );
}
