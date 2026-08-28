import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/online_gallery/gallery_source.dart';
import 'gallery_detail_action_panel.dart';
import 'gallery_detail_controller.dart';
import 'gallery_detail_info_panel.dart';
import 'gallery_detail_media_viewer.dart';
import 'gallery_detail_models.dart';

class GalleryDetailDialogView extends StatelessWidget {
  const GalleryDetailDialogView({
    super.key,
    required this.controller,
    required this.viewModel,
    required this.actions,
  });

  final GalleryDetailController controller;
  final GalleryDetailViewModel viewModel;
  final GalleryDetailActions actions;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return KeyboardListener(
      focusNode: controller.keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(context, event),
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: mediaQuery.size.width < 600 ? 8 : 24,
          vertical: mediaQuery.size.height < 600 ? 8 : 24,
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240, maxHeight: 840),
          child: SizedBox(
            width: double.infinity,
            height: 840,
            child: Column(
              children: [
                _GalleryDetailHeader(viewModel: viewModel, actions: actions),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final mediaViewer = GalleryDetailMediaViewer(
                        controller: controller,
                        viewModel: viewModel,
                        actions: actions,
                      );
                      final infoPanel = GalleryDetailInfoPanel(
                        viewModel: viewModel,
                        actions: actions,
                        actionPanel: GalleryDetailActionPanel(
                          viewModel: viewModel,
                          actions: actions,
                        ),
                      );
                      if (constraints.maxWidth < 840) {
                        return Column(
                          children: [
                            SizedBox(
                              height: (constraints.maxHeight * 0.46).clamp(
                                220.0,
                                390.0,
                              ),
                              child: mediaViewer,
                            ),
                            Divider(
                              height: 1,
                              color: Theme.of(context).dividerColor,
                            ),
                            Expanded(child: infoPanel),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 7, child: mediaViewer),
                          VerticalDivider(
                            width: 1,
                            color: Theme.of(context).dividerColor,
                          ),
                          SizedBox(
                            width: constraints.maxWidth < 1050 ? 390 : 430,
                            child: infoPanel,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(BuildContext context, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      actions.close();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      actions.moveToMedia(viewModel.mediaIndex - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      actions.moveToMedia(viewModel.mediaIndex + 1);
    }
  }
}

class _GalleryDetailHeader extends StatelessWidget {
  const _GalleryDetailHeader({required this.viewModel, required this.actions});

  final GalleryDetailViewModel viewModel;
  final GalleryDetailActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = viewModel.item.title?.trim();
    final codexTitle = _metadataString('codexTitle');
    final codexVersion = _metadataString('codexVersion');
    final subtitleParts = [
      if (codexTitle.isNotEmpty) codexTitle,
      if (codexVersion.isNotEmpty) codexVersion,
      if (viewModel.item.author?.trim().isNotEmpty == true)
        viewModel.item.author!.trim(),
      if (viewModel.item.createdAt.trim().isNotEmpty)
        viewModel.item.createdAt.trim(),
    ];
    final fallbackTitle =
        viewModel.item.sourceId == GallerySourceId.quickTagCloud
        ? viewModel.labels.untitled
        : '${viewModel.labels.sourceName} #${viewModel.item.sourceWorkId}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              viewModel.labels.sourceName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title?.isNotEmpty == true ? title! : fallbackTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _favoriteButton(context),
          IconButton(
            onPressed: viewModel.hasSourceUrl ? actions.openSource : null,
            icon: const Icon(Icons.open_in_new),
            tooltip: viewModel.labels.openSource,
          ),
          IconButton(
            onPressed: actions.close,
            icon: const Icon(Icons.close),
            tooltip: viewModel.labels.close,
          ),
        ],
      ),
    );
  }

  Widget _favoriteButton(BuildContext context) {
    final theme = Theme.of(context);
    final loading =
        viewModel.favoriteLoading || viewModel.favoriteActionPending;
    return IconButton(
      onPressed: loading || !viewModel.canToggleFavorite
          ? null
          : actions.toggleFavorite,
      tooltip: viewModel.isFavorited
          ? viewModel.labels.removeFavorite
          : viewModel.labels.addFavorite,
      icon: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 140),
        child: loading
            ? SizedBox(
                key: const ValueKey('favorite-loading'),
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : Icon(
                viewModel.isFavorited ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(viewModel.isFavorited),
                color: viewModel.isFavorited ? theme.colorScheme.primary : null,
              ),
      ),
    );
  }

  String _metadataString(String key) =>
      viewModel.detail.rawSourceMetadata[key]?.toString().trim() ?? '';
}
