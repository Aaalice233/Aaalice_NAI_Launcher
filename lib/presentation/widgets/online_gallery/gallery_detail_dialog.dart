import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import 'gallery_detail_controller.dart';
import 'gallery_detail_dialog_view.dart';
import 'gallery_detail_models.dart';
import 'gallery_tag_context_menu.dart';

export 'gallery_detail_models.dart' show GalleryDetailDialogLabels;

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
    this.isOutputFiltered,
    this.prefetchCoordinator,
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
  final bool Function(String tag)? isOutputFiltered;
  final OnlineGalleryPrefetchCoordinator? prefetchCoordinator;

  @override
  ConsumerState<GalleryDetailDialog> createState() =>
      _GalleryDetailDialogState();
}

class _GalleryDetailDialogState extends ConsumerState<GalleryDetailDialog> {
  late final GalleryDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GalleryDetailController(
      item: widget.item,
      detail: widget.detail,
      isFavorited: widget.isFavorited,
      prefetchCoordinator: widget.prefetchCoordinator,
    )..addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.prefetchAdjacent(context, _controller.mediaIndex);
      }
    });
  }

  @override
  void didUpdateWidget(covariant GalleryDetailDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mediaChanged =
        oldWidget.item.stableKey != widget.item.stableKey ||
        oldWidget.item.focusedMediaId != widget.item.focusedMediaId ||
        oldWidget.item.focusedMediaIndex != widget.item.focusedMediaIndex ||
        !_sameMediaIds(oldWidget.detail.media, widget.detail.media);
    _controller.update(
      item: widget.item,
      detail: widget.detail,
      isFavorited: widget.isFavorited,
    );
    if (mediaChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.syncPageAndPrefetch(context);
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool _sameMediaIds(List<GalleryMedia> previous, List<GalleryMedia> next) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      if (previous[index].id != next[index].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final outputFilter =
        widget.isOutputFiltered ??
        ref.watch(onlineGalleryOutputFilterProvider).contains;
    final viewModel = GalleryDetailViewModel(
      item: widget.item,
      detail: widget.detail,
      labels: widget.labels,
      mediaIndex: _controller.mediaIndex,
      imageRevision: _controller.imageRevision,
      isFavorited: _controller.isFavorited,
      favoriteLoading: widget.favoriteLoading,
      favoriteActionPending: _controller.favoriteActionPending,
      queueActionPending: _controller.queueActionPending,
      downloadActionPending: _controller.downloadActionPending,
      canToggleFavorite: widget.canToggleFavorite,
      isOutputFiltered: outputFilter,
    );
    final actions = GalleryDetailActions(
      close: () => Navigator.of(context).maybePop(),
      moveToMedia: (index) => _controller.moveTo(context, index),
      mediaPageChanged: (index) => _controller.onPageChanged(context, index),
      retryMedia: _controller.retryMedia,
      toggleFavorite: () => _controller.toggleFavorite(widget.onToggleFavorite),
      openSource: widget.onOpenSource,
      copyPrompt: widget.onCopyPrompt,
      copyNegativePrompt: widget.onCopyNegativePrompt,
      copyCharacter: widget.onCopyCharacter,
      copyAll: widget.onCopyAll,
      sendToGenerate: widget.onSendToGenerate,
      addToQueue: () => _controller.addToQueue(widget.onAddToQueue),
      downloadCurrentOriginal: (media) =>
          _controller.download(() => widget.onDownloadCurrentOriginal(media)),
      searchTag: _searchTag,
      showTagMenu: _showTagMenu,
      copyMetadata: widget.onCopyMetadata,
      downloadAll: widget.onDownloadAll == null
          ? null
          : (media) => _controller.download(() => widget.onDownloadAll!(media)),
      sendToReverse: widget.onSendToReverse,
      copyArtistChain: widget.onCopyArtistChain,
      copyFullPrompt: widget.onCopyFullPrompt,
      copyRawArtistFragments: widget.onCopyRawArtistFragments,
      hasArtistChain: widget.hasArtistChain,
    );
    return GalleryDetailDialogView(
      controller: _controller,
      viewModel: viewModel,
      actions: actions,
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
}
