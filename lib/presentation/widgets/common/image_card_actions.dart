import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/mosaic/mosaic_derivative_registry.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/services/android_media_store_service.dart';
import '../../../core/utils/image_save_utils.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/watermark/watermark_derivative_registry.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/mosaic_settings_provider.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../providers/copy_drag_watermark_provider.dart';
import '../../providers/watermark_settings_provider.dart';
import '../../screens/mosaic/mosaic_editor_launcher.dart';
import '../../screens/dlss/dlss_enhancement_panel.dart';
import '../../screens/dlss/dlss_error_view.dart';
import '../../screens/watermark/watermark_editor_launcher.dart';
import '../../utils/clipboard_image.dart';
import 'app_toast.dart';
import 'image_card_controller.dart';
import 'image_card_action.dart';
export 'image_card_action.dart';
import 'image_card_models.dart';

typedef ImageClipboardWriter = Future<void> Function(Uint8List bytes);

final imageClipboardWriterProvider = Provider<ImageClipboardWriter>(
  (ref) => writeImageBytesToClipboardAsPng,
);

class ImageCardActionScope extends InheritedWidget {
  const ImageCardActionScope({
    super.key,
    required this.onAddToAgent,
    required super.child,
  });

  final ImageCardCallback onAddToAgent;

  static ImageCardActionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ImageCardActionScope>();

  @override
  bool updateShouldNotify(ImageCardActionScope oldWidget) =>
      onAddToAgent != oldWidget.onAddToAgent;
}

class ImageCardActionCatalog {
  const ImageCardActionCatalog._();

  static List<ImageCardAction> build({
    required BuildContext context,
    required ImageCardViewData data,
    required ImageCardCapabilities capabilities,
    required ImageCardActionCoordinator coordinator,
    ImageCardCallback? onAddToAgent,
  }) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const <ImageCardAction>[];
    final actions = <ImageCardAction>[];
    void add(
      ImageCardActionId id,
      IconData icon,
      String label,
      ImageCardCallback? callback, {
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
      hover: false,
    );
    if (capabilities.enableSelection &&
        capabilities.onSelectionChanged != null) {
      add(
        ImageCardActionId.select,
        Icons.check_circle_outline,
        l10n.common_multiSelect,
        () => capabilities.onSelectionChanged!(true),
        hover: false,
      );
    }
    if (capabilities.enableSaveAction) {
      add(
        ImageCardActionId.save,
        Icons.save_alt_rounded,
        l10n.image_save,
        coordinator.saveImage,
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
        menuLabel: l10n.shortcut_action_copy_image,
      );
    }
    add(
      ImageCardActionId.addToAgent,
      Icons.smart_toy_outlined,
      l10n.agentChat_addResource,
      onAddToAgent,
    );
    add(
      ImageCardActionId.shareDiscord,
      Icons.send_rounded,
      l10n.discordShare_action,
      capabilities.onShareToDiscord,
      hover: false,
    );
    if (coordinator.watermarkEnabled &&
        (data.imageBytes != null ||
            (data.sourceFilePath?.isNotEmpty ?? false))) {
      add(
        ImageCardActionId.createWatermark,
        Icons.branding_watermark_outlined,
        coordinator.isWatermarkDerivative
            ? l10n.watermark_actionRegenerate
            : l10n.watermark_actionCreate,
        coordinator.openWatermarkEditor,
      );
    }
    if (coordinator.mosaicEnabled &&
        (data.imageBytes != null ||
            (data.sourceFilePath?.isNotEmpty ?? false))) {
      add(
        ImageCardActionId.createMosaic,
        Icons.grid_on_rounded,
        coordinator.isMosaicDerivative
            ? l10n.mosaic_actionRegenerate
            : l10n.mosaic_actionCreate,
        coordinator.openMosaicEditor,
      );
    }
    add(
      ImageCardActionId.saveToLibrary,
      Icons.bookmark_add_rounded,
      l10n.image_saveToLibrary,
      capabilities.onSaveToLibrary == null ? null : coordinator.saveToLibrary,
    );
    add(
      ImageCardActionId.openFolder,
      Icons.folder_open,
      l10n.shortcut_action_open_folder,
      capabilities.onOpenInExplorer,
      hover: false,
    );
    add(
      ImageCardActionId.reversePrompt,
      Icons.manage_search_rounded,
      l10n.drop_reversePrompt,
      capabilities.onReversePrompt,
    );
    add(
      ImageCardActionId.imageToImage,
      Icons.image_outlined,
      l10n.drop_img2img,
      capabilities.onImageToImage,
    );
    add(
      ImageCardActionId.vibeTransfer,
      Icons.palette_outlined,
      l10n.drop_vibeTransfer,
      capabilities.onVibeTransfer,
    );
    add(
      ImageCardActionId.preciseReference,
      Icons.center_focus_strong,
      l10n.drop_characterReference,
      capabilities.onPreciseReference,
    );
    add(
      ImageCardActionId.saveToPreciseRefLibrary,
      Icons.bookmark_add_outlined,
      l10n.drop_saveToPreciseRefLibrary,
      capabilities.onSaveToPreciseRefLibrary,
    );
    add(
      ImageCardActionId.editImage,
      Icons.edit_outlined,
      l10n.img2img_editImage,
      capabilities.onEditImage,
    );
    add(
      ImageCardActionId.inpaint,
      Icons.draw_outlined,
      l10n.img2img_inpaint,
      capabilities.onInpaint,
    );
    add(
      ImageCardActionId.generateVariations,
      Icons.auto_awesome_motion_outlined,
      l10n.img2img_generateVariations,
      capabilities.onGenerateVariations,
    );
    add(
      ImageCardActionId.directorTools,
      Icons.auto_fix_high_outlined,
      l10n.img2img_directorTools,
      capabilities.onDirectorTools,
    );
    add(
      ImageCardActionId.enhance,
      Icons.auto_awesome_outlined,
      l10n.img2img_enhance,
      capabilities.onEnhance,
    );
    if (capabilities.enableSaveAction &&
        PlatformCapabilities.current.supportsDlssEnhancement &&
        (data.imageBytes != null || data.sourceFilePath != null)) {
      add(
        ImageCardActionId.dlssEnhance,
        Icons.tonality_outlined,
        l10n.dlss_menu,
        coordinator.openDlss,
      );
    }
    add(
      ImageCardActionId.upscale,
      Icons.zoom_out_map_rounded,
      l10n.image_upscale,
      capabilities.onUpscale,
    );
    add(
      ImageCardActionId.sendToKrita,
      Icons.brush_outlined,
      l10n.gallery_sendToKritaAction,
      capabilities.onSendToKrita,
    );
    add(
      ImageCardActionId.favorite,
      data.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      data.isFavorite ? l10n.common_unfavorite : l10n.common_favorite,
      capabilities.onFavoriteToggle,
      hover: false,
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

  Future<void> openDlss() async {
    try {
      final path = _data.sourceFilePath;
      final bytes = path == null || path.isEmpty
          ? _data.imageBytes
          : await File(path).readAsBytes();
      if (bytes != null && context.mounted) {
        await showDlssEnhancement(context, bytes);
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, dlssErrorLabel(context, error));
      }
    }
  }

  bool get watermarkEnabled =>
      ref.read(watermarkSettingsProvider).configuration.enabled;

  bool get mosaicEnabled =>
      ref.read(mosaicSettingsProvider).configuration.enabled;

  bool get isWatermarkDerivative {
    final path = _data.sourceFilePath;
    if (path == null || path.isEmpty) return false;
    return WatermarkDerivativeRegistry(
      ref.read(localStorageServiceProvider),
    ).isDerivative(path);
  }

  Future<void> openWatermarkEditor() async {
    final bytes = _data.imageBytes;
    final sourcePath = _data.sourceFilePath;
    if (sourcePath != null && sourcePath.isNotEmpty) {
      await WatermarkEditorLauncher.openForLocalPath(
        context: context,
        path: sourcePath,
        fallbackBytes: bytes,
      );
      return;
    }
    if (bytes == null) return;
    await WatermarkEditorLauncher.open(
      context: context,
      sourceBytes: bytes,
      sourceFileName: 'image_${(_data.index ?? 0) + 1}.png',
    );
  }

  bool get isMosaicDerivative {
    final path = _data.sourceFilePath;
    if (path == null || path.isEmpty) return false;
    return MosaicDerivativeRegistry(
      ref.read(localStorageServiceProvider),
    ).isDerivative(path);
  }

  Future<void> openMosaicEditor() async {
    final bytes = _data.imageBytes;
    final sourcePath = _data.sourceFilePath;
    if (sourcePath != null && sourcePath.isNotEmpty) {
      await MosaicEditorLauncher.openForLocalPath(
        context: context,
        path: sourcePath,
        fallbackBytes: bytes,
      );
      return;
    }
    if (bytes == null) return;
    await MosaicEditorLauncher.open(
      context: context,
      sourceBytes: bytes,
      sourceFileName: 'image_${(_data.index ?? 0) + 1}.png',
    );
  }

  void warmShareTransferCache() {
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    controller.shareTransferCache?.warmUp(
      stripMetadata: stripMetadata,
      transform: ref.read(copyDragWatermarkProvider),
    );
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

  ImageCardCallback createCopyImageAction() {
    final l10n = context.l10n;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    final clipboardWriter = ref.read(imageClipboardWriterProvider);
    final transform = ref.read(copyDragWatermarkProvider);
    final cache = controller.shareTransferCache;
    return () => _copyPreparedImage(
      cache: cache,
      stripMetadata: stripMetadata,
      transform: transform,
      clipboardWriter: clipboardWriter,
      overlay: overlay,
      l10n: l10n,
    );
  }

  static Future<void> _copyPreparedImage({
    required ShareImageTransferCache? cache,
    required bool stripMetadata,
    required ShareImageTransform? transform,
    required ImageClipboardWriter clipboardWriter,
    required OverlayState? overlay,
    required AppLocalizations l10n,
  }) async {
    try {
      if (cache == null) throw StateError(l10n.toast_imageDataUnavailable);
      final shareImage = await cache.prepareImage(
        stripMetadata: stripMetadata,
        transform: transform,
      );
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
