part of 'vibe_library_screen.dart';

extension _VibeLibraryScreenLayout on _VibeLibraryScreenState {
  /// 构建工具栏
  Widget _buildToolbar(
    VibeLibraryState state,
    SelectionModeState selectionState,
    ThemeData theme,
  ) {
    // 选择模式时显示批量操作栏
    if (selectionState.isActive) {
      return _buildBulkActionBar(state, selectionState, theme);
    }

    // 普通工具栏
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9)
                : theme.colorScheme.surface.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.2 : 0.3,
                ),
              ),
            ),
          ),
          child: Row(
            children: [
              // 标题
              Text(
                context.l10n.vibeLibrary_title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // 数量
              if (!state.isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.4,
                          )
                        : theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    state.hasFilters
                        ? '${state.filteredCount}/${state.totalCount}'
                        : '${state.totalCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              // 搜索框
              Expanded(child: _buildSearchField(theme, state)),
              const SizedBox(width: 8),
              // 排序按钮
              _buildSortButton(theme, state),
              const SizedBox(width: 6),
              // 分类面板切换
              CompactIconButton(
                icon: _showCategoryPanel
                    ? Icons.view_sidebar
                    : Icons.view_sidebar_outlined,
                label: context.l10n.common_categories,
                tooltip: _showCategoryPanel
                    ? context.l10n.vibeLibrary_hideCategoryPanel
                    : context.l10n.vibeLibrary_showCategoryPanel,
                onPressed: () {
                  _updateLayoutState(() {
                    _showCategoryPanel = !_showCategoryPanel;
                  });
                },
              ),
              const SizedBox(width: 6),
              // 选择模式
              CompactIconButton(
                icon: Icons.checklist,
                label: context.l10n.common_multiSelect,
                tooltip: context.l10n.vibeLibrary_enterSelectionMode,
                onPressed: () {
                  ref
                      .read(vibeLibrarySelectionNotifierProvider.notifier)
                      .enter();
                },
              ),
              const SizedBox(width: 6),
              // 导入按钮（支持右键菜单）
              GestureDetector(
                onSecondaryTapDown: (details) {
                  if (!(_isImporting || _isPickingFile)) {
                    _showImportMenu(details.globalPosition);
                  }
                },
                child: CompactIconButton(
                  icon: Icons.file_download_outlined,
                  label: context.l10n.common_import,
                  tooltip: context.l10n.vibeLibrary_importTooltip,
                  isLoading: _isPickingFile,
                  onPressed: (_isImporting || _isPickingFile)
                      ? null
                      : () => _importVibes(),
                ),
              ),
              const SizedBox(width: 6),
              // 导出按钮
              CompactIconButton(
                icon: Icons.file_upload_outlined,
                label: context.l10n.common_export,
                tooltip: context.l10n.vibeLibrary_exportTooltip,
                onPressed: state.entries.isEmpty ? null : () => _exportVibes(),
              ),
              const SizedBox(width: 6),
              // 打开文件夹按钮
              CompactIconButton(
                icon: Icons.folder_open_outlined,
                label: context.l10n.common_folder,
                tooltip: context.l10n.vibeLibrary_openFolderTooltip,
                onPressed: () => _openVibeLibraryFolder(),
              ),
              const SizedBox(width: 6),
              // 刷新按钮
              _buildRefreshButton(state, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建搜索框
  Widget _buildSearchField(ThemeData theme, VibeLibraryState state) {
    return Container(
      height: 36,
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: context.l10n.vibeLibrary_searchHint,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  onPressed: () {
                    _searchDebounceTimer?.cancel();
                    _searchController.clear();
                    ref
                        .read(vibeLibraryNotifierProvider.notifier)
                        .clearSearch();
                    _updateLayoutState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: (value) {
          _updateLayoutState(() {});
          _searchDebounceTimer?.cancel();
          _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
            if (!mounted) {
              return;
            }
            ref
                .read(vibeLibraryNotifierProvider.notifier)
                .setSearchQuery(value);
          });
        },
        onSubmitted: (value) {
          ref.read(vibeLibraryNotifierProvider.notifier).setSearchQuery(value);
        },
      ),
    );
  }

  /// 构建排序按钮
  Widget _buildSortButton(ThemeData theme, VibeLibraryState state) {
    IconData sortIcon;
    String sortLabel;

    switch (state.sortOrder) {
      case VibeLibrarySortOrder.createdAt:
        sortIcon = Icons.access_time;
        sortLabel = context.l10n.vibeSelectorSortCreated;
      case VibeLibrarySortOrder.lastUsed:
        sortIcon = Icons.history;
        sortLabel = context.l10n.vibeSelectorSortLastUsed;
      case VibeLibrarySortOrder.usedCount:
        sortIcon = Icons.trending_up;
        sortLabel = context.l10n.vibeSelectorSortUsedCount;
      case VibeLibrarySortOrder.name:
        sortIcon = Icons.sort_by_alpha;
        sortLabel = context.l10n.vibeSelectorSortName;
    }

    return PopupMenuButton<VibeLibrarySortOrder>(
      tooltip: context.l10n.vibeLibrary_sortTooltip,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sortIcon, size: 16),
            const SizedBox(width: 4),
            Text(sortLabel, style: const TextStyle(fontSize: 12)),
            Icon(
              state.sortDescending
                  ? Icons.arrow_drop_down
                  : Icons.arrow_drop_up,
              size: 16,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _buildSortMenuItem(
          VibeLibrarySortOrder.createdAt,
          context.l10n.vibeSelectorSortCreated,
          Icons.access_time,
          state,
        ),
        _buildSortMenuItem(
          VibeLibrarySortOrder.lastUsed,
          context.l10n.vibeSelectorSortLastUsed,
          Icons.history,
          state,
        ),
        _buildSortMenuItem(
          VibeLibrarySortOrder.usedCount,
          context.l10n.vibeSelectorSortUsedCount,
          Icons.trending_up,
          state,
        ),
        _buildSortMenuItem(
          VibeLibrarySortOrder.name,
          context.l10n.vibeSelectorSortName,
          Icons.sort_by_alpha,
          state,
        ),
      ],
      onSelected: (order) {
        ref.read(vibeLibraryNotifierProvider.notifier).setSortOrder(order);
      },
    );
  }

  PopupMenuItem<VibeLibrarySortOrder> _buildSortMenuItem(
    VibeLibrarySortOrder order,
    String label,
    IconData icon,
    VibeLibraryState state,
  ) {
    final isSelected = state.sortOrder == order;
    return PopupMenuItem(
      value: order,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.blue : null),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue : null,
              fontWeight: isSelected ? FontWeight.w600 : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              state.sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
              size: 16,
              color: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  /// 构建刷新按钮
  Widget _buildRefreshButton(VibeLibraryState state, ThemeData theme) {
    if (state.isLoading) {
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.vibeLibrary_loading,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return CompactIconButton(
      icon: Icons.refresh,
      label: context.l10n.vibeLibrary_refresh,
      tooltip: context.l10n.vibeLibrary_refresh,
      onPressed: () {
        ref
            .read(vibeLibraryNotifierProvider.notifier)
            .reload(syncFileSystem: true, showLoading: true);
      },
    );
  }

  /// 构建批量操作栏
  Widget _buildBulkActionBar(
    VibeLibraryState state,
    SelectionModeState selectionState,
    ThemeData theme,
  ) {
    final currentIds = state.currentEntries.map((e) => e.id).toList();
    final isAllSelected =
        currentIds.isNotEmpty &&
        currentIds.every((id) => selectionState.selectedIds.contains(id));

    return BulkActionBar(
      selectedCount: selectionState.selectedIds.length,
      isAllSelected: isAllSelected,
      onExit: () {
        ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
      },
      onSelectAll: () {
        if (isAllSelected) {
          ref
              .read(vibeLibrarySelectionNotifierProvider.notifier)
              .clearSelection();
        } else {
          ref
              .read(vibeLibrarySelectionNotifierProvider.notifier)
              .selectAll(currentIds);
        }
      },
      actions: [
        BulkActionItem(
          icon: Icons.send,
          label: context.l10n.vibeLibrary_sendToGeneration,
          onPressed: () => _batchSendToGeneration(),
          color: theme.colorScheme.primary,
        ),
        BulkActionItem(
          icon: Icons.drive_file_move_outline,
          label: context.l10n.common_move,
          onPressed: () => _showMoveToCategoryDialog(context),
          color: theme.colorScheme.secondary,
        ),
        BulkActionItem(
          icon: Icons.file_upload_outlined,
          label: context.l10n.common_export,
          onPressed: () => _batchExport(),
          color: theme.colorScheme.secondary,
        ),
        BulkActionItem(
          icon: Icons.favorite_border,
          label: context.l10n.common_favorite,
          onPressed: () => _batchToggleFavorite(),
          color: theme.colorScheme.primary,
        ),
        BulkActionItem(
          icon: Icons.delete_outline,
          label: context.l10n.common_delete,
          onPressed: () => _batchDelete(),
          color: theme.colorScheme.error,
          isDanger: true,
          showDividerBefore: true,
        ),
      ],
    );
  }

  /// 构建主体内容
  Widget _buildBody(
    VibeLibraryState state,
    int columns,
    double itemWidth,
    SelectionModeState selectionState,
  ) {
    if (state.error != null) {
      return GalleryErrorView(
        error: state.error,
        onRetry: () {
          ref
              .read(vibeLibraryNotifierProvider.notifier)
              .reload(syncFileSystem: true, showLoading: true);
        },
      );
    }

    if (state.isInitializing && state.entries.isEmpty) {
      return const GalleryLoadingView();
    }

    if (state.entries.isEmpty) {
      return const VibeLibraryEmptyView();
    }

    return VibeLibraryContentView(columns: columns, itemWidth: itemWidth);
  }

  /// 构建分页条
  Widget _buildPaginationBar(VibeLibraryState state, double contentWidth) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: state.currentPage > 0
                ? () {
                    ref
                        .read(vibeLibraryNotifierProvider.notifier)
                        .loadPreviousPage();
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.vibeLibrary_pageIndicator(
                state.currentPage + 1,
                state.totalPages,
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: state.currentPage < state.totalPages - 1
                ? () {
                    ref
                        .read(vibeLibraryNotifierProvider.notifier)
                        .loadNextPage();
                  }
                : null,
          ),
          const SizedBox(width: 16),
          Text(
            context.l10n.vibeLibrary_itemsPerPage,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: state.pageSize,
            underline: const SizedBox(),
            items: [20, 50, 100].map((size) {
              return DropdownMenuItem(value: size, child: Text('$size'));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(vibeLibraryNotifierProvider.notifier)
                    .setPageSize(value);
              }
            },
          ),
          const Spacer(),
          Text(
            context.l10n.vibeLibrary_totalCount(state.filteredCount.toString()),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
