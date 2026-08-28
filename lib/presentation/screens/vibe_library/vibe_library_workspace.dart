import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/constants/model_capabilities.dart';
import '../../../data/models/vibe/vibe_import_progress.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/novelai_vibe_codec.dart';
import '../../providers/selection_mode_provider.dart';
import '../../providers/vibe_library_category_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/common/compact_icon_button.dart';
import '../../widgets/common/input_surface_container.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import 'vibe_library_commands.dart';
import 'vibe_library_screen_controller.dart';
import 'widgets/category/vibe_category_tree_view.dart';
import 'widgets/vibe_library_content_view.dart';
import 'widgets/vibe_library_empty_view.dart';

class VibeLibraryWorkspace extends StatelessWidget {
  const VibeLibraryWorkspace({
    super.key,
    required this.libraryState,
    required this.categoryState,
    required this.selectionState,
    required this.currentModel,
    required this.controller,
    required this.onCommand,
  });

  final VibeLibraryState libraryState;
  final VibeLibraryCategoryState categoryState;
  final SelectionModeState selectionState;
  final String currentModel;
  final VibeLibraryScreenController controller;
  final ValueChanged<VibeLibraryCommand> onCommand;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const categoryPanelWidth = 260.0;
        final persistent = constraints.maxWidth >= 1000;
        final showCategories = controller.showCategoryPanel && persistent;
        final contentWidth =
            constraints.maxWidth - (showCategories ? categoryPanelWidth : 0);
        const gridPadding = 32.0;
        const gridSpacing = vibeLibraryGridSpacing;
        final gridWidth = (contentWidth - gridPadding).clamp(
          0.0,
          double.infinity,
        );
        final columns = ((gridWidth + gridSpacing) / (170 + gridSpacing))
            .floor()
            .clamp(1, 8);
        final itemWidth = (gridWidth - gridSpacing * (columns - 1)) / columns;

        final content = Stack(
          children: [
            Row(
              children: [
                if (showCategories)
                  _CategoryPanel(
                    libraryState: libraryState,
                    categoryState: categoryState,
                    onCommand: onCommand,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _Toolbar(
                        libraryState: libraryState,
                        selectionState: selectionState,
                        currentModel: currentModel,
                        controller: controller,
                        compact: contentWidth < 1050,
                        showCategoryPanel: showCategories,
                        usePersistentCategories: persistent,
                        onCommand: onCommand,
                      ),
                      Expanded(
                        child: _Body(
                          state: libraryState,
                          columns: columns,
                          itemWidth: itemWidth,
                          onCommand: onCommand,
                        ),
                      ),
                      if (!libraryState.isLoading &&
                          libraryState.filteredEntries.isNotEmpty &&
                          libraryState.totalPages > 0)
                        _PaginationBar(
                          state: libraryState,
                          compact: contentWidth < 700,
                          onCommand: onCommand,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (controller.isDragging) const _DropOverlay(),
            if (controller.isImporting)
              _ImportOverlay(progress: controller.importProgress),
          ],
        );

        if (!PlatformCapabilities.current.supportsExternalFileDrop) {
          return content;
        }
        return DropRegion(
          formats: Formats.standardFormats,
          hitTestBehavior: HitTestBehavior.opaque,
          onDropOver: (event) {
            if (!event.session.allowedOperations.contains(DropOperation.copy)) {
              return DropOperation.none;
            }
            controller.setDragging(true);
            return DropOperation.copy;
          },
          onDropLeave: (_) => controller.setDragging(false),
          onPerformDrop: (event) async {
            controller.setDragging(false);
            onCommand(PerformVibeDropCommand(event));
          },
          child: content,
        );
      },
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.libraryState,
    required this.categoryState,
    required this.onCommand,
  });

  final VibeLibraryState libraryState;
  final VibeLibraryCategoryState categoryState;
  final ValueChanged<VibeLibraryCommand> onCommand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
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
                    context.l10n.vibeLibrary_categories,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => onCommand(const CreateCategoryCommand()),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    context.l10n.common_new,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: VibeCategoryTreeView(
              categories: categoryState.categories,
              totalEntryCount: libraryState.entries.length,
              favoriteCount: libraryState.favoriteCount,
              selectedCategoryId: categoryState.selectedCategoryId,
              onCategorySelected: (id) => onCommand(SelectCategoryCommand(id)),
              onCategoryRename: (id, name) async =>
                  onCommand(RenameCategoryCommand(id, name)),
              onCategoryDelete: (id) async =>
                  onCommand(DeleteCategoryCommand(id)),
              onAddSubCategory: (id) async =>
                  onCommand(CreateCategoryCommand(parentId: id)),
              onCategoryMove: (id, parentId) async =>
                  onCommand(MoveCategoryCommand(id, parentId)),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ToolbarMenuAction { export, openFolder }

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.libraryState,
    required this.selectionState,
    required this.currentModel,
    required this.controller,
    required this.compact,
    required this.showCategoryPanel,
    required this.usePersistentCategories,
    required this.onCommand,
  });

  final VibeLibraryState libraryState;
  final SelectionModeState selectionState;
  final String currentModel;
  final VibeLibraryScreenController controller;
  final bool compact;
  final bool showCategoryPanel;
  final bool usePersistentCategories;
  final ValueChanged<VibeLibraryCommand> onCommand;

  @override
  Widget build(BuildContext context) {
    if (selectionState.isActive) return _buildBulkBar(context);
    final theme = Theme.of(context);
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
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: compact
              ? _buildCompact(context)
              : Row(
                  children: [
                    Text(
                      context.l10n.vibeLibrary_title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!libraryState.isLoading)
                      _CountBadge(state: libraryState),
                    const SizedBox(width: 12),
                    Expanded(child: _SearchField(controller: controller)),
                    const SizedBox(width: 8),
                    _SortButton(state: libraryState, onCommand: onCommand),
                    const SizedBox(width: 6),
                    CompactIconButton(
                      icon: showCategoryPanel
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                      label: context.l10n.common_categories,
                      tooltip: showCategoryPanel
                          ? context.l10n.vibeLibrary_hideCategoryPanel
                          : context.l10n.vibeLibrary_showCategoryPanel,
                      onPressed: () => onCommand(
                        usePersistentCategories
                            ? const ToggleCategoryPanelCommand()
                            : const ShowCategoryPanelCommand(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    CompactIconButton(
                      icon: Icons.checklist,
                      label: context.l10n.common_multiSelect,
                      tooltip: context.l10n.vibeLibrary_enterSelectionMode,
                      onPressed: () =>
                          onCommand(const EnterSelectionModeCommand()),
                    ),
                    if (libraryState.entries.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onSecondaryTapDown: controller.isBusy
                            ? null
                            : (details) => onCommand(
                                ShowImportMenuCommand(details.globalPosition),
                              ),
                        child: CompactIconButton(
                          icon: Icons.file_download_outlined,
                          label: context.l10n.common_import,
                          tooltip: context.l10n.vibeLibrary_importTooltip,
                          isLoading: controller.isPickingFile,
                          onPressed: controller.isBusy
                              ? null
                              : () => onCommand(const ImportVibesCommand()),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    CompactIconButton(
                      icon: Icons.file_upload_outlined,
                      label: context.l10n.common_export,
                      tooltip: context.l10n.vibeLibrary_exportTooltip,
                      onPressed: libraryState.entries.isEmpty
                          ? null
                          : () => onCommand(const ExportVibesCommand()),
                    ),
                    if (PlatformCapabilities.current.supportsOpenFolder) ...[
                      const SizedBox(width: 6),
                      CompactIconButton(
                        icon: Icons.folder_open_outlined,
                        label: context.l10n.common_folder,
                        tooltip: context.l10n.vibeLibrary_openFolderTooltip,
                        onPressed: () =>
                            onCommand(const OpenLibraryFolderCommand()),
                      ),
                    ],
                    const SizedBox(width: 6),
                    _RefreshButton(state: libraryState, onCommand: onCommand),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
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
                      context.l10n.vibeLibrary_title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!libraryState.isLoading) ...[
                    const SizedBox(width: 8),
                    Text(
                      libraryState.hasFilters
                          ? '${libraryState.filteredCount}/${libraryState.totalCount}'
                          : '${libraryState.totalCount}',
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => onCommand(
                usePersistentCategories
                    ? const ToggleCategoryPanelCommand()
                    : const ShowCategoryPanelCommand(),
              ),
              tooltip: context.l10n.common_categories,
              icon: Icon(
                showCategoryPanel
                    ? Icons.view_sidebar
                    : Icons.view_sidebar_outlined,
              ),
            ),
            IconButton(
              onPressed: () => onCommand(const EnterSelectionModeCommand()),
              tooltip: context.l10n.vibeLibrary_enterSelectionMode,
              icon: const Icon(Icons.checklist),
            ),
            PopupMenuButton<_ToolbarMenuAction>(
              tooltip: context.l10n.nav_more,
              onSelected: (action) => onCommand(
                action == _ToolbarMenuAction.export
                    ? const ExportVibesCommand()
                    : const OpenLibraryFolderCommand(),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _ToolbarMenuAction.export,
                  enabled: libraryState.entries.isNotEmpty,
                  child: ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: Text(context.l10n.common_export),
                  ),
                ),
                if (PlatformCapabilities.current.supportsOpenFolder)
                  PopupMenuItem(
                    value: _ToolbarMenuAction.openFolder,
                    child: ListTile(
                      leading: const Icon(Icons.folder_open_outlined),
                      title: Text(context.l10n.common_folder),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _SearchField(controller: controller, touch: true)),
            const SizedBox(width: 4),
            _SortButton(state: libraryState, onCommand: onCommand, touch: true),
            if (libraryState.entries.isNotEmpty) ...[
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: controller.isBusy
                    ? null
                    : () => onCommand(const ImportVibesCommand()),
                tooltip: context.l10n.vibeLibrary_importTooltip,
                icon: controller.isPickingFile
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
              ),
            ],
            const SizedBox(width: 4),
            _RefreshButton(
              state: libraryState,
              onCommand: onCommand,
              touch: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBulkBar(BuildContext context) {
    final ids = libraryState.currentEntries.map((entry) => entry.id).toList();
    final allSelected =
        ids.isNotEmpty && ids.every(selectionState.selectedIds.contains);
    final canMark =
        ModelCapabilityRegistry.of(currentModel).supportsVibeTransfer &&
        NovelAiVibeCodec.normalizeModelOrNull(currentModel) != null;
    final theme = Theme.of(context);
    return BulkActionBar(
      selectedCount: selectionState.selectedIds.length,
      isAllSelected: allSelected,
      onExit: () => onCommand(const ExitSelectionModeCommand()),
      onSelectAll: () =>
          onCommand(ToggleCurrentPageSelectionCommand(select: !allSelected)),
      actions: [
        BulkActionItem(
          icon: Icons.send,
          label: context.l10n.vibeLibrary_sendToGeneration,
          color: theme.colorScheme.primary,
          onPressed: () => onCommand(const SendSelectionToGenerationCommand()),
        ),
        BulkActionItem(
          icon: Icons.drive_file_move_outline,
          label: context.l10n.common_move,
          color: theme.colorScheme.secondary,
          onPressed: () => onCommand(const MoveSelectionCommand()),
        ),
        BulkActionItem(
          icon: Icons.file_upload_outlined,
          label: context.l10n.common_export,
          color: theme.colorScheme.secondary,
          onPressed: () => onCommand(const ExportSelectionCommand()),
        ),
        BulkActionItem(
          icon: Icons.favorite_border,
          label: context.l10n.common_favorite,
          color: theme.colorScheme.primary,
          onPressed: () => onCommand(const ToggleSelectionFavoriteCommand()),
        ),
        if (canMark)
          BulkActionItem(
            icon: Icons.model_training_outlined,
            label: context.l10n.vibeLibrary_markEncodingModel,
            color: theme.colorScheme.secondary,
            onPressed: controller.isMarkingEncodingModel
                ? null
                : () => onCommand(const MarkSelectionEncodingModelCommand()),
          ),
        BulkActionItem(
          icon: Icons.delete_forever_outlined,
          label: context.l10n.common_delete,
          color: theme.colorScheme.error,
          isDanger: true,
          showDividerBefore: true,
          onPressed: () => onCommand(const DeleteSelectionCommand()),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.state});

  final VibeLibraryState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        state.hasFilters
            ? '${state.filteredCount}/${state.totalCount}'
            : '${state.totalCount}',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, this.touch = false});

  final VibeLibraryScreenController controller;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputSurfaceContainer(
      height: touch ? 48 : 36,
      constraints: touch ? null : const BoxConstraints(maxWidth: 300),
      borderRadius: touch ? 16 : 18,
      child: TextField(
        controller: controller.searchController,
        style: theme.textTheme.bodyMedium,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: context.l10n.vibeLibrary_searchHint,
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: controller.searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: controller.clearSearch,
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: controller.searchChanged,
        onSubmitted: controller.submitSearch,
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.state,
    required this.onCommand,
    this.touch = false,
  });

  final VibeLibraryState state;
  final ValueChanged<VibeLibraryCommand> onCommand;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state.sortOrder) {
      VibeLibrarySortOrder.createdAt => (
        Icons.access_time,
        context.l10n.vibeSelectorSortCreated,
      ),
      VibeLibrarySortOrder.lastUsed => (
        Icons.history,
        context.l10n.vibeSelectorSortLastUsed,
      ),
      VibeLibrarySortOrder.usedCount => (
        Icons.trending_up,
        context.l10n.vibeSelectorSortUsedCount,
      ),
      VibeLibrarySortOrder.name => (
        Icons.sort_by_alpha,
        context.l10n.vibeSelectorSortName,
      ),
    };
    return PopupMenuButton<VibeLibrarySortOrder>(
      tooltip: context.l10n.vibeLibrary_sortTooltip,
      onSelected: (order) => onCommand(ChangeSortCommand(order)),
      itemBuilder: (context) => VibeLibrarySortOrder.values
          .map((order) => _buildMenuItem(context, order))
          .toList(),
      child: Container(
        height: touch ? 48 : 36,
        constraints: touch ? const BoxConstraints(minWidth: 48) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: touch ? 20 : 16),
            if (!touch) ...[
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
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
    );
  }

  PopupMenuItem<VibeLibrarySortOrder> _buildMenuItem(
    BuildContext context,
    VibeLibrarySortOrder order,
  ) {
    final selected = state.sortOrder == order;
    final icon = switch (order) {
      VibeLibrarySortOrder.createdAt => Icons.access_time,
      VibeLibrarySortOrder.lastUsed => Icons.history,
      VibeLibrarySortOrder.usedCount => Icons.trending_up,
      VibeLibrarySortOrder.name => Icons.sort_by_alpha,
    };
    return PopupMenuItem(
      value: order,
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? Colors.blue : null),
          const SizedBox(width: 8),
          Text(
            _sortLabel(context, order),
            style: TextStyle(
              color: selected ? Colors.blue : null,
              fontWeight: selected ? FontWeight.w600 : null,
            ),
          ),
          if (selected) ...[
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

  String _sortLabel(BuildContext context, VibeLibrarySortOrder order) =>
      switch (order) {
        VibeLibrarySortOrder.createdAt => context.l10n.vibeSelectorSortCreated,
        VibeLibrarySortOrder.lastUsed => context.l10n.vibeSelectorSortLastUsed,
        VibeLibrarySortOrder.usedCount =>
          context.l10n.vibeSelectorSortUsedCount,
        VibeLibrarySortOrder.name => context.l10n.vibeSelectorSortName,
      };
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({
    required this.state,
    required this.onCommand,
    this.touch = false,
  });

  final VibeLibraryState state;
  final ValueChanged<VibeLibraryCommand> onCommand;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return SizedBox(
        height: touch ? 48 : 36,
        width: touch ? 48 : 88,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              if (!touch) ...[
                const SizedBox(width: 6),
                Text(
                  context.l10n.vibeLibrary_loading,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ],
          ),
        ),
      );
    }
    return CompactIconButton(
      icon: Icons.refresh,
      label: touch ? null : context.l10n.vibeLibrary_refresh,
      tooltip: context.l10n.vibeLibrary_refresh,
      onPressed: () => onCommand(const RefreshLibraryCommand()),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.columns,
    required this.itemWidth,
    required this.onCommand,
  });

  final VibeLibraryState state;
  final int columns;
  final double itemWidth;
  final ValueChanged<VibeLibraryCommand> onCommand;

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return GalleryErrorView(
        error: state.error,
        onRetry: () => onCommand(const RefreshLibraryCommand()),
      );
    }
    if (state.isInitializing && state.entries.isEmpty) {
      return const GalleryLoadingView();
    }
    if (state.entries.isEmpty) {
      return VibeLibraryEmptyView(
        onImport: () => onCommand(const ImportVibesCommand()),
      );
    }
    return VibeLibraryContentView(columns: columns, itemWidth: itemWidth);
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.state,
    required this.compact,
    required this.onCommand,
  });

  final VibeLibraryState state;
  final bool compact;
  final ValueChanged<VibeLibraryCommand> onCommand;

  @override
  Widget build(BuildContext context) {
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
      child: compact
          ? Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: _controls(context),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ..._pageControls(context),
                const SizedBox(width: 16),
                ..._pageSizeControls(context),
                const Spacer(),
                _totalCount(context),
              ],
            ),
    );
  }

  List<Widget> _controls(BuildContext context) => [
    ..._pageControls(context),
    ..._pageSizeControls(context),
    _totalCount(context),
  ];

  List<Widget> _pageControls(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.chevron_left),
      onPressed: state.currentPage > 0
          ? () => onCommand(const PreviousPageCommand())
          : null,
    ),
    Text(
      context.l10n.vibeLibrary_pageIndicator(
        state.currentPage + 1,
        state.totalPages,
      ),
    ),
    IconButton(
      icon: const Icon(Icons.chevron_right),
      onPressed: state.currentPage < state.totalPages - 1
          ? () => onCommand(const NextPageCommand())
          : null,
    ),
  ];

  List<Widget> _pageSizeControls(BuildContext context) => [
    Text(context.l10n.vibeLibrary_itemsPerPage),
    DropdownButton<int>(
      value: state.pageSize,
      underline: const SizedBox(),
      items: const [20, 50, 100]
          .map((size) => DropdownMenuItem(value: size, child: Text('$size')))
          .toList(),
      onChanged: (size) {
        if (size != null) onCommand(ChangePageSizeCommand(size));
      },
    ),
  ];

  Widget _totalCount(BuildContext context) =>
      Text(context.l10n.vibeLibrary_totalCount(state.filteredCount.toString()));
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(context.l10n.vibeLibrary_dropImportHint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportOverlay extends StatelessWidget {
  const _ImportOverlay({required this.progress});

  final ImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    value: progress.progress,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.vibeLibrary_importing,
                  style: theme.textTheme.titleMedium,
                ),
                if (progress.isActive) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${progress.current} / ${progress.total}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
                if (progress.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    progress.message,
                    style: const TextStyle(color: Colors.white70),
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
