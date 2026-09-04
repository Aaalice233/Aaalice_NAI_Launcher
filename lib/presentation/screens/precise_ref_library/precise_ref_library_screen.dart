import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/services/file_export_service.dart';
import '../../../core/utils/file_explorer_utils.dart';
import '../../../core/utils/precise_ref_library_path_helper.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../data/services/precise_ref_library_archive_service.dart';
import '../../../data/services/precise_ref_library_storage_service.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/precise_ref_library_provider.dart';
import '../../providers/precise_ref_library_selection_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../services/precise_ref_library_batch_sender.dart';
import '../../router/app_routes.dart';
import '../../services/image_workflow_launcher.dart';
import '../../utils/dropped_file_reader.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/common/library_classification_drag.dart';
import '../../widgets/common/precise_reference_type_dialog.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/gallery/gallery_sidebar.dart';
import '../../widgets/gallery/gallery_library_toolbar.dart';
import '../../agent_chat/widgets/agent_resource_drop_region.dart';
import 'widgets/precise_ref_card.dart';
import 'widgets/precise_ref_entry_edit_dialog.dart';
import 'widgets/precise_ref_library_sidebar.dart';
import 'widgets/precise_ref_selector_dialog.dart';

/// 精准参考库页面
///
/// 管理可复用的精准参考图片：卡片网格 + 搜索 + 收藏 + 排序，
/// 支持拖拽/粘贴/文件选择入库，条目可一键发送到精准参考或图生图。
class PreciseRefLibraryScreen extends ConsumerStatefulWidget {
  const PreciseRefLibraryScreen({super.key});

  @override
  ConsumerState<PreciseRefLibraryScreen> createState() =>
      _PreciseRefLibraryScreenState();
}

class _PreciseRefLibraryScreenState
    extends ConsumerState<PreciseRefLibraryScreen> {
  static const List<int> _pageSizeOptions = [20, 50, 100];

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  bool _isDragging = false;
  bool _isPickingFile = false;
  bool _isExporting = false;
  bool _showCategoryPanel = true;
  int _currentPage = 0;
  int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(preciseRefLibraryNotifierProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _currentPage = 0);
      ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .setSearchQuery(value);
    });
  }

  // ============================================================
  // 入库
  // ============================================================

  /// 导入时套用的类型：正处于某个类型分类下时跟随该分类，否则用默认
  PreciseRefType get _importType =>
      ref.read(preciseRefLibraryNotifierProvider).typeFilter ??
      PreciseRefType.characterAndStyle;

  Future<void> _importImages() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'gif',
          'bmp',
          PreciseRefLibraryArchiveService.extension,
        ],
        allowMultiple: true,
        withData: false,
      );
      if (result == null || !mounted) return;

      final importType = _importType;
      var archiveImportedCount = 0;
      var archiveFailedCount = 0;
      final archiveService = PreciseRefLibraryArchiveService(
        ref.read(preciseRefLibraryStorageServiceProvider),
      );
      for (final file in result.files.where(
        (file) =>
            p.extension(file.name).toLowerCase() ==
            '.${PreciseRefLibraryArchiveService.extension}',
      )) {
        final path = file.path;
        if (path == null) {
          archiveFailedCount++;
          continue;
        }
        try {
          archiveImportedCount += (await archiveService.importFromPath(
            path,
          )).length;
        } on Object {
          archiveFailedCount++;
        }
      }
      final sources = [
        for (final file in result.files)
          if (p.extension(file.name).toLowerCase() !=
              '.${PreciseRefLibraryArchiveService.extension}')
            PreciseRefLibraryImportSource(
              name: p.basenameWithoutExtension(file.name),
              type: importType,
              loadBytes: () async {
                final filePath = file.path;
                return filePath == null
                    ? file.bytes
                    : File(filePath).readAsBytes();
              },
            ),
      ];
      final batch = await ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .importMany(sources);
      if (archiveImportedCount > 0) {
        await ref
            .read(preciseRefLibraryNotifierProvider.notifier)
            .reload(showLoading: false);
      }
      final importedCount = batch.importedCount + archiveImportedCount;
      final failedCount = batch.failedCount + archiveFailedCount;
      if (mounted && importedCount > 0) {
        AppToast.success(
          context,
          context.l10n.preciseRefLib_importedCount(importedCount),
        );
      }
      if (mounted && failedCount > 0) {
        AppToast.error(
          context,
          context.l10n.preciseRefLib_importFailedCount(failedCount),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.preciseRefLib_importFailed('$e'));
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingFile = false);
      }
    }
  }

  Future<void> _exportEntries(List<PreciseRefLibraryEntry> entries) async {
    if (_isExporting || entries.isEmpty) return;
    setState(() => _isExporting = true);
    final exportTitle = context.l10n.preciseRefLib_exportTitle;
    File? temporary;
    try {
      final tempDir = await getTemporaryDirectory();
      temporary = File(
        p.join(
          tempDir.path,
          'precise-references-${DateTime.now().millisecondsSinceEpoch}.'
          '${PreciseRefLibraryArchiveService.extension}',
        ),
      );
      await PreciseRefLibraryArchiveService(
        ref.read(preciseRefLibraryStorageServiceProvider),
      ).exportToPath(entries: entries, outputPath: temporary.path);
      final saved = await FileExportService.saveFileFromPath(
        sourcePath: temporary.path,
        fileName:
            'precise-references.${PreciseRefLibraryArchiveService.extension}',
        dialogTitle: exportTitle,
        mimeType: 'application/zip',
        allowedExtensions: const [PreciseRefLibraryArchiveService.extension],
      );
      if (mounted && saved != null) {
        AppToast.success(
          context,
          context.l10n.preciseRefLib_exportedCount(entries.length),
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.preciseRefLib_exportFailed('$error'),
        );
      }
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _chooseAndExportEntries() async {
    final entries = await PreciseRefSelectorDialog.show(
      context,
      purpose: PreciseRefSelectorPurpose.export,
    );
    if (!mounted || entries == null || entries.isEmpty) return;
    await _exportEntries(entries);
  }

  Future<void> _openLibraryFolder() async {
    if (!PlatformCapabilities.current.supportsOpenFolder) return;
    try {
      final path = await PreciseRefLibraryPathHelper.instance.getDefaultPath();
      await PreciseRefLibraryPathHelper.instance.ensurePathExists(path);
      await FileExplorerUtils.openDirectory(path);
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.preciseRefLib_openFolderFailed('$error'),
        );
      }
    }
  }

  Future<void> _handleDrop(PerformDropEvent event) async {
    // 在拖放会话仍存活时并发发起全部读取；逐个串行读取会导致
    // 后续 item 的 reader 随会话释放而失效（platform reader not found）
    final futures = <Future<DroppedFileData?>>[];
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;
      futures.add(
        DroppedFileReader.read(
          reader,
          logTag: 'PreciseRefLibraryDrop',
        ).catchError((Object _) => null),
      );
    }
    final results = await Future.wait(futures);
    if (!mounted) return;

    final importType = _importType;
    final validDrops = results
        .whereType<DroppedFileData>()
        .where((dropped) => dropped.bytes.isNotEmpty)
        .toList();
    final readFailureCount = results.length - validDrops.length;
    final sources = [
      for (final dropped in validDrops)
        PreciseRefLibraryImportSource(
          name: p.basenameWithoutExtension(dropped.fileName),
          type: importType,
          loadBytes: () async => dropped.bytes,
        ),
    ];
    final PreciseRefLibraryBatchImportResult batch;
    try {
      batch = await ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .importMany(sources);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.preciseRefLib_importFailed('$e'));
      }
      return;
    }
    if (!mounted) return;
    final failedCount = readFailureCount + batch.failedCount;
    if (batch.importedCount > 0) {
      AppToast.success(
        context,
        context.l10n.preciseRefLib_importedCount(batch.importedCount),
      );
    }
    if (failedCount > 0) {
      AppToast.error(
        context,
        context.l10n.preciseRefLib_importFailedCount(failedCount),
      );
    }
  }

  // ============================================================
  // 发送
  // ============================================================

  Future<void> _sendToPreciseRef(PreciseRefLibraryEntry entry) async {
    final l10n = context.l10n;
    final params = ref.read(generationParamsNotifierProvider);
    if (!params.isV4Model) {
      AppToast.warning(context, l10n.preciseRef_v4Only);
      return;
    }

    final bytes = await ref
        .read(preciseRefLibraryStorageServiceProvider)
        .readImageBytes(entry.id);
    if (!mounted) return;
    if (bytes == null) {
      AppToast.error(context, l10n.preciseRefLib_imageMissing);
      return;
    }

    // 不等待：方法在第一个 await 前已把原图塞进状态，
    // Director PNG 规范化在后台完成后自动替换（与拖拽/图库发送路径一致）
    unawaited(
      ref
          .read(generationParamsNotifierProvider.notifier)
          .addPreciseReferenceFromImage(
            bytes,
            type: entry.type,
            strength: entry.strength,
            fidelity: entry.fidelity,
          ),
    );
    unawaited(
      ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .recordUsage(entry.id),
    );
    AppToast.success(context, l10n.preciseRefLib_sent(entry.name));
    context.go(AppRoutes.home);
  }

  Future<void> _sendToImg2Img(PreciseRefLibraryEntry entry) async {
    final l10n = context.l10n;
    final bytes = await ref
        .read(preciseRefLibraryStorageServiceProvider)
        .readImageBytes(entry.id);
    if (!mounted) return;
    if (bytes == null) {
      AppToast.error(context, l10n.preciseRefLib_imageMissing);
      return;
    }

    ImageWorkflowLauncher.openImageToImage(ref, bytes);
    unawaited(
      ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .recordUsage(entry.id),
    );
    AppToast.success(context, l10n.preciseRefLib_sentToImg2Img(entry.name));
    context.go(AppRoutes.home);
  }

  Future<void> _sendSelection(
    PreciseRefLibraryState state,
    Set<String> selectedIds,
  ) async {
    final params = ref.read(generationParamsNotifierProvider);
    if (!params.isV4Model) {
      AppToast.warning(context, context.l10n.preciseRef_v4Only);
      return;
    }
    final storage = ref.read(preciseRefLibraryStorageServiceProvider);
    final generation = ref.read(generationParamsNotifierProvider.notifier);
    final library = ref.read(preciseRefLibraryNotifierProvider.notifier);
    final result = await const PreciseRefLibraryBatchSender().send(
      orderedEntries: state.filteredEntries,
      selectedIds: selectedIds,
      loadBytes: storage.readImageBytes,
      sendEntry: (bytes, entry) => generation.addPreciseReferenceFromImage(
        bytes,
        type: entry.type,
        strength: entry.strength,
        fidelity: entry.fidelity,
      ),
      recordUsage: (id) async {
        await library.recordUsage(id);
      },
    );
    if (!mounted) return;
    final failedNames = result.failedEntries
        .map((entry) => entry.name)
        .toList();
    final summary = context.l10n.preciseRefLib_sentSelectedSummary(
      result.successfulEntries.length,
      failedNames.length,
    );
    if (failedNames.isEmpty) {
      AppToast.success(context, summary);
    } else {
      AppToast.error(
        context,
        '$summary\n${context.l10n.preciseRefLib_failedItems(failedNames.join(', '))}',
      );
    }
    if (result.successfulEntries.isNotEmpty) context.go(AppRoutes.home);
  }

  Future<void> _changeSelectionType(Set<String> selectedIds) async {
    final type = await PreciseReferenceTypeDialog.show(context);
    if (type == null || !mounted) return;
    await ref
        .read(preciseRefLibraryNotifierProvider.notifier)
        .updateEntriesType(selectedIds, type);
  }

  Future<void> _toggleSelectionFavorite(
    PreciseRefLibraryState state,
    Set<String> selectedIds,
  ) async {
    final selected = state.entries.where(
      (entry) => selectedIds.contains(entry.id),
    );
    final allFavorite =
        selected.isNotEmpty && selected.every((entry) => entry.isFavorite);
    await ref
        .read(preciseRefLibraryNotifierProvider.notifier)
        .setEntriesFavorite(selectedIds, isFavorite: !allFavorite);
  }

  Future<void> _deleteSelection(Set<String> selectedIds) async {
    if (selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.common_confirmDelete),
        content: Text(
          context.l10n.preciseRefLib_confirmDeleteSelected(selectedIds.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await ref
        .read(preciseRefLibraryNotifierProvider.notifier)
        .deleteEntries(selectedIds);
    if (!mounted) return;
    ref.read(preciseRefLibrarySelectionNotifierProvider.notifier).exit();
    AppToast.success(context, context.l10n.preciseRefLib_deletedCount(deleted));
  }

  // ============================================================
  // 编辑 / 删除
  // ============================================================

  Future<void> _editEntry(PreciseRefLibraryEntry entry) async {
    final result = await PreciseRefEntryEditDialog.show(context, entry);
    if (result == null) return;
    await ref
        .read(preciseRefLibraryNotifierProvider.notifier)
        .updateEntry(
          entry.id,
          name: result.name,
          type: result.type,
          strength: result.strength,
          fidelity: result.fidelity,
        );
  }

  Future<void> _deleteEntry(PreciseRefLibraryEntry entry) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.preciseRefLib_confirmDeleteTitle),
        content: Text(l10n.preciseRefLib_confirmDelete(entry.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            key: const Key('precise-ref-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final removed = await ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .deleteEntry(entry.id);
      if (mounted && !removed) {
        AppToast.error(context, l10n.preciseRefLib_deleteFailed);
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, l10n.preciseRefLib_deleteFailed);
      }
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(preciseRefLibraryNotifierProvider);
    final selection = ref.watch(preciseRefLibrarySelectionNotifierProvider);

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final persistentCategories = constraints.maxWidth >= 840;
        final showSidebar = persistentCategories && _showCategoryPanel;
        final mainWidth = constraints.maxWidth - (showSidebar ? 250 : 0);
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final layout = computePreciseRefGridLayout(mainWidth, textScale);
        return Stack(
          children: [
            GalleryCollectionWorkspace(
              toolbar: _buildToolbar(
                state,
                selection: selection,
                persistentCategories: persistentCategories,
                showPageTitle: true,
              ),
              sidebar: showSidebar
                  ? PreciseRefLibrarySidebar(
                      state: state,
                      onFilterChanged: _selectSidebarFilter,
                      onEntryTypeDrop: _setEntryType,
                      onFavoriteDrop: _favoriteEntry,
                    )
                  : null,
              body: state.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        value: MediaQuery.disableAnimationsOf(context)
                            ? 0.72
                            : null,
                      ),
                    )
                  : state.error != null
                  ? _buildErrorView(state.error!)
                  : state.filteredEntries.isEmpty
                  ? _buildEmptyView(state)
                  : _buildGrid(state, layout),
              footer: !state.isLoading && state.filteredEntries.isNotEmpty
                  ? _buildPagination(state, mainWidth)
                  : null,
            ),
            if (_isDragging) _buildDropOverlay(),
          ],
        );
      },
    );

    final body = !PlatformCapabilities.current.supportsExternalFileDrop
        ? content
        : DropRegion(
            formats: Formats.standardFormats,
            hitTestBehavior: HitTestBehavior.opaque,
            onDropOver: (event) {
              if (event.session.allowedOperations.contains(
                DropOperation.copy,
              )) {
                if (!_isDragging) {
                  setState(() => _isDragging = true);
                }
                return DropOperation.copy;
              }
              return DropOperation.none;
            },
            onDropLeave: (event) {
              if (_isDragging) {
                setState(() => _isDragging = false);
              }
            },
            onPerformDrop: (event) async {
              setState(() => _isDragging = false);
              // 不等待处理完成，让拖放回调立即返回（避免资源管理器卡死）
              unawaited(_handleDrop(event));
            },
            child: content,
          );
    return PopScope<void>(
      canPop: !selection.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selection.isActive) {
          ref.read(preciseRefLibrarySelectionNotifierProvider.notifier).exit();
        }
      },
      child: Scaffold(body: body),
    );
  }

  void _selectSidebarFilter({
    required bool favoritesOnly,
    PreciseRefType? type,
  }) {
    setState(() => _currentPage = 0);
    ref
        .read(preciseRefLibraryNotifierProvider.notifier)
        .setSidebarFilter(favoritesOnly: favoritesOnly, type: type);
  }

  Future<void> _showCategoryPanelSheet(PreciseRefLibraryState state) {
    return AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.tagLibrary_categories,
      initialChildSize: 0.72,
      builder: (panelContext, scrollController) => PreciseRefLibrarySidebar(
        state: state,
        modal: true,
        onFilterChanged: ({required bool favoritesOnly, PreciseRefType? type}) {
          _selectSidebarFilter(favoritesOnly: favoritesOnly, type: type);
          Navigator.of(panelContext).pop();
        },
        onEntryTypeDrop: _setEntryType,
        onFavoriteDrop: _favoriteEntry,
      ),
    );
  }

  Widget _buildErrorView(String error) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              l10n.preciseRefLib_loadFailed(error),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('precise-ref-library-retry'),
              onPressed: () => ref
                  .read(preciseRefLibraryNotifierProvider.notifier)
                  .reload(showLoading: true),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.common_retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(
    PreciseRefLibraryState state, {
    required SelectionModeState selection,
    required bool persistentCategories,
    required bool showPageTitle,
  }) {
    final l10n = context.l10n;
    if (selection.isActive) return _buildBulkBar(state, selection);
    final title = GalleryCollectionPageTitle(
      key: const Key('precise-ref-library-page-title'),
      icon: Icons.center_focus_strong,
      title: l10n.preciseRefLib_title,
    );
    final search = GalleryLibrarySearchField(
      key: const Key('precise-ref-library-search-surface'),
      controller: _searchController,
      hintText: l10n.preciseRefLib_searchHint,
      onChanged: _onSearchChanged,
    );
    final sort = GalleryLibrarySortMenu<PreciseRefLibrarySortOrder>(
      key: const Key('precise-ref-library-sort-menu'),
      label: l10n.preciseRefLib_sortBy,
      value: state.sortOrder,
      descending: state.sortDescending,
      onSelected: (order) {
        setState(() => _currentPage = 0);
        ref
            .read(preciseRefLibraryNotifierProvider.notifier)
            .setSortOrder(order);
      },
      options: [
        GalleryLibrarySortOption(
          value: PreciseRefLibrarySortOrder.createdAt,
          label: l10n.preciseRefLib_sortCreatedAt,
        ),
        GalleryLibrarySortOption(
          value: PreciseRefLibrarySortOrder.lastUsed,
          label: l10n.preciseRefLib_sortLastUsed,
        ),
        GalleryLibrarySortOption(
          value: PreciseRefLibrarySortOrder.usedCount,
          label: l10n.preciseRefLib_sortUsedCount,
        ),
        GalleryLibrarySortOption(
          value: PreciseRefLibrarySortOrder.name,
          label: l10n.preciseRefLib_sortName,
        ),
      ],
    );
    final importButton = GalleryLibraryAction(
      key: const Key('precise-ref-library-import-button'),
      onPressed: _isPickingFile ? null : _importImages,
      icon: Icons.add_photo_alternate_outlined,
      label: l10n.preciseRefLib_import,
      tooltip: l10n.preciseRefLib_import,
      isLoading: _isPickingFile,
    );
    final categories = GalleryLibraryAction(
      key: const Key('precise-ref-library-categories-button'),
      icon: _showCategoryPanel && persistentCategories
          ? Icons.view_sidebar
          : Icons.view_sidebar_outlined,
      label: l10n.common_categories,
      tooltip: persistentCategories && _showCategoryPanel
          ? l10n.localGallery_hideCategoryPanel
          : l10n.localGallery_showCategoryPanel,
      onPressed: persistentCategories
          ? () => setState(() => _showCategoryPanel = !_showCategoryPanel)
          : () => _showCategoryPanelSheet(state),
    );

    return GalleryLibraryToolbar(
      key: const Key('precise-ref-library-unified-toolbar'),
      title: showPageTitle ? title : const SizedBox.shrink(),
      count: GalleryLibraryCountBadge(
        label: state.hasFilters
            ? '${state.filteredEntries.length}/${state.totalCount}'
            : '${state.totalCount}',
      ),
      search: search,
      actions: [
        sort,
        categories,
        GalleryLibraryAction(
          key: const Key('precise-ref-library-multi-select-button'),
          icon: Icons.checklist,
          label: l10n.common_multiSelect,
          tooltip: l10n.preciseRefLib_enterSelectionMode,
          onPressed: () => ref
              .read(preciseRefLibrarySelectionNotifierProvider.notifier)
              .enter(),
        ),
        importButton,
        GalleryLibraryAction(
          key: const Key('precise-ref-library-export-button'),
          icon: Icons.file_download_outlined,
          label: l10n.common_export,
          isLoading: _isExporting,
          onPressed: state.entries.isEmpty || _isExporting
              ? null
              : _chooseAndExportEntries,
        ),
        if (PlatformCapabilities.current.supportsOpenFolder)
          GalleryLibraryAction(
            key: const Key('precise-ref-library-folder-button'),
            icon: Icons.folder_open_outlined,
            label: l10n.common_folder,
            onPressed: _openLibraryFolder,
          ),
        GalleryLibraryAction(
          key: const Key('precise-ref-library-refresh-button'),
          icon: Icons.refresh,
          label: l10n.common_refresh,
          isLoading: state.isLoading,
          onPressed: state.isLoading
              ? null
              : () => ref
                    .read(preciseRefLibraryNotifierProvider.notifier)
                    .reload(showLoading: true),
        ),
      ],
    );
  }

  Widget _buildBulkBar(
    PreciseRefLibraryState state,
    SelectionModeState selection,
  ) {
    final pageIds = _currentPageEntries(
      state,
    ).map((entry) => entry.id).toList();
    final allSelected =
        pageIds.isNotEmpty && pageIds.every(selection.selectedIds.contains);
    final selectedEntries = state.entries
        .where((entry) => selection.selectedIds.contains(entry.id))
        .toList();
    final allFavorite =
        selectedEntries.isNotEmpty &&
        selectedEntries.every((entry) => entry.isFavorite);
    final theme = Theme.of(context);
    return BulkActionBar(
      selectedCount: selection.selectedIds.length,
      isAllSelected: allSelected,
      onExit: () =>
          ref.read(preciseRefLibrarySelectionNotifierProvider.notifier).exit(),
      onSelectAll: () {
        final notifier = ref.read(
          preciseRefLibrarySelectionNotifierProvider.notifier,
        );
        allSelected
            ? notifier.deselectAll(pageIds)
            : notifier.selectAll(pageIds);
      },
      actions: [
        BulkActionItem(
          icon: Icons.send,
          label: context.l10n.preciseRefLib_sendToPreciseRef,
          color: theme.colorScheme.primary,
          onPressed: selection.selectedIds.isEmpty
              ? null
              : () => _sendSelection(state, selection.selectedIds),
        ),
        BulkActionItem(
          icon: Icons.category_outlined,
          label: context.l10n.preciseRefLib_changeType,
          color: theme.colorScheme.secondary,
          onPressed: selection.selectedIds.isEmpty
              ? null
              : () => _changeSelectionType(selection.selectedIds),
        ),
        BulkActionItem(
          icon: Icons.favorite_border,
          label: allFavorite
              ? context.l10n.common_unfavorite
              : context.l10n.common_favorite,
          color: theme.colorScheme.primary,
          onPressed: selection.selectedIds.isEmpty
              ? null
              : () => _toggleSelectionFavorite(state, selection.selectedIds),
        ),
        BulkActionItem(
          icon: Icons.file_upload_outlined,
          label: context.l10n.common_export,
          color: theme.colorScheme.secondary,
          onPressed: selectedEntries.isEmpty || _isExporting
              ? null
              : () => _exportEntries(selectedEntries),
        ),
        BulkActionItem(
          icon: Icons.delete_forever_outlined,
          label: context.l10n.common_delete,
          color: theme.colorScheme.error,
          isDanger: true,
          showDividerBefore: true,
          onPressed: selection.selectedIds.isEmpty
              ? null
              : () => _deleteSelection(selection.selectedIds),
        ),
      ],
    );
  }

  Widget _buildGrid(PreciseRefLibraryState state, PreciseRefGridLayout layout) {
    final entries = _currentPageEntries(state);
    final selection = ref.watch(preciseRefLibrarySelectionNotifierProvider);
    return GridView.builder(
      key: const PageStorageKey('precise_ref_library_grid'),
      padding: EdgeInsets.all(layout.padding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: layout.columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: layout.mainAxisExtent,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final card = PreciseRefCard(
          entry: entry,
          isSelectionMode: selection.isActive,
          isSelected: selection.selectedIds.contains(entry.id),
          onToggleSelection: () => ref
              .read(preciseRefLibrarySelectionNotifierProvider.notifier)
              .toggle(entry.id),
          onEnterSelectionMode: () => ref
              .read(preciseRefLibrarySelectionNotifierProvider.notifier)
              .enterAndSelect(entry.id),
          onSendToPreciseRef: () => _sendToPreciseRef(entry),
          onSendToImg2Img: () => _sendToImg2Img(entry),
          onEdit: () => _editEntry(entry),
          onDelete: () => _deleteEntry(entry),
          onToggleFavorite: () {
            ref
                .read(preciseRefLibraryNotifierProvider.notifier)
                .toggleFavorite(entry.id);
          },
          onClassify: () => _classifyEntry(entry),
        );
        if (selection.isActive) {
          return KeyedSubtree(
            key: Key('precise-ref-card-${entry.id}'),
            child: card,
          );
        }
        return AgentResourceDragSource(
          key: Key('precise-ref-card-${entry.id}'),
          reference: AgentChatResourceReference(
            kind: AgentChatResourceKind.preciseRefLibraryEntry,
            source: 'precise_reference_library',
            resourceId: entry.id,
            display: {'name': entry.name},
          ),
          child: LibraryClassificationDragSource<PreciseRefLibraryEntry>(
            data: entry,
            label: entry.name,
            child: card,
          ),
        );
      },
    );
  }

  List<PreciseRefLibraryEntry> _currentPageEntries(
    PreciseRefLibraryState state,
  ) {
    final totalPages = _totalPagesFor(state.filteredEntries.length);
    final page = _currentPage.clamp(0, totalPages - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, state.filteredEntries.length);
    return state.filteredEntries.sublist(start, end);
  }

  Future<void> _classifyEntry(PreciseRefLibraryEntry entry) async {
    final type = await PreciseReferenceTypeDialog.show(context);
    if (type == null || !mounted) return;
    await _setEntryType(entry, type);
  }

  Future<void> _setEntryType(
    PreciseRefLibraryEntry entry,
    PreciseRefType type,
  ) async {
    if (entry.type == type) return;
    await ref
        .read(preciseRefLibraryNotifierProvider.notifier)
        .updateEntry(entry.id, type: type);
  }

  Future<void> _favoriteEntry(PreciseRefLibraryEntry entry) async {
    if (entry.isFavorite) return;
    await ref
        .read(preciseRefLibraryNotifierProvider.notifier)
        .toggleFavorite(entry.id);
  }

  Widget _buildPagination(PreciseRefLibraryState state, double contentWidth) {
    final totalItems = state.filteredEntries.length;
    final totalPages = _totalPagesFor(totalItems);
    final currentPage = _currentPage.clamp(0, totalPages - 1);
    return PaginationBar(
      key: const Key('precise-ref-library-pagination'),
      currentPage: currentPage,
      totalPages: totalPages,
      totalItems: totalItems,
      itemsPerPage: _pageSize,
      itemsPerPageOptions: _pageSizeOptions,
      onPageChanged: (page) => setState(() => _currentPage = page),
      onItemsPerPageChanged: (size) {
        setState(() {
          _pageSize = size;
          _currentPage = 0;
        });
      },
      showItemsPerPage: true,
      showTotalInfo: true,
      compact: contentWidth < 680,
      totalIcon: Icons.center_focus_strong,
      totalItemsLabel: context.l10n.preciseRefLib_entryCount(totalItems),
      tonalCard: true,
    );
  }

  int _totalPagesFor(int totalItems) =>
      ((totalItems + _pageSize - 1) ~/ _pageSize).clamp(1, 1 << 30);

  Widget _buildEmptyView(PreciseRefLibraryState state) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final supportsExternalFileDrop =
        PlatformCapabilities.current.supportsExternalFileDrop;

    // 过滤后无结果：给出条目总数与一键清除过滤
    if (state.hasFilters) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${l10n.localGallery_noMatchingResults} '
                '(${l10n.preciseRefLib_entryCount(state.totalCount)})',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('precise-ref-library-clear-filters'),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _currentPage = 0);
                  ref
                      .read(preciseRefLibraryNotifierProvider.notifier)
                      .clearFilters();
                },
                icon: const Icon(Icons.filter_alt_off, size: 18),
                label: Text(l10n.localGallery_clearFilters),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.center_focus_strong,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              supportsExternalFileDrop
                  ? l10n.preciseRefLib_empty
                  : l10n.preciseRefLib_emptyTouch,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!state.hasFilters) ...[
              const SizedBox(height: 6),
              Text(
                supportsExternalFileDrop
                    ? l10n.preciseRefLib_emptyHint
                    : l10n.preciseRefLib_emptyHintTouch,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('precise-ref-library-empty-import-button'),
                onPressed: _isPickingFile ? null : _importImages,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(l10n.preciseRefLib_import),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropOverlay() {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.preciseRefLib_empty,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class PreciseRefGridLayout {
  const PreciseRefGridLayout({
    required this.columns,
    required this.mainAxisExtent,
    required this.padding,
  });

  final int columns;
  final double mainAxisExtent;
  final double padding;
}

PreciseRefGridLayout computePreciseRefGridLayout(
  double availableWidth,
  double textScale,
) {
  final padding = availableWidth < 600 ? 12.0 : 16.0;
  final scale = textScale.clamp(1.0, 3.0);
  final minCardWidth = 176 + (scale - 1) * 44;
  final usableWidth = (availableWidth - padding * 2).clamp(
    0.0,
    double.infinity,
  );
  final columns = ((usableWidth + 12) / (minCardWidth + 12)).floor().clamp(
    1,
    8,
  );
  final cardWidth = columns == 0
      ? usableWidth
      : (usableWidth - (columns - 1) * 12) / columns;
  return PreciseRefGridLayout(
    columns: columns,
    mainAxisExtent: cardWidth * 1.22 + (scale - 1) * 24,
    padding: padding,
  );
}
