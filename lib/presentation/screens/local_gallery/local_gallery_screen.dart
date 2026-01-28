import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../data/repositories/local_gallery_repository.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/models/image/image_params.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../providers/collection_provider.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../providers/gallery_folder_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/grouped_grid_view.dart';
import '../../widgets/bulk_export_dialog.dart';
import '../../widgets/bulk_metadata_edit_dialog.dart';
import '../../widgets/collection_select_dialog.dart';
import '../../widgets/gallery/local_gallery_toolbar.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import '../../widgets/gallery/gallery_content_view.dart';
import '../../widgets/gallery/image_context_menu.dart';
import '../../widgets/common/themed_confirm_dialog.dart';

import '../../widgets/common/app_toast.dart';

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
  bool _use3DCardView = true;

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
    final screenWidth = MediaQuery.of(context).size.width;

    // 计算列数（200px/列，最少2列，最多8列）
    final columns = (screenWidth / 200).floor().clamp(2, 8);
    final itemWidth = screenWidth / columns;

    return KeyboardListener(
      focusNode: _shortcutsFocusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, bulkOpState),
      child: Scaffold(
        body: Column(
          children: [
            // 顶部工具栏
            LocalGalleryToolbar(
              use3DCardView: _use3DCardView,
              onToggleViewMode: () =>
                  setState(() => _use3DCardView = !_use3DCardView),
              onOpenFolder: _openImageFolder,
              onRefresh: () =>
                  ref.read(localGalleryNotifierProvider.notifier).refresh(),
              onEnterSelectionMode: () => ref
                  .read(localGallerySelectionNotifierProvider.notifier)
                  .enter(),
              onUndo: bulkOpState.canUndo ? _undo : null,
              onRedo: bulkOpState.canRedo ? _redo : null,
              canUndo: bulkOpState.canUndo,
              canRedo: bulkOpState.canRedo,
              groupedGridViewKey: _groupedGridViewKey,
              onAddToCollection: _addSelectedToCollection,
              onDeleteSelected: _deleteSelectedImages,
              onExportSelected: _exportSelectedImages,
              onEditMetadata: _editSelectedMetadata,
              onMoveToFolder: _moveSelectedToFolder,
            ),
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
                onPageChanged: (p) =>
                    ref.read(localGalleryNotifierProvider.notifier).loadPage(p),
                onItemsPerPageChanged: (size) => ref
                    .read(localGalleryNotifierProvider.notifier)
                    .setPageSize(size),
                showItemsPerPage: true,
                showTotalInfo: true,
                compact: screenWidth < 600,
              ),
          ],
        ),
      ),
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

  /// 打开图片保存文件夹
  Future<void> _openImageFolder() async {
    try {
      final dir = await LocalGalleryRepository.instance.getImageDirectory();

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final absolutePath = dir.absolute.path;

      if (Platform.isWindows) {
        final windowsPath = absolutePath.replaceAll('/', '\\');
        await Process.run('explorer.exe', [windowsPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [absolutePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [absolutePath]);
      } else {
        final uri = Uri.directory(absolutePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.info(
          context,
          context.l10n.localGallery_cannotOpenFolder(e.toString()),
        );
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

    if (metadata.prompt.isNotEmpty) {
      paramsNotifier.updatePrompt(metadata.prompt);
    }
    if (metadata.negativePrompt.isNotEmpty) {
      paramsNotifier.updateNegativePrompt(metadata.negativePrompt);
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
