import '../../widgets/common/image_card_action.dart';
import '../../widgets/common/image_card_batch_scope.dart';
import 'dart:async';
import '../../services/library_sidebar_move_service.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/model_capabilities.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/shortcuts/shortcut_manager.dart';
import '../../../core/utils/file_explorer_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/novelai_vibe_codec.dart';
import '../../../core/utils/vibe_library_path_helper.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../providers/generation/generation_params_notifier.dart';
import '../../providers/vibe_library_category_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../providers/vibe_library_selection_provider.dart';
import '../../router/app_routes.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/pro_context_menu.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import 'vibe_import_controller.dart';
import 'vibe_library_commands.dart';
import 'vibe_library_screen_controller.dart';
import 'vibe_library_workspace.dart';
import 'widgets/category/vibe_category_tree_view.dart';
import 'widgets/category/vibe_category_destination_panel.dart';
export 'widgets/category/vibe_category_destination_panel.dart';
import 'widgets/menus/vibe_import_menu.dart';
import 'widgets/vibe_export_dialog_advanced.dart';

class VibeLibraryScreen extends ConsumerStatefulWidget {
  const VibeLibraryScreen({super.key, this.pickImportFiles});

  @visibleForTesting
  final Future<List<PlatformFile>?> Function()? pickImportFiles;

  @override
  ConsumerState<VibeLibraryScreen> createState() => _VibeLibraryScreenState();
}

class _VibeLibraryScreenState extends ConsumerState<VibeLibraryScreen> {
  late final VibeLibraryScreenController _controller;
  late final VibeImportController _imports;

  /// 窄屏分类抽屉所在 Scaffold 的 key
  ///
  /// 【偏离上游】上游窄屏走 AdaptivePresenter.showPanel 的底部面板，不需要
  /// Scaffold 句柄；我们保留左侧 Drawer 呈现，触发入口在工具栏命令里
  /// （context 在 Scaffold 之上），只能靠 key 打开。
  final GlobalKey<ScaffoldState> _categoryDrawerScaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _controller = VibeLibraryScreenController(
      pickImportFiles: widget.pickImportFiles,
      onSearch: (query) =>
          ref.read(vibeLibraryNotifierProvider.notifier).setSearchQuery(query),
    )..addListener(_rebuild);
    _imports = VibeImportController(
      ref: ref,
      screenController: _controller,
      context: () => context,
      mounted: () => mounted,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vibeLibraryNotifierProvider.notifier).initialize();
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(vibeLibraryNotifierProvider);
    ref.listen(
      vibeLibraryNotifierProvider.select(
        (s) => (s.searchQuery, s.selectedCategoryId, s.favoritesOnly),
      ),
      (_, _) {
        ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
      },
    );
    final categories = ref.watch(vibeLibraryCategoryNotifierProvider);
    final selection = ref.watch(vibeLibrarySelectionNotifierProvider);
    final model = ref.watch(
      generationParamsNotifierProvider.select((params) => params.model),
    );
    ref.listen(
      vibeLibraryCategoryNotifierProvider.select((state) => state.error),
      (_, error) {
        if (error == null) return;
        AppToast.error(context, error.localized(context.l10n));
        ref.read(vibeLibraryCategoryNotifierProvider.notifier).clearError();
      },
    );
    return ImageCardBatchScope(
      targetIds: selection.selectedIds,
      actions: _buildBatchActions(selection.selectedIds, model),
      child: PopScope<void>(
        canPop: !selection.isActive,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && selection.isActive) {
            ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
          }
        },
        child: Scaffold(
          key: _categoryDrawerScaffoldKey,
          // 【偏离上游】上游窄屏把分类树塞进底部弹面板，这里改成左侧 Drawer
          // 承载同一棵 VibeCategoryTreeView。关闭边缘拖拽：Vibe 卡片有横向
          // 手势，边缘拖拽会与之抢触点。
          drawer: _buildCategoryDrawer(),
          drawerEnableOpenDragGesture: false,
          body: Shortcuts(
            shortcuts: {
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.keyI,
              ): const VibeImportIntent(),
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.keyE,
              ): const VibeExportIntent(),
            },
            child: Actions(
              actions: {
                VibeImportIntent: CallbackAction<VibeImportIntent>(
                  onInvoke: (_) {
                    if (!_controller.isBusy) unawaited(_imports.importFiles());
                    return null;
                  },
                ),
                VibeExportIntent: CallbackAction<VibeExportIntent>(
                  onInvoke: (_) {
                    if (library.entries.isNotEmpty) unawaited(_export());
                    return null;
                  },
                ),
              },
              child: VibeLibraryWorkspace(
                libraryState: library,
                categoryState: categories,
                selectionState: selection,
                currentModel: model,
                controller: _controller,
                onCommand: _handleCommand,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<ImageCardAction> _buildBatchActions(Set<String> ids, String model) {
    final canMark =
        ModelCapabilityRegistry.of(model).supportsVibeTransfer &&
        NovelAiVibeCodec.normalizeModelOrNull(model) != null;
    final theme = Theme.of(context);
    return [
      ImageCardAction(
        id: ImageCardActionId.vibeTransfer,
        supportsBatch: true,
        icon: Icons.send,
        label: context.l10n.vibeLibrary_sendToGeneration,
        iconColor: theme.colorScheme.primary,
        invoke: () => _sendSelection(ids),
      ),
      ImageCardAction(
        id: ImageCardActionId.classify,
        supportsBatch: true,
        icon: Icons.drive_file_move_outline,
        label: context.l10n.common_move,
        iconColor: theme.colorScheme.secondary,
        invoke: () => _moveSelection(ids),
      ),
      ImageCardAction(
        id: ImageCardActionId.export,
        supportsBatch: true,
        icon: Icons.file_upload_outlined,
        label: context.l10n.common_export,
        iconColor: theme.colorScheme.secondary,
        invoke: () => _exportSelection(ids),
      ),
      ImageCardAction(
        id: ImageCardActionId.favorite,
        supportsBatch: true,
        icon: Icons.favorite_border,
        label: context.l10n.common_favorite,
        iconColor: theme.colorScheme.primary,
        invoke: () => _toggleFavorites(ids),
      ),
      if (canMark)
        ImageCardAction(
          id: ImageCardActionId.markEncodingModel,
          supportsBatch: true,
          icon: Icons.model_training_outlined,
          label: context.l10n.vibeLibrary_markEncodingModel,
          iconColor: theme.colorScheme.secondary,
          isLoading: _controller.isMarkingEncodingModel,
          invoke: () => _markEncodingModel(ids),
        ),
      ImageCardAction(
        id: ImageCardActionId.delete,
        supportsBatch: true,
        icon: Icons.delete_forever_outlined,
        label: context.l10n.common_delete,
        iconColor: theme.colorScheme.error,
        isDanger: true,
        invoke: () => _deleteSelection(ids),
      ),
    ];
  }

  Future<void> _handleCommand(VibeLibraryCommand command) async {
    final library = ref.read(vibeLibraryNotifierProvider.notifier);
    final selection = ref.read(vibeLibrarySelectionNotifierProvider.notifier);
    final categories = ref.read(vibeLibraryCategoryNotifierProvider.notifier);
    switch (command) {
      case ImportVibesCommand():
        await _imports.importFiles();
      case ImportImagesCommand():
        await _imports.importImages();
      case ImportClipboardCommand():
        await _imports.importClipboard();
      case PerformVibeDropCommand(:final event):
        await _imports.importDrop(event);
      case ShowImportMenuCommand(:final position):
        _showImportMenu(position);
      case ExportVibesCommand(:final entries):
        await _export(entries);
      case OpenLibraryFolderCommand():
        await _openFolder();
      case RefreshLibraryCommand():
        await library.reload(syncFileSystem: true, showLoading: true);
      case ToggleCategoryPanelCommand():
        _controller.toggleCategoryPanel();
      case ShowCategoryPanelCommand():
        _openCategoryDrawer();
      case SelectCategoryCommand(:final categoryId):
        _selectCategory(categoryId);
      case CreateCategoryCommand():
        await _createCategory();
      case RenameCategoryCommand(:final categoryId, :final name):
        await categories.renameCategory(categoryId, name);
      case DeleteCategoryCommand(:final categoryId):
        await _deleteCategory(categoryId);
      case EnterSelectionModeCommand():
        selection.enter();
      case ExitSelectionModeCommand():
        selection.exit();
      case ToggleCurrentPageSelectionCommand(:final select):
        final ids = ref
            .read(vibeLibraryNotifierProvider)
            .currentEntries
            .map((entry) => entry.id)
            .toList();
        select ? selection.selectAll(ids) : selection.deselectAll(ids);
      case ChangeSortCommand(:final order):
        await library.setSortOrder(order);
      case ChangePageSizeCommand(:final size):
        await library.setPageSize(size);
      case ChangePageCommand(:final page):
        await library.loadPage(page);
      case SendSelectionToGenerationCommand():
        await _sendSelection();
      case MoveSelectionCommand():
        await _moveSelection();
      case ExportSelectionCommand():
        await _exportSelection();
      case ToggleSelectionFavoriteCommand():
        await _toggleFavorites();
      case MarkSelectionEncodingModelCommand():
        await _markEncodingModel();
      case DeleteSelectionCommand():
        await _deleteSelection();
      case ClassifyVibeEntryCommand(:final entryId, :final categoryId):
        await library.updateEntryCategory(entryId, categoryId);
      case FavoriteVibeEntryCommand(:final entryId):
        final entry = ref
            .read(vibeLibraryNotifierProvider)
            .entries
            .cast<VibeLibraryEntry?>()
            .firstWhere((item) => item?.id == entryId, orElse: () => null);
        if (entry != null && !entry.isFavorite) {
          await library.toggleFavorite(entryId);
        }
    }
  }

  void _selectCategory(String? id) {
    ref.read(vibeLibraryCategoryNotifierProvider.notifier).selectCategory(id);
    final notifier = ref.read(vibeLibraryNotifierProvider.notifier);
    if (id == 'favorites') {
      unawaited(notifier.setFavoritesOnly(true));
    } else {
      unawaited(notifier.setCategoryFilter(id));
    }
  }

  /// 窄屏分类抽屉
  ///
  /// 【偏离上游】上游 v4.2.1 是 `_showCategoryPanel`（AdaptivePresenter
  /// .showPanel 底部面板，vibe_library_screen.dart:308）。用户点名保留左侧
  /// 边栏，所以只换承载容器：里面仍是同一棵 VibeCategoryTreeView，没有重建。
  Widget _buildCategoryDrawer() => Drawer(
    key: const Key('vibe-library-category-drawer'),
    width: 290,
    child: SafeArea(
      child: Consumer(
        builder: (context, panelRef, _) {
          final library = panelRef.watch(vibeLibraryNotifierProvider);
          final categories = panelRef.watch(
            vibeLibraryCategoryNotifierProvider,
          );
          return VibeCategoryTreeView(
            showSortHeader: true,
            onCategoryMoveToSlot: (id, targetId, slot) => panelRef
                .read(librarySidebarMoveServiceProvider)
                .moveVibeCategory(id, targetId, slot),
            categories: categories.categories,
            totalEntryCount: library.entries.length,
            favoriteCount: library.favoriteCount,
            categoryEntryCounts: library.categoryEntryCounts,
            selectedCategoryId: categories.selectedCategoryId,
            onCategorySelected: (id) {
              _selectCategory(id);
              _closeCategoryDrawer();
            },
            onCategoryRename: (id, name) => panelRef
                .read(vibeLibraryCategoryNotifierProvider.notifier)
                .renameCategory(id, name),
            onCategoryDelete: _deleteCategory,
            onCreateCategory: _createCategory,
          );
        },
      ),
    ),
  );

  void _openCategoryDrawer() {
    _categoryDrawerScaffoldKey.currentState?.openDrawer();
  }

  void _closeCategoryDrawer() {
    _categoryDrawerScaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _createCategory() async {
    final name = await _controller.runDialogLocked(
      () => ThemedInputDialog.show(
        context: context,
        title: context.l10n.vibeLibrary_createCategoryTitle,
        hintText: context.l10n.vibeLibrary_categoryNameHint,
        confirmText: context.l10n.vibeLibrary_createCategoryConfirm,
        cancelText: context.l10n.common_cancel,
      ),
    );
    if (name?.isNotEmpty == true && mounted) {
      await ref
          .read(vibeLibraryCategoryNotifierProvider.notifier)
          .createCategory(name!);
    }
  }

  Future<void> _deleteCategory(String id) async {
    final confirmed = await _controller.runDialogLocked(
      () => ThemedConfirmDialog.show(
        context: context,
        title: context.l10n.vibeLibrary_deleteCategoryTitle,
        content: context.l10n.vibeLibrary_deleteCategoryContent,
        confirmText: context.l10n.common_delete,
        cancelText: context.l10n.common_cancel,
        type: ThemedConfirmDialogType.danger,
      ),
    );
    if (confirmed == true && mounted) {
      final deleted = await ref
          .read(vibeLibraryCategoryNotifierProvider.notifier)
          .deleteCategory(id, moveEntriesToParent: true);
      if (deleted && mounted) {
        final library = ref.read(vibeLibraryNotifierProvider.notifier);
        if (ref.read(vibeLibraryNotifierProvider).selectedCategoryId == id) {
          await library.clearCategoryFilter();
        }
        await library.loadFromCache();
      }
    }
  }

  Set<String> get _selectedIds =>
      ref.read(vibeLibrarySelectionNotifierProvider).selectedIds;

  Future<void> _moveSelection([Set<String>? targets]) async {
    final selectedIds = Set<String>.of(targets ?? _selectedIds);
    final categories = ref.read(vibeLibraryCategoryNotifierProvider).categories;
    if (categories.isEmpty) {
      AppToast.warning(context, context.l10n.vibeLibrary_noCategoriesAvailable);
      return;
    }
    final destination = await _controller.runDialogLocked(
      () => VibeCategoryDestinationPanel.show(context, categories: categories),
    );
    if (destination == null || !mounted) return;
    final count = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .bulkMoveToCategory(
          selectedIds.toList(),
          destination.isEmpty ? null : destination,
        );
    if (!mounted) return;
    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    AppToast.success(
      context,
      context.l10n.vibeLibrary_movedToCategory('$count'),
    );
  }

  Future<void> _toggleFavorites([Set<String>? targets]) async {
    final selectedIds = Set<String>.of(targets ?? _selectedIds);
    for (final id in selectedIds) {
      await ref.read(vibeLibraryNotifierProvider.notifier).toggleFavorite(id);
    }
    if (mounted) {
      ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
      AppToast.success(context, context.l10n.vibeLibrary_favoriteStatusUpdated);
    }
  }

  Future<void> _markEncodingModel([Set<String>? targets]) async {
    final selectedIds = Set<String>.of(targets ?? _selectedIds);
    if (_controller.isMarkingEncodingModel || selectedIds.isEmpty) return;
    final model = NovelAiVibeCodec.normalizeModelOrNull(
      ref.read(generationParamsNotifierProvider).model,
    );
    if (model == null ||
        !ModelCapabilityRegistry.of(model).supportsVibeTransfer) {
      return;
    }
    _controller.setMarkingEncodingModel(true);
    try {
      final confirmed = await _controller.runDialogLocked(
        () => ThemedConfirmDialog.show(
          context: context,
          title: context.l10n.vibeLibrary_markEncodingModel,
          content: context.l10n.vibeLibrary_markEncodingModelContent(
            selectedIds.length,
            ImageModels.modelDisplayNames[model] ?? model,
          ),
          confirmText: context.l10n.common_confirm,
          cancelText: context.l10n.common_cancel,
        ),
      );
      if (confirmed == true) {
        final result = await ref
            .read(vibeLibraryNotifierProvider.notifier)
            .bulkUpdateEncodingModel(selectedIds, model);
        if (mounted) {
          ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
          AppToast.success(
            context,
            context.l10n.vibeLibrary_encodingModelMarked(result.successCount),
          );
        }
      }
    } finally {
      _controller.setMarkingEncodingModel(false);
    }
  }

  Future<void> _sendSelection([Set<String>? targets]) async {
    final selectedIds = Set<String>.of(targets ?? _selectedIds);
    final ids = selectedIds.toList();
    if (ids.isEmpty) return;
    if (ids.length > 16) {
      await _showVibeLimitDialog(
        context.l10n.vibeLibrary_tooManySelectedContent(ids.length),
      );
      return;
    }
    final entries = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .resolveEntriesByIds(ids);
    final params = ref.read(generationParamsNotifierProvider);
    if (!mounted) return;
    final remaining = 16 - params.vibeReferencesV4.length;
    if (entries.length > remaining) {
      await _showVibeLimitDialog(
        context.l10n.vibeLibrary_tooManyExistingContent(
          params.vibeReferencesV4.length,
          remaining,
        ),
      );
      return;
    }
    ref
        .read(generationParamsNotifierProvider.notifier)
        .addVibeReferences(
          entries.map((entry) => entry.toVibeReference()).toList(),
          recordUsage: false,
        );
    AppToast.success(
      context,
      context.l10n.vibeLibrary_sentToGenerationCount(entries.length),
    );
    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    context.go(AppRoutes.home);
  }

  Future<void> _showVibeLimitDialog(String message) {
    return _controller.runDialogLocked(
      () => ThemedConfirmDialog.showInfo(
        context: context,
        title: context.l10n.vibeLibrary_tooManyTitle,
        content: message,
        confirmText: context.l10n.common_ok,
        icon: Icons.info_outline,
      ),
    );
  }

  Future<void> _exportSelection([Set<String>? targets]) async {
    final selectedIds = Set<String>.of(targets ?? _selectedIds);
    final ids = selectedIds.toList();
    if (ids.isEmpty) return;
    final entriesById = {
      for (final entry in ref.read(vibeLibraryNotifierProvider).entries)
        entry.id: entry,
    };
    final entries = [
      for (final id in ids)
        if (entriesById[id] != null) entriesById[id]!,
    ];
    if (entries.isEmpty) return;
    await _export(entries);
    if (mounted) ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
  }

  Future<void> _deleteSelection([Set<String>? targets]) async {
    final selectedIds = Set<String>.of(targets ?? _selectedIds);
    final ids = selectedIds.toList();
    final confirmed = await _controller.runDialogLocked(
      () => ThemedConfirmDialog.show(
        context: context,
        title: context.l10n.common_confirmDelete,
        content: context.l10n.vibeLibrary_deleteSelectedContent(ids.length),
        confirmText: context.l10n.common_delete,
        cancelText: context.l10n.common_cancel,
        type: ThemedConfirmDialogType.danger,
        icon: Icons.delete_forever_outlined,
      ),
    );
    if (confirmed != true) return;
    final deletedCount = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .bulkDeleteEntries(ids);
    if (mounted) {
      AppToast.success(
        context,
        context.l10n.vibeLibrary_deletedCount(deletedCount),
      );
      ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    }
  }

  void _showImportMenu(Offset position) {
    unawaited(
      context.showImportMenu(
        position: position,
        items: [
          ProMenuItem(
            id: 'file',
            label: context.l10n.vibeLibrary_importFromFile,
            icon: Icons.folder_outlined,
            onTap: _imports.importFiles,
          ),
          ProMenuItem(
            id: 'image',
            label: context.l10n.vibeLibrary_importFromImage,
            icon: Icons.image_outlined,
            onTap: _imports.importImages,
          ),
          ProMenuItem(
            id: 'clipboard',
            label: context.l10n.vibeLibrary_importFromClipboard,
            icon: Icons.content_paste,
            onTap: _imports.importClipboard,
          ),
        ],
      ),
    );
  }

  Future<void> _openFolder() async {
    if (!PlatformCapabilities.current.supportsOpenFolder) return;
    try {
      await FileExplorerUtils.openDirectory(
        await VibeLibraryPathHelper.instance.getPath(),
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.vibeLibrary_openFolderFailed('$error'),
        );
      }
    }
  }

  Future<void> _export([List<VibeLibraryEntry>? entries]) async {
    final source = entries ?? ref.read(vibeLibraryNotifierProvider).entries;
    final selected = source.length == 1
        ? await ref
              .read(vibeLibraryNotifierProvider.notifier)
              .resolveEntriesByIds(source.map((entry) => entry.id))
        : source;
    if (selected.isEmpty || !mounted) return;
    await _controller.runDialogLocked(
      () => VibeExportDialogAdvanced.show(context, entries: selected),
    );
  }
}
