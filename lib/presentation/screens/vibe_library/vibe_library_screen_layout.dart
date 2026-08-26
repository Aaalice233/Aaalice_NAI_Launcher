part of 'vibe_library_screen.dart';

enum _VibeToolbarAction { export, openFolder }

extension _VibeLibraryScreenLayout on _VibeLibraryScreenState {
  /// 构建工具栏
  Widget _buildToolbar(
    VibeLibraryState state,
    SelectionModeState selectionState,
    ThemeData theme, {
    required bool showCategoryPanel,
    required VoidCallback onToggleCategoryPanel,
    required bool compact,
  }) {
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
          child: compact
              ? _buildCompactToolbar(
                  state,
                  theme,
                  showCategoryPanel: showCategoryPanel,
                  onToggleCategoryPanel: onToggleCategoryPanel,
                )
              : Row(
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
                      icon: showCategoryPanel
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                      label: context.l10n.common_categories,
                      tooltip: showCategoryPanel
                          ? context.l10n.vibeLibrary_hideCategoryPanel
                          : context.l10n.vibeLibrary_showCategoryPanel,
                      onPressed: onToggleCategoryPanel,
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
                    // 空库只保留主体中的主导入入口，避免重复动作。
                    if (state.entries.isNotEmpty) ...[
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
                    ],
                    // 导出按钮
                    CompactIconButton(
                      icon: Icons.file_upload_outlined,
                      label: context.l10n.common_export,
                      tooltip: context.l10n.vibeLibrary_exportTooltip,
                      onPressed: state.entries.isEmpty
                          ? null
                          : () => _exportVibes(),
                    ),
                    const SizedBox(width: 6),
                    // 打开文件夹按钮
                    if (PlatformCapabilities.current.supportsOpenFolder) ...[
                      CompactIconButton(
                        icon: Icons.folder_open_outlined,
                        label: context.l10n.common_folder,
                        tooltip: context.l10n.vibeLibrary_openFolderTooltip,
                        onPressed: () => _openVibeLibraryFolder(),
                      ),
                      const SizedBox(width: 6),
                    ],
                    // 刷新按钮
                    _buildRefreshButton(state, theme),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCompactToolbar(
    VibeLibraryState state,
    ThemeData theme, {
    required bool showCategoryPanel,
    required VoidCallback onToggleCategoryPanel,
  }) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      l10n.vibeLibrary_title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!state.isLoading) ...[
                    const SizedBox(width: 8),
                    Text(
                      state.hasFilters
                          ? '${state.filteredCount}/${state.totalCount}'
                          : '${state.totalCount}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onToggleCategoryPanel,
              tooltip: l10n.common_categories,
              icon: Icon(
                showCategoryPanel
                    ? Icons.view_sidebar
                    : Icons.view_sidebar_outlined,
              ),
            ),
            IconButton(
              onPressed: () => ref
                  .read(vibeLibrarySelectionNotifierProvider.notifier)
                  .enter(),
              tooltip: l10n.vibeLibrary_enterSelectionMode,
              icon: const Icon(Icons.checklist),
            ),
            PopupMenuButton<_VibeToolbarAction>(
              tooltip: l10n.nav_more,
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case _VibeToolbarAction.export:
                    unawaited(_exportVibes());
                    return;
                  case _VibeToolbarAction.openFolder:
                    unawaited(_openVibeLibraryFolder());
                    return;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _VibeToolbarAction.export,
                  enabled: state.entries.isNotEmpty,
                  child: ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: Text(l10n.common_export),
                  ),
                ),
                if (PlatformCapabilities.current.supportsOpenFolder)
                  PopupMenuItem(
                    value: _VibeToolbarAction.openFolder,
                    child: ListTile(
                      leading: const Icon(Icons.folder_open_outlined),
                      title: Text(l10n.common_folder),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSearchField(theme, state, touch: true)),
            const SizedBox(width: 4),
            _buildSortButton(theme, state, touch: true),
            if (state.entries.isNotEmpty) ...[
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: (_isImporting || _isPickingFile)
                    ? null
                    : () => _importVibes(),
                tooltip: l10n.vibeLibrary_importTooltip,
                icon: _isPickingFile
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
              ),
            ],
            const SizedBox(width: 4),
            _buildRefreshButton(state, theme, touch: true),
          ],
        ),
      ],
    );
  }

  /// 构建搜索框
  Widget _buildSearchField(
    ThemeData theme,
    VibeLibraryState state, {
    bool touch = false,
  }) {
    return InputSurfaceContainer(
      height: touch ? 48 : 36,
      constraints: touch ? null : const BoxConstraints(maxWidth: 300),
      borderRadius: touch ? 16 : 18,
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyMedium,
        textAlignVertical: TextAlignVertical.center,
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
  Widget _buildSortButton(
    ThemeData theme,
    VibeLibraryState state, {
    bool touch = false,
  }) {
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
        height: touch ? 48 : 36,
        constraints: touch ? const BoxConstraints(minWidth: 48) : null,
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
            Icon(sortIcon, size: touch ? 20 : 16),
            if (!touch) ...[
              const SizedBox(width: 4),
              Text(sortLabel, style: const TextStyle(fontSize: 12)),
            ],
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
  Widget _buildRefreshButton(
    VibeLibraryState state,
    ThemeData theme, {
    bool touch = false,
  }) {
    if (state.isLoading) {
      return Container(
        height: touch ? 48 : 36,
        constraints: touch ? const BoxConstraints(minWidth: 48) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
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
            if (!touch) ...[
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
          ],
        ),
      );
    }

    return CompactIconButton(
      icon: Icons.refresh,
      label: touch ? null : context.l10n.vibeLibrary_refresh,
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
    final currentModel = ref.watch(
      generationParamsNotifierProvider.select((params) => params.model),
    );
    final canMarkEncodingModel =
        ModelCapabilityRegistry.of(currentModel).supportsVibeTransfer &&
        NovelAiVibeCodec.normalizeModelOrNull(currentModel) != null;

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
        if (canMarkEncodingModel)
          BulkActionItem(
            icon: Icons.model_training_outlined,
            label: context.l10n.vibeLibrary_markEncodingModel,
            onPressed: _isMarkingEncodingModel
                ? null
                : () => _batchMarkEncodingModel(),
            color: theme.colorScheme.secondary,
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
      return VibeLibraryEmptyView(onImport: _importVibes);
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

  /// 构建导入进度覆盖层
  Widget _buildImportOverlay(ThemeData theme) {
    final hasProgress = _importProgress.isActive;
    final progressValue = _importProgress.progress;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    value: progressValue,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.vibeLibrary_importing,
                  style: theme.textTheme.titleMedium,
                ),
                if (hasProgress) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_importProgress.current} / ${_importProgress.total}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_importProgress.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _importProgress.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
