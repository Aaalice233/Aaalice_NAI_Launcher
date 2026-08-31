import 'package:flutter/material.dart';

import '../../../data/models/online_gallery/gallery_item.dart';
import 'gallery_detail_models.dart';

class GalleryDetailActionPanel extends StatelessWidget {
  const GalleryDetailActionPanel({
    super.key,
    required this.viewModel,
    required this.actions,
  });

  final GalleryDetailViewModel viewModel;
  final GalleryDetailActions actions;

  @override
  Widget build(BuildContext context) {
    final media = viewModel.currentMedia;
    final canDownload =
        media != null &&
        galleryMediaHasOriginal(media) &&
        galleryMediaDownloadUrl(media).isNotEmpty;
    final canReverse =
        media != null &&
        media.capability.isFlutterImage &&
        media.capability.imageDisplayUrl.isNotEmpty &&
        actions.sendToReverse != null;
    final canWatermark =
        canDownload &&
        media.capability.isFlutterImage &&
        actions.downloadAndWatermark != null;
    final canDownloadAll =
        actions.downloadAll != null && viewModel.media.length > 1;
    const actionStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(42)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    );

    Widget label(String value) =>
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis);
    Widget row(Widget first, Widget second) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 8),
        Expanded(child: second),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            FilledButton.icon(
              style: actionStyle,
              onPressed: viewModel.hasCopyableContent
                  ? actions.sendToGenerate
                  : null,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: label(viewModel.labels.sendToGenerate),
            ),
            OutlinedButton.icon(
              style: actionStyle,
              onPressed:
                  viewModel.hasCopyableContent && !viewModel.queueActionPending
                  ? actions.addToQueue
                  : null,
              icon: viewModel.queueActionPending
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add, size: 18),
              label: label(viewModel.labels.addToQueue),
            ),
          ),
          const SizedBox(height: 8),
          row(
            _copyActionsButton(media, actionStyle),
            OutlinedButton.icon(
              style: actionStyle,
              onPressed: canDownload && !viewModel.downloadActionPending
                  ? () => actions.downloadCurrentOriginal(media)
                  : null,
              icon: viewModel.downloadActionPending
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 18),
              label: label(viewModel.labels.downloadOriginal),
            ),
          ),
          if (canWatermark) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: actionStyle,
              onPressed: viewModel.downloadActionPending
                  ? null
                  : () => actions.downloadAndWatermark!(media),
              icon: const Icon(Icons.branding_watermark_outlined, size: 18),
              label: label(viewModel.labels.downloadAndWatermark),
            ),
          ],
          if (canReverse || canDownloadAll) ...[
            const SizedBox(height: 8),
            row(
              canReverse
                  ? OutlinedButton.icon(
                      style: actionStyle,
                      onPressed: () => actions.sendToReverse!(media),
                      icon: const Icon(Icons.manage_search, size: 18),
                      label: label(viewModel.labels.sendToReverse),
                    )
                  : const SizedBox.shrink(),
              canDownloadAll
                  ? OutlinedButton.icon(
                      style: actionStyle,
                      onPressed: viewModel.downloadActionPending
                          ? null
                          : () => actions.downloadAll!(viewModel.media),
                      icon: const Icon(Icons.download_for_offline, size: 18),
                      label: label(viewModel.labels.downloadAll),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _copyActionsButton(GalleryMedia? media, ButtonStyle style) {
    final hasArtistChain =
        media != null && actions.hasArtistChain?.call(media) == true;
    final hasCopyActions =
        viewModel.hasPrompt ||
        viewModel.hasNegativePrompt ||
        (actions.copyFullPrompt == null && viewModel.hasCopyableContent) ||
        (media != null &&
            (actions.copyMetadata != null ||
                actions.copyArtistChain != null ||
                actions.copyFullPrompt != null ||
                actions.copyRawArtistFragments != null));

    return MenuAnchor(
      menuChildren: [
        if (media != null && actions.copyArtistChain != null)
          MenuItemButton(
            onPressed: hasArtistChain
                ? () => actions.copyArtistChain!(media)
                : null,
            leadingIcon: const Icon(Icons.brush_outlined, size: 18),
            child: Text(
              hasArtistChain
                  ? viewModel.labels.copyArtistChain
                  : viewModel.labels.noArtistChain,
            ),
          ),
        if (media != null && actions.copyFullPrompt != null)
          MenuItemButton(
            onPressed: () => actions.copyFullPrompt!(media),
            leadingIcon: const Icon(Icons.copy_all, size: 18),
            child: Text(viewModel.labels.copyFullPrompt),
          ),
        if (media != null && actions.copyRawArtistFragments != null)
          MenuItemButton(
            onPressed: hasArtistChain
                ? () => actions.copyRawArtistFragments!(media)
                : null,
            leadingIcon: const Icon(Icons.code, size: 18),
            child: Text(viewModel.labels.copyRawArtistFragments),
          ),
        if (actions.copyFullPrompt == null && viewModel.hasCopyableContent)
          MenuItemButton(
            onPressed: actions.copyAll,
            leadingIcon: const Icon(Icons.copy_all_outlined, size: 18),
            child: Text(viewModel.labels.copyAll),
          ),
        if (media != null && actions.copyMetadata != null)
          MenuItemButton(
            onPressed: () => actions.copyMetadata!(media),
            leadingIcon: const Icon(Icons.data_object, size: 18),
            child: Text(viewModel.labels.copyMetadata),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton.icon(
        style: style,
        onPressed: hasCopyActions
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
        icon: const Icon(Icons.content_copy_outlined, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                viewModel.labels.copyActions,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
