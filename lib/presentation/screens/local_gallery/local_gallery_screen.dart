import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_prompt_formatter.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../widgets/shortcuts/shortcut_aware_widget.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/models/character/character_prompt.dart' as char;
import '../../../data/models/image/image_params.dart';
import '../../../data/models/metadata/metadata_import_options.dart';
import '../../../core/utils/zip_utils.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../providers/collection_provider.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../providers/gallery_folder_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/grouped_grid_view.dart' show GroupedGridViewState, ImageDateGroup;
import '../../widgets/bulk_metadata_edit_dialog.dart';
import '../../widgets/collection_select_dialog.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import '../../widgets/gallery/gallery_content_view.dart';
import '../../widgets/gallery/gallery_category_tree_view.dart';
import '../../widgets/gallery/image_send_destination_dialog.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';

import '../../widgets/common/app_toast.dart';
import '../../widgets/gallery/local_gallery_toolbar.dart';
import '../../widgets/gallery_filter_panel.dart';
import 'dart:async';

/// 本地画廊屏幕
/// Local gallery screen
class LocalGalleryScreen extends ConsumerStatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  ConsumerState<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends ConsumerState<LocalGalleryScreen> {
  /// Key for accessing GroupedGridView's scrollToGroup method
  /// 用于访问 GroupedGridView 的 scrollToGroup 方法的键
  final GlobalKey<GroupedGridViewState> _groupedGridViewKey =
      GlobalKey<GroupedGridViewState>();

  /// Focus node for keyboard shortcuts
  /// 用于键盘快捷键的焦点节点
  final FocusNode _shortcutsFocusNode = FocusNode();

  /// 是否使用3D卡片视图
  /// Whether to use 3D card view mode
  final bool _use3DCardView = true;

  /// 是否显示分类面板
  /// Whether to show category panel
  bool _showCategoryPanel = true;

  @override
  void initState() {
    super.initState();
    // 首次加载时检查权限并扫描图片
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndScan();
      await _showFirstTimeTip();
    });
  }

  @override
  void dispose() {
    _shortcutsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final bulkOpState = ref.watch(bulkOperationNotifierProvider);
    final categoryState = ref.watch(galleryCategoryNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    // 计算内容区域宽度（减去分类面板宽度）
    final contentWidth = _showCategoryPanel && screenWidth > 800
        ? screenWidth - 250
        : screenWidth;

    // 计算列数（200px/列，最少2列，最多8列）
    final columns = (contentWidth / 200).floor().clamp(2, 8);
    final itemWidth = contentWidth / columns;

    // 定义快捷键动作映射
    final shortcuts = <String, VoidCallback>{
      // 上一页
      ShortcutIds.previousPage: () {
        if (state.currentPage > 0) {
          ref.read(localGalleryNotifierProvider.notifier).loadPage(state.currentPage - 1);
        }
      },
      // 下一页
      ShortcutIds.nextPage: () {
        if (state.currentPage < state.totalPages - 1) {
          ref.read(localGalleryNotifierProvider.notifier).loadPage(state.currentPage + 1);
        }
      },
      // 刷新
      ShortcutIds.refreshGallery: () {
        ref.read(localGalleryNotifierProvider.notifier).refresh();
      },
      // 搜索聚焦
      ShortcutIds.focusSearch: () {
        // 通过 FocusScope 请求搜索框焦点
        // 搜索框在 LocalGalleryToolbar 中，需要通过全局 key 或其他方式访问
        // 这里使用 FocusManager 来请求焦点到搜索框
        final focusNode = FocusManager.instance.primaryFocus;
        if (focusNode != null) {
          focusNode.unfocus();
        }
        // 延迟一下确保能正确聚焦到搜索框
        Future.delayed(const Duration(milliseconds: 50), () {
          FocusManager.instance.primaryFocus?.requestFocus();
        });
      },
      // 进入选择模式
      ShortcutIds.enterSelectionMode: () {
        ref.read(localGallerySelectionNotifierProvider.notifier).enter();
      },
      // 打开筛选面板
      ShortcutIds.openFilterPanel: () {
        showGalleryFilterPanel(context);
      },
      // 清除筛选
      ShortcutIds.clearFilter: () {
        ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
      },
      // 切换分类面板
      ShortcutIds.toggleCategoryPanel: () {
        // 通过回调触发分类面板切换
        _toggleCategoryPanel();
      },
      // 跳转到日期
      ShortcutIds.jumpToDate: () {
        _jumpToDate();
      },
      // 打开文件夹
      ShortcutIds.openFolder: () {
        _openGalleryFolder();
      },
    };

    return PageShortcuts(
      contextType: ShortcutContext.gallery,
      shortcuts: shortcuts,
      child: KeyboardListener(
        focusNode: _shortcutsFocusNode,
        autofocus: true,
        onKeyEvent: (event) => _handleKeyEvent(event, bulkOpState),
        child: Scaffold(
          body: Row(
            children: [
            // 左侧分类面板
            if (_showCategoryPanel && screenWidth > 800)
              Container(
                width: 250,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(
                    right: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // 顶部标题栏（参考词库布局）
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
                              '分类',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final name = await ThemedInputDialog.show(
                                context: context,
                                title: '新建分类',
                                hintText: '请输入分类名称',
                                confirmText: '创建',
                                cancelText: '取消',
                              );
                              if (name != null && name.isNotEmpty) {
                                await ref
                                    .read(
                                      galleryCategoryNotifierProvider.notifier,
                                    )
                                    .createCategory(name, parentId: null);
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              '新建',
                              style: TextStyle(fontSize: 13),
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
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                    // 分类树
                    Expanded(
                      child: GalleryCategoryTreeView(
                        categories: categoryState.categories,
                        totalImageCount: state.allFiles.length,
                        favoriteCount: ref
                            .read(localGalleryNotifierProvider.notifier)
                            .getTotalFavoriteCount(),
                        selectedCategoryId: categoryState.selectedCategoryId,
                        onCategorySelected: (id) {
                          ref
                              .read(galleryCategoryNotifierProvider.notifier)
                              .selectCategory(id);
                          // 处理收藏筛选
                          if (id == 'favorites') {
                            ref
                                .read(localGalleryNotifierProvider.notifier)
                                .setShowFavoritesOnly(true);
                          } else {
                            ref
                                .read(localGalleryNotifierProvider.notifier)
                                .setShowFavoritesOnly(false);
                          }
                        },
                        onCategoryRename: (id, newName) async {
                          await ref
                              .read(galleryCategoryNotifierProvider.notifier)
                              .renameCategory(id, newName);
                        },
                        onCategoryDelete: (id) async {
                          final confirmed = await ThemedConfirmDialog.show(
                            context: context,
                            title: '确认删除',
                            content: '确定要删除此分类吗？文件夹及其内容将被保留。',
                            confirmText: '删除',
                            cancelText: '取消',
                            type: ThemedConfirmDialogType.danger,
                            icon: Icons.delete_outline,
                          );
                          if (confirmed) {
                            await ref
                                .read(galleryCategoryNotifierProvider.notifier)
                                .deleteCategory(id, deleteFolder: false);
                          }
                        },
                        onAddSubCategory: (parentId) async {
                          final name = await ThemedInputDialog.show(
                            context: context,
                            title: parentId == null ? '新建分类' : '新建子分类',
                            hintText: '请输入分类名称',
                            confirmText: '创建',
                            cancelText: '取消',
                          );
                          if (name != null && name.isNotEmpty) {
                            await ref
                                .read(galleryCategoryNotifierProvider.notifier)
                                .createCategory(name, parentId: parentId);
                          }
                        },
                        onCategoryMove: (categoryId, newParentId) async {
                          await ref
                              .read(galleryCategoryNotifierProvider.notifier)
                              .moveCategory(categoryId, newParentId);
                        },
                        onCategoryReorder:
                            (parentId, oldIndex, newIndex) async {
                          await ref
                              .read(galleryCategoryNotifierProvider.notifier)
                              .reorderCategories(parentId, oldIndex, newIndex);
                        },
                        onImageDrop: (imagePath, categoryId) async {
                          final newPath = await ref
                              .read(galleryCategoryNotifierProvider.notifier)
                              .moveImageToCategory(imagePath, categoryId);
                          if (newPath != null) {
                            ref
                                .read(localGalleryNotifierProvider.notifier)
                                .refresh();
                            if (context.mounted) {
                              AppToast.success(context, '图片已移动到分类');
                            }
                          }
                        },
                        onSyncWithFileSystem: () async {
                          await ref
                              .read(galleryCategoryNotifierProvider.notifier)
                              .syncWithFileSystem();
                          if (context.mounted) {
                            AppToast.success(context, '分类已与文件夹同步');
                          }
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
                  // 批量操作栏（只在选择模式时显示）或工具栏
                  _buildToolbarOrSelectionBar(state, bulkOpState),
                  // 主体内容
                  Expanded(
                    child: _buildBody(state, columns, itemWidth),
                  ),
                  // 底部分页条（增强版）
                  if (!state.isIndexing &&
                      state.filteredFiles.isNotEmpty &&
                      state.totalPages > 0)
                    PaginationBar(
                      currentPage: state.currentPage,
                      totalPages: state.totalPages,
                      totalItems: state.filteredCount,
                      itemsPerPage: state.pageSize,
                      onPageChanged: (p) => ref
                          .read(localGalleryNotifierProvider.notifier)
                          .loadPage(p),
                      onItemsPerPageChanged: (size) => ref
                          .read(localGalleryNotifierProvider.notifier)
                          .setPageSize(size),
                      showItemsPerPage: true,
                      showTotalInfo: true,
                      compact: contentWidth < 600,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  /// 处理重建索引
  Future<void> _handleRebuildIndex() async {
    final notifier = ref.read(localGalleryNotifierProvider.notifier);
    final state = ref.read(localGalleryNotifierProvider);
    
    // 如果已经在更新中，则取消
    if (state.isRebuildingIndex) {
      await notifier.performFullScan(); // 这会触发取消
      if (mounted) {
        AppToast.info(context, '已取消索引更新');
      }
      return;
    }
    
    // 开始更新
    final result = await notifier.performFullScan();
    
    if (!mounted) return;
    
    if (result == null) {
      // 可能是取消或失败
      final currentState = ref.read(localGalleryNotifierProvider);
      if (!currentState.isRebuildingIndex) {
        // 确实已经停止了，可能是取消
        AppToast.info(context, '索引更新已停止');
      }
      return;
    }
    
    if (result.filesAdded == 0 && result.filesUpdated == 0 && result.filesDeleted == 0) {
      // 没有变化
      AppToast.info(context, '索引已是最新，无需更新');
    } else {
      // 有更新
      final parts = <String>[];
      if (result.filesAdded > 0) parts.add('新增 ${result.filesAdded} 张');
      if (result.filesUpdated > 0) parts.add('更新 ${result.filesUpdated} 张');
      if (result.filesDeleted > 0) parts.add('删除 ${result.filesDeleted} 张');
      
      AppToast.success(context, '索引更新完成：${parts.join('，')}');
    }
  }

  /// 构建工具栏或选择栏
  Widget _buildToolbarOrSelectionBar(
    LocalGalleryState state,
    BulkOperationState bulkOpState,
  ) {
    // 使用独立的美化工具栏组件
    return LocalGalleryToolbar(
      use3DCardView: _use3DCardView,
      onRefresh: () =>
          ref.read(localGalleryNotifierProvider.notifier).refresh(),
      onRebuildIndex: () => _handleRebuildIndex(),
      onEnterSelectionMode: () =>
          ref.read(localGallerySelectionNotifierProvider.notifier).enter(),
      canUndo: bulkOpState.canUndo,
      canRedo: bulkOpState.canRedo,
      onUndo: bulkOpState.canUndo
          ? () => ref.read(bulkOperationNotifierProvider.notifier).undo()
          : null,
      onRedo: bulkOpState.canRedo
          ? () => ref.read(bulkOperationNotifierProvider.notifier).redo()
          : null,
      groupedGridViewKey: _groupedGridViewKey,
      onAddToCollection: _addSelectedToCollection,
      onDeleteSelected: _deleteSelectedImages,
      onPackSelected: _packSelectedImages,
      onEditMetadata: _editSelectedMetadata,
      onMoveToFolder: _moveSelectedToFolder,
      showCategoryPanel: _showCategoryPanel,
      onOpenFolder: () => _openGalleryFolder(),
    );
  }

  /// Build main body content
  /// 构建主体内容
  Widget _buildBody(LocalGalleryState state, int columns, double itemWidth) {
    if (state.error != null) {
      return GalleryErrorView(
        error: state.error,
        onRetry: () =>
            ref.read(localGalleryNotifierProvider.notifier).refresh(),
      );
    }

    // 只有在真正加载中且没有文件时才显示加载视图
    // 后台索引时不应阻止用户浏览已加载的文件
    if (state.isLoading && state.allFiles.isEmpty) {
      return const GalleryLoadingView();
    }

    if (state.allFiles.isEmpty) {
      return const GalleryEmptyView();
    }

    return GalleryContentView(
      use3DCardView: _use3DCardView,
      columns: columns,
      itemWidth: itemWidth,
      groupedGridViewKey: _groupedGridViewKey,
      onReuseMetadata: _reuseMetadata,
      onSendToImg2Img: _sendToImg2Img,
      onContextMenu: (record, position) {
        _showImageContextMenu(record, position);
      },
    );
  }

  /// Handle keyboard events for undo/redo
  /// 处理撤销/重做的键盘事件
  void _handleKeyEvent(KeyEvent event, BulkOperationState bulkOpState) {
    if (event is KeyDownEvent) {
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

      if (isCtrlPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyZ) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            // Ctrl+Shift+Z for redo
            if (bulkOpState.canRedo) _redo();
          } else {
            // Ctrl+Z for undo
            if (bulkOpState.canUndo) _undo();
          }
        } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
          // Ctrl+Y for redo
          if (bulkOpState.canRedo) _redo();
        }
      }
    }
  }

  // ============================================================
  // Permission and initialization methods
  // 权限和初始化方法
  // ============================================================

  /// 检查权限并扫描图片
  Future<void> _checkPermissionsAndScan() async {
    final hasPermission = await PermissionUtils.checkGalleryPermission();

    if (!hasPermission) {
      final granted = await PermissionUtils.requestGalleryPermission();
      if (!granted && mounted) {
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (mounted) {
      ref.read(localGalleryNotifierProvider.notifier).initialize();
    }
  }

  /// 显示权限被拒绝对话框
  void _showPermissionDeniedDialog() async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.localGallery_permissionRequiredTitle,
      content: context.l10n.localGallery_permissionRequiredContent,
      confirmText: context.l10n.localGallery_openSettings,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.warning,
      icon: Icons.folder_off_outlined,
    );

    if (confirmed) {
      PermissionUtils.openAppSettings();
    }
  }

  /// 显示首次使用提示
  Future<void> _showFirstTimeTip() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTip =
        prefs.getBool(StorageKeys.hasSeenLocalGalleryTip) ?? false;

    if (hasSeenTip || !mounted) return;

    await prefs.setBool(StorageKeys.hasSeenLocalGalleryTip, true);
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await ThemedConfirmDialog.showInfo(
      context: context,
      title: context.l10n.localGallery_firstTimeTipTitle,
      content: context.l10n.localGallery_firstTimeTipContent,
      confirmText: context.l10n.localGallery_gotIt,
      icon: Icons.lightbulb_outline,
    );
  }

  // ============================================================
  // Folder operations
  // 文件夹操作
  // ============================================================

  /// 打开画廊文件夹
  Future<void> _openGalleryFolder() async {
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null || rootPath.isEmpty) {
        if (mounted) {
          AppToast.info(context, '未设置保存目录');
        }
        return;
      }

      final dir = Directory(rootPath);
      if (!await dir.exists()) {
        if (mounted) {
          AppToast.info(context, '文件夹不存在');
        }
        return;
      }

      if (Platform.isWindows) {
        // 使用 Process.start 避免等待进程完成导致的延迟
        await Process.start('explorer', [rootPath]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [rootPath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [rootPath]);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '打开文件夹失败: $e');
      }
    }
  }

  // ============================================================
  // Undo/Redo operations
  // 撤销/重做操作
  // ============================================================

  /// 撤销上一步操作
  Future<void> _undo() async {
    await ref.read(bulkOperationNotifierProvider.notifier).undo();
    await ref.read(localGalleryNotifierProvider.notifier).refresh();

    if (mounted) {
      AppToast.info(context, context.l10n.localGallery_undone);
    }
  }

  /// 重做上一步撤销的操作
  Future<void> _redo() async {
    await ref.read(bulkOperationNotifierProvider.notifier).redo();
    await ref.read(localGalleryNotifierProvider.notifier).refresh();

    if (mounted) {
      AppToast.info(context, context.l10n.localGallery_redone);
    }
  }

  // ============================================================
  // Bulk operations
  // 批量操作
  // ============================================================

  /// 批量删除选中的图片
  Future<void> _deleteSelectedImages() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.localGallery_confirmBulkDelete,
      content: context.l10n
          .localGallery_confirmBulkDeleteContent(selectedImages.length),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (!confirmed || !mounted) return;

    final deletedImages = <LocalImageRecord>[];
    for (final image in selectedImages) {
      try {
        final file = File(image.path);
        if (await file.exists()) {
          await file.delete();
          deletedImages.add(image);
        }
      } catch (e) {
        // Skip failed deletions
      }
    }

    ref.read(localGallerySelectionNotifierProvider.notifier).exit();
    await ref.read(localGalleryNotifierProvider.notifier).refresh();

    if (mounted && deletedImages.isNotEmpty) {
      AppToast.success(
        context,
        context.l10n.localGallery_deletedImages(deletedImages.length),
      );
    }
  }

  /// 批量打包选中的图片成压缩包
  Future<void> _packSelectedImages() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty || !mounted) return;

    // 直接使用保存文件对话框，用户可以选择路径并输入文件名
    final defaultName = 'images_${DateTime.now().millisecondsSinceEpoch}';
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存压缩包',
      fileName: '$defaultName.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null || !mounted) return;

    // 确保文件名以 .zip 结尾
    final finalPath =
        outputPath.endsWith('.zip') ? outputPath : '$outputPath.zip';

    // 显示打包进度
    AppToast.info(context, '正在打包 ${selectedImages.length} 张图片...');

    // 执行打包
    final imagePaths = selectedImages.map((img) => img.path).toList();
    final success = await ZipUtils.createZipFromImages(
      imagePaths,
      finalPath,
    );

    if (mounted) {
      if (success) {
        AppToast.success(context, '已打包 ${selectedImages.length} 张图片');
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
      } else {
        AppToast.error(context, '打包失败');
      }
    }
  }

  /// 批量编辑选中的图片元数据
  Future<void> _editSelectedMetadata() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    if (selectionState.selectedIds.isEmpty || !mounted) return;
    showBulkMetadataEditDialog(context);
  }

  /// 批量移动选中的图片到文件夹
  Future<void> _moveSelectedToFolder() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);
    final folderState = ref.read(galleryFolderNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    final folders = folderState.folders;
    if (folders.isEmpty) {
      if (mounted) {
        AppToast.info(context, context.l10n.localGallery_noFoldersAvailable);
      }
      return;
    }

    final selectedFolder = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.localGallery_moveToFolder),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(folder.name),
                subtitle: Text(
                  context.l10n.localGallery_imageCount(folder.imageCount),
                ),
                onTap: () => Navigator.of(context).pop(folder.path),
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

    if (selectedFolder == null || !mounted) return;

    final imagePaths = selectedImages.map((img) => img.path).toList();
    final movedCount =
        await GalleryFolderRepository.instance.moveImagesToFolder(
      imagePaths,
      selectedFolder,
    );

    if (mounted) {
      if (movedCount > 0) {
        AppToast.info(
          context,
          context.l10n.localGallery_movedImages(movedCount),
        );
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
        ref.read(localGalleryNotifierProvider.notifier).refresh();
        ref.read(galleryFolderNotifierProvider.notifier).refresh();
      } else {
        AppToast.info(context, context.l10n.localGallery_moveImagesFailed);
      }
    }
  }

  /// 批量添加选中的图片到集合
  Future<void> _addSelectedToCollection() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty || !mounted) return;

    final result = await CollectionSelectDialog.show(
      context,
      theme: Theme.of(context),
    );

    if (result == null) return;

    final imagePaths = selectedImages.map((img) => img.path).toList();
    final addedCount = await ref
        .read(collectionNotifierProvider.notifier)
        .addImagesToCollection(result.collectionId, imagePaths);

    if (mounted) {
      if (addedCount > 0) {
        AppToast.success(
          context,
          context.l10n.localGallery_addedToCollection(
            addedCount,
            result.collectionName,
          ),
        );
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
      } else {
        AppToast.info(context, context.l10n.localGallery_addToCollectionFailed);
      }
    }
  }

  // ============================================================
  // Image operations (reuse metadata, send to img2img)
  // 图片操作（复用元数据、发送到图生图）
  // ============================================================

  /// 复用图片的元数据参数到主界面
  Future<void> _reuseMetadata(LocalImageRecord record) async {
    final metadata = record.metadata;
    if (metadata == null || !metadata.hasData) return;

    // 显示参数选择对话框
    final options = await showDialog<MetadataImportOptions>(
      context: context,
      builder: (context) => _buildImportOptionsDialog(metadata),
    );

    if (options == null || !mounted) return; // 用户取消

    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);

    // 只有在勾选导入多角色提示词时才清空
    if (options.importCharacterPrompts && metadata.characterPrompts.isNotEmpty) {
      final characterNotifier =
          ref.read(characterPromptNotifierProvider.notifier);
      characterNotifier.clearAllCharacters();
    }

    // 根据选项应用参数
    if (options.importPrompt && metadata.prompt.isNotEmpty) {
      // 自动进行语法转换（SD→NAI + 格式化）
      var prompt = metadata.prompt;
      prompt = SdToNaiConverter.convert(prompt);
      prompt = NaiPromptFormatter.format(prompt);
      paramsNotifier.updatePrompt(prompt);
    }

    if (options.importNegativePrompt && metadata.negativePrompt.isNotEmpty) {
      // 自动进行语法转换（SD→NAI + 格式化）
      var negativePrompt = metadata.negativePrompt;
      negativePrompt = SdToNaiConverter.convert(negativePrompt);
      negativePrompt = NaiPromptFormatter.format(negativePrompt);
      paramsNotifier.updateNegativePrompt(negativePrompt);
    }

    // 应用多角色提示词（如果有）
    if (options.importCharacterPrompts && metadata.characterPrompts.isNotEmpty) {
      final characterNotifier =
          ref.read(characterPromptNotifierProvider.notifier);
      final characters = <char.CharacterPrompt>[];
      for (var i = 0; i < metadata.characterPrompts.length; i++) {
        // 自动进行语法转换（SD→NAI + 格式化）
        var prompt = metadata.characterPrompts[i];
        prompt = SdToNaiConverter.convert(prompt);
        prompt = NaiPromptFormatter.format(prompt);

        var negPrompt = i < metadata.characterNegativePrompts.length
            ? metadata.characterNegativePrompts[i]
            : '';
        if (negPrompt.isNotEmpty) {
          negPrompt = SdToNaiConverter.convert(negPrompt);
          negPrompt = NaiPromptFormatter.format(negPrompt);
        }

        // 尝试从提示词推断性别
        final gender = _inferGenderFromPrompt(prompt);

        characters.add(
          char.CharacterPrompt.create(
            name: 'Character ${i + 1}',
            gender: gender,
            prompt: prompt,
            negativePrompt: negPrompt,
          ),
        );
      }
      characterNotifier.replaceAll(characters);
    }

    if (options.importModel && metadata.model != null) {
      paramsNotifier.updateModel(metadata.model!);
    }
    if (options.importSampler && metadata.sampler != null) {
      paramsNotifier.updateSampler(metadata.sampler!);
    }
    if (options.importSteps && metadata.steps != null) {
      paramsNotifier.updateSteps(metadata.steps!);
    }
    if (options.importScale && metadata.scale != null) {
      paramsNotifier.updateScale(metadata.scale!);
    }
    if (options.importSize &&
        metadata.width != null &&
        metadata.height != null) {
      paramsNotifier.updateSize(metadata.width!, metadata.height!);
    }
    if (options.importSmea && metadata.smea != null) {
      paramsNotifier.updateSmea(metadata.smea!);
    }
    if (options.importSmeaDyn && metadata.smeaDyn != null) {
      paramsNotifier.updateSmeaDyn(metadata.smeaDyn!);
    }
    if (options.importNoiseSchedule && metadata.noiseSchedule != null) {
      paramsNotifier.updateNoiseSchedule(metadata.noiseSchedule!);
    }
    if (options.importCfgRescale && metadata.cfgRescale != null) {
      paramsNotifier.updateCfgRescale(metadata.cfgRescale!);
    }
    if (options.importQualityToggle && metadata.qualityToggle != null) {
      paramsNotifier.updateQualityToggle(metadata.qualityToggle!);
    }
    if (options.importUcPreset && metadata.ucPreset != null) {
      paramsNotifier.updateUcPreset(metadata.ucPreset!);
    }

    // 计算应用的参数数量
    var appliedCount = 0;
    if (options.importPrompt && metadata.prompt.isNotEmpty) appliedCount++;
    if (options.importNegativePrompt && metadata.negativePrompt.isNotEmpty) {
      appliedCount++;
    }
    if (options.importCharacterPrompts &&
        metadata.characterPrompts.isNotEmpty) {
      appliedCount++;
    }
    if (options.importSeed && metadata.seed != null) appliedCount++;
    if (options.importSteps && metadata.steps != null) appliedCount++;
    if (options.importScale && metadata.scale != null) appliedCount++;
    if (options.importSize &&
        metadata.width != null &&
        metadata.height != null) {
      appliedCount++;
    }
    if (options.importSampler && metadata.sampler != null) appliedCount++;
    if (options.importModel && metadata.model != null) appliedCount++;
    if (options.importSmea && metadata.smea != null) appliedCount++;
    if (options.importSmeaDyn && metadata.smeaDyn != null) appliedCount++;
    if (options.importNoiseSchedule && metadata.noiseSchedule != null) {
      appliedCount++;
    }
    if (options.importCfgRescale && metadata.cfgRescale != null) {
      appliedCount++;
    }
    if (options.importQualityToggle && metadata.qualityToggle != null) {
      appliedCount++;
    }
    if (options.importUcPreset && metadata.ucPreset != null) appliedCount++;

    if (mounted) {
      if (appliedCount > 0) {
        AppToast.info(
          context,
          context.l10n.metadataImport_appliedToMain(appliedCount),
        );
      } else {
        AppToast.warning(context, context.l10n.metadataImport_noParamsSelected);
      }
    }
  }

  /// 构建导入选项对话框（简化版，用于画廊）
  Widget _buildImportOptionsDialog(dynamic metadata) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.metadataImport_title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 快速预设按钮
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text(l10n.metadataImport_selectAll),
                    avatar: const Icon(Icons.select_all, size: 18),
                    onPressed: () => Navigator.of(context).pop(
                      MetadataImportOptions.all(),
                    ),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    side: BorderSide.none,
                  ),
                  ActionChip(
                    label: Text(l10n.metadataImport_promptsOnly),
                    avatar: const Icon(Icons.text_fields, size: 18),
                    onPressed: () => Navigator.of(context).pop(
                      MetadataImportOptions.promptsOnly(),
                    ),
                  ),
                  ActionChip(
                    label: Text(l10n.metadataImport_generationOnly),
                    avatar: const Icon(Icons.tune, size: 18),
                    onPressed: () => Navigator.of(context).pop(
                      MetadataImportOptions.generationOnly(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.metadataImport_quickSelectHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            MetadataImportOptions.all(),
          ),
          child: Text(l10n.common_confirm),
        ),
      ],
    );
  }

  /// 从提示词推断角色性别
  char.CharacterGender _inferGenderFromPrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.contains('1girl') ||
        lowerPrompt.contains('girl,') ||
        lowerPrompt.startsWith('girl')) {
      return char.CharacterGender.female;
    } else if (lowerPrompt.contains('1boy') ||
        lowerPrompt.contains('boy,') ||
        lowerPrompt.startsWith('boy')) {
      return char.CharacterGender.male;
    }
    return char.CharacterGender.other;
  }

  /// 发送图片到图生图
  Future<void> _sendToImg2Img(LocalImageRecord record) async {
    try {
      final file = File(record.path);
      if (!await file.exists()) {
        if (mounted) {
          AppToast.info(context, '图片文件不存在');
        }
        return;
      }

      final imageBytes = await file.readAsBytes();
      final paramsNotifier =
          ref.read(generationParamsNotifierProvider.notifier);

      paramsNotifier.setSourceImage(imageBytes);
      paramsNotifier.updateAction(ImageGenerationAction.img2img);

      if (mounted) {
        AppToast.success(context, '图片已发送到图生图，请切换到生成页面');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '发送失败: $e');
      }
    }
  }

  /// 发送图片到 Vibe Transfer
  /// 提取图片中的 vibe 数据并添加到生成参数
  Future<void> _sendToVibeTransfer(LocalImageRecord record) async {
    try {
      // 检查是否有 vibe 数据
      final vibeData = record.vibeData;
      if (vibeData == null) {
        if (mounted) {
          AppToast.warning(context, '此图片不包含 Vibe 数据');
        }
        return;
      }

      final paramsNotifier =
          ref.read(generationParamsNotifierProvider.notifier);

      // 添加 vibe 到生成参数
      paramsNotifier.addVibeReferenceV4(vibeData);

      if (mounted) {
        AppToast.success(
          context,
          'Vibe "${vibeData.displayName}" 已添加到生成参数',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '添加 Vibe 失败: $e');
      }
    }
  }

  /// 显示发送目标选择对话框
  Future<void> _showSendDestinationDialog(LocalImageRecord record) async {
    final destination = await ImageSendDestinationDialog.show(context, record);

    if (destination == null || !mounted) return;

    switch (destination) {
      case SendDestination.img2img:
        await _sendToImg2Img(record);
      case SendDestination.vibeTransfer:
        await _sendToVibeTransfer(record);
    }
  }

  /// 显示图片右键上下文菜单
  Future<void> _showImageContextMenu(
    LocalImageRecord record,
    Offset position,
  ) async {
    final metadata = record.metadata;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        // 发送到选项
        const PopupMenuItem(
          value: 'send_to',
          child: Row(
            children: [
              Icon(Icons.send, size: 18),
              SizedBox(width: 8),
              Text('发送到...'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (metadata?.prompt.isNotEmpty == true)
          const PopupMenuItem(
            value: 'copy_prompt',
            child: Row(
              children: [
                Icon(Icons.content_copy, size: 18),
                SizedBox(width: 8),
                Text('复制 Prompt'),
              ],
            ),
          ),
        if (metadata?.seed != null)
          const PopupMenuItem(
            value: 'copy_seed',
            child: Row(
              children: [
                Icon(Icons.tag, size: 18),
                SizedBox(width: 8),
                Text('复制 Seed'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'open_folder',
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 18),
              SizedBox(width: 8),
              Text('在文件夹中显示'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );

    if (value == null || !context.mounted) return;

    switch (value) {
      case 'send_to':
        await _showSendDestinationDialog(record);
      case 'copy_prompt':
        if (metadata?.fullPrompt.isNotEmpty == true) {
          await Clipboard.setData(ClipboardData(text: metadata!.fullPrompt));
          if (context.mounted) {
            AppToast.success(context, 'Prompt 已复制');
          }
        }
      case 'copy_seed':
        if (metadata?.seed != null) {
          await Clipboard.setData(
            ClipboardData(text: metadata!.seed.toString()),
          );
          if (context.mounted) {
            AppToast.success(context, 'Seed 已复制');
          }
        }
      case 'open_folder':
        await _openFileInFolder(record.path);
      case 'delete':
        await _confirmDeleteImage(record);
    }
  }

  /// 在文件夹中打开文件
  Future<void> _openFileInFolder(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.start('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [path.dirname(filePath)]);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '无法打开文件夹: $e');
      }
    }
  }

  /// 确认删除图片
  Future<void> _confirmDeleteImage(LocalImageRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除图片「${path.basename(record.path)}」吗？\n\n此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final file = File(record.path);
        if (await file.exists()) {
          await file.delete();
          await ref.read(localGalleryNotifierProvider.notifier).refresh();
          if (context.mounted) {
            AppToast.success(context, '图片已删除');
          }
        }
      } catch (e) {
        if (mounted) {
          AppToast.error(context, '删除失败: $e');
        }
      }
    }
  }

  /// 切换分类面板显示状态
  void _toggleCategoryPanel() {
    setState(() {
      _showCategoryPanel = !_showCategoryPanel;
    });
  }

  /// 跳转到日期
  Future<void> _jumpToDate() async {
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      // 确保分组视图已激活
      final currentState = ref.read(localGalleryNotifierProvider);
      final notifier = ref.read(localGalleryNotifierProvider.notifier);
      if (!currentState.isGroupedView) {
        await notifier.setGroupedView(true);
      }

      // 等待分组数据加载
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // 计算所选日期属于哪个分组
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final selectedDate = DateTime(picked.year, picked.month, picked.day);

      // ignore: undefined_enum_constant
      dynamic targetGroup;

      // ignore: undefined_enum_constant
      if (selectedDate == today) {
        targetGroup = ImageDateGroup.today;
        // ignore: undefined_enum_constant
      } else if (selectedDate == yesterday) {
        targetGroup = ImageDateGroup.yesterday;
        // ignore: undefined_enum_constant
      } else if (selectedDate.isAfter(thisWeekStart) &&
          selectedDate.isBefore(today)) {
        targetGroup = ImageDateGroup.thisWeek;
        // ignore: undefined_enum_constant
      } else {
        targetGroup = ImageDateGroup.earlier;
      }

      // 使用 key 跳转到对应分组
      if (_groupedGridViewKey.currentState != null) {
        (_groupedGridViewKey.currentState as dynamic)
            .scrollToGroup(targetGroup);
      }

      // 显示提示
      if (context.mounted) {
        AppToast.info(
          context,
          '已跳转到 ${picked.year}-${picked.month.toString().padLeft(2, '0')}',
        );
      }
    }
  }
}
