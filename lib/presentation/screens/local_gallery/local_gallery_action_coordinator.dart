import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/services/android_media_store_service.dart';
import '../../../core/services/file_export_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/file_explorer_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/zip_utils.dart';
import '../../../core/watermark/watermark_derivative_registry.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../agent_chat/providers/agent_chat_notifier.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/gallery_album_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/watermark_settings_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../router/app_routes.dart';
import '../watermark/watermark_editor_launcher.dart';
import 'local_gallery_move_target.dart';
import '../../services/image_workflow_launcher.dart';
import '../../utils/asset_protection_guard.dart';
import '../../utils/fixed_tag_metadata_matcher.dart';
import '../../utils/krita_send_helper.dart';
import '../../utils/local_gallery_metadata_resolver.dart';
import '../../utils/local_gallery_reference_factory.dart';
import '../../utils/metadata_import_coordinator.dart';
import '../../utils/precise_ref_library_import_helper.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../widgets/bulk_metadata_edit_dialog.dart';
import '../../widgets/gallery/album_select_dialog.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/image_detail/components/prompt_copy_dialog.dart';
import '../../widgets/common/precise_reference_type_dialog.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/discord_share/discord_share_dialog.dart';
import '../../widgets/gallery/local_image_context_menu.dart';
import '../../widgets/gallery/zip_export_metadata_dialog.dart';
import '../../widgets/metadata/metadata_import_dialog.dart';

Future<void> showLocalGalleryZipFailureDetails(
  BuildContext context,
  ZipCreationResult result,
) {
  final l10n = context.l10n;
  return AdaptivePresenter.showPanel<void>(
    context: context,
    titleBuilder: (context) => Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(l10n.localGallery_packPartialTitle)),
      ],
    ),
    initialChildSize: 0.78,
    minChildSize: 0.5,
    sideSheetWidth: 600,
    builder: (panelContext, scrollController) => ListView.builder(
      key: const ValueKey('local-gallery-zip-failure-list'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      itemCount: result.failures.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              l10n.localGallery_packedImagesWithFailures(
                result.exportedCount,
                result.failures.length,
              ),
            ),
          );
        }
        if (index == result.failures.length + 1) {
          return SafeArea(
            top: false,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.of(panelContext).pop(),
                child: Text(l10n.common_close),
              ),
            ),
          );
        }
        final failure = result.failures[index - 1];
        return Padding(
          padding: EdgeInsets.only(top: index == 1 ? 0 : 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 1) const Divider(height: 8),
              Text(
                path.basename(failure.path),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              SelectableText(
                failure.error,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    ),
  );
}

@immutable
class LocalGalleryImageAction {
  const LocalGalleryImageAction({
    required this.record,
    required this.action,
    this.metadata,
  });

  final LocalImageRecord record;
  final LocalImageContextAction action;
  final NaiImageMetadata? metadata;
}

/// Coordinates dialogs, IO, and navigation for gallery actions.
///
/// Lists are always resolved from providers/services at action time so this
/// coordinator never becomes a second source of gallery truth.
class LocalGalleryActionCoordinator {
  LocalGalleryActionCoordinator({
    required WidgetRef ref,
    required BuildContext Function() context,
    required bool Function() mounted,
  }) : _ref = ref,
       _context = context,
       _mounted = mounted;

  final WidgetRef _ref;
  final BuildContext Function() _context;
  final bool Function() _mounted;

  WatermarkDerivativeRegistry get _watermarkRegistry =>
      WatermarkDerivativeRegistry(_ref.read(localStorageServiceProvider));

  Future<List<LocalImageRecord>> _selectedImages() async {
    final selectedIds = _ref
        .read(localGallerySelectionNotifierProvider)
        .selectedIds
        .toList();
    if (selectedIds.isEmpty) return const [];
    final service = await _ref
        .read(localGalleryNotifierProvider.notifier)
        .getService();
    return service.getRecordsByPaths(selectedIds);
  }

  Future<void> undo() async {
    await _ref.read(bulkOperationNotifierProvider.notifier).undo();
    await _ref.read(localGalleryNotifierProvider.notifier).refresh();
    if (_mounted()) {
      AppToast.info(_context(), _context().l10n.localGallery_undone);
    }
  }

  Future<void> redo() async {
    await _ref.read(bulkOperationNotifierProvider.notifier).redo();
    await _ref.read(localGalleryNotifierProvider.notifier).refresh();
    if (_mounted()) {
      AppToast.info(_context(), _context().l10n.localGallery_redone);
    }
  }

  Future<void> deleteSelectedImages() async {
    final context = _context();
    final l10n = context.l10n;
    final selectedImages = await _selectedImages();
    if (selectedImages.isEmpty || !_mounted()) return;
    final confirmed = await ThemedConfirmDialog.show(
      context: _context(),
      title: l10n.localGallery_confirmBulkDelete,
      content: l10n.localGallery_confirmBulkDeleteContent(
        selectedImages.length,
      ),
      confirmText: l10n.common_delete,
      cancelText: l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );
    if (!confirmed || !_mounted()) return;
    final protected = await AssetProtectionGuard.confirmDangerousAction(
      context: _context(),
      ref: _ref,
      title: l10n.localGallery_protectedDeleteTitle,
      content: l10n.localGallery_protectedDeleteImagesContent(
        selectedImages.length,
      ),
      confirmText: l10n.common_delete,
      icon: Icons.delete_forever_outlined,
    );
    if (!protected || !_mounted()) return;

    var deletedCount = 0;
    for (final image in selectedImages) {
      try {
        final file = File(image.path);
        if (await file.exists()) {
          await file.delete();
          await _watermarkRegistry.remove(image.path);
          deletedCount++;
        }
      } catch (_) {
        // Individual failures do not prevent deleting the remaining selection.
      }
    }
    _ref.read(localGallerySelectionNotifierProvider.notifier).exit();
    await _ref.read(localGalleryNotifierProvider.notifier).refresh();
    if (_mounted() && deletedCount > 0) {
      AppToast.success(
        _context(),
        _context().l10n.localGallery_deletedImages(deletedCount),
      );
    }
  }

  Future<void> packSelectedImages() async {
    final selectedImages = await _selectedImages();
    if (selectedImages.isEmpty || !_mounted()) return;
    final includeMetadata = await ZipExportMetadataDialog.show(_context());
    if (includeMetadata == null || !_mounted()) return;

    final fileName = 'images_${DateTime.now().millisecondsSinceEpoch}.zip';
    String? desktopOutputPath;
    if (!PlatformCapabilities.current.supportsDocumentFileExport) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: _context().l10n.localGallery_saveZipArchive,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (outputPath == null || !_mounted()) return;
      final requestedPath = outputPath.endsWith('.zip')
          ? outputPath
          : '$outputPath.zip';
      desktopOutputPath = AssetProtectionGuard.shouldPreventOverwrite(_ref)
          ? await AssetProtectionGuard.resolveNonOverwritingPath(requestedPath)
          : requestedPath;
    }
    if (!_mounted()) return;

    final l10n = _context().l10n;
    final progressToast = AppToast.showProgress(
      _context(),
      l10n.localGallery_packingImages(selectedImages.length),
      progress: 0,
    );
    final imagePaths = selectedImages.map((image) => image.path).toList();
    void onProgress(ZipCreationProgress progress) {
      progressToast.updateProgress(
        progress.fraction,
        message: l10n.localGallery_packingProgress(
          progress.current,
          progress.total,
        ),
        subtitle: progress.currentFileName,
      );
    }

    late final ZipCreationResult result;
    String? savedLocation;
    if (PlatformCapabilities.current.supportsDocumentFileExport) {
      savedLocation = await FileExportService.withTemporaryOutput(
        fileName: fileName,
        action: (temporaryPath) async {
          result = await ZipUtils.createZipFromImagesDetailed(
            imagePaths,
            temporaryPath,
            stripMetadata: !includeMetadata,
            onProgress: onProgress,
          );
          if (!result.succeeded || !_mounted()) return null;
          return FileExportService.saveFileFromPath(
            sourcePath: temporaryPath,
            fileName: fileName,
            dialogTitle: l10n.localGallery_saveZipArchive,
            mimeType: 'application/zip',
            allowedExtensions: const ['zip'],
          );
        },
      );
    } else {
      result = await ZipUtils.createZipFromImagesDetailed(
        imagePaths,
        desktopOutputPath!,
        stripMetadata: !includeMetadata,
        onProgress: onProgress,
      );
      savedLocation = desktopOutputPath;
    }

    if (!_mounted()) {
      progressToast.dismiss();
      return;
    }
    if (result.succeeded && savedLocation == null) {
      progressToast.dismiss();
      return;
    }
    if (result.succeeded && !result.isPartial) {
      progressToast.complete(
        message: l10n.localGallery_packedImages(result.exportedCount),
      );
      _ref.read(localGallerySelectionNotifierProvider.notifier).exit();
    } else if (result.isPartial) {
      progressToast.dismiss();
      await _showZipPartialFailureDialog(result);
    } else {
      final details = result.error ?? l10n.localGallery_packFailed;
      progressToast.fail(
        message: l10n.localGallery_packFailedWithDetails(details),
      );
      AppLogger.e(
        'Local gallery ZIP export failed: $details',
        null,
        null,
        'LocalGalleryScreen',
      );
    }
  }

  Future<void> _showZipPartialFailureDialog(ZipCreationResult result) async {
    if (!_mounted()) return;
    await showLocalGalleryZipFailureDetails(_context(), result);
  }

  void editSelectedMetadata() {
    if (_ref
            .read(localGallerySelectionNotifierProvider)
            .selectedIds
            .isNotEmpty &&
        _mounted()) {
      showBulkMetadataEditDialog(_context());
    }
  }

  Future<void> moveSelectedToCategory() async {
    final l10n = _context().l10n;
    final selectedImages = await _selectedImages();
    if (selectedImages.isEmpty || !_mounted()) return;
    final categoryState = _ref.read(galleryCategoryNotifierProvider);
    final moveTargets = buildLocalGalleryMoveTargets(categoryState.categories);
    if (moveTargets.isEmpty) {
      AppToast.info(_context(), l10n.localGallery_noCategoriesAvailable);
      return;
    }
    final selectedCategoryId = await showLocalGalleryMoveTargetDialog(
      context: _context(),
      targets: moveTargets,
    );
    if (selectedCategoryId == null || !_mounted()) return;
    final protected = await AssetProtectionGuard.confirmDangerousAction(
      context: _context(),
      ref: _ref,
      title: l10n.localGallery_protectedBulkMoveTitle,
      content: l10n.localGallery_protectedBulkMoveContent(
        selectedImages.length,
      ),
      confirmText: l10n.localGallery_confirmMove,
      icon: Icons.drive_file_move_outline,
    );
    if (!protected || !_mounted()) return;
    var movedCount = 0;
    for (final image in selectedImages) {
      final newPath = await _ref
          .read(galleryCategoryNotifierProvider.notifier)
          .moveImageToCategory(image.path, selectedCategoryId);
      if (newPath == null) continue;
      await _watermarkRegistry.relocatePath(
        oldPath: image.path,
        newPath: newPath,
      );
      movedCount++;
    }
    if (!_mounted()) return;
    if (movedCount > 0) {
      AppToast.info(
        _context(),
        _context().l10n.localGallery_movedImages(movedCount),
      );
      _ref.read(localGallerySelectionNotifierProvider.notifier).exit();
      _ref.read(localGalleryNotifierProvider.notifier).refresh();
      // 物理移动改变了成员文件路径，立即刷新 sidecar 保持跨设备引用有效
      unawaited(
        _ref.read(galleryAlbumNotifierProvider.notifier).exportSidecarNow(),
      );
    } else {
      AppToast.info(_context(), _context().l10n.localGallery_moveImagesFailed);
    }
  }

  /// 把选中图片移出当前浏览的相簿（仅解除引用，不动物理文件）
  Future<void> removeSelectedFromAlbum() async {
    final albumId = _ref.read(galleryAlbumNotifierProvider).selectedAlbumId;
    if (albumId == null || albumId == 'favorites') return;
    final selectedImages = await _selectedImages();
    if (selectedImages.isEmpty || !_mounted()) return;
    final removed = await _ref
        .read(galleryAlbumNotifierProvider.notifier)
        .removeImagesByPaths(
          albumId,
          selectedImages.map((image) => image.path).toList(),
        );
    if (!_mounted()) return;
    if (removed > 0) {
      AppToast.info(
        _context(),
        _context().l10n.localGallery_removedFromAlbum(removed),
      );
      _ref.read(localGallerySelectionNotifierProvider.notifier).exit();
    } else {
      AppToast.info(_context(), _context().l10n.localGallery_albumNoMembers);
    }
  }

  Future<void> addSelectedToAlbum() async {
    final selectedImages = await _selectedImages();
    if (selectedImages.isEmpty || !_mounted()) return;
    final result = await AlbumSelectDialog.show(_context());
    if (result == null || !_mounted()) return;
    final addedCount = await _ref
        .read(galleryAlbumNotifierProvider.notifier)
        .addImagesByPaths(
          result.albumId,
          selectedImages.map((image) => image.path).toList(),
        );
    if (!_mounted()) return;
    if (addedCount > 0) {
      AppToast.success(
        _context(),
        _context().l10n.localGallery_addedToAlbumWithName(
          addedCount,
          result.albumName,
        ),
      );
      _ref.read(localGallerySelectionNotifierProvider.notifier).exit();
    } else {
      AppToast.info(_context(), _context().l10n.localGallery_albumAddFailed);
    }
  }

  Future<void> showImageContextMenu(
    LocalImageRecord record,
    Offset position,
  ) async {
    final metadata = record.metadata;
    final action = await LocalImageContextMenu.show(
      _context(),
      position: position,
      hasImportableMetadata: metadata?.hasData == true,
      hasPrompt: metadata?.prompt.isNotEmpty == true,
      hasSeed: metadata?.seed != null,
      isKritaConnected:
          PlatformCapabilities.current.supportsKritaBridge &&
          _ref.read(kritaBridgeNotifierProvider).status ==
              KritaBridgeStatus.connected,
      watermarkEnabled: _ref
          .read(watermarkSettingsProvider)
          .configuration
          .enabled,
      isWatermarkDerivative: WatermarkDerivativeRegistry(
        _ref.read(localStorageServiceProvider),
      ).isDerivative(record.path),
    );
    if (action == null || !_mounted()) return;
    await routeImageAction(
      LocalGalleryImageAction(
        record: record,
        action: action,
        metadata: metadata,
      ),
    );
  }

  Future<void> routeImageAction(LocalGalleryImageAction request) async {
    final record = request.record;
    final availableMetadata = request.metadata ?? record.metadata;
    switch (request.action) {
      case LocalImageContextAction.addToAgent:
        await _addToAgent(record);
      case LocalImageContextAction.sendToTextToImage:
      case LocalImageContextAction.importMetadata:
        await importImageMetadata(record);
      case LocalImageContextAction.sendToImg2Img:
        await _sendToImg2Img(record);
      case LocalImageContextAction.sendToReversePrompt:
        await _sendToReversePrompt(record);
      case LocalImageContextAction.sendToStyleTransfer:
        await _sendToStyleTransfer(record);
      case LocalImageContextAction.sendToPreciseReference:
        await _sendToPreciseReference(record);
      case LocalImageContextAction.saveToPreciseRefLibrary:
        await _saveToPreciseRefLibrary(record);
      case LocalImageContextAction.sendToKrita:
        await _sendToKrita(record);
      case LocalImageContextAction.upscale:
        await _sendToUpscale(record);
      case LocalImageContextAction.shareToDiscord:
        await _shareLocalImageToDiscord(record);
      case LocalImageContextAction.createWatermark:
        await WatermarkEditorLauncher.openForLocalPath(
          context: _context(),
          path: record.path,
        );
      case LocalImageContextAction.copyPrompt:
        await _copyPrompt(record, availableMetadata);
      case LocalImageContextAction.copySeed:
        await _copySeed(record, availableMetadata);
      case LocalImageContextAction.saveToSystemGallery:
        await _saveToSystemGallery(record);
      case LocalImageContextAction.showInFolder:
        await _openFileInFolder(record.path);
      case LocalImageContextAction.delete:
        await _confirmDeleteImage(record);
    }
  }

  Future<void> _addToAgent(LocalImageRecord record) async {
    try {
      final dataSource = (await _ref.read(
        databaseManagerProvider.future,
      )).galleryDataSource;
      final id = await dataSource?.getImageIdByPath(record.path);
      if (id == null) {
        throw StateError('Local gallery entry is unavailable.');
      }
      await _ref
          .read(agentChatNotifierProvider.notifier)
          .addPendingResource(
            AgentChatResourceReference(
              kind: AgentChatResourceKind.localGalleryImage,
              source: 'local_gallery',
              resourceId: id.toString(),
              display: {'name': path.basename(record.path)},
            ),
          );
      if (_mounted()) {
        AppToast.success(_context(), _context().l10n.agentChat_resourceAdded);
      }
    } on Object catch (error) {
      if (_mounted()) {
        AppToast.error(
          _context(),
          _context().l10n.agentChat_addResourceFailed('$error'),
        );
      }
    }
  }

  Future<void> _sendToImg2Img(LocalImageRecord record) async {
    try {
      final bytes = await _readExistingImage(record);
      if (bytes == null) return;
      ImageWorkflowLauncher.openImageToImage(_ref, bytes);
      if (_mounted()) {
        _context().go(AppRoutes.home);
        AppToast.success(
          _context(),
          _context().l10n.localGallery_sentToImageToImage,
        );
      }
    } catch (error) {
      _showSendError(error);
    }
  }

  Future<void> _sendToUpscale(LocalImageRecord record) async {
    try {
      final bytes = await _readExistingImage(record);
      if (bytes == null) return;
      ImageWorkflowLauncher.openUpscale(_ref, bytes);
      if (_mounted()) {
        _context().go(AppRoutes.home);
        AppToast.info(_context(), _context().l10n.gallery_upscalePanelLoaded);
      }
    } catch (error) {
      if (_mounted()) {
        AppToast.error(
          _context(),
          _context().l10n.gallery_readImageFailed('$error'),
        );
      }
    }
  }

  Future<void> _sendToStyleTransfer(LocalImageRecord record) async {
    try {
      if (!_mounted() || _warnIfStyleReferenceLimitReached()) return;
      final bytes = await _readExistingImage(record);
      if (bytes == null || !_mounted() || _warnIfStyleReferenceLimitReached()) {
        return;
      }
      final currentCount = _ref
          .read(generationParamsNotifierProvider)
          .vibeReferencesV4
          .length;
      _ref
          .read(generationParamsNotifierProvider.notifier)
          .addVibeReference(
            LocalGalleryReferenceFactory.createRawStyleReference(
              fileName: path.basename(record.path),
              imageBytes: bytes,
            ),
          );
      if (_mounted()) {
        _context().go(AppRoutes.home);
        AppToast.success(
          _context(),
          currentCount == 0
              ? _context().l10n.drop_addedToVibe
              : _context().l10n.toast_appendedStyleReferences(1),
        );
      }
    } catch (error) {
      _showSendError(error);
    }
  }

  bool _warnIfStyleReferenceLimitReached() {
    const maxCount = 16;
    if (_ref.read(generationParamsNotifierProvider).vibeReferencesV4.length <
        maxCount) {
      return false;
    }
    AppToast.warning(
      _context(),
      _context().l10n.toast_styleReferenceLimit(maxCount),
    );
    return true;
  }

  Future<void> _sendToPreciseReference(LocalImageRecord record) async {
    try {
      if (!await File(record.path).exists()) {
        _showMissingImage();
        return;
      }
      final selectedType = await PreciseReferenceTypeDialog.show(_context());
      if (selectedType == null || !_mounted()) return;
      final bytes = await File(record.path).readAsBytes();
      if (!_mounted()) return;
      unawaited(
        _ref
            .read(generationParamsNotifierProvider.notifier)
            .addPreciseReferenceFromImage(
              bytes,
              type: selectedType,
              strength: 1,
              fidelity: 1,
            ),
      );
      _context().go(AppRoutes.home);
      AppToast.success(_context(), _context().l10n.drop_addedToCharacterRef);
    } catch (error) {
      _showSendError(error);
    }
  }

  Future<void> _saveToPreciseRefLibrary(LocalImageRecord record) async {
    try {
      final bytes = await _readExistingImage(record);
      if (bytes == null || !_mounted()) return;
      await saveBytesToPreciseRefLibrary(
        _ref,
        _context(),
        bytes,
        suggestedName: path.basenameWithoutExtension(record.path),
      );
    } catch (error) {
      _showSendError(error);
    }
  }

  Future<void> importImageMetadata(LocalImageRecord record) async {
    try {
      final metadata = await resolveLocalGalleryMetadata(record);
      if (!_mounted()) return;
      if (metadata == null) {
        AppToast.warning(
          _context(),
          _context().l10n.metadataImport_noDataFound,
        );
        return;
      }
      final options = await MetadataImportDialog.show(
        _context(),
        metadata: metadata,
      );
      if (options == null || !_mounted()) return;
      final appliedCount = await MetadataImportCoordinator.apply(
        read: _ref.read,
        metadata: metadata,
        options: options,
        l10n: _context().l10n,
      );
      if (!_mounted()) return;
      if (appliedCount == 0) {
        AppToast.warning(
          _context(),
          _context().l10n.metadataImport_noParamsSelected,
        );
        return;
      }
      AppToast.success(
        _context(),
        _context().l10n.metadataImport_appliedCount(appliedCount),
      );
      _context().go(AppRoutes.home);
    } catch (error, stackTrace) {
      AppLogger.e('导入图片元数据失败', error, stackTrace, 'LocalGallery');
      if (_mounted()) {
        AppToast.error(
          _context(),
          _context().l10n.localGallery_importParamsFailed('$error'),
        );
      }
    }
  }

  Future<void> _sendToReversePrompt(LocalImageRecord record) async {
    try {
      final bytes = await _readExistingImage(record);
      if (bytes == null) return;
      await _ref
          .read(reversePromptProvider.notifier)
          .addImage(bytes, name: path.basename(record.path));
      if (_mounted()) {
        _context().go(AppRoutes.home);
        AppToast.success(
          _context(),
          _context().l10n.localGallery_sentToReversePrompt,
        );
      }
    } catch (error) {
      _showSendError(error);
    }
  }

  Future<void> _sendToKrita(LocalImageRecord record) async {
    try {
      final bytes = await _readExistingImage(record);
      if (bytes == null || !_mounted()) return;
      KritaSendHelper.sendImageBytes(
        _context(),
        _ref,
        bytes,
        name: path.basename(record.path),
      );
    } catch (error) {
      if (_mounted()) {
        AppToast.error(
          _context(),
          _context().l10n.localGallery_sendToKritaFailed('$error'),
        );
      }
    }
  }

  Future<void> _shareLocalImageToDiscord(LocalImageRecord record) async {
    if (!await File(record.path).exists()) {
      _showMissingImage();
      return;
    }
    try {
      var metadata =
          await resolveLocalGalleryMetadata(record) ?? record.metadata;
      if (metadata != null) {
        final fixedTags = _ref.read(fixedTagsNotifierProvider);
        metadata = matchMetadataFixedTags(
          metadata: metadata,
          positiveEntries: fixedTags.positiveEntries,
          negativeEntries: fixedTags.negativeEntries,
        );
      }
      final bytes = await File(record.path).readAsBytes();
      if (!_mounted()) return;
      await DiscordShareDialog.show(
        _context(),
        imageBytes: bytes,
        fileName: path.basename(record.path),
        metadata: metadata,
        width: metadata?.width,
        height: metadata?.height,
      );
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to prepare local image for Discord sharing',
        error,
        stackTrace,
        'DiscordShare',
      );
      if (_mounted()) {
        AppToast.error(
          _context(),
          _context().l10n.discordShare_failed(error.toString()),
        );
      }
    }
  }

  Future<void> _copyPrompt(
    LocalImageRecord record,
    NaiImageMetadata? metadata,
  ) async {
    final promptMetadata =
        await resolveLocalGalleryMetadata(record) ?? metadata;
    if (!_mounted()) return;
    if (promptMetadata?.fullPrompt.isNotEmpty != true) {
      AppToast.info(_context(), _context().l10n.toast_imageHasNoMetadata);
      return;
    }
    final fixedTags = _ref.read(fixedTagsNotifierProvider);
    final resolvedMetadata = matchMetadataFixedTags(
      metadata: promptMetadata!,
      positiveEntries: fixedTags.positiveEntries,
      negativeEntries: fixedTags.negativeEntries,
    );
    final prompt = await PromptCopyDialog.show(
      _context(),
      metadata: resolvedMetadata,
    );
    if (prompt == null || !_mounted()) return;
    await Clipboard.setData(ClipboardData(text: prompt));
    if (_mounted()) {
      AppToast.success(_context(), _context().l10n.localGallery_promptCopied);
    }
  }

  Future<void> _copySeed(
    LocalImageRecord record,
    NaiImageMetadata? metadata,
  ) async {
    final seedMetadata = await resolveLocalGalleryMetadata(record) ?? metadata;
    if (!_mounted() || seedMetadata?.seed == null) return;
    await Clipboard.setData(ClipboardData(text: seedMetadata!.seed.toString()));
    if (_mounted()) {
      AppToast.success(_context(), _context().l10n.localGallery_seedCopied);
    }
  }

  Future<void> _saveToSystemGallery(LocalImageRecord record) async {
    try {
      final file = File(record.path);
      if (!await file.exists()) {
        _showMissingImage();
        return;
      }
      await AndroidMediaStoreService.saveImageFromPath(
        sourcePath: file.path,
        fileName: path.basename(file.path),
      );
      if (_mounted()) {
        AppToast.success(
          _context(),
          _context().l10n.image_savedToSystemGallery,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to export local gallery image to system gallery',
        error,
        stackTrace,
        'LocalGallery',
      );
      if (_mounted()) {
        AppToast.error(
          _context(),
          _context().l10n.localGallery_saveToSystemGalleryFailed('$error'),
        );
      }
    }
  }

  Future<void> _openFileInFolder(String filePath) async {
    try {
      await FileExplorerUtils.revealFile(filePath);
    } catch (error) {
      if (_mounted()) {
        AppToast.error(
          _context(),
          _context().l10n.localGallery_cannotOpenFolder('$error'),
        );
      }
    }
  }

  Future<void> _confirmDeleteImage(LocalImageRecord record) async {
    final context = _context();
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.common_confirmDelete,
      content: context.l10n.localGallery_confirmDeleteImageContent(
        path.basename(record.path),
      ),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );
    if (!confirmed || !_mounted()) return;
    final protected = await AssetProtectionGuard.confirmDangerousAction(
      context: _context(),
      ref: _ref,
      title: _context().l10n.localGallery_protectedDeleteTitle,
      content: _context().l10n.localGallery_protectedDeleteImageContent(
        path.basename(record.path),
      ),
      confirmText: _context().l10n.localGallery_confirmDelete,
      icon: Icons.delete_outline,
    );
    if (!protected || !_mounted()) return;
    try {
      final file = File(record.path);
      if (!await file.exists()) return;
      await file.delete();
      await _watermarkRegistry.remove(record.path);
      await _ref.read(localGalleryNotifierProvider.notifier).refresh();
      if (_mounted()) {
        AppToast.success(_context(), _context().l10n.localGallery_imageDeleted);
      }
    } catch (error) {
      if (_mounted()) {
        AppToast.error(
          _context(),
          _context().l10n.localGallery_deleteFailed('$error'),
        );
      }
    }
  }

  Future<Uint8List?> _readExistingImage(LocalImageRecord record) async {
    final file = File(record.path);
    if (!await file.exists()) {
      _showMissingImage();
      return null;
    }
    return file.readAsBytes();
  }

  void _showMissingImage() {
    if (_mounted()) {
      AppToast.info(_context(), _context().l10n.localGallery_imageFileMissing);
    }
  }

  void _showSendError(Object error) {
    if (_mounted()) {
      AppToast.error(
        _context(),
        _context().l10n.localGallery_sendFailed('$error'),
      );
    }
  }
}
