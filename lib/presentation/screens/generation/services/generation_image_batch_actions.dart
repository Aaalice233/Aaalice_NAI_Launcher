import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/services/android_media_store_service.dart';
import '../../../../core/services/file_export_service.dart';
import '../../../../core/utils/image_save_utils.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/zip_utils.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../providers/generation/image_card_selection_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../utils/zip_export_progress.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/image_card_action.dart';
import 'generation_image_deletion.dart';

class GenerationImageBatchActions {
  GenerationImageBatchActions({
    required this.context,
    required this.images,
    required this.gallery,
    required this.selection,
    required this.deletion,
  });
  final BuildContext context;
  final List<GeneratedImage> images;
  final LocalGalleryNotifier gallery;
  final GenerationImageCardSelection selection;
  final GenerationImageDeletion deletion;

  List<ImageCardAction> build() => [
    ImageCardAction(
      id: ImageCardActionId.export,
      icon: Icons.archive_outlined,
      label: context.l10n.common_pack,
      supportsBatch: true,
      invoke: _packSelectedImages,
    ),
    ImageCardAction(
      id: ImageCardActionId.save,
      icon: Icons.save_alt,
      label: context.l10n.image_save,
      supportsBatch: true,
      isPrimary: true,
      invoke: _saveSelectedImages,
    ),
    ImageCardAction(
      id: ImageCardActionId.delete,
      icon: Icons.delete_outline,
      label: context.l10n.common_delete,
      supportsBatch: true,
      isDanger: true,
      invoke: () => deletion.confirmAndDelete(images),
    ),
  ];
  Future<void> _saveSelectedImages() async {
    if (images.isEmpty) return;

    try {
      final saveDirPath = await GalleryFolderRepository.instance.getRootPath();
      if (saveDirPath == null) return;

      final selectedImages = images;

      Object? systemGalleryError;
      // 原子保存：日期分类路径 + 独占防冲突 + 失败清理，全部在工具内完成
      for (int i = 0; i < selectedImages.length; i++) {
        final image = selectedImages[i];
        final filePath = await ImageSaveUtils.saveBytesToDatedPath(
          rootPath: saveDirPath,
          bytes: image.bytes,
          seed: await ImageSaveUtils.resolveSeed(
            metadata: image.metadata,
            bytes: image.bytes,
          ),
        );
        if (PlatformCapabilities.current.supportsSystemGalleryExport) {
          try {
            await AndroidMediaStoreService.savePng(
              bytes: image.bytes,
              fileName: p.basename(filePath),
            );
          } catch (error) {
            systemGalleryError ??= error;
          }
        }
      }

      await gallery.refresh();

      if (context.mounted) {
        if (systemGalleryError != null) {
          AppToast.warning(
            context,
            context.l10n.image_savedAppOnly(systemGalleryError.toString()),
          );
        } else {
          AppToast.success(
            context,
            PlatformCapabilities.current.supportsSystemGalleryExport
                ? context.l10n.image_savedToSystemGallery
                : context.l10n.image_imageSaved(saveDirPath),
          );
        }
        selection.deselectAll(images.map((image) => image.id));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  /// 打包选中的图片成压缩包
  Future<void> _packSelectedImages() async {
    if (images.isEmpty) return;

    final defaultName = 'images_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = '$defaultName.zip';
    String? desktopOutputPath;
    if (!PlatformCapabilities.current.supportsDocumentFileExport) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: context.l10n.localGallery_saveZipArchive,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (outputPath == null || !context.mounted) return;
      desktopOutputPath = outputPath.endsWith('.zip')
          ? outputPath
          : '$outputPath.zip';
    }

    final progress = ZipExportProgress(context, images.length);

    Directory? tempDir;
    try {
      // 先将选中的图片保存到临时目录
      tempDir = await Directory.systemTemp.createTemp('nai_pack_');
      final imagePaths = <String>[];

      final selectedImages = images;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < selectedImages.length; i++) {
        final imageFileName = 'NAI_${timestamp}_${i + 1}.png';
        final file = File('${tempDir.path}/$imageFileName');
        await file.writeAsBytes(selectedImages[i].bytes);
        imagePaths.add(file.path);
      }

      late ZipCreationResult result;
      String? savedLocation;
      if (PlatformCapabilities.current.supportsDocumentFileExport) {
        savedLocation = await FileExportService.withTemporaryOutput(
          fileName: fileName,
          action: (temporaryPath) async {
            result = await ZipUtils.createZipFromImagesDetailed(
              imagePaths,
              temporaryPath,
              onProgress: progress.update,
            );
            if (!result.succeeded || !context.mounted) return null;
            return FileExportService.saveFileFromPath(
              sourcePath: temporaryPath,
              fileName: fileName,
              dialogTitle: context.l10n.localGallery_saveZipArchive,
              mimeType: 'application/zip',
              allowedExtensions: const ['zip'],
            );
          },
        );
      } else {
        result = await ZipUtils.createZipFromImagesDetailed(
          imagePaths,
          desktopOutputPath!,
          onProgress: progress.update,
        );
        savedLocation = desktopOutputPath;
      }

      if (context.mounted) {
        if (result.succeeded && savedLocation != null) {
          if (result.isPartial) {
            progress.controller.dismiss();
            AppToast.warning(
              context,
              context.l10n.localGallery_packedImagesWithFailures(
                result.exportedCount,
                result.failures.length,
              ),
            );
          } else {
            progress.controller.complete(
              message: context.l10n.localGallery_packedImages(
                result.exportedCount,
              ),
            );
          }
          if (!result.isPartial) {
            selection.deselectAll(images.map((image) => image.id));
          }
        } else if (!result.succeeded) {
          progress.controller.fail(
            message: context.l10n.localGallery_packFailedWithDetails(
              result.error ?? context.l10n.localGallery_packFailed,
            ),
          );
        } else {
          progress.controller.dismiss();
        }
      } else {
        progress.controller.dismiss();
      }
    } catch (e) {
      progress.controller.dismiss();
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.toast_packFailedWithError(e.toString()),
        );
      }
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
}
