import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../router/app_router.dart';
import '../../../core/utils/file_picker_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../../data/models/online_gallery/gallery_source.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/services/online_gallery/artist_chain_parser.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/pending_prompt_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../common/app_toast.dart';

Future<void> showAiTagDetailDialog(
  BuildContext context, {
  required GalleryItem item,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _AiTagDetailDialog(item: item),
  );
}

class _AiTagDetailDialog extends ConsumerStatefulWidget {
  const _AiTagDetailDialog({required this.item});

  final GalleryItem item;

  @override
  ConsumerState<_AiTagDetailDialog> createState() => _AiTagDetailDialogState();
}

class _AiTagDetailDialogState extends ConsumerState<_AiTagDetailDialog> {
  late Future<GalleryDetail> _detailFuture;
  late final PageController _pageController;
  final FocusNode _keyboardFocus = FocusNode();
  int _mediaIndex = 0;
  int _downloadCompleted = 0;
  int _downloadTotal = 0;
  bool _didPrefetchInitialAdjacent = false;
  bool _didResolveInitialMedia = false;

  @override
  void initState() {
    super.initState();
    _mediaIndex = widget.item.focusedMediaIndex ?? 0;
    _pageController = PageController(initialPage: _mediaIndex);
    _detailFuture = ref
        .read(onlineGalleryNotifierProvider.notifier)
        .loadDetail(widget.item);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _detailFuture = ref
          .read(onlineGalleryNotifierProvider.notifier)
          .loadDetail(widget.item, forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240, maxHeight: 820),
        child: FutureBuilder<GalleryDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                width: 560,
                height: 420,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return SizedBox(
                width: 560,
                height: 420,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text(_detailErrorMessage(snapshot.error)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.common_retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            return _buildDetail(snapshot.data!);
          },
        ),
      ),
    );
  }

  String _detailErrorMessage(Object? error) {
    if (error is GallerySourceException) {
      return switch (error.code) {
        GallerySourceErrorCode.detailNotFound =>
          context.l10n.onlineGallery_detailNotFound,
        GallerySourceErrorCode.configurationUnavailable =>
          context.l10n.onlineGallery_sourceConfigUnavailable,
        GallerySourceErrorCode.rateLimited =>
          context.l10n.onlineGallery_sourceRateLimited,
        GallerySourceErrorCode.timeout =>
          context.l10n.onlineGallery_sourceTimeout,
        GallerySourceErrorCode.network =>
          context.l10n.onlineGallery_sourceNetworkError,
        GallerySourceErrorCode.malformedResponse =>
          context.l10n.onlineGallery_sourceMalformedResponse,
        _ => context.l10n.onlineGallery_imageUnavailable,
      };
    }
    return context.l10n.onlineGallery_imageUnavailable;
  }

  Widget _buildDetail(GalleryDetail detail) {
    if (!_didResolveInitialMedia) {
      _didResolveInitialMedia = true;
      final focusedMediaId = widget.item.focusedMediaId;
      final resolvedIndex = focusedMediaId == null
          ? _mediaIndex.clamp(0, detail.media.length - 1)
          : detail.media.indexWhere((media) => media.id == focusedMediaId);
      final targetIndex = resolvedIndex < 0 ? 0 : resolvedIndex;
      if (targetIndex != _mediaIndex) {
        _mediaIndex = targetIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(targetIndex);
          }
        });
      }
    }
    if (!_didPrefetchInitialAdjacent) {
      _didPrefetchInitialAdjacent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prefetchAdjacent(detail, _mediaIndex);
      });
    }
    final theme = Theme.of(context);
    final media = detail.media[_mediaIndex.clamp(0, detail.media.length - 1)];
    return KeyboardListener(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _moveTo(detail, _mediaIndex - 1);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _moveTo(detail, _mediaIndex + 1);
        }
      },
      child: Column(
        children: [
          _buildHeader(theme, detail),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 860;
                if (compact) {
                  return ListView(
                    children: [
                      SizedBox(
                        height: constraints.maxHeight * 0.58,
                        child: _buildViewer(detail),
                      ),
                      _buildInfoPanel(theme, detail, media),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 7, child: _buildViewer(detail)),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 370,
                      child: _buildInfoPanel(theme, detail, media),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, GalleryDetail detail) {
    final item = detail.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'AI TAG',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title?.isNotEmpty == true
                      ? item.title!
                      : 'Work #${item.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.author?.isNotEmpty == true)
                  Text(
                    item.author!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (_downloadTotal > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('$_downloadCompleted / $_downloadTotal'),
            ),
          IconButton(
            onPressed: () => launchUrl(
              Uri.parse(item.postUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            tooltip: context.l10n.onlineGallery_open,
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }

  Widget _buildViewer(GalleryDetail detail) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: detail.media.length,
                onPageChanged: (index) {
                  setState(() => _mediaIndex = index);
                  _prefetchAdjacent(detail, index);
                },
                itemBuilder: (context, index) {
                  final media = detail.media[index];
                  return Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: InteractiveViewer(
                      minScale: 0.75,
                      maxScale: 5,
                      child: CachedNetworkImage(
                        imageUrl: media.displayUrl,
                        cacheManager: OnlineGalleryImageCacheManager.instance,
                        cacheKey: onlineGalleryImageCacheKeyForUrl(
                          media.displayUrl,
                        ),
                        memCacheWidth:
                            GalleryImageSizing.detailViewportTargetWidth(
                              MediaQuery.devicePixelRatioOf(context),
                              MediaQuery.sizeOf(context).width,
                            ),
                        httpHeaders: onlineGalleryImageHeadersForUrl(
                          media.displayUrl,
                        ),
                        fit: BoxFit.contain,
                        placeholder: (_, __) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => Center(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await CachedNetworkImage.evictFromCache(
                                media.displayUrl,
                                cacheManager:
                                    OnlineGalleryImageCacheManager.instance,
                                cacheKey: onlineGalleryImageCacheKeyForUrl(
                                  media.displayUrl,
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(context.l10n.common_retry),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_mediaIndex > 0) _navigationButton(detail, left: true),
              if (_mediaIndex + 1 < detail.media.length)
                _navigationButton(detail, left: false),
            ],
          ),
        ),
        if (detail.media.length > 1)
          SizedBox(
            height: 82,
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              scrollDirection: Axis.horizontal,
              itemCount: detail.media.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final media = detail.media[index];
                final selected = index == _mediaIndex;
                return InkWell(
                  onTap: () => _moveTo(detail, index),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 64,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: media.previewUrl,
                      cacheManager: OnlineGalleryImageCacheManager.instance,
                      cacheKey: onlineGalleryImageCacheKeyForUrl(
                        media.previewUrl,
                      ),
                      memCacheWidth: GalleryImageSizing.gridTargetWidth(
                        layoutWidth: 64,
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                      ),
                      httpHeaders: onlineGalleryImageHeadersForUrl(
                        media.previewUrl,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _navigationButton(GalleryDetail detail, {required bool left}) {
    return Positioned(
      left: left ? 12 : null,
      right: left ? null : 12,
      top: 0,
      bottom: 0,
      child: Center(
        child: IconButton.filledTonal(
          onPressed: () => _moveTo(detail, _mediaIndex + (left ? -1 : 1)),
          icon: Icon(left ? Icons.chevron_left : Icons.chevron_right),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(
    ThemeData theme,
    GalleryDetail detail,
    GalleryMedia media,
  ) {
    final item = detail.item;
    final artistChain = ArtistChainParser.parse(media.prompt);
    final artistHuntMode = widget.item.focusedMediaId != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (item.rank != null)
              Chip(
                label: Text(context.l10n.onlineGallery_rankNumber(item.rank!)),
              ),
            if (item.aiType?.isNotEmpty == true)
              Chip(label: Text(item.aiType!)),
            Chip(
              label: Text(
                context.l10n.onlineGallery_multipleImages(item.mediaCount),
              ),
            ),
            if (item.viewCount != null)
              Chip(
                label: Text(
                  '${context.l10n.onlineGallery_views} ${item.viewCount}',
                ),
              ),
            if (item.favoriteCount != null)
              Chip(
                label: Text(
                  '${context.l10n.onlineGallery_favCount} ${item.favoriteCount}',
                ),
              ),
          ],
        ),
        if (detail.description?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          SelectableText(detail.description!),
        ],
        if (item.createdAt.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(item.createdAt, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: item.tags
              .map(
                (tag) => Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        if (artistHuntMode && artistChain.isNotEmpty)
          _metadataSection(
            context.l10n.onlineGallery_artistChain,
            artistChain.formattedText,
          ),
        if (media.prompt?.isNotEmpty == true)
          _metadataSection('Prompt', media.prompt!),
        if (media.negativePrompt?.isNotEmpty == true)
          _metadataSection(
            context.l10n.prompt_negativePrompt,
            media.negativePrompt!,
          ),
        if (media.metadataError?.isNotEmpty == true) ...[
          Text(
            context.l10n.onlineGallery_metadataParseFailed,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (artistHuntMode) ...[
              FilledButton.tonalIcon(
                onPressed: artistChain.isNotEmpty
                    ? () => _copy(artistChain.formattedText)
                    : null,
                icon: const Icon(Icons.brush_outlined, size: 16),
                label: Text(
                  artistChain.isNotEmpty
                      ? context.l10n.onlineGallery_copyArtistChain
                      : context.l10n.onlineGallery_noArtistChain,
                ),
              ),
              OutlinedButton.icon(
                onPressed: media.prompt?.isNotEmpty == true
                    ? () => _copy(media.prompt!)
                    : null,
                icon: const Icon(Icons.copy_all, size: 16),
                label: Text(context.l10n.onlineGallery_copyFullPrompt),
              ),
              OutlinedButton.icon(
                onPressed: artistChain.rawFragments.isNotEmpty
                    ? () => _copy(artistChain.rawText)
                    : null,
                icon: const Icon(Icons.code, size: 16),
                label: Text(context.l10n.onlineGallery_copyRawArtistFragments),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: media.prompt?.isNotEmpty == true
                    ? () => _copy(media.prompt!)
                    : null,
                icon: const Icon(Icons.copy, size: 16),
                label: Text(context.l10n.localGallery_copyPrompt),
              ),
            OutlinedButton.icon(
              onPressed: media.negativePrompt?.isNotEmpty == true
                  ? () => _copy(media.negativePrompt!)
                  : null,
              icon: const Icon(Icons.copy_all, size: 16),
              label: Text(context.l10n.prompt_negativePrompt),
            ),
            OutlinedButton.icon(
              onPressed: () => _copy(_fullMetadata(media)),
              icon: const Icon(Icons.data_object, size: 16),
              label: Text(context.l10n.onlineGallery_copyFullMetadata),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _sendToGenerate(detail, media),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(context.l10n.onlineGallery_sendToTextToImage),
            ),
            OutlinedButton.icon(
              onPressed: () => _addToQueue(detail, media),
              icon: const Icon(Icons.playlist_add, size: 16),
              label: Text(context.l10n.onlineGallery_addToQueue),
            ),
            OutlinedButton.icon(
              onPressed: () => _sendToReverse(media),
              icon: const Icon(Icons.manage_search, size: 16),
              label: Text(context.l10n.onlineGallery_sendToReversePrompt),
            ),
            OutlinedButton.icon(
              onPressed: _downloadTotal > 0
                  ? null
                  : () => _downloadMedia(detail, [media]),
              icon: const Icon(Icons.download, size: 16),
              label: Text(context.l10n.common_download),
            ),
            OutlinedButton.icon(
              onPressed: _downloadTotal > 0
                  ? null
                  : () => _downloadMedia(detail, detail.media),
              icon: const Icon(Icons.download_for_offline, size: 16),
              label: Text(context.l10n.onlineGallery_downloadAllMedia),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metadataSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(title),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(content),
          ),
        ],
      ),
    );
  }

  void _moveTo(GalleryDetail detail, int index) {
    if (index < 0 || index >= detail.media.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _prefetchAdjacent(GalleryDetail detail, int index) {
    for (final target in [index - 1, index + 1]) {
      if (target < 0 || target >= detail.media.length) continue;
      final media = detail.media[target];
      final request = GalleryImageRequest.forUrl(
        sourceId: GallerySourceId.aiTag,
        url: media.displayUrl,
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

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppToast.success(context, context.l10n.onlineGallery_copied);
  }

  String _promptFor(GalleryDetail detail, GalleryMedia media) {
    return media.prompt ?? detail.prompt ?? detail.item.tags.join(', ');
  }

  String _fullMetadata(GalleryMedia media) {
    if (media.rawMetadata?.isNotEmpty == true) return media.rawMetadata!;
    return const JsonEncoder.withIndent('  ').convert(media.metadata);
  }

  void _sendToGenerate(GalleryDetail detail, GalleryMedia media) {
    final prompt = _promptFor(detail, media);
    if (prompt.isEmpty) {
      AppToast.info(context, context.l10n.onlineGallery_noTagInfo);
      return;
    }
    ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
    ref
        .read(pendingPromptNotifierProvider.notifier)
        .set(
          prompt: prompt,
          negativePrompt: media.negativePrompt ?? detail.negativePrompt,
        );
    Navigator.pop(context);
    context.go(AppRoutes.generation);
  }

  Future<void> _addToQueue(GalleryDetail detail, GalleryMedia media) async {
    final prompt = _promptFor(detail, media);
    if (prompt.isEmpty) return;
    final added = await ref
        .read(replicationQueueNotifierProvider.notifier)
        .add(
          ReplicationTask.create(
            prompt: prompt,
            negativePrompt: media.negativePrompt ?? detail.negativePrompt ?? '',
            thumbnailUrl: media.previewUrl,
            source: ReplicationTaskSource.online,
            width: media.width > 0 ? media.width : null,
            height: media.height > 0 ? media.height : null,
          ),
        );
    if (!mounted) return;
    if (added) {
      AppToast.success(context, context.l10n.onlineGallery_addedToQueue);
    } else {
      AppToast.warning(context, context.l10n.onlineGallery_queueFullMax);
    }
  }

  Future<void> _sendToReverse(GalleryMedia media) async {
    try {
      final file = await OnlineGalleryImageCacheManager.instance.getSingleFile(
        media.downloadUrl,
        key: onlineGalleryImageCacheKeyForUrl(media.downloadUrl),
        headers: onlineGalleryImageHeadersForUrl(media.downloadUrl),
      );
      await ref
          .read(reversePromptProvider.notifier)
          .addImage(
            await file.readAsBytes(),
            name: 'ai_tag_${widget.item.id}_${_mediaIndex + 1}',
          );
      if (!mounted) return;
      Navigator.pop(context);
      context.go(AppRoutes.generation);
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.onlineGallery_reversePromptSendFailed('$error'),
        );
      }
    }
  }

  Future<void> _downloadMedia(
    GalleryDetail detail,
    List<GalleryMedia> mediaItems,
  ) async {
    final directory = await FilePickerUtils.pickDirectoryModal(
      dialogTitle: context.l10n.onlineGallery_chooseDownloadDirectory,
    );
    if (directory == null || !mounted) return;
    setState(() {
      _downloadCompleted = 0;
      _downloadTotal = mediaItems.length;
    });
    var failures = 0;
    for (var start = 0; start < mediaItems.length; start += 3) {
      final end = (start + 3).clamp(0, mediaItems.length);
      await Future.wait(
        List.generate(end - start, (offset) async {
          final index = start + offset;
          final media = mediaItems[index];
          try {
            final sourceFile = await OnlineGalleryImageCacheManager.instance
                .getSingleFile(
                  media.downloadUrl,
                  key: onlineGalleryImageCacheKeyForUrl(media.downloadUrl),
                  headers: onlineGalleryImageHeadersForUrl(media.downloadUrl),
                );
            final pageIndex = detail.media.indexOf(media) + 1;
            final destination = path.join(
              directory,
              'ai_tag_${detail.item.id}_p${pageIndex.toString().padLeft(2, '0')}.webp',
            );
            await File(
              destination,
            ).writeAsBytes(await sourceFile.readAsBytes());
          } catch (_) {
            failures++;
          } finally {
            if (mounted) setState(() => _downloadCompleted++);
          }
        }),
      );
    }
    if (!mounted) return;
    setState(() {
      _downloadCompleted = 0;
      _downloadTotal = 0;
    });
    if (failures == 0) {
      AppToast.success(
        context,
        context.l10n.onlineGallery_downloadSelectedCompleted(
          mediaItems.length,
          0,
        ),
      );
    } else {
      AppToast.warning(
        context,
        context.l10n.onlineGallery_downloadSelectedCompleted(
          mediaItems.length - failures,
          failures,
        ),
      );
    }
  }
}
