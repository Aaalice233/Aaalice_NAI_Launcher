import 'package:flutter/material.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../common/image_card_action.dart';
import '../common/image_card_context_menu.dart';

enum LocalImageContextAction {
  addToAgent,
  moveToCategory,
  sendToTextToImage,
  sendToImg2Img,
  sendToReversePrompt,
  sendToStyleTransfer,
  sendToPreciseReference,
  saveToPreciseRefLibrary,
  sendToKrita,
  upscale,
  dlssEnhance,
  shareToDiscord,
  createWatermark,
  createMosaic,
  importMetadata,
  copyPrompt,
  copySeed,
  saveToSystemGallery,
  showInFolder,
  delete,
}

class LocalImageContextMenu {
  const LocalImageContextMenu._();

  static ImageCardActionId idFor(
    LocalImageContextAction action,
  ) => switch (action) {
    LocalImageContextAction.addToAgent => ImageCardActionId.addToAgent,
    LocalImageContextAction.moveToCategory => ImageCardActionId.classify,
    LocalImageContextAction.sendToTextToImage =>
      ImageCardActionId.sendToGeneration,
    LocalImageContextAction.sendToImg2Img => ImageCardActionId.imageToImage,
    LocalImageContextAction.sendToReversePrompt =>
      ImageCardActionId.reversePrompt,
    LocalImageContextAction.sendToStyleTransfer =>
      ImageCardActionId.vibeTransfer,
    LocalImageContextAction.sendToPreciseReference =>
      ImageCardActionId.preciseReference,
    LocalImageContextAction.saveToPreciseRefLibrary =>
      ImageCardActionId.saveToPreciseRefLibrary,
    LocalImageContextAction.sendToKrita => ImageCardActionId.sendToKrita,
    LocalImageContextAction.upscale => ImageCardActionId.upscale,
    LocalImageContextAction.dlssEnhance => ImageCardActionId.dlssEnhance,
    LocalImageContextAction.shareToDiscord => ImageCardActionId.shareDiscord,
    LocalImageContextAction.createWatermark =>
      ImageCardActionId.createWatermark,
    LocalImageContextAction.createMosaic => ImageCardActionId.createMosaic,
    LocalImageContextAction.importMetadata => ImageCardActionId.importMetadata,
    LocalImageContextAction.copyPrompt => ImageCardActionId.copyPrompt,
    LocalImageContextAction.copySeed => ImageCardActionId.copySeed,
    LocalImageContextAction.saveToSystemGallery => ImageCardActionId.save,
    LocalImageContextAction.showInFolder => ImageCardActionId.openFolder,
    LocalImageContextAction.delete => ImageCardActionId.delete,
  };

  static Future<LocalImageContextAction?> show(
    BuildContext context, {
    required Offset position,
    required bool hasImportableMetadata,
    required bool hasPrompt,
    required bool hasSeed,
    required bool isKritaConnected,
    bool watermarkEnabled = false,
    bool isWatermarkDerivative = false,
    bool mosaicEnabled = false,
    bool isMosaicDerivative = false,
  }) async {
    LocalImageContextAction? selected;
    await ImageCardContextMenu.show(
      context: context,
      position: position,
      actions: buildActions(
        context,
        onAction: (action) async {
          selected = action;
        },
        hasImportableMetadata: hasImportableMetadata,
        hasPrompt: hasPrompt,
        hasSeed: hasSeed,
        isKritaConnected: isKritaConnected,
        watermarkEnabled: watermarkEnabled,
        isWatermarkDerivative: isWatermarkDerivative,
        mosaicEnabled: mosaicEnabled,
        isMosaicDerivative: isMosaicDerivative,
      ),
    );
    return selected;
  }

  static List<ImageCardAction> buildActions(
    BuildContext context, {
    required Future<void> Function(LocalImageContextAction) onAction,
    required bool hasImportableMetadata,
    required bool hasPrompt,
    required bool hasSeed,
    required bool isKritaConnected,
    bool watermarkEnabled = false,
    bool isWatermarkDerivative = false,
    bool mosaicEnabled = false,
    bool isMosaicDerivative = false,
  }) {
    final action = _factory(context, onAction);
    return [
      ...buildSendActions(
        context,
        onAction: onAction,
        isKritaConnected: isKritaConnected,
      ),
      action(
        value: LocalImageContextAction.addToAgent,
        icon: Icons.auto_awesome_outlined,
        label: context.l10n.agentChat_addResource,
      ),
      action(
        value: LocalImageContextAction.moveToCategory,
        icon: Icons.drive_file_move_outline,
        label: context.l10n.localGallery_moveToCategory,
      ),
      if (watermarkEnabled)
        action(
          value: LocalImageContextAction.createWatermark,
          icon: Icons.branding_watermark_outlined,
          label: isWatermarkDerivative
              ? context.l10n.watermark_actionRegenerate
              : context.l10n.watermark_actionCreate,
        ),
      if (mosaicEnabled)
        action(
          value: LocalImageContextAction.createMosaic,
          icon: Icons.grid_on_rounded,
          label: isMosaicDerivative
              ? context.l10n.mosaic_actionRegenerate
              : context.l10n.mosaic_actionCreate,
        ),
      if (hasImportableMetadata)
        action(
          value: LocalImageContextAction.importMetadata,
          icon: Icons.data_object,
          label: context.l10n.localGallery_importImageMetadata,
        ),
      if (hasPrompt)
        action(
          value: LocalImageContextAction.copyPrompt,
          icon: Icons.text_snippet_outlined,
          label: context.l10n.localGallery_copyPrompt,
        ),
      if (hasSeed)
        action(
          value: LocalImageContextAction.copySeed,
          icon: Icons.tag,
          label: context.l10n.localGallery_copySeed,
        ),
      if (PlatformCapabilities.current.supportsSystemGalleryExport)
        action(
          value: LocalImageContextAction.saveToSystemGallery,
          icon: Icons.save_alt_rounded,
          label: context.l10n.localGallery_saveToSystemGallery,
        ),
      if (PlatformCapabilities.current.supportsOpenFolder)
        action(
          value: LocalImageContextAction.showInFolder,
          icon: Icons.folder_open,
          label: context.l10n.localGallery_showInFolder,
        ),
      action(
        value: LocalImageContextAction.delete,
        icon: Icons.delete_outline,
        label: context.l10n.common_delete,
        isDanger: true,
      ),
    ];
  }

  static List<ImageCardAction> buildSendActions(
    BuildContext context, {
    required Future<void> Function(LocalImageContextAction) onAction,
    required bool isKritaConnected,
    bool watermarkEnabled = false,
    bool isWatermarkDerivative = false,
    bool mosaicEnabled = false,
    bool isMosaicDerivative = false,
  }) {
    final action = _factory(context, onAction);
    return [
      action(
        value: LocalImageContextAction.sendToTextToImage,
        icon: Icons.text_fields,
        label: context.l10n.onlineGallery_sendToTextToImage,
      ),
      action(
        value: LocalImageContextAction.sendToImg2Img,
        icon: Icons.image_outlined,
        label: context.l10n.localGallery_sendToImg2Img,
      ),
      action(
        value: LocalImageContextAction.sendToReversePrompt,
        icon: Icons.manage_search_rounded,
        label: context.l10n.localGallery_sendToReversePrompt,
      ),
      action(
        value: LocalImageContextAction.sendToStyleTransfer,
        icon: Icons.palette_outlined,
        label: context.l10n.localGallery_sendToStyleTransfer,
      ),
      action(
        value: LocalImageContextAction.sendToPreciseReference,
        icon: Icons.center_focus_strong,
        label: context.l10n.localGallery_sendToPreciseReference,
      ),
      action(
        value: LocalImageContextAction.saveToPreciseRefLibrary,
        icon: Icons.bookmark_add_outlined,
        label: context.l10n.localGallery_saveToPreciseRefLibrary,
      ),
      action(
        value: LocalImageContextAction.sendToKrita,
        icon: Icons.brush_outlined,
        label: context.l10n.localGallery_sendToKrita,
        enabled: isKritaConnected,
      ),
      action(
        value: LocalImageContextAction.upscale,
        icon: Icons.zoom_in,
        label: context.l10n.gallery_upscale,
      ),
      if (PlatformCapabilities.current.supportsDlssEnhancement)
        action(
          value: LocalImageContextAction.dlssEnhance,
          icon: Icons.auto_awesome,
          label: context.l10n.dlss_menu,
        ),
      action(
        value: LocalImageContextAction.shareToDiscord,
        icon: Icons.send_rounded,
        label: context.l10n.discordShare_action,
      ),
      if (watermarkEnabled)
        action(
          value: LocalImageContextAction.createWatermark,
          icon: Icons.branding_watermark_outlined,
          label: isWatermarkDerivative
              ? context.l10n.watermark_actionRegenerate
              : context.l10n.watermark_actionCreate,
        ),
      if (mosaicEnabled)
        action(
          value: LocalImageContextAction.createMosaic,
          icon: Icons.grid_on_rounded,
          label: isMosaicDerivative
              ? context.l10n.mosaic_actionRegenerate
              : context.l10n.mosaic_actionCreate,
        ),
    ];
  }

  static ImageCardAction Function({
    required LocalImageContextAction value,
    required IconData icon,
    required String label,
    bool enabled,
    bool isDanger,
  })
  _factory(
    BuildContext context,
    Future<void> Function(LocalImageContextAction) onAction,
  ) =>
      ({
        required value,
        required icon,
        required label,
        enabled = true,
        isDanger = false,
      }) => ImageCardAction(
        id: idFor(value),
        icon: icon,
        label: label,
        invoke: () => onAction(value),
        enabled: enabled,
        isDanger: isDanger,
        showOnHover: const {
          LocalImageContextAction.addToAgent,
          LocalImageContextAction.copyPrompt,
          LocalImageContextAction.delete,
          LocalImageContextAction.dlssEnhance,
        }.contains(value),
      );
}
