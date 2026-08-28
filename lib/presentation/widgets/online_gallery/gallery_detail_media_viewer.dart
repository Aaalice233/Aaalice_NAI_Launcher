import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import 'gallery_detail_controller.dart';
import 'gallery_detail_models.dart';
import 'video_player_widget.dart';

class GalleryDetailMediaViewer extends StatelessWidget {
  const GalleryDetailMediaViewer({
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
    final theme = Theme.of(context);
    if (viewModel.media.isEmpty) return _noImageState(theme);

    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: controller.pageController,
                  itemCount: viewModel.media.length,
                  onPageChanged: actions.mediaPageChanged,
                  itemBuilder: (context, index) =>
                      _mediaPage(context, theme, viewModel.media[index], index),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _darkOverlay(
                    child: Text(
                      viewModel.labels.imageCounter(
                        viewModel.mediaIndex + 1,
                        viewModel.media.length,
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _darkOverlay(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.zoom_in,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          viewModel.labels.zoomHint,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_currentMediaFacts.isNotEmpty)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _darkOverlay(
                      child: Text(
                        _currentMediaFacts,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                if (viewModel.mediaIndex > 0) _navigationButton(left: true),
                if (viewModel.mediaIndex + 1 < viewModel.media.length)
                  _navigationButton(left: false),
              ],
            ),
          ),
          if (viewModel.media.length > 1) _thumbnailStrip(theme),
        ],
      ),
    );
  }

  String get _currentMediaFacts {
    final media = viewModel.currentMedia;
    if (media == null) return '';
    final values = <String>[];
    if (media.width > 0 && media.height > 0) {
      values.add('${media.width} × ${media.height}');
    }
    final extension = media.extension?.trim().toUpperCase() ?? '';
    if (extension.isNotEmpty) values.add(extension);
    return values.join(' · ');
  }

  Widget _mediaPage(
    BuildContext context,
    ThemeData theme,
    GalleryMedia media,
    int index,
  ) {
    final imageUrl = galleryMediaDisplayUrl(media);
    if (imageUrl.isEmpty) return _noImageState(theme, dark: true);
    final extension = media.extension?.toLowerCase();
    if (media.mediaType == 'video' ||
        extension == 'webm' ||
        extension == 'mp4') {
      return VideoPlayerWidget(videoUrl: imageUrl);
    }

    return InteractiveViewer(
      minScale: 0.75,
      maxScale: 5,
      boundaryMargin: const EdgeInsets.all(40),
      child: Center(
        child: CachedNetworkImage(
          key: ValueKey('$imageUrl:$index:${viewModel.imageRevision}'),
          imageUrl: imageUrl,
          cacheManager: OnlineGalleryImageCacheManager.instance,
          cacheKey: onlineGalleryImageCacheKeyForUrl(imageUrl),
          httpHeaders: onlineGalleryImageHeadersForUrl(imageUrl),
          memCacheWidth: GalleryImageSizing.detailViewportTargetWidth(
            MediaQuery.devicePixelRatioOf(context),
            MediaQuery.sizeOf(context).width,
          ),
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
          errorWidget: (_, __, ___) => _imageError(theme, media),
        ),
      ),
    );
  }

  Widget _imageError(ThemeData theme, GalleryMedia media) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 46,
        ),
        const SizedBox(height: 10),
        Text(
          viewModel.labels.imageLoadFailed,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () => actions.retryMedia(media),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(viewModel.labels.retry),
        ),
      ],
    );
  }

  Widget _noImageState(ThemeData theme, {bool dark = false}) {
    final foreground = dark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    return ColoredBox(
      color: dark ? Colors.black : theme.colorScheme.surfaceContainerLow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 54,
                color: foreground,
              ),
              const SizedBox(height: 12),
              Text(
                viewModel.labels.noImage,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                viewModel.labels.noImageDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navigationButton({required bool left}) {
    return Positioned(
      left: left ? 12 : null,
      right: left ? null : 12,
      top: 0,
      bottom: 0,
      child: Center(
        child: IconButton.filled(
          onPressed: () =>
              actions.moveToMedia(viewModel.mediaIndex + (left ? -1 : 1)),
          tooltip: left
              ? viewModel.labels.previousImage
              : viewModel.labels.nextImage,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.55),
            foregroundColor: Colors.white,
          ),
          icon: Icon(left ? Icons.chevron_left : Icons.chevron_right),
        ),
      ),
    );
  }

  Widget _thumbnailStrip(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 82,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          scrollDirection: Axis.horizontal,
          itemCount: viewModel.media.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final media = viewModel.media[index];
            final selected = index == viewModel.mediaIndex;
            final previewUrl = galleryMediaPreviewUrl(media);
            return Semantics(
              button: true,
              selected: selected,
              label: viewModel.labels.imageCounter(
                index + 1,
                viewModel.media.length,
              ),
              child: InkWell(
                onTap: () => actions.moveToMedia(index),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 140),
                  width: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.dividerColor.withValues(alpha: 0.45),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: previewUrl.isEmpty
                      ? const Icon(Icons.image_not_supported_outlined)
                      : CachedNetworkImage(
                          imageUrl: previewUrl,
                          cacheManager: OnlineGalleryImageCacheManager.instance,
                          cacheKey: onlineGalleryImageCacheKeyForUrl(
                            previewUrl,
                          ),
                          httpHeaders: onlineGalleryImageHeadersForUrl(
                            previewUrl,
                          ),
                          memCacheWidth: GalleryImageSizing.gridTargetWidth(
                            layoutWidth: 64,
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                          ),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _darkOverlay({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: child,
      ),
    );
  }
}
