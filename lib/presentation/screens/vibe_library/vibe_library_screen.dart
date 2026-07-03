import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../core/utils/vibe_image_embedder.dart';
import '../../../core/utils/vibe_library_path_helper.dart';
import '../../../data/models/vibe/vibe_library_category.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_import_service.dart';
import '../../providers/generation/generation_params_notifier.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../providers/vibe_library_category_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../providers/vibe_library_selection_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/compact_icon_button.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../../widgets/common/pro_context_menu.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import '../../../core/shortcuts/shortcut_manager.dart';
import '../../../data/models/vibe/vibe_import_progress.dart';
import '../../../data/services/vibe_library_import_repository_impl.dart';
import '../../../data/services/vibe_library_storage_service.dart';
import 'vibe_drop_import_preprocessor.dart';
import 'widgets/category/vibe_category_tree_view.dart';
import 'widgets/menus/vibe_import_menu.dart';
import 'widgets/vibe_library_content_view.dart';
import 'widgets/vibe_library_empty_view.dart';
import 'widgets/vibe_bundle_import_dialog.dart' as bundle_import_dialog;
import 'widgets/vibe_export_dialog_advanced.dart';
import 'widgets/vibe_image_encode_dialog.dart' as encode_dialog;
import 'widgets/vibe_import_naming_dialog.dart' as naming_dialog;

part 'vibe_library_screen_layout.dart';

const List<String> _vibeImportImageExtensions = ['png', 'jpg', 'jpeg', 'webp'];

/// Vibe库屏幕
/// Vibe Library Screen
class VibeLibraryScreen extends ConsumerStatefulWidget {
  const VibeLibraryScreen({super.key});

  @override
  ConsumerState<VibeLibraryScreen> createState() => _VibeLibraryScreenState();
}

class _VibeLibraryScreenState extends ConsumerState<VibeLibraryScreen> {
  /// 是否显示分类面板
  bool _showCategoryPanel = true;

  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  /// 是否正在拖拽文件
  bool _isDragging = false;

  /// 是否正在导入
  bool _isImporting = false;

  /// 是否正在打开文件选择器
  bool _isPickingFile = false;

  /// 导入进度信息
  ImportProgress _importProgress = const ImportProgress();

  @override
  void initState() {
    super.initState();
    // 初始化Vibe库
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vibeLibraryNotifierProvider.notifier).initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Set<String>? _reservedImportNames;

  void _beginImportSession() {
    _reservedImportNames = ref
        .read(vibeLibraryNotifierProvider)
        .entries
        .map((entry) => entry.name.toLowerCase())
        .toSet();
  }

  void _endImportSession() {
    _reservedImportNames = null;
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateLayoutState(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vibeLibraryNotifierProvider);
    final categoryState = ref.watch(vibeLibraryCategoryNotifierProvider);
    final selectionState = ref.watch(vibeLibrarySelectionNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    // 计算内容区域宽度
    const categoryPanelWidth = 260.0;
    final contentWidth = _showCategoryPanel && screenWidth > 800
        ? screenWidth - categoryPanelWidth
        : screenWidth;

    // 计算列数（200px/列，最少2列，最多8列）
    final columns = (contentWidth / 200).floor().clamp(2, 8);
    // 考虑 GridView padding (16 * 2 = 32) 后计算每个 item 的宽度
    final itemWidth = (contentWidth - 32) / columns;

    return Scaffold(
      body: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI):
              const VibeImportIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE):
              const VibeExportIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            VibeImportIntent: CallbackAction<VibeImportIntent>(
              onInvoke: (intent) {
                if (!(_isImporting || _isPickingFile)) {
                  _importVibes();
                }
                return null;
              },
            ),
            VibeExportIntent: CallbackAction<VibeExportIntent>(
              onInvoke: (intent) {
                final state = ref.read(vibeLibraryNotifierProvider);
                if (state.entries.isNotEmpty) {
                  _exportVibes();
                }
                return null;
              },
            ),
          },
          child: DropRegion(
            formats: Formats.standardFormats,
            hitTestBehavior: HitTestBehavior.opaque,
            onDropOver: (event) {
              // 检查是否包含文件
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
              // 重要：不要等待 _handleDrop 完成，让拖放回调立即返回
              unawaited(_handleDrop(event));
              return;
            },
            child: Stack(
              children: [
                Row(
                  children: [
                    // 左侧分类面板
                    if (_showCategoryPanel && screenWidth > 800)
                      Container(
                        width: categoryPanelWidth,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          border: Border(
                            right: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            // 顶部标题栏
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
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
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _showCreateCategoryDialog(context),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text(
                                      context.l10n.common_new,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                            // 分类树
                            Expanded(
                              child: VibeCategoryTreeView(
                                categories: categoryState.categories,
                                totalEntryCount: state.entries.length,
                                favoriteCount: state.favoriteCount,
                                selectedCategoryId:
                                    categoryState.selectedCategoryId,
                                onCategorySelected: (id) {
                                  ref
                                      .read(
                                        vibeLibraryCategoryNotifierProvider
                                            .notifier,
                                      )
                                      .selectCategory(id);
                                  if (id == 'favorites') {
                                    ref
                                        .read(
                                          vibeLibraryNotifierProvider.notifier,
                                        )
                                        .setFavoritesOnly(true);
                                  } else {
                                    // 切换到其他分类时，清除收藏过滤状态
                                    ref
                                        .read(
                                          vibeLibraryNotifierProvider.notifier,
                                        )
                                        .setFavoritesOnly(false);
                                    ref
                                        .read(
                                          vibeLibraryNotifierProvider.notifier,
                                        )
                                        .setCategoryFilter(id);
                                  }
                                },
                                onCategoryRename: (id, newName) async {
                                  await ref
                                      .read(
                                        vibeLibraryCategoryNotifierProvider
                                            .notifier,
                                      )
                                      .renameCategory(id, newName);
                                },
                                onCategoryDelete: (id) async {
                                  final confirmed =
                                      await ThemedConfirmDialog.show(
                                        context: context,
                                        title: context
                                            .l10n
                                            .vibeLibrary_deleteCategoryTitle,
                                        content: context
                                            .l10n
                                            .vibeLibrary_deleteCategoryContent,
                                        confirmText: context.l10n.common_delete,
                                        cancelText: context.l10n.common_cancel,
                                        type: ThemedConfirmDialogType.danger,
                                        icon: Icons.delete_outline,
                                      );
                                  if (confirmed) {
                                    await ref
                                        .read(
                                          vibeLibraryCategoryNotifierProvider
                                              .notifier,
                                        )
                                        .deleteCategory(
                                          id,
                                          moveEntriesToParent: true,
                                        );
                                  }
                                },
                                onAddSubCategory: (parentId) async {
                                  final name = await ThemedInputDialog.show(
                                    context: context,
                                    title: parentId == null
                                        ? context
                                              .l10n
                                              .vibeLibrary_createCategoryTitle
                                        : context
                                              .l10n
                                              .vibeLibrary_createSubCategoryTitle,
                                    hintText: context
                                        .l10n
                                        .vibeLibrary_categoryNameHint,
                                    confirmText: context
                                        .l10n
                                        .vibeLibrary_createCategoryConfirm,
                                    cancelText: context.l10n.common_cancel,
                                  );
                                  if (name != null && name.isNotEmpty) {
                                    await ref
                                        .read(
                                          vibeLibraryCategoryNotifierProvider
                                              .notifier,
                                        )
                                        .createCategory(
                                          name,
                                          parentId: parentId,
                                        );
                                  }
                                },
                                onCategoryMove:
                                    (categoryId, newParentId) async {
                                      await ref
                                          .read(
                                            vibeLibraryCategoryNotifierProvider
                                                .notifier,
                                          )
                                          .moveCategory(
                                            categoryId,
                                            newParentId,
                                          );
                                    },
                              ),
                            ),
                          ],
                        ),
                      ),
                    // 右侧主内容
                    Expanded(
                      child: Column(
                        children: [
                          // 工具栏
                          _buildToolbar(state, selectionState, theme),
                          // 主体内容
                          Expanded(
                            child: _buildBody(
                              state,
                              columns,
                              itemWidth,
                              selectionState,
                            ),
                          ),
                          // 底部分页条
                          if (!state.isLoading &&
                              state.filteredEntries.isNotEmpty &&
                              state.totalPages > 0)
                            _buildPaginationBar(state, contentWidth),
                        ],
                      ),
                    ),
                  ],
                ),
                // 拖拽覆盖层
                if (_isDragging) _buildDropOverlay(theme),
                // 导入进度覆盖层
                if (_isImporting) _buildImportOverlay(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示创建分类对话框
  Future<void> _showCreateCategoryDialog(BuildContext context) async {
    final name = await ThemedInputDialog.show(
      context: context,
      title: context.l10n.vibeLibrary_createCategoryTitle,
      hintText: context.l10n.vibeLibrary_categoryNameHint,
      confirmText: context.l10n.vibeLibrary_createCategoryConfirm,
      cancelText: context.l10n.common_cancel,
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(vibeLibraryCategoryNotifierProvider.notifier)
          .createCategory(name);
    }
  }

  /// 显示移动到分类对话框
  Future<void> _showMoveToCategoryDialog(BuildContext context) async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final categories = ref.read(vibeLibraryCategoryNotifierProvider).categories;

    if (categories.isEmpty) {
      if (mounted) {
        AppToast.warning(
          context,
          context.l10n.vibeLibrary_noCategoriesAvailable,
        );
      }
      return;
    }

    final selectedCategory = await showDialog<VibeLibraryCategory>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.vibeLibrary_moveToCategory),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(context.l10n.vibeLibrary_uncategorized),
                  onTap: () => Navigator.of(context).pop(null),
                );
              }
              final category = categories[index - 1];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(category.name),
                onTap: () => Navigator.of(context).pop(category),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
        ],
      ),
    );

    if (selectedCategory == null || !mounted) return;

    final categoryId = selectedCategory.id;
    final ids = selectionState.selectedIds.toList();

    var movedCount = 0;
    for (final id in ids) {
      final result = await ref
          .read(vibeLibraryNotifierProvider.notifier)
          .updateEntryCategory(id, categoryId);
      if (result != null) movedCount++;
    }

    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    if (!context.mounted) return;
    AppToast.success(
      context,
      context.l10n.vibeLibrary_movedToCategory(movedCount.toString()),
    );
  }

  /// 批量切换收藏
  Future<void> _batchToggleFavorite() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    for (final id in ids) {
      await ref.read(vibeLibraryNotifierProvider.notifier).toggleFavorite(id);
    }

    if (mounted) {
      AppToast.success(context, context.l10n.vibeLibrary_favoriteStatusUpdated);
      ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    }
  }

  /// 批量发送到生成页面
  Future<void> _batchSendToGeneration() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    // 检查是否超过16个限制
    if (selectedIds.length > 16) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.vibeLibrary_tooManyTitle),
            content: Text(
              context.l10n.vibeLibrary_tooManySelectedContent(
                selectedIds.length,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.common_ok),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 获取选中的条目
    final selectedEntries = await _resolveEntriesByIds(selectedIds);
    if (selectedEntries.isEmpty) return;

    // 获取当前的生成参数
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentParams = ref.read(generationParamsNotifierProvider);

    // 检查添加后是否会超过16个
    final currentVibeCount = currentParams.vibeReferencesV4.length;
    final willExceedLimit = currentVibeCount + selectedEntries.length > 16;

    if (willExceedLimit) {
      final remainingSlots = 16 - currentVibeCount;
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.vibeLibrary_tooManyTitle),
            content: Text(
              context.l10n.vibeLibrary_tooManyExistingContent(
                currentVibeCount,
                remainingSlots,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.common_ok),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 添加选中的Vibe到生成参数
    final vibes = selectedEntries.map((e) => e.toVibeReference()).toList();
    paramsNotifier.addVibeReferences(vibes, recordUsage: false);

    // 显示成功提示
    if (mounted) {
      AppToast.success(
        context,
        context.l10n.vibeLibrary_sentToGenerationCount(selectedEntries.length),
      );
    }

    // 退出选择模式
    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();

    // 跳转到生成页面
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  /// 批量导出
  Future<void> _batchExport() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    if (ids.isEmpty) return;

    final state = ref.read(vibeLibraryNotifierProvider);
    final entriesById = {for (final entry in state.entries) entry.id: entry};
    final selectedEntries = [
      for (final id in ids)
        if (entriesById[id] != null) entriesById[id]!,
    ];

    if (selectedEntries.isEmpty) return;

    // 打开导出对话框
    await _exportVibes(specificEntries: selectedEntries);

    // 退出选择模式
    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
  }

  /// 批量删除
  Future<void> _batchDelete() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.common_confirmDelete,
      content: context.l10n.vibeLibrary_deleteSelectedContent(ids.length),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed) {
      await ref.read(vibeLibraryNotifierProvider.notifier).deleteEntries(ids);

      if (mounted) {
        AppToast.success(
          context,
          context.l10n.vibeLibrary_deletedCount(ids.length),
        );
        ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
      }
    }
  }

  /// 显示导入右键菜单
  void _showImportMenu(Offset position) {
    Navigator.of(context).push(
      ImportMenu(
        position: position,
        items: [
          ProMenuItem(
            id: 'import_file',
            label: context.l10n.vibeLibrary_importFromFile,
            icon: Icons.folder_outlined,
            onTap: () => _importVibes(),
          ),
          ProMenuItem(
            id: 'import_image',
            label: context.l10n.vibeLibrary_importFromImage,
            icon: Icons.image_outlined,
            onTap: () => _importVibesFromImage(),
          ),
          ProMenuItem(
            id: 'import_clipboard',
            label: context.l10n.vibeLibrary_importFromClipboard,
            icon: Icons.content_paste,
            onTap: () => _importVibesFromClipboard(),
          ),
        ],
        onSelect: (_) {},
      ),
    );
  }

  /// 打开 Vibe 库文件夹（存放 .naiv4vibe 文件的地方）
  Future<void> _openVibeLibraryFolder() async {
    try {
      // 获取 vibe 文件存储路径
      final vibePath = await VibeLibraryPathHelper.instance.getPath();
      final dir = Directory(vibePath);

      // 确保目录存在
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      if (Platform.isWindows) {
        // 使用 Process.start 避免等待进程完成导致的延迟
        await Process.start('explorer', [vibePath]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [vibePath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [vibePath]);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.vibeLibrary_openFolderFailed('$e'),
        );
      }
    }
  }

  /// 导入 Vibe 文件
  Future<void> _importVibes() async {
    final files = await _pickImportFiles();
    if (files == null || files.isEmpty) {
      return;
    }

    _beginImportSession();
    if (!mounted) {
      _endImportSession();
      return;
    }

    setState(() => _isImporting = true);

    try {
      final (imageFiles, regularFiles) = await _categorizeFiles(files);
      final currentCategoryId = ref
          .read(vibeLibraryNotifierProvider)
          .selectedCategoryId;
      final targetCategoryId =
          (currentCategoryId != null && currentCategoryId != 'favorites')
          ? currentCategoryId
          : null;
      final result = await _processImportSources(
        imageItems: imageFiles,
        vibeFiles: regularFiles,
        targetCategoryId: targetCategoryId,
        onProgress: (current, total, message) {
          AppLogger.d(message, 'VibeLibrary');
        },
      );

      if (!mounted) {
        return;
      }
      setState(() => _isImporting = false);

      // 如果发生了编码流程，跳过额外的 reload（编码保存时已刷新）
      await _handleImportResult(
        result.success,
        result.fail,
        skipReload: result.hasEncoding,
      );
    } finally {
      _endImportSession();
      if (mounted && _isImporting) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<List<PlatformFile>?> _pickImportFiles() async {
    if (!mounted) {
      return null;
    }
    setState(() => _isPickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'naiv4vibe',
          'naiv4vibebundle',
          ..._vibeImportImageExtensions,
        ],
        allowMultiple: true,
        dialogTitle: context.l10n.vibeLibrary_importFileDialogTitle,
        withData: false,
        lockParentWindow: true,
      );

      return result?.files;
    } finally {
      if (mounted) {
        setState(() => _isPickingFile = false);
      }
    }
  }

  Future<(List<VibeImageImportItem>, List<PlatformFile>)> _categorizeFiles(
    List<PlatformFile> files,
  ) async {
    final imageFiles = <VibeImageImportItem>[];
    final regularFiles = <PlatformFile>[];

    for (final file in files) {
      final ext = file.extension?.toLowerCase() ?? '';
      if (_vibeImportImageExtensions.contains(ext)) {
        try {
          final bytes = await _readPlatformFileBytes(file);
          imageFiles.add(VibeImageImportItem(source: file.name, bytes: bytes));
        } catch (e) {
          AppLogger.e('读取图片文件失败: ${file.name}', e, null, 'VibeLibrary');
        }
      } else if (ext == 'naiv4vibe' || ext == 'naiv4vibebundle') {
        regularFiles.add(file);
      }
    }

    return (imageFiles, regularFiles);
  }

  Future<({int success, int fail, bool hasEncoding})> _processImportSources({
    required List<VibeImageImportItem> imageItems,
    required List<PlatformFile> vibeFiles,
    String? targetCategoryId,
    required ImportProgressCallback onProgress,
  }) async {
    final storage = ref.read(vibeLibraryStorageServiceProvider);
    final repository = VibeLibraryStorageImportRepository(storage);
    final importService = VibeImportService(repository: repository);

    var totalSuccess = 0;
    var totalFail = 0;
    var hasEncoding = false; // 标记是否有图片经过编码流程
    final totalCount = imageItems.length + vibeFiles.length;

    // 单独处理每张图片，以便支持无 Vibe 数据图片的编码流程
    for (var i = 0; i < imageItems.length; i++) {
      final imageItem = imageItems[i];
      onProgress(
        i + 1,
        totalCount,
        '导入图片(${i + 1}/${imageItems.length}): ${imageItem.source}',
      );

      // 检测是否经过编码流程
      final result = await _processSingleImageImport(
        imageFile: imageItem,
        targetCategoryId: targetCategoryId,
        onEncodingTriggered: () => hasEncoding = true,
      );

      if (result == true) {
        totalSuccess++;
      } else if (result == false) {
        totalFail++;
      }
      // result == null 表示用户取消，不计入成功或失败
    }

    if (vibeFiles.isNotEmpty) {
      try {
        var applyNamingToAll = false;
        String? batchNamingBase;
        final result = await importService.importFromFile(
          files: vibeFiles,
          categoryId: targetCategoryId,
          onProgress: (current, _, message) {
            onProgress(imageItems.length + current, totalCount, message);
          },
          onNaming:
              (
                suggestedName, {
                required bool isBatch,
                Uint8List? thumbnail,
              }) async {
                if (!mounted) {
                  return null;
                }

                if (isBatch && applyNamingToAll && batchNamingBase != null) {
                  return batchNamingBase;
                }

                final namingResult =
                    await naming_dialog.VibeImportNamingDialog.show(
                      context: context,
                      suggestedName: suggestedName,
                      thumbnail: thumbnail,
                      isBatchImport: isBatch,
                    );
                if (namingResult == null) {
                  return null;
                }

                final customName = namingResult.name.trim();
                if (customName.isEmpty) {
                  return null;
                }

                if (isBatch && namingResult.applyToAll) {
                  applyNamingToAll = true;
                  batchNamingBase = customName;
                }
                return customName;
              },
          onBundleOption: (bundleName, vibes) async {
            if (!mounted) {
              return null;
            }

            final bundleResult =
                await bundle_import_dialog.VibeBundleImportDialog.show(
                  context: context,
                  bundleName: bundleName,
                  vibeNames: vibes.map((vibe) => vibe.displayName).toList(),
                  vibeReferences: vibes,
                );
            if (bundleResult == null) {
              return null;
            }

            switch (bundleResult.option) {
              case bundle_import_dialog.BundleImportOption.keepAsBundle:
                return BundleImportOption.keepAsBundle(
                  configuredReferences: bundleResult.configuredVibes,
                );
              case bundle_import_dialog.BundleImportOption.split:
                return BundleImportOption.split(
                  configuredReferences: bundleResult.configuredVibes,
                );
              case bundle_import_dialog.BundleImportOption.importSelected:
                return BundleImportOption.select(
                  bundleResult.selectedIndices ?? const <int>[],
                  configuredReferences: bundleResult.configuredVibes,
                );
            }
          },
        );
        totalSuccess += result.successCount;
        totalFail += result.failCount;
      } catch (e, stackTrace) {
        AppLogger.e('导入 Vibe 文件失败', e, stackTrace, 'VibeLibrary');
        totalFail += vibeFiles.length;
      }
    }

    return (success: totalSuccess, fail: totalFail, hasEncoding: hasEncoding);
  }

  Future<void> _handleImportResult(
    int totalSuccess,
    int totalFail, {
    bool skipReload = false,
  }) async {
    // 用户全部取消，不显示任何提示
    if (totalSuccess == 0 && totalFail == 0) {
      return;
    }

    // 导入流程直接写入存储层，无需额外重扫文件系统。
    if (totalSuccess > 0 && !skipReload) {
      await ref.read(vibeLibraryNotifierProvider.notifier).loadFromCache();
    }

    if (!mounted) {
      return;
    }

    if (totalFail == 0) {
      AppToast.success(
        context,
        context.l10n.vibeLibrary_importSuccessCount(totalSuccess),
      );
    } else {
      AppToast.warning(
        context,
        context.l10n.vibeLibrary_importSummary(totalSuccess, totalFail),
      );
    }
  }

  /// 读取 PlatformFile 的字节
  Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw ArgumentError('File path is empty: ${file.name}');
    }

    return File(path).readAsBytes();
  }

  /// 导出 Vibe (使用 V2 对话框)
  Future<void> _exportVibes({List<VibeLibraryEntry>? specificEntries}) async {
    final state = ref.read(vibeLibraryNotifierProvider);
    final sourceEntries = specificEntries ?? state.entries;
    final entriesToExport = sourceEntries.length == 1
        ? await _resolveEntriesForAction(sourceEntries)
        : sourceEntries;

    if (entriesToExport.isEmpty || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => VibeExportDialogAdvanced(entries: entriesToExport),
    );
  }

  Future<List<VibeLibraryEntry>> _resolveEntriesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];

    final state = ref.read(vibeLibraryNotifierProvider);
    final entriesById = {for (final entry in state.entries) entry.id: entry};
    final entries = <VibeLibraryEntry>[];
    for (final id in ids) {
      final entry = entriesById[id];
      if (entry != null) {
        entries.add(entry);
      }
    }

    return _resolveEntriesForAction(entries);
  }

  Future<List<VibeLibraryEntry>> _resolveEntriesForAction(
    List<VibeLibraryEntry> entries,
  ) async {
    if (entries.isEmpty) return const [];

    final storage = ref.read(vibeLibraryStorageServiceProvider);
    final resolvedEntries = <VibeLibraryEntry>[];

    for (final entry in entries) {
      resolvedEntries.add(await storage.getEntry(entry.id) ?? entry);
    }

    return resolvedEntries;
  }

  /// 递归扫描文件夹内可导入的图片和 Vibe 文件
  Future<Map<String, List<String>>> _scanImportableFilesInFolder(
    String folderPath,
  ) async {
    final vibeFiles = <String>[];
    final imageFiles = <String>[];
    final dir = Directory(folderPath);

    if (!await dir.exists()) {
      return {'images': imageFiles, 'vibeFiles': vibeFiles};
    }

    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          final ext = p.extension(fileName).toLowerCase();
          if (_vibeImportImageExtensions.contains(ext.replaceFirst('.', ''))) {
            imageFiles.add(entity.path);
          } else if (ext == '.naiv4vibe' || ext == '.naiv4vibebundle') {
            vibeFiles.add(entity.path);
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e('扫描文件夹失败: $folderPath', e, stackTrace, 'VibeLibrary');
    }

    return {'images': imageFiles, 'vibeFiles': vibeFiles};
  }

  /// 在 Isolate 中分类文件
  static Future<Map<String, List<String>>> _classifyPathsIsolate(
    List<String> paths,
  ) async {
    final folderPaths = <String>[];
    final imagePaths = <String>[];
    final vibeFilePaths = <String>[];

    for (final path in paths) {
      try {
        final entity = await FileSystemEntity.type(path, followLinks: false);

        if (entity == FileSystemEntityType.directory) {
          folderPaths.add(path);
        } else if (entity == FileSystemEntityType.file) {
          final fileName = p.basename(path);
          final ext = p.extension(fileName).toLowerCase();

          if (_vibeImportImageExtensions.contains(ext.replaceFirst('.', ''))) {
            imagePaths.add(path);
          } else if (ext == '.naiv4vibe' || ext == '.naiv4vibebundle') {
            vibeFilePaths.add(path);
          }
        }
      } catch (e) {
        // 忽略无法访问的路径
      }
    }

    return {
      'folders': folderPaths,
      'images': imagePaths,
      'vibeFiles': vibeFilePaths,
    };
  }

  /// 处理拖拽文件
  /// 支持 .naiv4vibe, .naiv4vibebundle, .png/.jpg/.jpeg/.webp 格式，以及文件夹
  Future<void> _handleDrop(PerformDropEvent event) async {
    _beginImportSession();
    try {
      final allPaths = <String>[];

      for (final item in event.session.items) {
        final reader = item.dataReader;
        if (reader == null) continue;

        if (reader.canProvide(Formats.fileUri)) {
          final completer = Completer<Uri?>();
          final progress = reader.getValue<Uri>(
            Formats.fileUri,
            (uri) {
              if (!completer.isCompleted) {
                completer.complete(uri);
              }
            },
            onError: (e) {
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            },
          );

          if (progress == null) continue;

          final uri = await completer.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
          if (uri != null) {
            allPaths.add(uri.toFilePath());
          }
        }
      }

      if (allPaths.isEmpty) {
        return;
      }

      final classified = await compute(_classifyPathsIsolate, allPaths);
      final folderPaths = classified['folders'] ?? <String>[];
      final imagePaths = classified['images'] ?? <String>[];
      final vibeFilePaths = classified['vibeFiles'] ?? <String>[];

      if (folderPaths.isNotEmpty) {
        for (final folderPath in folderPaths) {
          final scanned = await _scanImportableFilesInFolder(folderPath);
          imagePaths.addAll(scanned['images'] ?? const <String>[]);
          vibeFilePaths.addAll(scanned['vibeFiles'] ?? const <String>[]);
        }
      }

      if (imagePaths.isEmpty && vibeFilePaths.isEmpty) {
        return;
      }

      if (mounted) {
        setState(() {
          _isImporting = true;
          _importProgress = ImportProgress(
            total: imagePaths.length + vibeFilePaths.length,
            message: context.l10n.vibeLibrary_preparingImport,
          );
        });
      }

      final currentCategoryId = ref
          .read(vibeLibraryNotifierProvider)
          .selectedCategoryId;
      final targetCategoryId =
          (currentCategoryId != null && currentCategoryId != 'favorites')
          ? currentCategoryId
          : null;

      final imagePreprocessResult =
          await VibeDropImportPreprocessor.collectImageItems(imagePaths);
      final imageItems = imagePreprocessResult.items;
      final preProcessFail =
          imagePreprocessResult.failedCount +
          imagePreprocessResult.skippedOversizedCount +
          imagePreprocessResult.skippedTotalLimitCount;

      final vibeFiles = vibeFilePaths
          .map(
            (path) => PlatformFile(name: p.basename(path), size: 0, path: path),
          )
          .toList();

      final result = await _processImportSources(
        imageItems: imageItems,
        vibeFiles: vibeFiles,
        targetCategoryId: targetCategoryId,
        onProgress: (current, total, message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _importProgress = _importProgress.copyWith(
              current: current,
              total: total,
              message: message,
            );
          });
        },
      );

      final totalSuccess = result.success;
      final totalFail = result.fail + preProcessFail;

      if (mounted) {
        setState(() {
          _isImporting = false;
          _importProgress = const ImportProgress();
        });
      }

      if (totalSuccess == 0 && totalFail == 0) {
        return;
      }

      if (totalSuccess > 0) {
        await ref.read(vibeLibraryNotifierProvider.notifier).loadFromCache();
      }

      if (mounted) {
        if (totalFail == 0) {
          AppToast.success(
            context,
            context.l10n.vibeLibrary_importSuccessCount(totalSuccess),
          );
        } else {
          AppToast.warning(
            context,
            context.l10n.vibeLibrary_importSummary(totalSuccess, totalFail),
          );
        }
      }
    } finally {
      _endImportSession();
      if (mounted &&
          (_isImporting || _importProgress != const ImportProgress())) {
        setState(() {
          _isImporting = false;
          _importProgress = const ImportProgress();
        });
      }
    }
  }

  /// 构建拖拽覆盖层
  Widget _buildDropOverlay(ThemeData theme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                  ),
                ],
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
                  Text(
                    context.l10n.vibeLibrary_dropImportHint,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

  /// 从图片导入 Vibe
  Future<void> _importVibesFromImage() async {
    if (!mounted) return;
    _beginImportSession();
    setState(() => _isPickingFile = true);

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _vibeImportImageExtensions,
        allowMultiple: true,
        dialogTitle: context.l10n.vibeLibrary_importImageDialogTitle,
        withData: false,
        lockParentWindow: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingFile = false);
      }
    }

    if (!mounted) {
      _endImportSession();
      return;
    }

    if (result == null || result.files.isEmpty) {
      _endImportSession();
      return;
    }

    setState(() => _isImporting = true);

    // 获取当前选中的分类
    final currentCategoryId = ref
        .read(vibeLibraryNotifierProvider)
        .selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
        ? currentCategoryId
        : null;

    // 收集图片文件
    final imageFiles = <VibeImageImportItem>[];
    for (final file in result.files) {
      try {
        final bytes = await _readPlatformFileBytes(file);
        imageFiles.add(VibeImageImportItem(source: file.name, bytes: bytes));
      } catch (e) {
        AppLogger.e('读取图片文件失败: ${file.name}', e, null, 'VibeLibrary');
      }
    }

    var totalSuccess = 0;
    var totalFail = 0;

    try {
      // 处理每张图片
      for (final imageFile in imageFiles) {
        final result = await _processSingleImageImport(
          imageFile: imageFile,
          targetCategoryId: targetCategoryId,
        );

        if (result == true) {
          totalSuccess++;
        } else if (result == false) {
          totalFail++;
        }
        // result == null 表示用户取消，不计入统计
      }

      if (!mounted) {
        return;
      }
      setState(() => _isImporting = false);

      // 用户全部取消，不显示任何提示
      if (totalSuccess == 0 && totalFail == 0) {
        return;
      }

      // 重新加载数据
      if (totalSuccess > 0) {
        await ref.read(vibeLibraryNotifierProvider.notifier).loadFromCache();
      }

      if (mounted) {
        if (totalFail == 0) {
          AppToast.success(
            context,
            context.l10n.vibeLibrary_importSuccessCount(totalSuccess),
          );
        } else {
          AppToast.warning(
            context,
            context.l10n.vibeLibrary_importSummary(totalSuccess, totalFail),
          );
        }
      }
    } finally {
      _endImportSession();
      if (mounted && _isImporting) {
        setState(() => _isImporting = false);
      }
    }
  }

  /// 处理单张图片导入
  ///
  /// 返回:
  /// - true: 成功导入
  /// - false: 导入失败
  /// - null: 用户取消
  Future<bool?> _processSingleImageImport({
    required VibeImageImportItem imageFile,
    String? targetCategoryId,
    VoidCallback? onEncodingTriggered,
  }) async {
    try {
      final references = await VibeFileParser.parseFile(
        imageFile.source,
        imageFile.bytes,
      );
      final shouldEncodeAsRawImage =
          references.isNotEmpty &&
          references.every(
            (reference) =>
                reference.sourceType == VibeSourceType.rawImage &&
                reference.vibeEncoding.isEmpty,
          );

      if (shouldEncodeAsRawImage) {
        onEncodingTriggered?.call();
        return await _handleImageEncoding(
          imageFile: imageFile,
          targetCategoryId: targetCategoryId,
        );
      }

      final encodedReferences = references
          .where((reference) => reference.vibeEncoding.isNotEmpty)
          .toList();
      if (encodedReferences.isEmpty) {
        onEncodingTriggered?.call();
        return await _handleImageEncoding(
          imageFile: imageFile,
          targetCategoryId: targetCategoryId,
        );
      }

      // 如果是 bundle（多个 vibes），让用户选择处理方式
      if (encodedReferences.length > 1) {
        return await _handleBundleImport(
          imageFile: imageFile,
          vibes: encodedReferences,
          targetCategoryId: targetCategoryId,
        );
      }

      // 单个 vibe，直接保存
      return await _saveVibeReference(
        reference: encodedReferences.first,
        categoryId: targetCategoryId,
      );
    } on NoVibeDataException {
      // 标记编码流程被触发
      onEncodingTriggered?.call();
      return await _handleImageEncoding(
        imageFile: imageFile,
        targetCategoryId: targetCategoryId,
      );
    } catch (e) {
      if (_isNoVibeDataError(e)) {
        // 标记编码流程被触发
        onEncodingTriggered?.call();
        return await _handleImageEncoding(
          imageFile: imageFile,
          targetCategoryId: targetCategoryId,
        );
      }
      AppLogger.e('处理图片失败: ${imageFile.source}', e, null, 'VibeLibrary');
      return false;
    }
  }

  /// 保存 VibeReference 到库
  Future<bool> _saveVibeReference({
    required VibeReference reference,
    String? categoryId,
  }) async {
    try {
      final storage = ref.read(vibeLibraryStorageServiceProvider);

      // 生成唯一名称（处理重名）
      final baseName = reference.displayName.trim().isEmpty
          ? 'vibe_${DateTime.now().millisecondsSinceEpoch}'
          : reference.displayName.trim();
      final uniqueName = _generateUniqueName(baseName);

      // 创建条目
      final entry = VibeLibraryEntry.fromVibeReference(
        name: uniqueName,
        vibeData: reference,
        categoryId: categoryId,
      );

      await storage.saveEntry(entry);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('保存 Vibe 到库失败', e, stackTrace, 'VibeLibrary');
      return false;
    }
  }

  /// 生成唯一名称（避免重名）
  String _generateUniqueName(String baseName) {
    final existingNames =
        _reservedImportNames ??
        ref
            .read(vibeLibraryNotifierProvider)
            .entries
            .map((e) => e.name.toLowerCase())
            .toSet();

    if (!existingNames.contains(baseName.toLowerCase())) {
      _reservedImportNames?.add(baseName.toLowerCase());
      return baseName;
    }

    // 名称冲突，添加序号
    var index = 2;
    var candidateName = '$baseName ($index)';
    while (existingNames.contains(candidateName.toLowerCase())) {
      index++;
      candidateName = '$baseName ($index)';
    }
    _reservedImportNames?.add(candidateName.toLowerCase());
    return candidateName;
  }

  /// 处理 Bundle 导入
  Future<bool?> _handleBundleImport({
    required VibeImageImportItem imageFile,
    required List<VibeReference> vibes,
    String? targetCategoryId,
  }) async {
    if (!mounted) return null;

    // 显示 Bundle 导入选项对话框
    final result = await showDialog<bundle_import_dialog.BundleImportResult>(
      context: context,
      builder: (context) => bundle_import_dialog.VibeBundleImportDialog(
        bundleName: imageFile.source,
        vibeNames: vibes.map((v) => v.displayName).toList(),
        vibeReferences: vibes,
      ),
    );

    if (result == null) return null; // 用户取消

    final selectedVibes = _getSelectedVibesForBundle(result, vibes);
    if (selectedVibes == null) return null;

    // 保持为 Bundle - 保存整个 bundle 为一个条目
    if (result.option == bundle_import_dialog.BundleImportOption.keepAsBundle) {
      return await _saveAsBundle(
        vibes: selectedVibes,
        bundleName: imageFile.source,
        categoryId: targetCategoryId,
      );
    }

    // 拆分导入或选择性导入 - 保存所有选中的 vibes
    return await _saveMultipleVibes(selectedVibes, targetCategoryId);
  }

  List<VibeReference>? _getSelectedVibesForBundle(
    bundle_import_dialog.BundleImportResult result,
    List<VibeReference> vibes,
  ) {
    final configuredVibes =
        result.configuredVibes != null &&
            result.configuredVibes!.length == vibes.length
        ? result.configuredVibes!
        : vibes;
    switch (result.option) {
      case bundle_import_dialog.BundleImportOption.keepAsBundle:
      case bundle_import_dialog.BundleImportOption.split:
        return configuredVibes;
      case bundle_import_dialog.BundleImportOption.importSelected:
        final indices = result.selectedIndices;
        if (indices == null || indices.isEmpty) return null;
        return indices
            .where((index) => index >= 0 && index < configuredVibes.length)
            .map((index) => configuredVibes[index])
            .toList();
    }
  }

  Future<bool> _saveMultipleVibes(
    List<VibeReference> vibes,
    String? categoryId,
  ) async {
    var successCount = 0;
    for (final vibe in vibes) {
      final saved = await _saveVibeReference(
        reference: vibe,
        categoryId: categoryId,
      );
      if (saved) successCount++;
    }
    return successCount > 0;
  }

  /// 保存为 Bundle 条目
  Future<bool> _saveAsBundle({
    required List<VibeReference> vibes,
    required String bundleName,
    String? categoryId,
  }) async {
    try {
      final storage = ref.read(vibeLibraryStorageServiceProvider);

      // 生成唯一名称（处理重名）
      final baseName = bundleName.trim().isEmpty
          ? 'vibe-bundle_${DateTime.now().millisecondsSinceEpoch}'
          : bundleName.trim();
      final uniqueName = _generateUniqueName(baseName);

      // 使用 saveBundleEntry 保存整个 bundle
      final saved = await storage.saveBundleEntry(
        vibes,
        name: uniqueName,
        categoryId: categoryId,
      );
      return saved.filePath != null;
    } catch (e, stackTrace) {
      AppLogger.e('保存 Bundle 到库失败', e, stackTrace, 'VibeLibrary');
      return false;
    }
  }

  /// 处理图片编码流程
  bool _isNoVibeDataError(Object e) {
    return e is NoVibeDataException ||
        e.toString().contains('No naiv4vibe metadata');
  }

  Future<bool?> _handleImageEncoding({
    required VibeImageImportItem imageFile,
    String? targetCategoryId,
  }) async {
    if (!mounted) return null;

    final l10n = context.l10n;

    // 显示编码配置对话框
    final config = await encode_dialog.VibeImageEncodeDialog.show(
      context: context,
      imageBytes: imageFile.bytes,
      fileName: imageFile.source,
    );

    if (config == null) return null; // 用户取消

    // 编码重试循环
    while (mounted) {
      if (!mounted) break;

      // 显示编码中对话框，使用自己的 context 管理
      final dialogCompleter = Completer<void>();
      BuildContext? dialogContext;

      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (ctx) {
            dialogContext = ctx;
            dialogCompleter.complete();
            return const encode_dialog.VibeImageEncodingDialog();
          },
        ),
      );

      // 等待对话框显示完成
      await dialogCompleter.future;

      void closeDialog() {
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.of(dialogContext!).pop();
        }
      }

      String? encoding;
      String? errorMessage;

      try {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);
        final params = ref.read(generationParamsNotifierProvider);
        final model = params.model;

        encoding = await notifier
            .encodeVibeWithCache(
              imageFile.bytes,
              model: model,
              informationExtracted: config.infoExtracted,
              vibeName: config.name,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                errorMessage = l10n.vibeLibrary_encodeTimeout;
                return null;
              },
            );
      } catch (e) {
        errorMessage = e.toString();
        AppLogger.e('Vibe 编码失败: ${imageFile.source}', e, null, 'VibeLibrary');
      } finally {
        // 关闭编码中对话框
        closeDialog();
      }

      if (encoding != null && mounted) {
        // 编码成功，保存到 Vibe 库
        return await _saveEncodedVibe(
          name: config.name,
          encoding: encoding,
          imageBytes: imageFile.bytes,
          strength: config.strength,
          infoExtracted: config.infoExtracted,
          categoryId: targetCategoryId,
        );
      }

      // 编码失败，显示错误对话框
      if (!mounted) return null;

      final action = await encode_dialog.VibeImageEncodeErrorDialog.show(
        context: context,
        fileName: imageFile.source,
        errorMessage: errorMessage ?? context.l10n.vibeLibrary_unknownError,
      );

      if (action == encode_dialog.VibeEncodeErrorAction.skip) {
        return false; // 标记为失败，继续下一张
      } else if (action == null) {
        return null; // 用户关闭对话框，视为取消
      }
      // 否则重试
    }

    return null;
  }

  /// 保存编码后的 Vibe 到库
  Future<bool> _saveEncodedVibe({
    required String name,
    required String encoding,
    required Uint8List imageBytes,
    required double strength,
    required double infoExtracted,
    String? categoryId,
  }) async {
    try {
      final storage = ref.read(vibeLibraryStorageServiceProvider);

      // 创建 VibeReference
      final reference = VibeReference(
        displayName: name,
        vibeEncoding: encoding,
        strength: strength,
        infoExtracted: infoExtracted,
        sourceType: VibeSourceType.naiv4vibe,
        thumbnail: imageBytes,
        rawImageData: imageBytes,
      );

      // 创建并保存条目
      final entry = VibeLibraryEntry.fromVibeReference(
        name: name,
        vibeData: reference,
        categoryId: categoryId,
      );

      await storage.saveEntry(entry);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('保存编码 Vibe 失败', e, stackTrace, 'VibeLibrary');
      return false;
    }
  }

  /// 从剪贴板导入 Vibe 编码
  Future<void> _importVibesFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim();

    if (text == null || text.isEmpty) {
      if (mounted) {
        AppToast.error(context, context.l10n.vibeLibrary_clipboardEmpty);
      }
      return;
    }

    _beginImportSession();
    if (!mounted) {
      _endImportSession();
      return;
    }
    setState(() => _isImporting = true);

    // 获取当前选中的分类
    final currentCategoryId = ref
        .read(vibeLibraryNotifierProvider)
        .selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
        ? currentCategoryId
        : null;

    // 创建导入服务和仓库
    final storage = ref.read(vibeLibraryStorageServiceProvider);
    final repository = VibeLibraryStorageImportRepository(storage);
    final importService = VibeImportService(repository: repository);

    var totalSuccess = 0;
    var totalFail = 0;

    try {
      try {
        final result = await importService.importFromEncoding(
          items: [VibeEncodingImportItem(source: '剪贴板', encoding: text)],
          categoryId: targetCategoryId,
          onProgress: (current, total, message) {
            AppLogger.d(message, 'VibeLibrary');
          },
        );
        totalSuccess += result.successCount;
        totalFail += result.failCount;
      } catch (e, stackTrace) {
        AppLogger.e('从剪贴板导入 Vibe 失败', e, stackTrace, 'VibeLibrary');
        totalFail++;
      }

      if (!mounted) {
        return;
      }
      setState(() => _isImporting = false);

      // 用户全部取消，不显示任何提示
      if (totalSuccess == 0 && totalFail == 0) {
        return;
      }

      // 重新加载数据
      if (totalSuccess > 0) {
        await ref.read(vibeLibraryNotifierProvider.notifier).loadFromCache();
      }

      if (mounted) {
        if (totalFail == 0) {
          AppToast.success(
            context,
            context.l10n.vibeLibrary_importSuccessCount(totalSuccess),
          );
        } else {
          AppToast.warning(
            context,
            context.l10n.vibeLibrary_importSummary(totalSuccess, totalFail),
          );
        }
      }
    } finally {
      _endImportSession();
      if (mounted && _isImporting) {
        setState(() => _isImporting = false);
      }
    }
  }
}
