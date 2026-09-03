import 'package:flutter/material.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../common/context_menu_anchor.dart';

enum LocalImageContextAction {
  addToAgent,
  sendToTextToImage,
  sendToImg2Img,
  sendToReversePrompt,
  sendToStyleTransfer,
  sendToPreciseReference,
  saveToPreciseRefLibrary,
  sendToKrita,
  upscale,
  shareToDiscord,
  createWatermark,
  importMetadata,
  copyPrompt,
  copySeed,
  saveToSystemGallery,
  showInFolder,
  delete,
}

class LocalImageContextMenu {
  const LocalImageContextMenu._();

  static const double _maxWidth = 420;
  static const double _screenPadding = 8;

  static Future<LocalImageContextAction?> show(
    BuildContext context, {
    required Offset position,
    required bool hasImportableMetadata,
    required bool hasPrompt,
    required bool hasSeed,
    required bool isKritaConnected,
    bool watermarkEnabled = false,
    bool isWatermarkDerivative = false,
  }) {
    return showMenu<LocalImageContextAction>(
      context: context,
      constraints: _constraints(context),
      position: contextMenuAnchorAt(context, position),
      popUpAnimationStyle: AnimationStyle.noAnimation,
      items: buildEntries(
        context,
        hasImportableMetadata: hasImportableMetadata,
        hasPrompt: hasPrompt,
        hasSeed: hasSeed,
        isKritaConnected: isKritaConnected,
        watermarkEnabled: watermarkEnabled,
        isWatermarkDerivative: isWatermarkDerivative,
      ),
    );
  }

  static Future<LocalImageContextAction?> showSendActions(
    BuildContext context, {
    required Offset position,
    required bool isKritaConnected,
    bool watermarkEnabled = false,
    bool isWatermarkDerivative = false,
  }) {
    return showMenu<LocalImageContextAction>(
      context: context,
      constraints: _constraints(context),
      position: contextMenuAnchorAt(context, position),
      popUpAnimationStyle: AnimationStyle.noAnimation,
      items: buildSendEntries(
        context,
        isKritaConnected: isKritaConnected,
        watermarkEnabled: watermarkEnabled,
        isWatermarkDerivative: isWatermarkDerivative,
      ),
    );
  }

  static BoxConstraints _constraints(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableWidth =
        mediaQuery.size.width -
        mediaQuery.padding.horizontal -
        (_screenPadding * 2);
    return BoxConstraints(
      maxWidth: availableWidth.clamp(0.0, _maxWidth).toDouble(),
    );
  }

  static List<PopupMenuEntry<LocalImageContextAction>> buildEntries(
    BuildContext context, {
    required bool hasImportableMetadata,
    required bool hasPrompt,
    required bool hasSeed,
    required bool isKritaConnected,
    bool watermarkEnabled = false,
    bool isWatermarkDerivative = false,
  }) {
    final hasImageInfoActions = hasImportableMetadata || hasPrompt || hasSeed;

    return [
      _item(
        context,
        value: LocalImageContextAction.addToAgent,
        icon: Icons.auto_awesome_outlined,
        label: context.l10n.agentChat_addResource,
      ),
      const PopupMenuDivider(),
      ...buildSendEntries(context, isKritaConnected: isKritaConnected),
      if (watermarkEnabled)
        _item(
          context,
          value: LocalImageContextAction.createWatermark,
          icon: Icons.branding_watermark_outlined,
          label: isWatermarkDerivative
              ? context.l10n.watermark_actionRegenerate
              : context.l10n.watermark_actionCreate,
        ),
      if (hasImageInfoActions) const PopupMenuDivider(),
      if (hasImportableMetadata)
        _item(
          context,
          value: LocalImageContextAction.importMetadata,
          icon: Icons.data_object,
          label: context.l10n.localGallery_importImageMetadata,
        ),
      if (hasPrompt)
        _item(
          context,
          value: LocalImageContextAction.copyPrompt,
          icon: Icons.content_copy,
          label: context.l10n.localGallery_copyPrompt,
        ),
      if (hasSeed)
        _item(
          context,
          value: LocalImageContextAction.copySeed,
          icon: Icons.tag,
          label: context.l10n.localGallery_copySeed,
        ),
      const PopupMenuDivider(),
      if (PlatformCapabilities.current.supportsSystemGalleryExport)
        _item(
          context,
          value: LocalImageContextAction.saveToSystemGallery,
          icon: Icons.save_alt_rounded,
          label: context.l10n.localGallery_saveToSystemGallery,
        ),
      if (PlatformCapabilities.current.supportsOpenFolder)
        _item(
          context,
          value: LocalImageContextAction.showInFolder,
          icon: Icons.folder_open,
          label: context.l10n.localGallery_showInFolder,
        ),
      _item(
        context,
        value: LocalImageContextAction.delete,
        icon: Icons.delete_outline,
        label: context.l10n.common_delete,
        destructive: true,
      ),
    ];
  }

  static List<PopupMenuEntry<LocalImageContextAction>> buildSendEntries(
    BuildContext context, {
    required bool isKritaConnected,
    bool watermarkEnabled = false,
    bool isWatermarkDerivative = false,
  }) {
    return [
      _item(
        context,
        value: LocalImageContextAction.sendToTextToImage,
        icon: Icons.text_fields,
        label: context.l10n.onlineGallery_sendToTextToImage,
      ),
      _item(
        context,
        value: LocalImageContextAction.sendToImg2Img,
        icon: Icons.image_outlined,
        label: context.l10n.localGallery_sendToImg2Img,
      ),
      _item(
        context,
        value: LocalImageContextAction.sendToReversePrompt,
        icon: Icons.manage_search_rounded,
        label: context.l10n.localGallery_sendToReversePrompt,
      ),
      _item(
        context,
        value: LocalImageContextAction.sendToStyleTransfer,
        icon: Icons.palette_outlined,
        label: context.l10n.localGallery_sendToStyleTransfer,
      ),
      _item(
        context,
        value: LocalImageContextAction.sendToPreciseReference,
        icon: Icons.center_focus_strong,
        label: context.l10n.localGallery_sendToPreciseReference,
      ),
      _item(
        context,
        value: LocalImageContextAction.saveToPreciseRefLibrary,
        icon: Icons.bookmark_add_outlined,
        label: context.l10n.localGallery_saveToPreciseRefLibrary,
      ),
      _item(
        context,
        value: LocalImageContextAction.sendToKrita,
        icon: Icons.brush_outlined,
        label: context.l10n.localGallery_sendToKrita,
        enabled: isKritaConnected,
      ),
      _item(
        context,
        value: LocalImageContextAction.upscale,
        icon: Icons.zoom_in,
        label: context.l10n.gallery_upscale,
      ),
      _item(
        context,
        value: LocalImageContextAction.shareToDiscord,
        icon: Icons.send_rounded,
        label: context.l10n.discordShare_action,
      ),
      if (watermarkEnabled) const PopupMenuDivider(),
      if (watermarkEnabled)
        _item(
          context,
          value: LocalImageContextAction.createWatermark,
          icon: Icons.branding_watermark_outlined,
          label: isWatermarkDerivative
              ? context.l10n.watermark_actionRegenerate
              : context.l10n.watermark_actionCreate,
        ),
    ];
  }

  static PopupMenuItem<LocalImageContextAction> _item(
    BuildContext context, {
    required LocalImageContextAction value,
    required IconData icon,
    required String label,
    bool enabled = true,
    bool destructive = false,
  }) {
    final color = !enabled
        ? Theme.of(context).disabledColor
        : destructive
        ? Theme.of(context).colorScheme.error
        : null;

    return PopupMenuItem<LocalImageContextAction>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: color == null ? null : TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
