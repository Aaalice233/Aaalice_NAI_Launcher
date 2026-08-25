import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/online_gallery_blacklist_provider.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import '../common/app_toast.dart';

enum OnlineGalleryTagContextAction { copy, search, outputFilter, blacklist }

Future<OnlineGalleryTagContextAction?> showOnlineGalleryTagContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required String tag,
  required Offset globalPosition,
  ValueChanged<String>? onSearch,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final outputFilter = ref.read(onlineGalleryOutputFilterProvider);
  final blacklist = ref.read(onlineGalleryBlacklistNotifierProvider);
  final normalized = OnlineGalleryOutputFilterSettings.normalizeTag(tag);
  final isOutputFiltered = outputFilter.contains(tag);
  final isBlacklisted =
      normalized != null && blacklist.effectiveTags.contains(normalized);

  final action = await showMenu<OnlineGalleryTagContextAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(
        value: OnlineGalleryTagContextAction.copy,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.content_copy_outlined, size: 20),
          title: Text(context.l10n.common_copy),
        ),
      ),
      PopupMenuItem(
        value: OnlineGalleryTagContextAction.search,
        enabled: onSearch != null,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.search, size: 20),
          title: Text(context.l10n.common_search),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: OnlineGalleryTagContextAction.outputFilter,
        enabled: !isOutputFiltered,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(
            isOutputFiltered
                ? Icons.check_circle_outline
                : Icons.filter_alt_off_outlined,
            size: 20,
          ),
          title: Text(
            isOutputFiltered
                ? context.l10n.onlineGallery_outputFilterAlreadyAdded
                : context.l10n.onlineGallery_addTagToOutputFilter,
          ),
          subtitle: Text(context.l10n.onlineGallery_outputFilterMenuHint),
        ),
      ),
      PopupMenuItem(
        value: OnlineGalleryTagContextAction.blacklist,
        enabled: !isBlacklisted,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(
            isBlacklisted ? Icons.check_circle_outline : Icons.block,
            size: 20,
          ),
          title: Text(
            isBlacklisted
                ? context.l10n.onlineGallery_blacklistAlreadyAdded
                : context.l10n.onlineGallery_addTagToBlacklist,
          ),
          subtitle: Text(context.l10n.onlineGallery_blacklistMenuHint),
        ),
      ),
    ],
  );

  if (action == OnlineGalleryTagContextAction.copy) {
    await Clipboard.setData(ClipboardData(text: tag));
    if (context.mounted) {
      AppToast.success(context, context.l10n.onlineGallery_copied);
    }
  } else if (action == OnlineGalleryTagContextAction.search) {
    onSearch?.call(tag);
  } else if (action == OnlineGalleryTagContextAction.outputFilter) {
    final added = await ref
        .read(onlineGalleryOutputFilterProvider.notifier)
        .addTag(tag);
    if (added && context.mounted) {
      AppToast.success(
        context,
        context.l10n.onlineGallery_outputFilterTagAdded(tag),
      );
    }
  } else if (action == OnlineGalleryTagContextAction.blacklist) {
    final added = await ref
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .addTag(tag);
    if (added && context.mounted) {
      AppToast.success(
        context,
        context.l10n.onlineGallery_blacklistTagAdded(tag),
      );
    }
  }
  return action;
}
