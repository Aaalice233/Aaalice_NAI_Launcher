import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';

enum LocalImageContextAction {
  sendToImg2Img,
  sendToReversePrompt,
  sendToStyleTransfer,
  sendToPreciseReference,
  sendToKrita,
  importMetadata,
  copyPrompt,
  copySeed,
  showInFolder,
  delete,
}

class LocalImageContextMenu {
  const LocalImageContextMenu._();

  static Future<LocalImageContextAction?> show(
    BuildContext context, {
    required Offset position,
    required bool hasImportableMetadata,
    required bool hasPrompt,
    required bool hasSeed,
    required bool isKritaConnected,
  }) {
    return showMenu<LocalImageContextAction>(
      context: context,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: buildEntries(
        context,
        hasImportableMetadata: hasImportableMetadata,
        hasPrompt: hasPrompt,
        hasSeed: hasSeed,
        isKritaConnected: isKritaConnected,
      ),
    );
  }

  static List<PopupMenuEntry<LocalImageContextAction>> buildEntries(
    BuildContext context, {
    required bool hasImportableMetadata,
    required bool hasPrompt,
    required bool hasSeed,
    required bool isKritaConnected,
  }) {
    final hasImageInfoActions = hasImportableMetadata || hasPrompt || hasSeed;

    return [
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
        value: LocalImageContextAction.sendToKrita,
        icon: Icons.brush_outlined,
        label: context.l10n.localGallery_sendToKrita,
        enabled: isKritaConnected,
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
