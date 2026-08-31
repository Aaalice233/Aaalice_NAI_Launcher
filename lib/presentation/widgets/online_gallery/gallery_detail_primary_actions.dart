import 'package:flutter/material.dart';

import 'gallery_detail_models.dart';

class GalleryDetailPrimaryActions extends StatelessWidget {
  const GalleryDetailPrimaryActions({
    super.key,
    required this.viewModel,
    required this.actions,
  });

  final GalleryDetailViewModel viewModel;
  final GalleryDetailActions actions;

  @override
  Widget build(BuildContext context) {
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    );
    final media = viewModel.currentMedia;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('gallery-detail-generate'),
              style: style,
              onPressed: viewModel.canUseGenerationActions
                  ? () => actions.sendToGenerate(media)
                  : null,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                viewModel.labels.sendToGenerate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('gallery-detail-queue'),
              style: style,
              onPressed:
                  viewModel.canUseGenerationActions &&
                      !viewModel.queueActionPending
                  ? () => actions.addToQueue(media)
                  : null,
              icon: viewModel.queueActionPending
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add, size: 18),
              label: Text(
                viewModel.labels.addToQueue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
