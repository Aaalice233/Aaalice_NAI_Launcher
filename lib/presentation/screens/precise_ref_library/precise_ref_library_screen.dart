import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../data/services/precise_ref_library_storage_service.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/precise_ref_library_provider.dart';
import '../../router/app_routes.dart';
import '../../services/image_workflow_launcher.dart';
import '../../utils/dropped_file_reader.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/input_surface_container.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/gallery/gallery_sidebar.dart';
import '../../agent_chat/widgets/agent_resource_drop_region.dart';
import 'widgets/precise_ref_card.dart';
import 'widgets/precise_ref_entry_edit_dialog.dart';
import 'widgets/precise_ref_library_sidebar.dart';

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
        type: FileType.image,
        allowMultiple: true,
        withData: false,
      );
      if (result == null || !mounted) return;

      final importType = _importType;
      final sources = [
        for (final file in result.files)
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
      if (mounted && batch.importedCount > 0) {
        AppToast.success(
          context,
          context.l10n.preciseRefLib_importedCount(batch.importedCount),
        );
      }
      if (mounted && batch.failedCount > 0) {
        AppToast.error(
          context,
          context.l10n.preciseRefLib_importFailedCount(batch.failedCount),
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

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = constraints.maxWidth >= 840;
        final mainWidth = constraints.maxWidth - (showSidebar ? 250 : 0);
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final layout = computePreciseRefGridLayout(mainWidth, textScale);
        return Stack(
          children: [
            GalleryCollectionWorkspace(
              toolbar: _buildToolbar(
                state,
                showCategoryButton: !showSidebar,
                showPageTitle: true,
              ),
              sidebar: showSidebar
                  ? PreciseRefLibrarySidebar(
                      state: state,
                      onFilterChanged: _selectSidebarFilter,
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

    if (!PlatformCapabilities.current.supportsExternalFileDrop) {
      return Scaffold(body: content);
    }

    return Scaffold(
      body: DropRegion(
        formats: Formats.standardFormats,
        hitTestBehavior: HitTestBehavior.opaque,
        onDropOver: (event) {
          if (event.session.allowedOperations.contains(DropOperation.copy)) {
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
      ),
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

  Future<void> _showCategoryPanel(PreciseRefLibraryState state) {
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
    required bool showCategoryButton,
    required bool showPageTitle,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final touchTarget = context.interactionPolicy.shouldExposeTouchAlternatives;

    final title = GalleryCollectionPageTitle(
      key: const Key('precise-ref-library-page-title'),
      icon: Icons.center_focus_strong,
      title: l10n.preciseRefLib_title,
      subtitle: l10n.preciseRefLib_entryCount(state.totalCount),
      maxWidth: 210,
    );
    final searchHeight = touchTarget ? 48.0 : 40.0;
    final search = InputSurfaceContainer(
      key: const Key('precise-ref-library-search-surface'),
      height: searchHeight,
      borderRadius: searchHeight / 2,
      focusedBorderColor: theme.colorScheme.primary.withValues(alpha: 0.38),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, _) => TextField(
          key: const Key('precise-ref-library-search'),
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: l10n.preciseRefLib_searchHint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.common_clear,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: _onSearchChanged,
        ),
      ),
    );
    final favorites = IconButton(
      key: const Key('precise-ref-library-favorites-toggle'),
      tooltip: l10n.preciseRefLib_favoritesOnly,
      icon: Icon(
        state.favoritesOnly
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        color: state.favoritesOnly ? theme.colorScheme.error : null,
      ),
      onPressed: () {
        setState(() => _currentPage = 0);
        ref
            .read(preciseRefLibraryNotifierProvider.notifier)
            .toggleFavoritesOnly();
      },
      style: _toolbarIconButtonStyle(theme),
    );
    final sort = PopupMenuButton<PreciseRefLibrarySortOrder>(
      key: const Key('precise-ref-library-sort-menu'),
      tooltip: l10n.preciseRefLib_sortBy,
      icon: const Icon(Icons.sort),
      onSelected: (order) {
        setState(() => _currentPage = 0);
        ref
            .read(preciseRefLibraryNotifierProvider.notifier)
            .setSortOrder(order);
      },
      itemBuilder: (context) => [
        _sortMenuItem(
          PreciseRefLibrarySortOrder.createdAt,
          l10n.preciseRefLib_sortCreatedAt,
          state,
        ),
        _sortMenuItem(
          PreciseRefLibrarySortOrder.lastUsed,
          l10n.preciseRefLib_sortLastUsed,
          state,
        ),
        _sortMenuItem(
          PreciseRefLibrarySortOrder.usedCount,
          l10n.preciseRefLib_sortUsedCount,
          state,
        ),
        _sortMenuItem(
          PreciseRefLibrarySortOrder.name,
          l10n.preciseRefLib_sortName,
          state,
        ),
      ],
      style: _toolbarIconButtonStyle(theme),
    );
    final importButton = FilledButton.icon(
      key: const Key('precise-ref-library-import-button'),
      onPressed: _isPickingFile ? null : _importImages,
      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
      label: Text(l10n.preciseRefLib_import),
      style: _toolbarImportButtonStyle(
        theme,
        minimumHeight: touchTarget ? 48 : 40,
      ),
    );
    final showToolbarImport = state.totalCount > 0 || state.hasFilters;
    final categories = IconButton(
      key: const Key('precise-ref-library-categories-button'),
      tooltip: l10n.localGallery_showCategoryPanel,
      onPressed: () => _showCategoryPanel(state),
      icon: const Icon(Icons.folder_outlined),
      style: _toolbarIconButtonStyle(theme),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        favorites,
        const SizedBox(width: 2),
        sort,
        if (showToolbarImport) ...[const SizedBox(width: 8), importButton],
      ],
    );
    final utilityActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [favorites, const SizedBox(width: 2), sort],
    );

    return GalleryCollectionToolbarSurface(
      key: const Key('precise-ref-library-unified-toolbar'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
          if (constraints.maxWidth >= 700 && !largeText) {
            return Row(
              children: [
                if (showCategoryButton) ...[
                  categories,
                  const SizedBox(width: 8),
                ],
                if (showPageTitle) ...[
                  title,
                  const SizedBox(
                    width: GalleryCollectionChrome.toolbarGroupGap,
                  ),
                ],
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: search,
                  ),
                ),
                const SizedBox(width: 10),
                actions,
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (showCategoryButton) ...[
                    categories,
                    const SizedBox(width: 4),
                  ],
                  if (showPageTitle) Expanded(child: title) else const Spacer(),
                  utilityActions,
                ],
              ),
              const SizedBox(height: 10),
              search,
              if (showToolbarImport) ...[
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: importButton),
              ],
            ],
          );
        },
      ),
    );
  }

  ButtonStyle _toolbarIconButtonStyle(ThemeData theme) {
    final colors = theme.colorScheme;
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size.square(context.interactionPolicy.minimumControlExtent),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return colors.primary;
        }
        return colors.onSurfaceVariant;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.pressed)) {
          return colors.primaryContainer.withValues(alpha: 0.72);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return colors.primaryContainer.withValues(alpha: 0.48);
        }
        return Colors.transparent;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  ButtonStyle _toolbarImportButtonStyle(
    ThemeData theme, {
    required double minimumHeight,
  }) {
    final colors = theme.colorScheme;
    return FilledButton.styleFrom(
      minimumSize: Size(64, minimumHeight),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled)
            ? colors.onSurface.withValues(alpha: 0.38)
            : colors.onPrimary;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.pressed)) {
          return Color.alphaBlend(
            colors.onPrimary.withValues(alpha: 0.14),
            colors.primary,
          );
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return Color.alphaBlend(
            colors.onPrimary.withValues(alpha: 0.08),
            colors.primary,
          );
        }
        return colors.primary;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
    );
  }

  PopupMenuItem<PreciseRefLibrarySortOrder> _sortMenuItem(
    PreciseRefLibrarySortOrder order,
    String label,
    PreciseRefLibraryState state,
  ) {
    final selected = state.sortOrder == order;
    return PopupMenuItem(
      value: order,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (selected)
            Icon(
              state.sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
              size: 16,
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(PreciseRefLibraryState state, PreciseRefGridLayout layout) {
    final totalPages = _totalPagesFor(state.filteredEntries.length);
    final page = _currentPage.clamp(0, totalPages - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, state.filteredEntries.length);
    final entries = state.filteredEntries.sublist(start, end);
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
        return AgentResourceDragSource(
          key: Key('precise-ref-card-${entry.id}'),
          reference: AgentChatResourceReference(
            kind: AgentChatResourceKind.preciseRefLibraryEntry,
            source: 'precise_reference_library',
            resourceId: entry.id,
            display: {'name': entry.name},
          ),
          child: PreciseRefCard(
            entry: entry,
            onSendToPreciseRef: () => _sendToPreciseRef(entry),
            onSendToImg2Img: () => _sendToImg2Img(entry),
            onEdit: () => _editEntry(entry),
            onDelete: () => _deleteEntry(entry),
            onToggleFavorite: () {
              ref
                  .read(preciseRefLibraryNotifierProvider.notifier)
                  .toggleFavorite(entry.id);
            },
          ),
        );
      },
    );
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
