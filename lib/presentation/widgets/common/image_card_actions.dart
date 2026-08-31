import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/services/android_media_store_service.dart';
import '../../../core/utils/image_save_utils.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/watermark/watermark_derivative_registry.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../providers/watermark_settings_provider.dart';
import '../../screens/watermark/watermark_editor_launcher.dart';
import '../../utils/clipboard_image.dart';
import 'app_toast.dart';
import 'image_card_controller.dart';
import 'image_card_models.dart';

typedef ImageClipboardWriter = Future<void> Function(Uint8List bytes);

final imageClipboardWriterProvider = Provider<ImageClipboardWriter>(
  (ref) => writeImageBytesToClipboardAsPng,
);

enum ImageCardActionId {
  viewDetail,
  save,
  copy,
  shareDiscord,
  createWatermark,
  saveToLibrary,
  openFolder,
  reversePrompt,
  imageToImage,
  vibeTransfer,
  preciseReference,
  saveToPreciseRefLibrary,
  editImage,
  inpaint,
  generateVariations,
  directorTools,
  enhance,
  upscale,
  sendToKrita,
}

@immutable
class ImageCardAction {
  const ImageCardAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.menuLabel,
    required this.invoke,
    required this.group,
    required this.showOnHover,
    this.isPrimary = false,
    this.isDanger = false,
  });

  final ImageCardActionId id;
  final IconData icon;
  final String label;
  final String menuLabel;
  final VoidCallback invoke;
  final int group;
  final bool showOnHover;
  final bool isPrimary;
  final bool isDanger;
}

class ImageCardActionCatalog {
  const ImageCardActionCatalog._();

  static List<ImageCardAction> build({
    required BuildContext context,
    required ImageCardViewData data,
    required ImageCardCapabilities capabilities,
    required ImageCardActionCoordinator coordinator,
  }) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const <ImageCardAction>[];
    final actions = <ImageCardAction>[];
    void add(
      ImageCardActionId id,
      IconData icon,
      String label,
      VoidCallback? callback, {
      required int group,
      bool hover = true,
      bool primary = false,
      bool danger = false,
      String? menuLabel,
    }) {
      if (callback == null) return;
      actions.add(
        ImageCardAction(
          id: id,
          icon: icon,
          label: label,
          menuLabel: menuLabel ?? label,
          invoke: callback,
          group: group,
          showOnHover: hover,
          isPrimary: primary,
          isDanger: danger,
        ),
      );
    }

    add(
      ImageCardActionId.viewDetail,
      Icons.open_in_full,
      l10n.image_viewDetail,
      capabilities.onFullscreen,
      group: 0,
      hover: false,
    );
    if (capabilities.enableSaveAction) {
      add(
        ImageCardActionId.save,
        Icons.save_alt_rounded,
        l10n.image_save,
        coordinator.saveImage,
        group: 1,
        primary: true,
        menuLabel: l10n.shortcut_action_save_image,
      );
    }
    if (capabilities.enableCopyAction) {
      add(
        ImageCardActionId.copy,
        Icons.copy_rounded,
        l10n.image_copy,
        coordinator.createCopyImageAction(),
        group: 1,
        menuLabel: l10n.shortcut_action_copy_image,
      );
    }
    add(
      ImageCardActionId.shareDiscord,
      Icons.send_rounded,
      l10n.discordShare_action,
      capabilities.onShareToDiscord,
      group: 1,
      hover: false,
    );
    if (coordinator.watermarkEnabled && data.imageBytes != null) {
      add(
        ImageCardActionId.createWatermark,
        Icons.branding_watermark_outlined,
        coordinator.isWatermarkDerivative
            ? l10n.watermark_actionRegenerate
            : l10n.watermark_actionCreate,
        coordinator.openWatermarkEditor,
        group: 1,
        hover: false,
      );
    }
    add(
      ImageCardActionId.saveToLibrary,
      Icons.bookmark_add_rounded,
      l10n.image_saveToLibrary,
      capabilities.onSaveToLibrary == null ? null : coordinator.saveToLibrary,
      group: 1,
    );
    add(
      ImageCardActionId.openFolder,
      Icons.folder_open,
      l10n.shortcut_action_open_folder,
      capabilities.onOpenInExplorer,
      group: 2,
      hover: false,
    );
    add(
      ImageCardActionId.reversePrompt,
      Icons.manage_search_rounded,
      l10n.drop_reversePrompt,
      capabilities.onReversePrompt,
      group: 3,
    );
    add(
      ImageCardActionId.imageToImage,
      Icons.image_outlined,
      l10n.drop_img2img,
      capabilities.onImageToImage,
      group: 3,
    );
    add(
      ImageCardActionId.vibeTransfer,
      Icons.palette_outlined,
      l10n.drop_vibeTransfer,
      capabilities.onVibeTransfer,
      group: 3,
    );
    add(
      ImageCardActionId.preciseReference,
      Icons.center_focus_strong,
      l10n.drop_characterReference,
      capabilities.onPreciseReference,
      group: 3,
    );
    add(
      ImageCardActionId.saveToPreciseRefLibrary,
      Icons.bookmark_add_outlined,
      l10n.drop_saveToPreciseRefLibrary,
      capabilities.onSaveToPreciseRefLibrary,
      group: 3,
    );
    add(
      ImageCardActionId.editImage,
      Icons.edit_outlined,
      l10n.img2img_editImage,
      capabilities.onEditImage,
      group: 4,
    );
    add(
      ImageCardActionId.inpaint,
      Icons.draw_outlined,
      l10n.img2img_inpaint,
      capabilities.onInpaint,
      group: 4,
    );
    add(
      ImageCardActionId.generateVariations,
      Icons.auto_awesome_motion_outlined,
      l10n.img2img_generateVariations,
      capabilities.onGenerateVariations,
      group: 4,
    );
    add(
      ImageCardActionId.directorTools,
      Icons.auto_fix_high_outlined,
      l10n.img2img_directorTools,
      capabilities.onDirectorTools,
      group: 4,
    );
    add(
      ImageCardActionId.enhance,
      Icons.auto_awesome_outlined,
      l10n.img2img_enhance,
      capabilities.onEnhance,
      group: 4,
    );
    add(
      ImageCardActionId.upscale,
      Icons.zoom_out_map_rounded,
      l10n.image_upscale,
      capabilities.onUpscale,
      group: 4,
    );
    add(
      ImageCardActionId.sendToKrita,
      Icons.brush_outlined,
      l10n.gallery_sendToKritaAction,
      capabilities.onSendToKrita,
      group: 4,
    );
    return actions;
  }
}

class ImageCardActionCoordinator {
  ImageCardActionCoordinator({
    required this.context,
    required this.ref,
    required this.controller,
  });

  final BuildContext context;
  final WidgetRef ref;
  final ImageCardController controller;

  ImageCardViewData get _data => controller.data;
  ImageCardCapabilities get _capabilities => controller.capabilities;

  bool get watermarkEnabled =>
      ref.read(watermarkSettingsProvider).configuration.enabled;

  WatermarkDerivativeLink? get _watermarkLink {
    final path = _data.sourceFilePath;
    if (path == null || path.isEmpty) return null;
    return WatermarkDerivativeRegistry(
      ref.read(localStorageServiceProvider),
    ).find(path);
  }

  bool get isWatermarkDerivative => _watermarkLink != null;

  Future<void> openWatermarkEditor() async {
    final bytes = _data.imageBytes;
    if (bytes == null) return;
    final sourcePath = _data.sourceFilePath;
    if (sourcePath != null && sourcePath.isNotEmpty) {
      await WatermarkEditorLauncher.openForLocalPath(
        context: context,
        path: sourcePath,
        fallbackBytes: bytes,
      );
      return;
    }
    await WatermarkEditorLauncher.open(
      context: context,
      sourceBytes: bytes,
      sourceFileName: 'image_${(_data.index ?? 0) + 1}.png',
    );
  }

  void warmShareTransferCache() {
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    controller.warmShareTransferCache(stripMetadata: stripMetadata);
  }

  Future<void> saveImage() async {
    final l10n = context.l10n;
    final bytes = _data.imageBytes;
    if (bytes == null) return;
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null || rootPath.isEmpty) {
        if (context.mounted) AppToast.error(context, l10n.toast_saveDirNotSet);
        return;
      }
      final filePath = await ImageSaveUtils.saveBytesToDatedPath(
        rootPath: rootPath,
        bytes: bytes,
        seed: await ImageSaveUtils.resolveSeed(bytes: bytes),
      );
      if (PlatformCapabilities.current.supportsSystemGalleryExport) {
        try {
          await AndroidMediaStoreService.savePng(
            bytes: bytes,
            fileName: p.basename(filePath),
          );
        } catch (error) {
          if (context.mounted) {
            AppToast.warning(
              context,
              l10n.image_savedAppOnly(error.toString()),
            );
          }
          return;
        }
      }
      if (context.mounted) {
        AppToast.success(
          context,
          PlatformCapabilities.current.supportsSystemGalleryExport
              ? l10n.image_savedToSystemGallery
              : l10n.toast_savedTo(rootPath),
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, l10n.image_saveFailed(error.toString()));
      }
    }
  }

  VoidCallback createCopyImageAction() {
    final l10n = context.l10n;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    final clipboardWriter = ref.read(imageClipboardWriterProvider);
    final cache = controller.shareTransferCache;
    return () => unawaited(
      _copyPreparedImage(
        cache: cache,
        stripMetadata: stripMetadata,
        clipboardWriter: clipboardWriter,
        overlay: overlay,
        l10n: l10n,
      ),
    );
  }

  static Future<void> _copyPreparedImage({
    required ShareImageTransferCache? cache,
    required bool stripMetadata,
    required ImageClipboardWriter clipboardWriter,
    required OverlayState? overlay,
    required AppLocalizations l10n,
  }) async {
    try {
      if (cache == null) throw StateError(l10n.toast_imageDataUnavailable);
      final shareImage = await cache.prepareImage(stripMetadata: stripMetadata);
      await clipboardWriter(shareImage.bytes);
      AppToast.successOnOverlay(overlay, l10n.image_copiedToClipboard);
    } catch (error) {
      AppToast.errorOnOverlay(overlay, l10n.image_copyFailed(error.toString()));
    }
  }

  void saveToLibrary() {
    final bytes = _data.imageBytes;
    if (bytes != null) _capabilities.onSaveToLibrary?.call(bytes, '');
  }
}
