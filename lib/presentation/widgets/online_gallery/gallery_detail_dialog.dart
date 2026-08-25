import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/utils/prompt_tag_utils.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../../data/models/online_gallery/gallery_source.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import '../tag_chip.dart';
import 'gallery_detail_overview_card.dart';
import 'gallery_detail_tag_section.dart';
import 'gallery_detail_text_section.dart';
import 'gallery_tag_context_menu.dart';
import 'video_player_widget.dart';

/// All user-facing copy used by [GalleryDetailDialog].
///
/// Keeping these values outside the widget lets the caller connect generated
/// localizations without making this reusable presentation component depend on
/// a provider or localization extension.
class GalleryDetailDialogLabels {
  const GalleryDetailDialogLabels({
    required this.sourceName,
    required this.untitled,
    required this.codex,
    required this.category,
    required this.positivePrompt,
    required this.negativePrompt,
    required this.characterPrompts,
    required this.note,
    required this.rawTags,
    required this.artists,
    required this.characters,
    required this.copyrights,
    required this.general,
    required this.metadata,
    required this.tagContextMenuTooltip,
    required this.outputFilteredTagTooltip,
    required this.author,
    required this.imageFile,
    required this.originalFile,
    required this.declaredSource,
    required this.contributors,
    required this.noImage,
    required this.noImageDescription,
    required this.imageLoadFailed,
    required this.retry,
    required this.zoomHint,
    required this.copyActions,
    required this.copyPositive,
    required this.copyNegative,
    required this.copyCharacter,
    required this.copyAll,
    required this.addFavorite,
    required this.removeFavorite,
    required this.openSource,
    required this.sendToGenerate,
    required this.addToQueue,
    required this.downloadOriginal,
    required this.previousImage,
    required this.nextImage,
    required this.close,
    required this.emptyValue,
    required this.imageCounter,
    required this.multipleImages,
    required this.views,
    required this.favoriteCount,
    required this.rating,
    required this.score,
    required this.copyMetadata,
    required this.downloadAll,
    required this.sendToReverse,
    required this.copyArtistChain,
    required this.copyFullPrompt,
    required this.copyRawArtistFragments,
    required this.noArtistChain,
  });

  final String sourceName;
  final String untitled;
  final String codex;
  final String category;
  final String positivePrompt;
  final String negativePrompt;
  final String characterPrompts;
  final String note;
  final String rawTags;
  final String artists;
  final String characters;
  final String copyrights;
  final String general;
  final String metadata;
  final String tagContextMenuTooltip;
  final String outputFilteredTagTooltip;
  final String author;
  final String imageFile;
  final String originalFile;
  final String declaredSource;
  final String contributors;
  final String noImage;
  final String noImageDescription;
  final String imageLoadFailed;
  final String retry;
  final String zoomHint;
  final String copyActions;
  final String copyPositive;
  final String copyNegative;
  final String copyCharacter;
  final String copyAll;
  final String addFavorite;
  final String removeFavorite;
  final String openSource;
  final String sendToGenerate;
  final String addToQueue;
  final String downloadOriginal;
  final String previousImage;
  final String nextImage;
  final String close;
  final String emptyValue;
  final String Function(int current, int total) imageCounter;
  final String Function(int count) multipleImages;
  final String views;
  final String favoriteCount;
  final String rating;
  final String score;
  final String copyMetadata;
  final String downloadAll;
  final String sendToReverse;
  final String copyArtistChain;
  final String copyFullPrompt;
  final String copyRawArtistFragments;
  final String noArtistChain;
}

/// Source-neutral detail surface shared by every online gallery adapter.
///
/// Source-specific mutations remain callback-driven while media, metadata,
/// prompt and tag interactions use one consistent responsive layout.
class GalleryDetailDialog extends ConsumerStatefulWidget {
  const GalleryDetailDialog({
    super.key,
    required this.item,
    required this.detail,
    required this.isFavorited,
    required this.favoriteLoading,
    this.canToggleFavorite = true,
    required this.labels,
    required this.onCopyPrompt,
    required this.onCopyNegativePrompt,
    required this.onCopyCharacter,
    required this.onCopyAll,
    required this.onToggleFavorite,
    required this.onOpenSource,
    required this.onSendToGenerate,
    required this.onAddToQueue,
    required this.onDownloadCurrentOriginal,
    required this.onTagSearch,
    required this.onBlacklistChanged,
    this.onCopyMetadata,
    this.onDownloadAll,
    this.onSendToReverse,
    this.onCopyArtistChain,
    this.onCopyFullPrompt,
    this.onCopyRawArtistFragments,
    this.hasArtistChain,
  });

  final GalleryItem item;
  final GalleryDetail detail;
  final bool isFavorited;
  final bool favoriteLoading;
  final bool canToggleFavorite;
  final GalleryDetailDialogLabels labels;

  final VoidCallback onCopyPrompt;
  final VoidCallback onCopyNegativePrompt;
  final void Function(GalleryCharacterPrompt character) onCopyCharacter;
  final VoidCallback onCopyAll;
  final Future<bool> Function() onToggleFavorite;
  final VoidCallback onOpenSource;
  final VoidCallback onSendToGenerate;
  final Future<void> Function() onAddToQueue;
  final Future<void> Function(GalleryMedia media) onDownloadCurrentOriginal;
  final ValueChanged<String> onTagSearch;
  final VoidCallback onBlacklistChanged;
  final void Function(GalleryMedia media)? onCopyMetadata;
  final Future<void> Function(List<GalleryMedia> media)? onDownloadAll;
  final Future<void> Function(GalleryMedia media)? onSendToReverse;
  final void Function(GalleryMedia media)? onCopyArtistChain;
  final void Function(GalleryMedia media)? onCopyFullPrompt;
  final void Function(GalleryMedia media)? onCopyRawArtistFragments;
  final bool Function(GalleryMedia media)? hasArtistChain;

  @override
  ConsumerState<GalleryDetailDialog> createState() =>
      _GalleryDetailDialogState();
}

class _GalleryDetailDialogState extends ConsumerState<GalleryDetailDialog> {
  late final PageController _pageController;
  final FocusNode _keyboardFocusNode = FocusNode();

  int _mediaIndex = 0;
  int _imageRevision = 0;
  bool _favoriteActionPending = false;
  late bool _isFavorited;
  bool _queueActionPending = false;
  bool _downloadActionPending = false;

  List<GalleryMedia> get _media => widget.detail.media;

  GalleryMedia? get _currentMedia =>
      _media.isEmpty ? null : _media[_mediaIndex.clamp(0, _media.length - 1)];

  List<String> get _currentRawTags {
    final mediaRawTags = _currentMedia?.rawMetadata?.trim() ?? '';
    return mediaRawTags.isEmpty ? widget.detail.rawTags : [mediaRawTags];
  }

  bool get _hasPrompt => widget.detail.prompt?.trim().isNotEmpty == true;

  bool get _hasNegativePrompt =>
      widget.detail.negativePrompt?.trim().isNotEmpty == true;

  List<GalleryCharacterPrompt> get _displayCharacterPrompts => widget
      .detail
      .characterPrompts
      .where(
        (character) =>
            character.prompt.trim().isNotEmpty ||
            character.negativePrompt.trim().isNotEmpty,
      )
      .toList(growable: false);

  bool get _hasCopyableContent =>
      _hasPrompt || _hasNegativePrompt || _displayCharacterPrompts.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _mediaIndex = _resolveInitialMediaIndex();
    _isFavorited = widget.isFavorited;
    _pageController = PageController(initialPage: _mediaIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prefetchAdjacent(_mediaIndex);
    });
  }

  @override
  void didUpdateWidget(covariant GalleryDetailDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorited != widget.isFavorited) {
      _isFavorited = widget.isFavorited;
    }
    if (oldWidget.item.stableKey == widget.item.stableKey &&
        oldWidget.detail.media == widget.detail.media) {
      return;
    }
    final nextIndex = _resolveInitialMediaIndex();
    _mediaIndex = nextIndex;
    _imageRevision++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients && _media.isNotEmpty) {
        _pageController.jumpToPage(nextIndex);
      }
      _prefetchAdjacent(nextIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  int _resolveInitialMediaIndex() {
    if (_media.isEmpty) return 0;
    final focusedId = widget.item.focusedMediaId;
    if (focusedId != null) {
      final matchingIndex = _media.indexWhere((media) => media.id == focusedId);
      if (matchingIndex >= 0) return matchingIndex;
    }
    return (widget.item.focusedMediaIndex ?? 0).clamp(0, _media.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final horizontalInset = mediaQuery.size.width < 600 ? 8.0 : 24.0;
    final verticalInset = mediaQuery.size.height < 600 ? 8.0 : 24.0;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: horizontalInset,
          vertical: verticalInset,
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240, maxHeight: 840),
          child: SizedBox(
            width: 1240,
            height: 840,
            child: Column(
              children: [
                _buildHeader(theme),
                Divider(height: 1, color: theme.dividerColor),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final useVerticalLayout = constraints.maxWidth < 840;
                      if (useVerticalLayout) {
                        final viewerHeight = (constraints.maxHeight * 0.46)
                            .clamp(220.0, 390.0);
                        return Column(
                          children: [
                            SizedBox(
                              height: viewerHeight,
                              child: _buildMediaPanel(theme),
                            ),
                            Divider(height: 1, color: theme.dividerColor),
                            Expanded(child: _buildInfoPanel(theme)),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 7, child: _buildMediaPanel(theme)),
                          VerticalDivider(width: 1, color: theme.dividerColor),
                          SizedBox(
                            width: constraints.maxWidth < 1050 ? 390 : 430,
                            child: _buildInfoPanel(theme),
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

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveTo(_mediaIndex - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveTo(_mediaIndex + 1);
    }
  }

  Widget _buildHeader(ThemeData theme) {
    final title = widget.item.title?.trim();
    final codexTitle = _metadataString('codexTitle');
    final codexVersion = _metadataString('codexVersion');
    final subtitleParts = [
      if (codexTitle.isNotEmpty) codexTitle,
      if (codexVersion.isNotEmpty) codexVersion,
      if (widget.item.author?.trim().isNotEmpty == true)
        widget.item.author!.trim(),
      if (widget.item.createdAt.trim().isNotEmpty) widget.item.createdAt.trim(),
    ];
    final fallbackTitle = widget.item.sourceId == GallerySourceId.quickTagCloud
        ? widget.labels.untitled
        : '${widget.labels.sourceName} #${widget.item.sourceWorkId}';

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
              widget.labels.sourceName,
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
          _favoriteButton(theme),
          IconButton(
            onPressed: _hasSourceUrl ? widget.onOpenSource : null,
            icon: const Icon(Icons.open_in_new),
            tooltip: widget.labels.openSource,
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
            tooltip: widget.labels.close,
          ),
        ],
      ),
    );
  }

  Widget _favoriteButton(ThemeData theme) {
    final loading = widget.favoriteLoading || _favoriteActionPending;
    return IconButton(
      onPressed: loading || !widget.canToggleFavorite ? null : _toggleFavorite,
      tooltip: _isFavorited
          ? widget.labels.removeFavorite
          : widget.labels.addFavorite,
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
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(_isFavorited),
                color: _isFavorited ? theme.colorScheme.primary : null,
              ),
      ),
    );
  }

  bool get _hasSourceUrl =>
      widget.detail.sourceUrl?.trim().isNotEmpty == true ||
      widget.item.postUrl.trim().isNotEmpty;

  String get _currentMediaFacts {
    final media = _currentMedia;
    if (media == null) return '';
    final values = <String>[];
    if (media.width > 0 && media.height > 0) {
      values.add('${media.width} × ${media.height}');
    }
    final extension = media.extension?.trim().toUpperCase() ?? '';
    if (extension.isNotEmpty) values.add(extension);
    return values.join(' · ');
  }

  Widget _buildMediaPanel(ThemeData theme) {
    if (_media.isEmpty) return _buildNoImageState(theme);

    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _media.length,
                  onPageChanged: (index) {
                    setState(() => _mediaIndex = index);
                    _prefetchAdjacent(index);
                  },
                  itemBuilder: (context, index) =>
                      _buildMediaPage(theme, _media[index], index),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _darkOverlay(
                    child: Text(
                      widget.labels.imageCounter(
                        _mediaIndex + 1,
                        _media.length,
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
                          widget.labels.zoomHint,
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
                if (_mediaIndex > 0)
                  _buildNavigationButton(left: true)
                else
                  const SizedBox.shrink(),
                if (_mediaIndex + 1 < _media.length)
                  _buildNavigationButton(left: false)
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
          if (_media.length > 1) _buildThumbnailStrip(theme),
        ],
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

  Widget _buildMediaPage(ThemeData theme, GalleryMedia media, int index) {
    final imageUrl = _displayUrl(media);
    if (imageUrl.isEmpty) return _buildNoImageState(theme, dark: true);
    final extension = media.extension?.toLowerCase();
    final isVideo =
        media.mediaType == 'video' || extension == 'webm' || extension == 'mp4';
    if (isVideo) return VideoPlayerWidget(videoUrl: imageUrl);

    return InteractiveViewer(
      minScale: 0.75,
      maxScale: 5,
      boundaryMargin: const EdgeInsets.all(40),
      child: Center(
        child: CachedNetworkImage(
          key: ValueKey('$imageUrl:$index:$_imageRevision'),
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
          errorWidget: (_, __, ___) => _buildImageError(theme, media),
        ),
      ),
    );
  }

  Widget _buildImageError(ThemeData theme, GalleryMedia media) {
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
          widget.labels.imageLoadFailed,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () => _retryImage(media),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(widget.labels.retry),
        ),
      ],
    );
  }

  Widget _buildNoImageState(ThemeData theme, {bool dark = false}) {
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
                widget.labels.noImage,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.labels.noImageDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton({required bool left}) {
    return Positioned(
      left: left ? 12 : null,
      right: left ? null : 12,
      top: 0,
      bottom: 0,
      child: Center(
        child: IconButton.filled(
          onPressed: () => _moveTo(_mediaIndex + (left ? -1 : 1)),
          tooltip: left ? widget.labels.previousImage : widget.labels.nextImage,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.55),
            foregroundColor: Colors.white,
          ),
          icon: Icon(left ? Icons.chevron_left : Icons.chevron_right),
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 82,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          scrollDirection: Axis.horizontal,
          itemCount: _media.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final media = _media[index];
            final selected = index == _mediaIndex;
            final previewUrl = _previewUrl(media);
            return Semantics(
              button: true,
              selected: selected,
              label: widget.labels.imageCounter(index + 1, _media.length),
              child: InkWell(
                onTap: () => _moveTo(index),
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

  Widget _buildInfoPanel(ThemeData theme) {
    final isQuickTagCloud =
        widget.item.sourceId == GallerySourceId.quickTagCloud;
    final codexTitle = _metadataString('codexTitle');
    final contributorNames = widget.detail.contributors
        .map((contributor) => contributor.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final attributions = <String>[];
    for (final value in [
      _currentMedia?.metadata['credit']?.toString(),
      _currentMedia?.metadata['author']?.toString(),
      widget.item.author,
    ]) {
      for (final part in (value ?? '').split(' · ')) {
        final normalized = part.trim();
        if (normalized.isNotEmpty &&
            !contributorNames.contains(normalized) &&
            !attributions.contains(normalized)) {
          attributions.add(normalized);
        }
      }
    }
    final author = attributions.join(' · ');
    final currentMedia = _currentMedia;
    final imageFile = currentMedia?.metadata['path']?.toString().trim() ?? '';
    final originalFile = currentMedia != null && _hasOriginal(currentMedia)
        ? currentMedia.metadata['original']?.toString().trim() ?? ''
        : '';
    final preferredFile = originalFile.isNotEmpty ? originalFile : imageFile;
    final preferredFileLabel = originalFile.isNotEmpty
        ? widget.labels.originalFile
        : widget.labels.imageFile;
    final declaredSource = _metadataString('declaredSource');
    final normalizedDeclaredSource = declaredSource.toLowerCase();
    final repeatsContributor = contributorNames.any(
      (name) => normalizedDeclaredSource.contains(name.toLowerCase()),
    );
    final showDeclaredSource =
        declaredSource.isNotEmpty && (!isQuickTagCloud || !repeatsContributor);
    final categoryPath = widget.detail.categoryPath
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final promptIsRepresentedByTags =
        widget.detail.prompt?.trim().isNotEmpty == true &&
        widget.detail.item.tagString.trim() == widget.detail.prompt!.trim();
    final showPromptCard = _hasPrompt && !promptIsRepresentedByTags;
    final note = widget.detail.note?.trim().isNotEmpty == true
        ? widget.detail.note!.trim()
        : widget.detail.description?.trim() ?? '';
    final characterPrompts = _displayCharacterPrompts;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            children: [
              if (isQuickTagCloud)
                _buildCodexOverview(
                  theme,
                  codexTitle: codexTitle,
                  categoryPath: categoryPath,
                  fileLabel: preferredFileLabel,
                  fileName: preferredFile,
                  author: author,
                  declaredSource: showDeclaredSource ? declaredSource : '',
                  note: note,
                )
              else ...[
                _buildItemBadges(theme),
                if (codexTitle.isNotEmpty || categoryPath.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildCodexContext(
                    codexTitle: codexTitle,
                    categoryPath: categoryPath,
                  ),
                ],
                if (widget.detail.item.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildTagSections(
                    sectionLabel: promptIsRepresentedByTags
                        ? widget.labels.positivePrompt
                        : '',
                    onCopySection: promptIsRepresentedByTags
                        ? widget.onCopyPrompt
                        : null,
                    sectionCopyTooltip: widget.labels.copyPositive,
                  ),
                ],
              ],
              if (!isQuickTagCloud && showPromptCard) ...[
                const SizedBox(height: 16),
                _buildPromptTagSection(
                  label: widget.labels.positivePrompt,
                  prompt: widget.detail.prompt!.trim(),
                  color: TagColors.general,
                  onCopy: widget.onCopyPrompt,
                  copyTooltip: widget.labels.copyPositive,
                ),
              ],
              if (!isQuickTagCloud && _hasNegativePrompt) ...[
                const SizedBox(height: 12),
                _buildPromptTagSection(
                  label: widget.labels.negativePrompt,
                  prompt: widget.detail.negativePrompt!.trim(),
                  color: theme.colorScheme.error,
                  onCopy: widget.onCopyNegativePrompt,
                  copyTooltip: widget.labels.copyNegative,
                ),
              ],
              if (!isQuickTagCloud && characterPrompts.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  widget.labels.characterPrompts,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (
                  var index = 0;
                  index < characterPrompts.length;
                  index++
                ) ...[
                  _buildCharacterTagSection(characterPrompts[index], index),
                  if (index + 1 < characterPrompts.length)
                    const SizedBox(height: 8),
                ],
              ],
              if (!isQuickTagCloud && note.isNotEmpty) ...[
                const SizedBox(height: 12),
                GalleryDetailTextSection(
                  title: widget.labels.note,
                  content: note,
                  accentColor: theme.colorScheme.tertiary,
                ),
              ],
              if (!isQuickTagCloud && _currentRawTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                GalleryDetailTextSection(
                  title: widget.labels.rawTags,
                  content: _currentRawTags.join('\n'),
                  accentColor: theme.colorScheme.secondary,
                  monospace: true,
                ),
              ],
              if (!isQuickTagCloud && preferredFile.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.image_outlined,
                  label: preferredFileLabel,
                  value: preferredFile,
                ),
              ],
              if (!isQuickTagCloud && author.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.person_outline,
                  label: widget.labels.author,
                  value: author,
                ),
              ],
              if (!isQuickTagCloud && showDeclaredSource) ...[
                const SizedBox(height: 12),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.dataset_outlined,
                  label: widget.labels.declaredSource,
                  value: declaredSource,
                ),
              ],
              if (!isQuickTagCloud &&
                  widget.detail.contributors.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildContributors(theme),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: SingleChildScrollView(child: _buildActionArea(theme)),
        ),
      ],
    );
  }

  Widget _buildItemBadges(ThemeData theme) {
    final item = widget.detail.item;
    final stats = <({IconData icon, String label, String value, Color accent})>[
      if (item.viewCount != null)
        (
          icon: Icons.visibility_rounded,
          label: widget.labels.views,
          value: '${item.viewCount}',
          accent: theme.colorScheme.primary,
        ),
      if (item.favoriteCount != null)
        (
          icon: Icons.favorite_rounded,
          label: widget.labels.favoriteCount,
          value: '${item.favoriteCount}',
          accent: theme.colorScheme.error,
        ),
      if (item.score != null)
        (
          icon: Icons.star_rounded,
          label: widget.labels.score,
          value: '${item.score}',
          accent: theme.colorScheme.tertiary,
        ),
      if (item.rating?.trim().isNotEmpty == true)
        (
          icon: Icons.shield_rounded,
          label: widget.labels.rating,
          value: item.rating!.toUpperCase(),
          accent: theme.colorScheme.secondary,
        ),
    ];
    final badges = <Widget>[
      if (item.rank != null) Chip(label: Text('#${item.rank}')),
      if (item.aiType?.trim().isNotEmpty == true)
        Chip(label: Text(item.aiType!.trim())),
      if (item.mediaCount > 1)
        Chip(label: Text(widget.labels.multipleImages(item.mediaCount))),
    ];

    if (stats.isEmpty && badges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final availableWidth = constraints.maxWidth;
              final itemWidth = stats.length == 1
                  ? availableWidth.clamp(0.0, 124.0).toDouble()
                  : (availableWidth - gap * (stats.length - 1)) / stats.length;
              return Wrap(
                key: const ValueKey('gallery-detail-stats'),
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final stat in stats)
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatItem(theme, stat),
                    ),
                ],
              );
            },
          ),
        if (stats.isNotEmpty && badges.isNotEmpty) const SizedBox(height: 10),
        if (badges.isNotEmpty)
          Wrap(spacing: 7, runSpacing: 7, children: badges),
      ],
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    ({IconData icon, String label, String value, Color accent}) stat,
  ) {
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          stat.accent.withValues(alpha: dark ? 0.12 : 0.08),
          theme.colorScheme.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: stat.accent.withValues(alpha: dark ? 0.2 : 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(stat.icon, size: 16, color: stat.accent),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stat.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSections({
    String sectionLabel = '',
    VoidCallback? onCopySection,
    String sectionCopyTooltip = '',
  }) {
    final item = widget.detail.item;
    final artists = PromptTagUtils.uniqueForDisplay(item.artistTags);
    final characters = PromptTagUtils.uniqueForDisplay(item.characterTags);
    final copyrights = PromptTagUtils.uniqueForDisplay(item.copyrightTags);
    final general = PromptTagUtils.uniqueForDisplay(item.generalTags);
    final metadata = PromptTagUtils.uniqueForDisplay(item.metaTags);
    final categorized = {
      for (final tag in [
        ...artists,
        ...characters,
        ...copyrights,
        ...general,
        ...metadata,
      ])
        tag.toLowerCase(),
    };
    final uncategorized = PromptTagUtils.uniqueForDisplay(
      item.tags.where((tag) => !categorized.contains(tag.trim().toLowerCase())),
    );
    return _buildTagCollection(
      [
        if (artists.isNotEmpty)
          GalleryDetailTagGroup(
            label: widget.labels.artists,
            tags: artists,
            color: TagColors.artist,
          ),
        if (characters.isNotEmpty)
          GalleryDetailTagGroup(
            label: widget.labels.characters,
            tags: characters,
            color: TagColors.character,
          ),
        if (copyrights.isNotEmpty)
          GalleryDetailTagGroup(
            label: widget.labels.copyrights,
            tags: copyrights,
            color: TagColors.copyright,
          ),
        if (categorized.isNotEmpty &&
            (general.isNotEmpty || uncategorized.isNotEmpty))
          GalleryDetailTagGroup(
            label: widget.labels.general,
            tags: PromptTagUtils.uniqueForDisplay([
              ...general,
              ...uncategorized,
            ]),
            color: TagColors.general,
          ),
        if (metadata.isNotEmpty)
          GalleryDetailTagGroup(
            label: widget.labels.metadata,
            tags: metadata,
            color: TagColors.meta,
          ),
        if (categorized.isEmpty && uncategorized.isNotEmpty)
          GalleryDetailTagGroup(
            label: widget.labels.rawTags,
            tags: uncategorized,
            color: TagColors.general,
          ),
      ],
      sectionLabel: sectionLabel,
      onCopySection: onCopySection,
      sectionCopyTooltip: sectionCopyTooltip,
    );
  }

  Widget _buildPromptTagSection({
    required String label,
    required String prompt,
    required Color color,
    VoidCallback? onCopy,
    String copyTooltip = '',
    String sectionLabel = '',
  }) {
    final tags = PromptTagUtils.parseForDisplay(prompt);
    return _buildTagCollection(
      [
        GalleryDetailTagGroup(
          label: label,
          tags: tags,
          color: color,
          onCopy: sectionLabel.isEmpty ? onCopy : null,
          copyTooltip: copyTooltip,
        ),
      ],
      sectionLabel: sectionLabel,
      onCopySection: sectionLabel.isEmpty ? null : onCopy,
      sectionCopyTooltip: copyTooltip,
    );
  }

  Widget _buildCharacterTagSection(
    GalleryCharacterPrompt character,
    int index,
  ) {
    final groups = <GalleryDetailTagGroup>[];
    final positive = PromptTagUtils.parseForDisplay(character.prompt);
    final negative = PromptTagUtils.parseForDisplay(character.negativePrompt);
    if (positive.isNotEmpty) {
      groups.add(
        GalleryDetailTagGroup(
          label: widget.labels.positivePrompt,
          tags: positive,
          color: TagColors.general,
        ),
      );
    }
    if (negative.isNotEmpty) {
      groups.add(
        GalleryDetailTagGroup(
          label: widget.labels.negativePrompt,
          tags: negative,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
    final sectionLabel = character.label.trim().isEmpty
        ? '#${index + 1}'
        : character.label.trim();
    return _buildTagCollection(
      groups,
      sectionLabel: sectionLabel,
      onCopySection: groups.isEmpty
          ? null
          : () => widget.onCopyCharacter(character),
      sectionCopyTooltip: widget.labels.copyCharacter,
    );
  }

  Widget _buildTagCollection(
    List<GalleryDetailTagGroup> groups, {
    String sectionLabel = '',
    VoidCallback? onCopySection,
    String sectionCopyTooltip = '',
  }) {
    final outputFilter = ref.watch(onlineGalleryOutputFilterProvider);
    return GalleryDetailTagSection(
      groups: groups,
      sectionLabel: sectionLabel,
      onCopySection: onCopySection,
      sectionCopyTooltip: sectionCopyTooltip,
      isOutputFiltered: outputFilter.contains,
      normalTooltip: widget.labels.tagContextMenuTooltip,
      filteredTooltip: widget.labels.outputFilteredTagTooltip,
      onTagTap: _searchTag,
      onTagSecondaryTapDown: _showTagMenu,
    );
  }

  void _searchTag(String tag) {
    final query = OnlineGalleryOutputFilterSettings.normalizeTag(tag) ?? tag;
    Navigator.of(context).pop();
    widget.onTagSearch(query);
  }

  Future<void> _showTagMenu(String tag, TapDownDetails details) async {
    final action = await showOnlineGalleryTagContextMenu(
      context: context,
      ref: ref,
      tag: tag,
      globalPosition: details.globalPosition,
      onSearch: _searchTag,
    );
    if (!mounted || action != OnlineGalleryTagContextAction.blacklist) return;
    Navigator.of(context).pop();
    widget.onBlacklistChanged();
  }

  Widget _buildCodexOverview(
    ThemeData theme, {
    required String codexTitle,
    required List<String> categoryPath,
    required String fileLabel,
    required String fileName,
    required String author,
    required String declaredSource,
    required String note,
  }) {
    final item = widget.detail.item;
    final rating = item.rating?.trim().toUpperCase() ?? '';
    final characterPrompts = _displayCharacterPrompts;
    final content = <Widget>[];
    void addContent(Widget child) {
      if (content.isNotEmpty) content.add(const SizedBox(height: 12));
      content.add(child);
    }

    final positivePrompt = widget.detail.prompt?.trim().isNotEmpty == true
        ? widget.detail.prompt!.trim()
        : item.tagString.trim().isNotEmpty
        ? item.tagString.trim()
        : item.tags.join(', ');
    if (positivePrompt.isNotEmpty) {
      addContent(
        _buildPromptTagSection(
          label: widget.labels.positivePrompt,
          prompt: positivePrompt,
          color: TagColors.general,
          onCopy: widget.onCopyPrompt,
          copyTooltip: widget.labels.copyPositive,
        ),
      );
    }
    if (_hasNegativePrompt) {
      addContent(
        _buildPromptTagSection(
          label: widget.labels.negativePrompt,
          prompt: widget.detail.negativePrompt!.trim(),
          color: theme.colorScheme.error,
          onCopy: widget.onCopyNegativePrompt,
          copyTooltip: widget.labels.copyNegative,
        ),
      );
    }
    if (characterPrompts.isNotEmpty) {
      addContent(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.labels.characterPrompts,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < characterPrompts.length; index++) ...[
              _buildCharacterTagSection(characterPrompts[index], index),
              if (index + 1 < characterPrompts.length)
                const SizedBox(height: 12),
            ],
          ],
        ),
      );
    }
    if (note.isNotEmpty) {
      addContent(
        GalleryDetailTextSection(
          title: widget.labels.note,
          content: note,
          accentColor: theme.colorScheme.tertiary,
        ),
      );
    }
    if (_currentRawTags.isNotEmpty) {
      addContent(
        GalleryDetailTextSection(
          title: widget.labels.rawTags,
          content: _currentRawTags.join('\n'),
          accentColor: theme.colorScheme.secondary,
          monospace: true,
        ),
      );
    }

    return GalleryDetailOverviewCard(
      icon: Icons.auto_stories_rounded,
      title: codexTitle.isEmpty ? widget.labels.codex : codexTitle,
      subtitle: categoryPath.join(' / '),
      badge: rating.isEmpty
          ? null
          : GalleryDetailOverviewBadgeData(
              icon: Icons.shield_rounded,
              label: rating,
              tooltip: widget.labels.rating,
            ),
      content: content.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
      metadata: [
        if (fileName.isNotEmpty)
          GalleryDetailOverviewMetadata(
            icon: Icons.image_rounded,
            label: fileLabel,
            value: fileName,
          ),
        if (author.isNotEmpty)
          GalleryDetailOverviewMetadata(
            icon: Icons.person_rounded,
            label: widget.labels.author,
            value: author,
          ),
        if (declaredSource.isNotEmpty)
          GalleryDetailOverviewMetadata(
            icon: Icons.dataset_rounded,
            label: widget.labels.declaredSource,
            value: declaredSource,
          ),
        for (final contributor in widget.detail.contributors)
          GalleryDetailOverviewMetadata(
            icon: Icons.person_rounded,
            value: contributor.role.trim().isEmpty
                ? contributor.name
                : '${contributor.name} · ${contributor.role.trim()}',
          ),
      ],
    );
  }

  Widget _buildCodexContext({
    required String codexTitle,
    required List<String> categoryPath,
  }) {
    final hasTitle = codexTitle.isNotEmpty;
    return GalleryDetailOverviewCard(
      icon: Icons.menu_book_rounded,
      title: hasTitle ? codexTitle : categoryPath.last,
      subtitle: hasTitle ? categoryPath.join(' / ') : '',
    );
  }

  Widget _buildCompactMetadata(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label  ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContributors(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups_rounded,
                  size: 17,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  widget.labels.contributors,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            for (
              var index = 0;
              index < widget.detail.contributors.length;
              index++
            ) ...[
              _buildContributor(theme, widget.detail.contributors[index]),
              if (index + 1 < widget.detail.contributors.length)
                const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContributor(ThemeData theme, GalleryContributor contributor) {
    final role = contributor.role.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.person_rounded,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            role.isEmpty ? contributor.name : '${contributor.name} · $role',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea(ThemeData theme) {
    final media = _currentMedia;
    final canDownload =
        media != null && _hasOriginal(media) && _downloadUrl(media).isNotEmpty;
    final canReverse = media != null && widget.onSendToReverse != null;
    final canDownloadAll = widget.onDownloadAll != null && _media.length > 1;
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
              onPressed: _hasCopyableContent ? widget.onSendToGenerate : null,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: label(widget.labels.sendToGenerate),
            ),
            OutlinedButton.icon(
              style: actionStyle,
              onPressed: _hasCopyableContent && !_queueActionPending
                  ? _addToQueue
                  : null,
              icon: _queueActionPending
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add, size: 18),
              label: label(widget.labels.addToQueue),
            ),
          ),
          const SizedBox(height: 8),
          row(
            _buildCopyActionsButton(media, actionStyle),
            OutlinedButton.icon(
              style: actionStyle,
              onPressed: canDownload && !_downloadActionPending
                  ? _downloadCurrent
                  : null,
              icon: _downloadActionPending
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 18),
              label: label(widget.labels.downloadOriginal),
            ),
          ),
          if (canReverse || canDownloadAll) ...[
            const SizedBox(height: 8),
            row(
              canReverse
                  ? OutlinedButton.icon(
                      style: actionStyle,
                      onPressed: () => widget.onSendToReverse!(media),
                      icon: const Icon(Icons.manage_search, size: 18),
                      label: label(widget.labels.sendToReverse),
                    )
                  : const SizedBox.shrink(),
              canDownloadAll
                  ? OutlinedButton.icon(
                      style: actionStyle,
                      onPressed: _downloadActionPending ? null : _downloadAll,
                      icon: const Icon(Icons.download_for_offline, size: 18),
                      label: label(widget.labels.downloadAll),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCopyActionsButton(GalleryMedia? media, ButtonStyle style) {
    final hasArtistChain =
        media != null && widget.hasArtistChain?.call(media) == true;
    final hasCopyActions =
        _hasPrompt ||
        _hasNegativePrompt ||
        (widget.onCopyFullPrompt == null && _hasCopyableContent) ||
        (media != null &&
            (widget.onCopyMetadata != null ||
                widget.onCopyArtistChain != null ||
                widget.onCopyFullPrompt != null ||
                widget.onCopyRawArtistFragments != null));

    return MenuAnchor(
      menuChildren: [
        if (media != null && widget.onCopyArtistChain != null)
          MenuItemButton(
            onPressed: hasArtistChain
                ? () => widget.onCopyArtistChain!(media)
                : null,
            leadingIcon: const Icon(Icons.brush_outlined, size: 18),
            child: Text(
              hasArtistChain
                  ? widget.labels.copyArtistChain
                  : widget.labels.noArtistChain,
            ),
          ),
        if (media != null && widget.onCopyFullPrompt != null)
          MenuItemButton(
            onPressed: () => widget.onCopyFullPrompt!(media),
            leadingIcon: const Icon(Icons.copy_all, size: 18),
            child: Text(widget.labels.copyFullPrompt),
          ),
        if (media != null && widget.onCopyRawArtistFragments != null)
          MenuItemButton(
            onPressed: hasArtistChain
                ? () => widget.onCopyRawArtistFragments!(media)
                : null,
            leadingIcon: const Icon(Icons.code, size: 18),
            child: Text(widget.labels.copyRawArtistFragments),
          ),
        if (widget.onCopyFullPrompt == null && _hasCopyableContent)
          MenuItemButton(
            onPressed: widget.onCopyAll,
            leadingIcon: const Icon(Icons.copy_all_outlined, size: 18),
            child: Text(widget.labels.copyAll),
          ),
        if (media != null && widget.onCopyMetadata != null)
          MenuItemButton(
            onPressed: () => widget.onCopyMetadata!(media),
            leadingIcon: const Icon(Icons.data_object, size: 18),
            child: Text(widget.labels.copyMetadata),
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
                widget.labels.copyActions,
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

  String _metadataString(String key) =>
      widget.detail.rawSourceMetadata[key]?.toString().trim() ?? '';

  String _displayUrl(GalleryMedia media) {
    if (media.displayUrl.isNotEmpty) return media.displayUrl;
    if (media.previewUrl.isNotEmpty) return media.previewUrl;
    return media.downloadUrl;
  }

  String _previewUrl(GalleryMedia media) {
    if (media.previewUrl.isNotEmpty) return media.previewUrl;
    return _displayUrl(media);
  }

  bool _hasOriginal(GalleryMedia media) {
    final value = media.metadata['hasOriginal'];
    if (value is bool) return value;
    return media.downloadUrl.isNotEmpty;
  }

  String _downloadUrl(GalleryMedia media) {
    if (media.downloadUrl.isNotEmpty) return media.downloadUrl;
    return _displayUrl(media);
  }

  void _moveTo(int index) {
    if (index < 0 || index >= _media.length || !_pageController.hasClients) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
    );
  }

  void _prefetchAdjacent(int index) {
    for (final targetIndex in [index - 1, index + 1]) {
      if (targetIndex < 0 || targetIndex >= _media.length) continue;
      final media = _media[targetIndex];
      final url = _displayUrl(media);
      if (url.isEmpty) continue;
      final request = GalleryImageRequest.forUrl(
        sourceId: widget.item.sourceId,
        url: url,
        tier: GalleryImageTier.sample,
        targetDecodeWidth: GalleryImageSizing.detailViewportTargetWidth(
          MediaQuery.devicePixelRatioOf(context),
          MediaQuery.sizeOf(context).width,
        ),
      );
      precacheImage(
        request.createImageProvider(OnlineGalleryImageCacheManager.instance),
        context,
      );
    }
  }

  Future<void> _retryImage(GalleryMedia media) async {
    final urls = <String>{media.previewUrl, media.displayUrl, media.downloadUrl}
      ..removeWhere((url) => url.isEmpty);
    for (final url in urls) {
      await CachedNetworkImage.evictFromCache(
        url,
        cacheManager: OnlineGalleryImageCacheManager.instance,
        cacheKey: onlineGalleryImageCacheKeyForUrl(url),
      );
    }
    if (mounted) setState(() => _imageRevision++);
  }

  Future<void> _toggleFavorite() async {
    setState(() => _favoriteActionPending = true);
    try {
      final changed = await widget.onToggleFavorite();
      if (changed && mounted) setState(() => _isFavorited = !_isFavorited);
    } finally {
      if (mounted) setState(() => _favoriteActionPending = false);
    }
  }

  Future<void> _addToQueue() async {
    setState(() => _queueActionPending = true);
    try {
      await widget.onAddToQueue();
    } finally {
      if (mounted) setState(() => _queueActionPending = false);
    }
  }

  Future<void> _downloadCurrent() async {
    final media = _currentMedia;
    if (media == null) return;
    setState(() => _downloadActionPending = true);
    try {
      await widget.onDownloadCurrentOriginal(media);
    } finally {
      if (mounted) setState(() => _downloadActionPending = false);
    }
  }

  Future<void> _downloadAll() async {
    final callback = widget.onDownloadAll;
    if (callback == null || _media.isEmpty) return;
    setState(() => _downloadActionPending = true);
    try {
      await callback(_media);
    } finally {
      if (mounted) setState(() => _downloadActionPending = false);
    }
  }
}
