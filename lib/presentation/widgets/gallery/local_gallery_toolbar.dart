import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../bulk_action_bar.dart';
import '../common/compact_icon_button.dart';
import '../common/input_surface_container.dart';
import '../gallery_filter_panel.dart';
import '../grouped_grid_view.dart' show ImageDateGroup;

import '../common/app_toast.dart';
import '../autocomplete/autocomplete_config.dart';
import '../autocomplete/autocomplete_wrapper.dart';

enum _LocalGalleryToolbarAction {
  date,
  toggleGrouped,
  clearFilters,
  undo,
  redo,
  openFolder,
}

/// Local gallery toolbar with search, filter and actions
/// 本地画廊工具栏（搜索、过滤、操作按钮）
class LocalGalleryToolbar extends ConsumerStatefulWidget {
  /// Whether 3D card view mode is active
  /// 是否启用3D卡片视图模式
  final bool use3DCardView;

  /// Callback when view mode is toggled
  /// 视图模式切换回调
  final VoidCallback? onToggleViewMode;

  /// Callback when open folder button is pressed
  /// 打开文件夹按钮回调
  final VoidCallback? onOpenFolder;

  /// Callback when refresh button is pressed
  /// 刷新按钮回调
  final VoidCallback? onRefresh;

  /// Callback when enter selection mode button is pressed
  /// 进入选择模式按钮回调
  final VoidCallback? onEnterSelectionMode;

  /// Callback when undo button is pressed
  /// 撤销按钮回调
  final VoidCallback? onUndo;

  /// Callback when redo button is pressed
  /// 重做按钮回调
  final VoidCallback? onRedo;

  /// Whether undo is available
  /// 是否可撤销
  final bool canUndo;

  /// Whether redo is available
  /// 是否可重做
  final bool canRedo;

  /// Key for GroupedGridView to scroll to group
  /// 用于滚动到分组的 GroupedGridView key
  final GlobalKey? groupedGridViewKey;

  /// Callbacks for bulk actions
  /// 批量操作回调
  final VoidCallback? onAddToAlbum;
  final VoidCallback? onRemoveFromAlbum;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onPackSelected;
  final VoidCallback? onEditMetadata;
  final VoidCallback? onMoveToCategory;

  /// Whether category panel is visible
  /// 是否显示分类面板
  final bool showCategoryPanel;

  /// Callback when category panel toggle is pressed
  /// 分类面板切换按钮回调
  final VoidCallback? onToggleCategoryPanel;

  /// Whether search autocomplete is enabled.
  /// 是否启用搜索自动补全。
  final bool enableSearchAutocomplete;

  const LocalGalleryToolbar({
    super.key,
    this.use3DCardView = true,
    this.onToggleViewMode,
    this.onOpenFolder,
    this.onRefresh,
    this.onEnterSelectionMode,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
    this.groupedGridViewKey,
    this.onAddToAlbum,
    this.onRemoveFromAlbum,
    this.onDeleteSelected,
    this.onPackSelected,
    this.onEditMetadata,
    this.onMoveToCategory,
    this.showCategoryPanel = true,
    this.onToggleCategoryPanel,
    this.enableSearchAutocomplete = true,
  });

  @override
  ConsumerState<LocalGalleryToolbar> createState() =>
      _LocalGalleryToolbarState();
}

class _LocalGalleryToolbarState extends ConsumerState<LocalGalleryToolbar> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode(onKeyEvent: _handleSearchKeyEvent);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    // Future 不需要 dispose
    super.dispose();
  }

  /// Search with debounce
  /// 搜索防抖
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
    });
  }

  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyA) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    return KeyEventResult.handled;
  }

  Future<void> _selectAllFilteredImages() async {
    final paths = await ref
        .read(localGalleryNotifierProvider.notifier)
        .getFilteredImagePaths();
    if (!mounted) return;

    ref
        .read(localGallerySelectionNotifierProvider.notifier)
        .replaceSelection(paths);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;

    // Show bulk action bar when in selection mode
    // 选择模式时显示批量操作栏
    if (selectionState.isActive) {
      final currentPageImagePaths = state.currentImages
          .map((r) => r.path)
          .toList();
      final isCurrentPageSelected =
          currentPageImagePaths.isNotEmpty &&
          currentPageImagePaths.every(
            (p) => selectionState.selectedIds.contains(p),
          );
      final selectableResultCount = state.hasFilters
          ? state.filteredCount
          : state.totalCount;
      final isAllResultSelected =
          selectableResultCount > 0 &&
          selectionState.selectedIds.length == selectableResultCount;

      return BulkActionBar(
        selectedCount: selectionState.selectedIds.length,
        isAllSelected: isCurrentPageSelected,
        isAllAvailableSelected: isAllResultSelected,
        onExit: () =>
            ref.read(localGallerySelectionNotifierProvider.notifier).exit(),
        onSelectAll: () {
          if (isCurrentPageSelected) {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .deselectAll(currentPageImagePaths);
          } else {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .selectAll(currentPageImagePaths);
          }
        },
        onSelectAllAvailable: selectableResultCount > 0
            ? () {
                if (isAllResultSelected) {
                  ref
                      .read(localGallerySelectionNotifierProvider.notifier)
                      .clearSelection();
                } else {
                  unawaited(_selectAllFilteredImages());
                }
              }
            : null,
        selectAllLabel: l10n.localGallery_selectCurrentPage,
        deselectAllLabel: l10n.localGallery_deselectCurrentPage,
        selectAllAvailableLabel: l10n.localGallery_selectAllResults,
        deselectAllAvailableLabel: l10n.localGallery_deselectAllResults,
        actions: [
          BulkActionItem(
            icon: Icons.drive_file_move_outline,
            label: l10n.localGallery_moveSelected,
            onPressed: widget.onMoveToCategory,
            color: theme.colorScheme.secondary,
          ),
          BulkActionItem(
            icon: Icons.archive_outlined,
            label: l10n.localGallery_packSelected,
            onPressed: widget.onPackSelected,
            color: theme.colorScheme.tertiary,
          ),
          BulkActionItem(
            icon: Icons.edit_outlined,
            label: l10n.localGallery_editMetadata,
            onPressed: widget.onEditMetadata,
            color: theme.colorScheme.primary,
          ),
          BulkActionItem(
            icon: Icons.playlist_add,
            label: l10n.localGallery_addToAlbum,
            onPressed: widget.onAddToAlbum,
            color: theme.colorScheme.secondary,
          ),
          if (widget.onRemoveFromAlbum != null)
            BulkActionItem(
              icon: Icons.playlist_remove,
              label: l10n.localGallery_removeFromAlbum,
              onPressed: widget.onRemoveFromAlbum,
              color: theme.colorScheme.secondary,
            ),
          BulkActionItem(
            icon: Icons.delete_outline,
            label: l10n.common_delete,
            onPressed: widget.onDeleteSelected,
            color: theme.colorScheme.error,
            isDanger: true,
            showDividerBefore: true,
          ),
        ],
      );
    }

    // Normal toolbar
    // 普通工具栏
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9)
                : theme.colorScheme.surface.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.3),
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final useCompactToolbar = constraints.maxWidth / textScale < 1050;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (useCompactToolbar)
                    _buildCompactToolbar(
                      theme,
                      state,
                      stackTitle: constraints.maxWidth < 400 || textScale >= 2,
                    )
                  else
                    Row(
                      key: const ValueKey('localGalleryDesktopToolbar'),
                      children: [
                        // Title
                        Text(
                          l10n.localGallery_title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Image count
                        if (!state.isIndexing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.4)
                                  : theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              state.hasFilters
                                  ? '${state.filteredCount}/${state.totalCount}'
                                  : '${state.totalCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        // Search field (expanded)
                        Expanded(child: _buildSearchField(theme, state)),
                        const SizedBox(width: 8),
                        // Filter button group
                        _buildDateRangeButton(theme, state),
                        const SizedBox(width: 6),
                        // 日期分组视图切换按钮
                        CompactIconButton(
                          icon: state.isGroupedView
                              ? Icons.view_module
                              : Icons.calendar_today,
                          label: state.isGroupedView
                              ? l10n.common_grid
                              : l10n.common_date,
                          tooltip: state.isGroupedView
                              ? l10n.localGallery_switchToGridView
                              : l10n.localGallery_switchToDateGroupedView,
                          shortcutId: ShortcutIds.jumpToDate,
                          isActive: state.isGroupedView,
                          onPressed: () {
                            if (state.isGroupedView) {
                              // 退出分组视图
                              ref
                                  .read(localGalleryNotifierProvider.notifier)
                                  .setGroupedView(false);
                            } else {
                              // 进入分组视图
                              _pickDateAndJump(context);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        CompactIconButton(
                          icon: Icons.tune,
                          label: l10n.common_filter,
                          tooltip: l10n.localGallery_openFilterPanel,
                          shortcutId: ShortcutIds.openFilterPanel,
                          onPressed: () => showGalleryFilterPanel(context),
                        ),
                        // Note: View mode toggle removed - only 3D card view is supported now
                        if (state.hasFilters) ...[
                          const SizedBox(width: 6),
                          CompactIconButton(
                            icon: Icons.filter_alt_off,
                            label: l10n.common_clear,
                            tooltip: l10n.localGallery_clearFilters,
                            shortcutId: ShortcutIds.clearFilter,
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(localGalleryNotifierProvider.notifier)
                                  .clearAllFilters();
                            },
                            isDanger: true,
                          ),
                        ],
                        // Divider
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            width: 1,
                            height: 24,
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        // Category panel toggle
                        if (widget.onToggleCategoryPanel != null) ...[
                          CompactIconButton(
                            icon: widget.showCategoryPanel
                                ? Icons.view_sidebar
                                : Icons.view_sidebar_outlined,
                            label: l10n.common_categories,
                            tooltip: widget.showCategoryPanel
                                ? l10n.localGallery_hideCategoryPanel
                                : l10n.localGallery_showCategoryPanel,
                            shortcutId: ShortcutIds.toggleCategoryPanel,
                            onPressed: widget.onToggleCategoryPanel,
                          ),
                          const SizedBox(width: 6),
                        ],
                        // Undo/Redo
                        if (widget.canUndo || widget.canRedo) ...[
                          CompactIconButton(
                            icon: Icons.undo,
                            tooltip: l10n.common_undo,
                            onPressed: widget.canUndo ? widget.onUndo : null,
                          ),
                          const SizedBox(width: 4),
                          CompactIconButton(
                            icon: Icons.redo,
                            tooltip: l10n.common_redo,
                            onPressed: widget.canRedo ? widget.onRedo : null,
                          ),
                          const SizedBox(width: 6),
                        ],
                        // Multi-select
                        CompactIconButton(
                          icon: Icons.checklist,
                          label: l10n.common_multiSelect,
                          tooltip: l10n.localGallery_enterSelectionMode,
                          shortcutId: ShortcutIds.enterSelectionMode,
                          onPressed: widget.onEnterSelectionMode,
                        ),
                        const SizedBox(width: 6),
                        // Open folder
                        CompactIconButton(
                          icon: Icons.folder_open,
                          label: l10n.common_folder,
                          tooltip: l10n.shortcut_action_open_folder,
                          shortcutId: ShortcutIds.openFolder,
                          onPressed: widget.onOpenFolder,
                        ),
                        const SizedBox(width: 6),
                        // Refresh button
                        CompactIconButton(
                          icon: Icons.refresh,
                          label: l10n.common_refresh,
                          tooltip: l10n.localGallery_refreshTooltip,
                          shortcutId: ShortcutIds.refreshGallery,
                          onPressed: widget.onRefresh,
                        ),
                      ],
                    ),
                  if (state.filterCriteria.selectedTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildSelectedTagChips(theme, state),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactToolbar(
    ThemeData theme,
    LocalGalleryState state, {
    required bool stackTitle,
  }) {
    final l10n = context.l10n;
    final minimumControlExtent = context.interactionPolicy.minimumControlExtent;
    final title = Text(
      l10n.localGallery_title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    final search = _buildSearchField(
      theme,
      state,
      touch: true,
      showResultCount: true,
    );

    return Column(
      key: const ValueKey('localGalleryCompactToolbar'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stackTitle) ...[
          title,
          const SizedBox(height: 8),
          search,
        ] else
          Row(
            key: const ValueKey('localGalleryMobileSearchRow'),
            children: [
              Flexible(flex: 0, child: title),
              const SizedBox(width: 12),
              Expanded(child: search),
            ],
          ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minimumControlExtent),
          child: SingleChildScrollView(
            key: const ValueKey('localGalleryMobileActionBar'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (widget.onToggleCategoryPanel != null) ...[
                  _buildCompactActionButton(
                    icon: widget.showCategoryPanel
                        ? Icons.view_sidebar
                        : Icons.view_sidebar_outlined,
                    label: l10n.common_categories,
                    tooltip: widget.showCategoryPanel
                        ? l10n.localGallery_hideCategoryPanel
                        : l10n.localGallery_showCategoryPanel,
                    onPressed: widget.onToggleCategoryPanel,
                  ),
                  const SizedBox(width: 4),
                ],
                _buildCompactActionButton(
                  icon: Icons.tune,
                  label: l10n.common_filter,
                  tooltip: l10n.localGallery_openFilterPanel,
                  onPressed: () => showGalleryFilterPanel(context),
                ),
                const SizedBox(width: 4),
                _buildCompactActionButton(
                  icon: state.isGroupedView
                      ? Icons.view_module
                      : Icons.calendar_today,
                  label: state.isGroupedView
                      ? l10n.common_grid
                      : l10n.common_date,
                  tooltip: state.isGroupedView
                      ? l10n.localGallery_switchToGridView
                      : l10n.localGallery_switchToDateGroupedView,
                  onPressed: () {
                    if (state.isGroupedView) {
                      ref
                          .read(localGalleryNotifierProvider.notifier)
                          .setGroupedView(false);
                    } else {
                      _pickDateAndJump(context);
                    }
                  },
                ),
                const SizedBox(width: 4),
                _buildCompactActionButton(
                  icon: Icons.checklist,
                  label: l10n.common_multiSelect,
                  tooltip: l10n.localGallery_enterSelectionMode,
                  onPressed: widget.onEnterSelectionMode,
                ),
                const SizedBox(width: 4),
                _buildCompactActionButton(
                  icon: Icons.refresh,
                  label: l10n.common_refresh,
                  tooltip: l10n.localGallery_refreshTooltip,
                  onPressed: widget.onRefresh,
                ),
                _buildCompactOverflow(theme, state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final minimumControlExtent = context.interactionPolicy.minimumControlExtent;
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          minimumSize: Size(0, minimumControlExtent),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildCompactOverflow(ThemeData theme, LocalGalleryState state) {
    final l10n = context.l10n;
    final minimumControlExtent = context.interactionPolicy.minimumControlExtent;
    return SizedBox.square(
      dimension: minimumControlExtent,
      child: PopupMenuButton<_LocalGalleryToolbarAction>(
        tooltip: l10n.nav_more,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          switch (action) {
            case _LocalGalleryToolbarAction.date:
              _pickDateAndJump(context);
              return;
            case _LocalGalleryToolbarAction.toggleGrouped:
              if (state.isGroupedView) {
                ref
                    .read(localGalleryNotifierProvider.notifier)
                    .setGroupedView(false);
              } else {
                _pickDateAndJump(context);
              }
              return;
            case _LocalGalleryToolbarAction.clearFilters:
              _searchController.clear();
              ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
              return;
            case _LocalGalleryToolbarAction.undo:
              widget.onUndo?.call();
              return;
            case _LocalGalleryToolbarAction.redo:
              widget.onRedo?.call();
              return;
            case _LocalGalleryToolbarAction.openFolder:
              widget.onOpenFolder?.call();
              return;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _LocalGalleryToolbarAction.date,
            child: ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(l10n.common_date),
            ),
          ),
          PopupMenuItem(
            value: _LocalGalleryToolbarAction.toggleGrouped,
            child: ListTile(
              leading: Icon(
                state.isGroupedView ? Icons.view_module : Icons.calendar_today,
              ),
              title: Text(
                state.isGroupedView
                    ? l10n.common_grid
                    : l10n.localGallery_switchToDateGroupedView,
              ),
            ),
          ),
          if (state.hasFilters)
            PopupMenuItem(
              value: _LocalGalleryToolbarAction.clearFilters,
              child: ListTile(
                leading: Icon(
                  Icons.filter_alt_off,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  l10n.localGallery_clearFilters,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          if (widget.canUndo)
            PopupMenuItem(
              value: _LocalGalleryToolbarAction.undo,
              child: ListTile(
                leading: const Icon(Icons.undo),
                title: Text(l10n.common_undo),
              ),
            ),
          if (widget.canRedo)
            PopupMenuItem(
              value: _LocalGalleryToolbarAction.redo,
              child: ListTile(
                leading: const Icon(Icons.redo),
                title: Text(l10n.common_redo),
              ),
            ),
          if (widget.onOpenFolder != null)
            PopupMenuItem(
              value: _LocalGalleryToolbarAction.openFolder,
              child: ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(l10n.common_folder),
              ),
            ),
        ],
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(localGalleryNotifierProvider.notifier).setSearchQuery('');
    setState(() {});
  }

  /// Build search field
  /// 构建搜索框 - 类似在线画廊的简洁圆角样式
  Widget _buildSearchField(
    ThemeData theme,
    LocalGalleryState state, {
    bool touch = false,
    bool showResultCount = false,
  }) {
    final searchField = InputSurfaceContainer(
      height: touch ? 48 : 36,
      constraints: touch ? null : const BoxConstraints(maxWidth: 300),
      borderRadius: touch ? 16 : 18,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: theme.textTheme.bodyMedium,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: context.l10n.localGallery_searchFilenamePromptPlaceholder,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          suffixIcon: showResultCount
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!state.isIndexing)
                      Text(
                        state.hasFilters
                            ? '${state.filteredCount}/${state.totalCount}'
                            : '${state.totalCount}',
                        key: const ValueKey(
                          'localGalleryMobileSearchResultCount',
                        ),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        tooltip: context.l10n.common_clear,
                        onPressed: _clearSearch,
                      )
                    else
                      const SizedBox(width: 12),
                  ],
                )
              : _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  tooltip: context.l10n.common_clear,
                  onPressed: _clearSearch,
                )
              : null,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {}); // 更新清除按钮可见性
          _onSearchChanged(value);
        },
        onSubmitted: (value) {
          _debounceTimer?.cancel();
          ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
        },
      ),
    );

    if (!widget.enableSearchAutocomplete) {
      return searchField;
    }

    return AutocompleteWrapper(
      controller: _searchController,
      focusNode: _searchFocusNode,
      config: const AutocompleteConfig(
        minQueryLength: 2,
        showTranslation: true,
        showCategory: true,
        showCount: true,
        autoInsertComma: false,
      ),
      onSuggestionSelected: (value) {
        // 选择补全建议后仍然作为搜索框文本处理，不转为标签 chip。
        _debounceTimer?.cancel();
        ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
      },
      child: searchField,
    );
  }

  Widget _buildSelectedTagChips(ThemeData theme, LocalGalleryState state) {
    final tags = state.filterCriteria.selectedTags;

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              context.l10n.localGallery_tagIntersection,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final tag in tags)
            InputChip(
              avatar: const Icon(Icons.tag, size: 14),
              label: Text(tag),
              onDeleted: () {
                ref
                    .read(localGalleryNotifierProvider.notifier)
                    .removeSelectedTag(tag);
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );
  }

  /// Build date range button
  /// 构建日期范围按钮
  Widget _buildDateRangeButton(ThemeData theme, LocalGalleryState state) {
    final hasDateRange =
        state.filterCriteria.dateStart != null ||
        state.filterCriteria.dateEnd != null;

    return OutlinedButton.icon(
      onPressed: () => _selectDateRange(context, state),
      icon: Icon(
        Icons.date_range,
        size: 16,
        color: hasDateRange ? theme.colorScheme.primary : null,
      ),
      label: Text(
        hasDateRange
            ? _formatDateRange(
                state.filterCriteria.dateStart,
                state.filterCriteria.dateEnd,
              )
            : context.l10n.localGallery_dateFilterButton,
        style: TextStyle(
          fontSize: 12,
          color: hasDateRange ? theme.colorScheme.primary : null,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
        side: hasDateRange
            ? BorderSide(color: theme.colorScheme.primary)
            : null,
      ),
    );
  }

  /// Format date range display
  /// 格式化日期范围显示
  String _formatDateRange(DateTime? start, DateTime? end) {
    final format = DateFormat('MM-dd');
    if (start != null && end != null) {
      return '${format.format(start)}~${format.format(end)}';
    } else if (start != null) {
      return '${format.format(start)}~';
    } else if (end != null) {
      return '~${format.format(end)}';
    }
    return '';
  }

  /// Select date range
  /// 选择日期范围
  Future<void> _selectDateRange(
    BuildContext context,
    LocalGalleryState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange:
          state.filterCriteria.dateStart != null &&
              state.filterCriteria.dateEnd != null
          ? DateTimeRange(
              start: state.filterCriteria.dateStart!,
              end: state.filterCriteria.dateEnd!,
            )
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref
          .read(localGalleryNotifierProvider.notifier)
          .setDateRange(picked.start, picked.end);
    }
  }

  /// Pick date and jump to corresponding group
  /// 选择日期并跳转到对应分组
  Future<void> _pickDateAndJump(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (pickerContext, child) {
        return Theme(
          data: Theme.of(pickerContext).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      // Ensure grouped view is activated
      final currentState = ref.read(localGalleryNotifierProvider);
      final notifier = ref.read(localGalleryNotifierProvider.notifier);
      if (!currentState.isGroupedView) {
        notifier.setGroupedView(true);
      }

      // Wait for grouped data to load
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Calculate which group the selected date belongs to
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final selectedDate = DateTime(picked.year, picked.month, picked.day);

      ImageDateGroup? targetGroup;

      if (selectedDate == today) {
        targetGroup = ImageDateGroup.today;
      } else if (selectedDate == yesterday) {
        targetGroup = ImageDateGroup.yesterday;
      } else if (selectedDate.isAfter(thisWeekStart) &&
          selectedDate.isBefore(today)) {
        targetGroup = ImageDateGroup.thisWeek;
      } else {
        targetGroup = ImageDateGroup.earlier;
      }

      // Jump to corresponding group using the key
      if (widget.groupedGridViewKey?.currentState != null) {
        (widget.groupedGridViewKey!.currentState as dynamic).scrollToGroup(
          targetGroup,
        );
      }

      // Show hint message
      if (context.mounted) {
        final month = picked.month.toString().padLeft(2, '0');
        AppToast.info(
          context,
          context.l10n.localGallery_jumpedToMonth(picked.year, month),
        );
      }
    }
  }
}
