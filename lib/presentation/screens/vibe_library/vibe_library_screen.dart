import 'dart:async';

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
import '../../../data/models/vibe/vibe_library_category.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../adaptive/adaptive_presenter.dart';
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
    return PopScope<void>(
      canPop: !selection.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selection.isActive) {
          ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
        }
      },
      child: Scaffold(
        body: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI):
                const VibeImportIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE):
                const VibeExportIntent(),
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
    );
  }

  void _handleCommand(VibeLibraryCommand command) {
    final library = ref.read(vibeLibraryNotifierProvider.notifier);
    final selection = ref.read(vibeLibrarySelectionNotifierProvider.notifier);
    final categories = ref.read(vibeLibraryCategoryNotifierProvider.notifier);
    switch (command) {
      case ImportVibesCommand():
        unawaited(_imports.importFiles());
      case ImportImagesCommand():
        unawaited(_imports.importImages());
      case ImportClipboardCommand():
        unawaited(_imports.importClipboard());
      case PerformVibeDropCommand(:final event):
        unawaited(_imports.importDrop(event));
      case ShowImportMenuCommand(:final position):
        _showImportMenu(position);
      case ExportVibesCommand(:final entries):
        unawaited(_export(entries));
      case OpenLibraryFolderCommand():
        unawaited(_openFolder());
      case RefreshLibraryCommand():
        unawaited(library.reload(syncFileSystem: true, showLoading: true));
      case ToggleCategoryPanelCommand():
        _controller.toggleCategoryPanel();
      case ShowCategoryPanelCommand():
        unawaited(_showCategoryPanel());
      case SelectCategoryCommand(:final categoryId):
        _selectCategory(categoryId);
      case CreateCategoryCommand(:final parentId):
        unawaited(_createCategory(parentId));
      case RenameCategoryCommand(:final categoryId, :final name):
        unawaited(categories.renameCategory(categoryId, name));
      case DeleteCategoryCommand(:final categoryId):
        unawaited(_deleteCategory(categoryId));
      case MoveCategoryCommand(:final categoryId, :final parentId):
        unawaited(categories.moveCategory(categoryId, parentId));
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
        unawaited(library.setSortOrder(order));
      case ChangePageSizeCommand(:final size):
        unawaited(library.setPageSize(size));
      case PreviousPageCommand():
        unawaited(library.loadPreviousPage());
      case NextPageCommand():
        unawaited(library.loadNextPage());
      case SendSelectionToGenerationCommand():
        unawaited(_sendSelection());
      case MoveSelectionCommand():
        unawaited(_moveSelection());
      case ExportSelectionCommand():
        unawaited(_exportSelection());
      case ToggleSelectionFavoriteCommand():
        unawaited(_toggleFavorites());
      case MarkSelectionEncodingModelCommand():
        unawaited(_markEncodingModel());
      case DeleteSelectionCommand():
        unawaited(_deleteSelection());
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

  Future<void> _showCategoryPanel() => AdaptivePresenter.showPanel<void>(
    context: context,
    title: context.l10n.vibeLibrary_categories,
    builder: (panelContext, _) => Consumer(
      builder: (context, panelRef, _) {
        final library = panelRef.watch(vibeLibraryNotifierProvider);
        final categories = panelRef.watch(vibeLibraryCategoryNotifierProvider);
        return VibeCategoryTreeView(
          categories: categories.categories,
          totalEntryCount: library.entries.length,
          favoriteCount: library.favoriteCount,
          selectedCategoryId: categories.selectedCategoryId,
          onCategorySelected: (id) {
            _selectCategory(id);
            Navigator.of(panelContext).maybePop();
          },
          onCategoryRename: (id, name) => panelRef
              .read(vibeLibraryCategoryNotifierProvider.notifier)
              .renameCategory(id, name),
          onCategoryDelete: _deleteCategory,
          onAddSubCategory: (id) => _createCategory(id),
          onCategoryMove: (id, parent) => panelRef
              .read(vibeLibraryCategoryNotifierProvider.notifier)
              .moveCategory(id, parent),
        );
      },
    ),
  );

  Future<void> _createCategory(String? parentId) async {
    final name = await _controller.runDialogLocked(
      () => ThemedInputDialog.show(
        context: context,
        title: parentId == null
            ? context.l10n.vibeLibrary_createCategoryTitle
            : context.l10n.vibeLibrary_createSubCategoryTitle,
        hintText: context.l10n.vibeLibrary_categoryNameHint,
        confirmText: context.l10n.vibeLibrary_createCategoryConfirm,
        cancelText: context.l10n.common_cancel,
      ),
    );
    if (name?.isNotEmpty == true && mounted) {
      await ref
          .read(vibeLibraryCategoryNotifierProvider.notifier)
          .createCategory(name!, parentId: parentId);
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

  Future<void> _moveSelection() async {
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
          _selectedIds.toList(),
          destination.isEmpty ? null : destination,
        );
    if (!mounted) return;
    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    AppToast.success(
      context,
      context.l10n.vibeLibrary_movedToCategory('$count'),
    );
  }

  Future<void> _toggleFavorites() async {
    for (final id in _selectedIds) {
      await ref.read(vibeLibraryNotifierProvider.notifier).toggleFavorite(id);
    }
    if (mounted) {
      ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
      AppToast.success(context, context.l10n.vibeLibrary_favoriteStatusUpdated);
    }
  }

  Future<void> _markEncodingModel() async {
    if (_controller.isMarkingEncodingModel || _selectedIds.isEmpty) return;
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
            _selectedIds.length,
            ImageModels.modelDisplayNames[model] ?? model,
          ),
          confirmText: context.l10n.common_confirm,
          cancelText: context.l10n.common_cancel,
        ),
      );
      if (confirmed == true) {
        final result = await ref
            .read(vibeLibraryNotifierProvider.notifier)
            .bulkUpdateEncodingModel(_selectedIds, model);
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

  Future<void> _sendSelection() async {
    final ids = _selectedIds.toList();
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

  Future<void> _exportSelection() async {
    final ids = _selectedIds.toList();
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

  Future<void> _deleteSelection() async {
    final ids = _selectedIds.toList();
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

/// 自适应的 Vibe 批量移动目标分类列表。
///
/// 空字符串表示“未分类”，null 仅表示用户取消，以保留既有返回值契约。
class VibeCategoryDestinationPanel extends StatelessWidget {
  const VibeCategoryDestinationPanel({
    super.key,
    required this.categories,
    this.scrollController,
  });

  final List<VibeLibraryCategory> categories;
  final ScrollController? scrollController;

  static Future<String?> show(
    BuildContext context, {
    required List<VibeLibraryCategory> categories,
  }) {
    return AdaptivePresenter.showForm<String>(
      context: context,
      title: context.l10n.vibeLibrary_moveToCategory,
      sideSheetWidth: 440,
      builder: (panelContext, scrollController) => VibeCategoryDestinationPanel(
        categories: categories,
        scrollController: scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('vibe-category-destination-list'),
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.folder_off_outlined),
          title: Text(context.l10n.vibeLibrary_uncategorized),
          onTap: () => Navigator.of(context).pop(''),
        ),
        for (final category in categories)
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(category.name),
            onTap: () => Navigator.of(context).pop(category.id),
          ),
      ],
    );
  }
}
