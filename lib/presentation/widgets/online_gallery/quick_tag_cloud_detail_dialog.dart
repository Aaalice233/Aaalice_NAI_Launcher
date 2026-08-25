import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../../data/models/online_gallery/gallery_source.dart';

/// All user-facing copy used by [QuickTagCloudDetailDialog].
///
/// Keeping these values outside the widget lets the caller connect generated
/// localizations without making this reusable presentation component depend on
/// a provider or localization extension.
class QuickTagCloudDetailDialogLabels {
  const QuickTagCloudDetailDialogLabels({
    required this.sourceName,
    required this.untitled,
    required this.codex,
    required this.category,
    required this.positivePrompt,
    required this.negativePrompt,
    required this.characterPrompts,
    required this.note,
    required this.rawTags,
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
}

/// A provider- and router-independent detail dialog for QuickTagCloud entries.
///
/// State-changing operations are deliberately exposed as callbacks. The caller
/// owns clipboard feedback, favorites, navigation, queue mutations, downloads,
/// and any related error reporting.
class QuickTagCloudDetailDialog extends StatefulWidget {
  const QuickTagCloudDetailDialog({
    super.key,
    required this.item,
    required this.detail,
    required this.isFavorited,
    required this.favoriteLoading,
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
  });

  final GalleryItem item;
  final GalleryDetail detail;
  final bool isFavorited;
  final bool favoriteLoading;
  final QuickTagCloudDetailDialogLabels labels;

  final VoidCallback onCopyPrompt;
  final VoidCallback onCopyNegativePrompt;
  final void Function(GalleryCharacterPrompt character) onCopyCharacter;
  final VoidCallback onCopyAll;
  final Future<bool> Function() onToggleFavorite;
  final VoidCallback onOpenSource;
  final VoidCallback onSendToGenerate;
  final Future<void> Function() onAddToQueue;
  final Future<void> Function(GalleryMedia media) onDownloadCurrentOriginal;

  @override
  State<QuickTagCloudDetailDialog> createState() =>
      _QuickTagCloudDetailDialogState();
}

class _QuickTagCloudDetailDialogState extends State<QuickTagCloudDetailDialog> {
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

  bool get _hasCopyableContent =>
      _hasPrompt ||
      _hasNegativePrompt ||
      widget.detail.characterPrompts.any(
        (character) =>
            character.prompt.trim().isNotEmpty ||
            character.negativePrompt.trim().isNotEmpty,
      );

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
  void didUpdateWidget(covariant QuickTagCloudDetailDialog oldWidget) {
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
    ];

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
                  title?.isNotEmpty == true ? title! : widget.labels.untitled,
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
      onPressed: loading ? null : _toggleFavorite,
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

  bool get _hasSourceUrl => widget.detail.sourceUrl?.trim().isNotEmpty == true;

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
    final codexTitle = _metadataString('codexTitle');
    final attributions = <String>[];
    for (final value in [
      _currentMedia?.metadata['credit']?.toString(),
      _currentMedia?.metadata['author']?.toString(),
      widget.item.author,
    ]) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty && !attributions.contains(normalized)) {
        attributions.add(normalized);
      }
    }
    final author = attributions.join(' · ');
    final currentMedia = _currentMedia;
    final imageFile = currentMedia?.metadata['path']?.toString().trim() ?? '';
    final originalFile = currentMedia != null && _hasOriginal(currentMedia)
        ? currentMedia.metadata['original']?.toString().trim() ?? ''
        : '';
    final declaredSource = _metadataString('declaredSource');
    final note = widget.detail.note?.trim().isNotEmpty == true
        ? widget.detail.note!.trim()
        : widget.detail.description?.trim() ?? '';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            children: [
              if (codexTitle.isNotEmpty)
                _buildCompactMetadata(
                  theme,
                  icon: Icons.menu_book_outlined,
                  label: widget.labels.codex,
                  value: codexTitle,
                ),
              if (widget.detail.categoryPath.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildCategoryPath(theme),
              ],
              if (_hasPrompt) ...[
                const SizedBox(height: 16),
                _DetailTextSection(
                  title: widget.labels.positivePrompt,
                  content: widget.detail.prompt!.trim(),
                  accentColor: theme.colorScheme.primary,
                ),
              ],
              if (_hasNegativePrompt) ...[
                const SizedBox(height: 12),
                _DetailTextSection(
                  title: widget.labels.negativePrompt,
                  content: widget.detail.negativePrompt!.trim(),
                  accentColor: theme.colorScheme.error,
                ),
              ],
              if (widget.detail.characterPrompts.isNotEmpty) ...[
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
                  index < widget.detail.characterPrompts.length;
                  index++
                ) ...[
                  _buildCharacterPrompt(
                    theme,
                    widget.detail.characterPrompts[index],
                    index,
                  ),
                  if (index + 1 < widget.detail.characterPrompts.length)
                    const SizedBox(height: 8),
                ],
              ],
              if (note.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailTextSection(
                  title: widget.labels.note,
                  content: note,
                  accentColor: theme.colorScheme.tertiary,
                ),
              ],
              if (_currentRawTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailTextSection(
                  title: widget.labels.rawTags,
                  content: _currentRawTags.join('\n'),
                  accentColor: theme.colorScheme.secondary,
                  monospace: true,
                ),
              ],
              if (imageFile.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.image_outlined,
                  label: widget.labels.imageFile,
                  value: imageFile,
                ),
              ],
              if (originalFile.isNotEmpty && originalFile != imageFile) ...[
                const SizedBox(height: 12),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.high_quality_outlined,
                  label: widget.labels.originalFile,
                  value: originalFile,
                ),
              ],
              if (author.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.person_outline,
                  label: widget.labels.author,
                  value: author,
                ),
              ],
              if (declaredSource.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.dataset_outlined,
                  label: widget.labels.declaredSource,
                  value: declaredSource,
                ),
              ],
              if (widget.detail.contributors.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildContributors(theme),
              ],
              if (!_hasCopyableContent &&
                  note.isEmpty &&
                  _currentRawTags.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    widget.labels.emptyValue,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
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

  Widget _buildCompactMetadata(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPath(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              widget.labels.category,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SelectableText(
          widget.detail.categoryPath.join(' / '),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterPrompt(
    ThemeData theme,
    GalleryCharacterPrompt character,
    int index,
  ) {
    final label = character.label.trim().isEmpty
        ? '#${index + 1}'
        : character.label.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: widget.labels.copyCharacter,
                onPressed:
                    character.prompt.trim().isEmpty &&
                        character.negativePrompt.trim().isEmpty
                    ? null
                    : () => widget.onCopyCharacter(character),
                icon: const Icon(Icons.content_copy, size: 16),
              ),
            ],
          ),
          if (character.prompt.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.labels.positivePrompt,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            SelectableText(character.prompt.trim()),
          ],
          if (character.negativePrompt.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.labels.negativePrompt,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            SelectableText(character.negativePrompt.trim()),
          ],
        ],
      ),
    );
  }

  Widget _buildContributors(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.groups_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              widget.labels.contributors,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final contributor in widget.detail.contributors)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.person_outline, size: 16),
                label: Text(
                  contributor.role.trim().isEmpty
                      ? contributor.name
                      : '${contributor.name} · ${contributor.role}',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionArea(ThemeData theme) {
    final media = _currentMedia;
    final canDownload =
        media != null && _hasOriginal(media) && _downloadUrl(media).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _hasPrompt ? widget.onCopyPrompt : null,
                icon: const Icon(Icons.content_copy, size: 17),
                label: Text(widget.labels.copyPositive),
              ),
              OutlinedButton.icon(
                onPressed: _hasNegativePrompt
                    ? widget.onCopyNegativePrompt
                    : null,
                icon: const Icon(Icons.copy_all_outlined, size: 17),
                label: Text(widget.labels.copyNegative),
              ),
              OutlinedButton.icon(
                onPressed: _hasCopyableContent ? widget.onCopyAll : null,
                icon: const Icon(Icons.data_object, size: 17),
                label: Text(widget.labels.copyAll),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _hasCopyableContent ? widget.onSendToGenerate : null,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(widget.labels.sendToGenerate),
              ),
              OutlinedButton.icon(
                onPressed: _hasCopyableContent && !_queueActionPending
                    ? _addToQueue
                    : null,
                icon: _queueActionPending
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add, size: 18),
                label: Text(widget.labels.addToQueue),
              ),
              OutlinedButton.icon(
                onPressed: canDownload && !_downloadActionPending
                    ? _downloadCurrent
                    : null,
                icon: _downloadActionPending
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(widget.labels.downloadOriginal),
              ),
            ],
          ),
        ],
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
        sourceId: GallerySourceId.quickTagCloud,
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
}

class _DetailTextSection extends StatelessWidget {
  const _DetailTextSection({
    required this.title,
    required this.content,
    required this.accentColor,
    this.monospace = false,
  });

  final String title;
  final String content;
  final Color accentColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: ColoredBox(
              color: accentColor,
              child: const SizedBox(width: 3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                SelectableText(
                  content,
                  style: monospace
                      ? theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        )
                      : theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
