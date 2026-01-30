import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/models/character/character_prompt.dart' as char;
import '../../../data/models/image/image_params.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../providers/collection_provider.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../providers/gallery_folder_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/grouped_grid_view.dart';
import '../../widgets/bulk_export_dialog.dart';
import '../../widgets/bulk_metadata_edit_dialog.dart';
import '../../widgets/collection_select_dialog.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import '../../widgets/gallery/gallery_content_view.dart';
import '../../widgets/gallery/gallery_category_tree_view.dart';
import '../../widgets/gallery/image_context_menu.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';

import '../../widgets/common/app_toast.dart';
import '../../widgets/gallery/local_gallery_toolbar.dart';
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

  /// 搜索框控制器
  final TextEditingController _searchController = TextEditingController();

  /// 搜索防抖定时器
  Timer? _debounceTimer;

  /// 是否使用3D卡片视图
  /// Whether to use 3D card view mode
  final bool _use3DCardView = true;

  /// 是否显示分类面板
  /// Whether to show category panel
  final bool _showCategoryPanel = true;

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
    _searchController.dispose();
    _debounceTimer?.cancel();
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

    return KeyboardListener(
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
    );
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
      onExportSelected: _exportSelectedImages,
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

    if (state.isIndexing) {
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
        ImageContextMenu.show(
          context,
          record,
          position,
          onRefresh: () =>
              ref.read(localGalleryNotifierProvider.notifier).refresh(),
        );
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

  /// 批量导出选中的图片元数据
  Future<void> _exportSelectedImages() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    if (selectionState.selectedIds.isEmpty || !mounted) return;
    showBulkExportDialog(context);
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
  void _reuseMetadata(LocalImageRecord record) {
    final metadata = record.metadata;
    if (metadata == null || !metadata.hasData) return;

    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);

    // 首先清空多角色提示词（套用元数据时总是清空）
    final characterNotifier =
        ref.read(characterPromptNotifierProvider.notifier);
    characterNotifier.clearAllCharacters();

    if (metadata.prompt.isNotEmpty) {
      paramsNotifier.updatePrompt(metadata.prompt);
    }
    if (metadata.negativePrompt.isNotEmpty) {
      paramsNotifier.updateNegativePrompt(metadata.negativePrompt);
    }

    // 应用多角色提示词（如果有）
    if (metadata.characterPrompts.isNotEmpty) {
      final characters = <char.CharacterPrompt>[];
      for (int i = 0; i < metadata.characterPrompts.length; i++) {
        final prompt = metadata.characterPrompts[i];
        final negPrompt = i < metadata.characterNegativePrompts.length
            ? metadata.characterNegativePrompts[i]
            : '';

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

    if (metadata.model != null) {
      paramsNotifier.updateModel(metadata.model!);
    }
    if (metadata.sampler != null) {
      paramsNotifier.updateSampler(metadata.sampler!);
    }
    if (metadata.steps != null) {
      paramsNotifier.updateSteps(metadata.steps!);
    }
    if (metadata.scale != null) {
      paramsNotifier.updateScale(metadata.scale!);
    }
    if (metadata.width != null && metadata.height != null) {
      paramsNotifier.updateSize(metadata.width!, metadata.height!);
    }
    if (metadata.smea != null) {
      paramsNotifier.updateSmea(metadata.smea!);
    }
    if (metadata.smeaDyn != null) {
      paramsNotifier.updateSmeaDyn(metadata.smeaDyn!);
    }
    if (metadata.noiseSchedule != null) {
      paramsNotifier.updateNoiseSchedule(metadata.noiseSchedule!);
    }
    if (metadata.cfgRescale != null) {
      paramsNotifier.updateCfgRescale(metadata.cfgRescale!);
    }

    AppToast.info(context, '参数已复用到主界面');
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
        AppToast.info(context, '图片已发送到图生图，请切换到生成页面');
      }
    } catch (e) {
      if (mounted) {
        AppToast.info(context, '发送失败: $e');
      }
    }
  }
}
