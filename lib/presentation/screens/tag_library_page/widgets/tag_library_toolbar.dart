import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../providers/tag_library_selection_provider.dart';
import '../../../widgets/autocomplete/autocomplete_config.dart';
import '../../../widgets/common/input_surface_container.dart';
import '../../../widgets/autocomplete/autocomplete_wrapper.dart';
import '../../../widgets/bulk_action_bar.dart';
import '../../../widgets/gallery/gallery_sidebar.dart';

/// 词库工具栏（搜索、视图切换、批量操作）
class TagLibraryToolbar extends ConsumerStatefulWidget {
  /// 紧凑布局中打开分类列表。
  final VoidCallback? onShowCategories;

  /// 进入选择模式按钮回调
  final VoidCallback? onEnterSelectionMode;

  /// 批量删除回调
  final VoidCallback? onBulkDelete;

  /// 批量转移分类回调
  final VoidCallback? onBulkMoveCategory;

  /// 批量切换收藏回调
  final VoidCallback? onBulkToggleFavorite;

  /// 批量复制内容回调
  final VoidCallback? onBulkCopy;

  /// 导入回调
  final VoidCallback? onImport;

  /// 导出回调
  final VoidCallback? onExport;

  /// 添加条目回调
  final VoidCallback? onAddEntry;

  /// 窄屏分类抽屉入口
  final VoidCallback? onOpenCategories;

  /// Persistent sidebars own page identity; compact layouts keep it here.
  final bool showPageTitle;

  const TagLibraryToolbar({
    super.key,
    this.onShowCategories,
    this.onEnterSelectionMode,
    this.onBulkDelete,
    this.onBulkMoveCategory,
    this.onBulkToggleFavorite,
    this.onBulkCopy,
    this.onImport,
    this.onExport,
    this.onAddEntry,
    this.onOpenCategories,
    this.showPageTitle = true,
  });

  @override
  ConsumerState<TagLibraryToolbar> createState() => _TagLibraryToolbarState();
}

class _TagLibraryToolbarState extends ConsumerState<TagLibraryToolbar> {
  static const double _sortMenuWidth = 176;

  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode(onKeyEvent: _handleSearchKeyEvent);
    _syncSearchController(ref.read(tagLibraryPageNotifierProvider).searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(
      tagLibraryPageNotifierProvider.select((state) => state.searchQuery),
      (_, next) => _syncSearchController(next),
    );

    final state = ref.watch(tagLibraryPageNotifierProvider);
    final selectionState = ref.watch(tagLibrarySelectionNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 获取当前筛选后的所有条目 ID
    final allEntryIds = state.filteredEntries.map((e) => e.id).toList();
    final isAllSelected =
        allEntryIds.isNotEmpty &&
        allEntryIds.every((id) => selectionState.selectedIds.contains(id));

    // 选择模式时显示批量操作栏
    if (selectionState.isActive) {
      return BulkActionBar(
        selectedCount: selectionState.selectedIds.length,
        isAllSelected: isAllSelected,
        onExit: () =>
            ref.read(tagLibrarySelectionNotifierProvider.notifier).exit(),
        onSelectAll: () {
          if (isAllSelected) {
            ref
                .read(tagLibrarySelectionNotifierProvider.notifier)
                .clearSelection();
          } else {
            ref
                .read(tagLibrarySelectionNotifierProvider.notifier)
                .selectAll(allEntryIds);
          }
        },
        actions: [
          BulkActionItem(
            icon: Icons.drive_file_move_outline,
            label: context.l10n.tagLibrary_transferCategory,
            onPressed: widget.onBulkMoveCategory,
            color: theme.colorScheme.secondary,
          ),
          BulkActionItem(
            icon: Icons.copy,
            label: context.l10n.tagLibrary_copyContent,
            onPressed: widget.onBulkCopy,
            color: theme.colorScheme.tertiary,
          ),
          BulkActionItem(
            icon: Icons.favorite_outline,
            label: context.l10n.common_favorite,
            onPressed: widget.onBulkToggleFavorite,
            color: Colors.pink,
          ),
          BulkActionItem(
            icon: Icons.delete_outline,
            label: context.l10n.common_delete,
            onPressed: widget.onBulkDelete,
            color: theme.colorScheme.error,
            isDanger: true,
            showDividerBefore: true,
          ),
        ],
      );
    }

    // 普通工具栏
    return Container(
      key: const Key('tag-library-toolbar'),
      padding: GalleryCollectionChrome.toolbarPadding(context),
      constraints: const BoxConstraints(
        minHeight: GalleryCollectionChrome.toolbarHeight,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.3),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final compact = constraints.maxWidth < 900 || textScale > 1.5;
          final stackPrimary = textScale > 1.5;
          final addButton = FilledButton.icon(
            key: const Key('tag-library-add-entry-button'),
            onPressed: widget.onAddEntry,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.tagLibrary_addEntry),
            style: FilledButton.styleFrom(
              minimumSize: Size(
                80,
                context.interactionPolicy.shouldExposeTouchAlternatives
                    ? 48
                    : 40,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              visualDensity: VisualDensity.standard,
            ),
          );
          final openCategories =
              widget.onShowCategories ?? widget.onOpenCategories;
          final categoriesButton = openCategories == null
              ? null
              : _CompactIconButton(
                  key: const Key('tag-library-categories-button'),
                  icon: Icons.account_tree_outlined,
                  label: context.l10n.common_categories,
                  onPressed: openCategories,
                );

          Widget buildActions() {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 排序下拉菜单
                _buildSortDropdown(theme, state),
                const SizedBox(width: 8),

                // 视图切换
                _buildViewModeToggle(theme, state),

                const SizedBox(width: 8),

                // 分隔线
                Container(
                  width: 1,
                  height: 24,
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 8),

                // 多选按钮
                _CompactIconButton(
                  icon: Icons.checklist,
                  label: context.l10n.common_multiSelect,
                  onPressed: widget.onEnterSelectionMode,
                ),
                const SizedBox(width: 6),

                // 导入按钮
                _CompactIconButton(
                  icon: Icons.file_upload_outlined,
                  label: context.l10n.common_import,
                  onPressed: widget.onImport,
                ),
                const SizedBox(width: 6),

                // 导出按钮
                _CompactIconButton(
                  icon: Icons.file_download_outlined,
                  label: context.l10n.common_export,
                  onPressed: state.entries.isEmpty ? null : widget.onExport,
                ),
              ],
            );
          }

          if (compact) {
            final primaryControls = stackPrimary
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchField(theme, state),
                      const SizedBox(height: 8),
                      if (categoriesButton != null) ...[
                        categoriesButton,
                        const SizedBox(height: 8),
                      ],
                      addButton,
                    ],
                  )
                : Row(
                    children: [
                      if (categoriesButton != null) ...[
                        categoriesButton,
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: _buildSearchField(theme, state)),
                      const SizedBox(width: 8),
                      addButton,
                    ],
                  );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showPageTitle) ...[
                  Text(
                    context.l10n.nav_dictionary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                primaryControls,
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: buildActions(),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              if (widget.showPageTitle) ...[
                Text(
                  context.l10n.nav_dictionary,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (categoriesButton != null) ...[
                categoriesButton,
                const SizedBox(width: 8),
              ],
              addButton,
              const SizedBox(width: 12),
              Expanded(child: _buildSearchField(theme, state)),
              const SizedBox(width: 12),
              buildActions(),
            ],
          );
        },
      ),
    );
  }

  void _syncSearchController(String query) {
    if (_searchController.text == query) return;

    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
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

  /// 构建搜索框
  Widget _buildSearchField(ThemeData theme, TagLibraryPageState state) {
    void updateSearch(String value) {
      ref.read(tagLibraryPageNotifierProvider.notifier).setSearchQuery(value);
    }

    return AutocompleteWrapper(
      controller: _searchController,
      focusNode: _searchFocusNode,
      config: const AutocompleteConfig(
        autoInsertComma: false,
        treatSpacesAsSeparators: true,
      ),
      onSuggestionSelected: updateSearch,
      child: InputSurfaceContainer(
        height: context.interactionPolicy.shouldExposeTouchAlternatives
            ? 48
            : 36,
        borderRadius: 18,
        isFocused: _searchFocusNode.hasFocus,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: theme.textTheme.bodyMedium,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: context.l10n.tagLibrary_searchHint,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      updateSearch('');
                    },
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
          onChanged: updateSearch,
        ),
      ),
    );
  }

  /// 构建视图切换按钮
  Widget _buildViewModeToggle(ThemeData theme, TagLibraryPageState state) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeButton(
            icon: Icons.view_list_rounded,
            isSelected: state.viewMode == TagLibraryViewMode.list,
            onTap: () => ref
                .read(tagLibraryPageNotifierProvider.notifier)
                .setViewMode(TagLibraryViewMode.list),
          ),
          _ViewModeButton(
            icon: Icons.grid_view_rounded,
            isSelected: state.viewMode == TagLibraryViewMode.card,
            onTap: () => ref
                .read(tagLibraryPageNotifierProvider.notifier)
                .setViewMode(TagLibraryViewMode.card),
          ),
          _ViewModeButton(
            icon: Icons.folder_copy_outlined,
            isSelected: state.viewMode == TagLibraryViewMode.grouped,
            onTap: () => ref
                .read(tagLibraryPageNotifierProvider.notifier)
                .setViewMode(TagLibraryViewMode.grouped),
          ),
        ],
      ),
    );
  }

  /// 构建排序菜单
  Widget _buildSortDropdown(ThemeData theme, TagLibraryPageState state) {
    final items = <(TagLibrarySortBy, IconData, String)>[
      (TagLibrarySortBy.order, Icons.sort, context.l10n.tagLibrary_sortCustom),
      (
        TagLibrarySortBy.name,
        Icons.sort_by_alpha,
        context.l10n.tagLibrary_sortName,
      ),
      (
        TagLibrarySortBy.useCount,
        Icons.trending_up,
        context.l10n.tagLibrary_sortUseCount,
      ),
      (
        TagLibrarySortBy.updatedAt,
        Icons.access_time,
        context.l10n.tagLibrary_sortUpdatedAt,
      ),
    ];
    final selected = items.firstWhere((item) => item.$1 == state.sortBy);

    return MenuAnchor(
      key: const Key('tag-library-sort-menu-anchor'),
      useRootOverlay: true,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        minimumSize: const WidgetStatePropertyAll(Size(_sortMenuWidth, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(_sortMenuWidth, 280)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4),
        ),
        backgroundColor: WidgetStatePropertyAll(
          theme.colorScheme.surfaceContainerHigh,
        ),
      ),
      menuChildren: [
        for (final item in items)
          MenuItemButton(
            key: ValueKey('tag-library-sort-option-${item.$1.name}'),
            onPressed: () => ref
                .read(tagLibraryPageNotifierProvider.notifier)
                .setSortBy(item.$1),
            leadingIcon: Icon(item.$2, size: 16),
            trailingIcon: state.sortBy == item.$1
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  )
                : null,
            child: Text(item.$3),
          ),
      ],
      builder: (context, controller, child) {
        return Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: const Key('tag-library-sort-menu-button'),
            onTap: controller.isOpen ? controller.close : controller.open,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: context.interactionPolicy.shouldExposeTouchAlternatives
                  ? 48
                  : 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected.$2,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selected.$3,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
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
          ),
        );
      },
    );
  }
}

/// 视图模式切换按钮
class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: BoxConstraints(
            minWidth: context.interactionPolicy.shouldExposeTouchAlternatives
                ? 48
                : 34,
            minHeight: context.interactionPolicy.shouldExposeTouchAlternatives
                ? 48
                : 34,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// 紧凑图标按钮
class _CompactIconButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;

  const _CompactIconButton({
    super.key,
    required this.icon,
    this.label,
    this.onPressed,
  });

  @override
  State<_CompactIconButton> createState() => _CompactIconButtonState();
}

class _CompactIconButtonState extends State<_CompactIconButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null;
    final hasLabel = widget.label != null && widget.label!.isNotEmpty;

    Color iconColor;
    Color labelColor;
    Color bgColor;

    iconColor = isEnabled
        ? (_isHovered
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: isDark ? 0.85 : 0.75,
                ))
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
    labelColor = isEnabled
        ? (_isHovered
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.85 : 0.75,
                ))
        : theme.colorScheme.onSurface.withValues(alpha: 0.35);
    bgColor = _isPressed
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.14)
        : (_isHovered
              ? theme.colorScheme.primary.withValues(
                  alpha: isDark ? 0.14 : 0.08,
                )
              : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.6)));
    return MouseRegion(
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Tooltip(
        message: widget.label ?? '',
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: isEnabled
              ? (_) {
                  setState(() => _isPressed = true);
                  _scaleController.forward();
                }
              : null,
          onTapUp: isEnabled
              ? (_) {
                  setState(() => _isPressed = false);
                  _scaleController.reverse();
                }
              : null,
          onTapCancel: isEnabled
              ? () {
                  setState(() => _isPressed = false);
                  _scaleController.reverse();
                }
              : null,
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 - ((1 - _scaleAnimation.value) * 0.25),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  constraints: BoxConstraints(
                    minHeight:
                        context.interactionPolicy.shouldExposeTouchAlternatives
                        ? 48
                        : 34,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: hasLabel ? 12 : 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 17, color: iconColor),
                      if (hasLabel) ...[
                        const SizedBox(width: 6),
                        Text(
                          widget.label!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: labelColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
