import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../providers/gallery_folder_provider.dart';
import '../bulk_action_bar.dart';
import '../gallery_filter_panel.dart';
import '../grouped_grid_view.dart' show ImageDateGroup;
import 'folder_tabs.dart';

import '../common/app_toast.dart';

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
  final VoidCallback? onAddToCollection;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onExportSelected;
  final VoidCallback? onEditMetadata;
  final VoidCallback? onMoveToFolder;

  /// Whether category panel is visible
  /// 是否显示分类面板
  final bool showCategoryPanel;

  /// Callback when category panel toggle is pressed
  /// 分类面板切换按钮回调
  final VoidCallback? onToggleCategoryPanel;

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
    this.onAddToCollection,
    this.onDeleteSelected,
    this.onExportSelected,
    this.onEditMetadata,
    this.onMoveToFolder,
    this.showCategoryPanel = true,
    this.onToggleCategoryPanel,
  });

  @override
  ConsumerState<LocalGalleryToolbar> createState() =>
      _LocalGalleryToolbarState();
}

class _LocalGalleryToolbarState extends ConsumerState<LocalGalleryToolbar> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show bulk action bar when in selection mode
    // 选择模式时显示批量操作栏
    if (selectionState.isActive) {
      final allImagePaths = state.currentImages.map((r) => r.path).toList();
      final isAllSelected = allImagePaths.isNotEmpty &&
          allImagePaths.every((p) => selectionState.selectedIds.contains(p));

      return BulkActionBar(
        onExit: () =>
            ref.read(localGallerySelectionNotifierProvider.notifier).exit(),
        onAddToCollection: selectionState.selectedIds.isNotEmpty
            ? widget.onAddToCollection
            : null,
        onDelete: selectionState.selectedIds.isNotEmpty
            ? widget.onDeleteSelected
            : null,
        onExport: selectionState.selectedIds.isNotEmpty
            ? widget.onExportSelected
            : null,
        onEditMetadata: selectionState.selectedIds.isNotEmpty
            ? widget.onEditMetadata
            : null,
        onSelectAll: () {
          if (isAllSelected) {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .clearSelection();
          } else {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .selectAll(allImagePaths);
          }
        },
        onMoveToFolder: selectionState.selectedIds.isNotEmpty
            ? widget.onMoveToFolder
            : null,
        isAllSelected: isAllSelected,
        totalCount: allImagePaths.length,
      );
    }

    // Normal toolbar
    // 普通工具栏
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.9)
                : theme.colorScheme.surface.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.3),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Single row: title + count + search + filter/action buttons
              Row(
                children: [
                  // Title
                  Text(
                    '本地画廊',
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
                                .withOpacity(0.4)
                            : theme.colorScheme.primaryContainer
                                .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
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
                  Expanded(
                    child: _buildSearchField(theme, state),
                  ),
                  const SizedBox(width: 8),
                  // Filter button group
                  _buildDateRangeButton(theme, state),
                  const SizedBox(width: 6),
                  _CompactIconButton(
                    icon: Icons.calendar_today,
                    label: '日期',
                    onPressed: () => _pickDateAndJump(context),
                  ),
                  const SizedBox(width: 6),
                  _CompactIconButton(
                    icon: Icons.tune,
                    label: '筛选',
                    onPressed: () => showGalleryFilterPanel(context),
                  ),
                  // Note: View mode toggle removed - only 3D card view is supported now
                  if (state.hasFilters) ...[
                    const SizedBox(width: 6),
                    _CompactIconButton(
                      icon: Icons.filter_alt_off,
                      label: '清除',
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
                      color: theme.dividerColor.withOpacity(0.3),
                    ),
                  ),
                  // Category panel toggle
                  if (widget.onToggleCategoryPanel != null) ...[
                    _CompactIconButton(
                      icon: widget.showCategoryPanel
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                      label: '分类',
                      tooltip: widget.showCategoryPanel ? '隐藏分类面板' : '显示分类面板',
                      onPressed: widget.onToggleCategoryPanel,
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Undo/Redo
                  if (widget.canUndo || widget.canRedo) ...[
                    _CompactIconButton(
                      icon: Icons.undo,
                      tooltip: '撤销',
                      onPressed: widget.canUndo ? widget.onUndo : null,
                    ),
                    const SizedBox(width: 4),
                    _CompactIconButton(
                      icon: Icons.redo,
                      tooltip: '重做',
                      onPressed: widget.canRedo ? widget.onRedo : null,
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Multi-select
                  _CompactIconButton(
                    icon: Icons.checklist,
                    label: '多选',
                    onPressed: widget.onEnterSelectionMode,
                  ),
                  const SizedBox(width: 6),
                  // Open folder
                  _CompactIconButton(
                    icon: Icons.folder_open,
                    label: '文件夹',
                    onPressed: widget.onOpenFolder,
                  ),
                  const SizedBox(width: 6),
                  // Refresh
                  state.isIndexing
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _CompactIconButton(
                          icon: Icons.refresh,
                          label: '刷新',
                          onPressed: widget.onRefresh,
                        ),
                ],
              ),
              const SizedBox(height: 6),
              // Folder tabs
              FolderTabs(
                onFolderSelected: (folderId) {
                  final folderState = ref.read(galleryFolderNotifierProvider);
                  final selectedFolder = folderState.selectedFolder;
                  ref
                      .read(localGalleryNotifierProvider.notifier)
                      .filterByFolder(selectedFolder?.path);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build search field
  /// 构建搜索框 - Modern glass-style design
  Widget _buildSearchField(ThemeData theme, LocalGalleryState state) {
    return _ModernSearchField(
      controller: _searchController,
      hintText: '搜索文件名或 Prompt...',
      onChanged: (value) {
        setState(() {}); // Update clear button visibility
        _onSearchChanged(value);
      },
      onSubmitted: (value) {
        _debounceTimer?.cancel();
        ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
      },
      onClear: () {
        _searchController.clear();
        ref.read(localGalleryNotifierProvider.notifier).setSearchQuery('');
      },
    );
  }

  /// Build date range button
  /// 构建日期范围按钮
  Widget _buildDateRangeButton(ThemeData theme, LocalGalleryState state) {
    final hasDateRange = state.dateStart != null || state.dateEnd != null;

    return OutlinedButton.icon(
      onPressed: () => _selectDateRange(context, state),
      icon: Icon(
        Icons.date_range,
        size: 16,
        color: hasDateRange ? theme.colorScheme.primary : null,
      ),
      label: Text(
        hasDateRange
            ? _formatDateRange(state.dateStart, state.dateEnd)
            : '日期过滤',
        style: TextStyle(
          fontSize: 12,
          color: hasDateRange ? theme.colorScheme.primary : null,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
        side:
            hasDateRange ? BorderSide(color: theme.colorScheme.primary) : null,
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
      initialDateRange: state.dateStart != null && state.dateEnd != null
          ? DateTimeRange(start: state.dateStart!, end: state.dateEnd!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(localGalleryNotifierProvider.notifier).setDateRange(
            picked.start,
            picked.end,
          );
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
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
        (widget.groupedGridViewKey!.currentState as dynamic)
            .scrollToGroup(targetGroup);
      }

      // Show hint message
      if (context.mounted) {
        AppToast.info(
          context,
          '已跳转到 ${picked.year}-${picked.month.toString().padLeft(2, '0')}',
        );
      }
    }
  }
}

/// Modern search field with glass-morphism style
/// 现代搜索框 - 毛玻璃风格 + 精致设计
class _ModernSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const _ModernSearchField({
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  State<_ModernSearchField> createState() => _ModernSearchFieldState();
}

class _ModernSearchFieldState extends State<_ModernSearchField>
    with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  bool _isHovered = false;
  final FocusNode _focusNode = FocusNode();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
        if (_focusNode.hasFocus) {
          _pulseController.forward().then((_) => _pulseController.reverse());
        }
      }
    });

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasText = widget.controller.text.isNotEmpty;

    // Premium glass-morphism color scheme
    final bgColor = isDark
        ? (_isFocused
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.85)
            : (_isHovered
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.7)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.55)))
        : (_isFocused
            ? Colors.white.withOpacity(0.95)
            : (_isHovered
                ? Colors.white.withOpacity(0.85)
                : Colors.white.withOpacity(0.7)));

    final borderColor = _isFocused
        ? theme.colorScheme.primary.withOpacity(isDark ? 0.8 : 0.6)
        : (_isHovered
            ? theme.colorScheme.primary.withOpacity(isDark ? 0.4 : 0.25)
            : theme.colorScheme.outline.withOpacity(isDark ? 0.25 : 0.18));

    final iconColor = _isFocused
        ? theme.colorScheme.primary
        : (_isHovered
            ? theme.colorScheme.primary.withOpacity(0.7)
            : theme.colorScheme.onSurfaceVariant
                .withOpacity(isDark ? 0.6 : 0.55));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.text,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 38,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: _isFocused ? 1.8 : 1.2,
          ),
          boxShadow: [
            if (_isFocused) ...[
              BoxShadow(
                color:
                    theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
              BoxShadow(
                color:
                    theme.colorScheme.primary.withOpacity(isDark ? 0.08 : 0.05),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ] else if (_isHovered)
              BoxShadow(
                color:
                    theme.colorScheme.shadow.withOpacity(isDark ? 0.15 : 0.08),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Search icon with pulse animation
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isFocused ? _pulseAnimation.value : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isFocused
                            ? theme.colorScheme.primary
                                .withOpacity(isDark ? 0.15 : 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: iconColor,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Text field
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant
                        .withOpacity(isDark ? 0.5 : 0.4),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
              ),
            ),
            // Clear button with better styling
            if (hasText)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _MicroIconButton(
                  icon: Icons.close_rounded,
                  size: 16,
                  onPressed: widget.onClear,
                ),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

/// Micro icon button for search field clear
/// 搜索框清除按钮
class _MicroIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onPressed;

  const _MicroIconButton({
    required this.icon,
    this.size = 18,
    this.onPressed,
  });

  @override
  State<_MicroIconButton> createState() => _MicroIconButtonState();
}

class _MicroIconButtonState extends State<_MicroIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.onSurfaceVariant
                    .withOpacity(isDark ? 0.15 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: theme.colorScheme.onSurfaceVariant
                .withOpacity(isDark ? 0.7 : 0.6),
          ),
        ),
      ),
    );
  }
}

/// Compact icon button for toolbar - Premium modern style
/// 工具栏紧凑图标按钮 - 精致现代风格
class _CompactIconButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool isDanger;
  final bool isPrimary;

  const _CompactIconButton({
    required this.icon,
    this.label,
    this.tooltip,
    this.onPressed,
    this.isDanger = false,
    this.isPrimary = false,
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
    Color borderColor;
    List<BoxShadow>? shadows;

    if (widget.isDanger) {
      iconColor = isEnabled
          ? theme.colorScheme.error
          : theme.colorScheme.error.withOpacity(0.4);
      labelColor = iconColor;
      bgColor = _isPressed
          ? theme.colorScheme.error.withOpacity(isDark ? 0.28 : 0.18)
          : (_isHovered
              ? theme.colorScheme.error.withOpacity(isDark ? 0.2 : 0.12)
              : theme.colorScheme.error.withOpacity(isDark ? 0.08 : 0.04));
      borderColor = _isHovered
          ? theme.colorScheme.error.withOpacity(isDark ? 0.6 : 0.4)
          : theme.colorScheme.error.withOpacity(isDark ? 0.3 : 0.2);
      if (_isHovered && isEnabled) {
        shadows = [
          BoxShadow(
            color: theme.colorScheme.error.withOpacity(isDark ? 0.2 : 0.12),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ];
      }
    } else if (widget.isPrimary) {
      iconColor = isEnabled
          ? (_isHovered ? Colors.white : theme.colorScheme.primary)
          : theme.colorScheme.primary.withOpacity(0.4);
      labelColor = iconColor;
      bgColor = _isPressed
          ? theme.colorScheme.primary.withOpacity(isDark ? 0.95 : 0.9)
          : (_isHovered
              ? theme.colorScheme.primary.withOpacity(isDark ? 0.85 : 0.8)
              : theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.1));
      borderColor = _isHovered
          ? theme.colorScheme.primary
          : theme.colorScheme.primary.withOpacity(isDark ? 0.5 : 0.4);
      if (_isHovered && isEnabled) {
        shadows = [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(isDark ? 0.35 : 0.25),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ];
      }
    } else {
      iconColor = isEnabled
          ? (_isHovered
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant
                  .withOpacity(isDark ? 0.85 : 0.75))
          : theme.colorScheme.onSurfaceVariant.withOpacity(0.35);
      labelColor = isEnabled
          ? (_isHovered
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(isDark ? 0.85 : 0.75))
          : theme.colorScheme.onSurface.withOpacity(0.35);
      bgColor = _isPressed
          ? theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.14)
          : (_isHovered
              ? theme.colorScheme.primary.withOpacity(isDark ? 0.14 : 0.08)
              : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.white.withOpacity(0.6)));
      borderColor = _isHovered
          ? theme.colorScheme.primary.withOpacity(isDark ? 0.5 : 0.35)
          : theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.15);
      if (_isHovered && isEnabled) {
        shadows = [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ];
      }
    }

    return MouseRegion(
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Tooltip(
        message: widget.tooltip ?? widget.label ?? '',
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
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
                scale: _scaleAnimation.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: hasLabel ? 12 : 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: borderColor,
                      width: _isHovered ? 1.4 : 1.0,
                    ),
                    boxShadow: shadows,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: 17,
                        color: iconColor,
                      ),
                      if (hasLabel) ...[
                        const SizedBox(width: 6),
                        Text(
                          widget.label!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: labelColor,
                            fontSize: 12.5,
                            fontWeight:
                                _isHovered ? FontWeight.w600 : FontWeight.w500,
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
