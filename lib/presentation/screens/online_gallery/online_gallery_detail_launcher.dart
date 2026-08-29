import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/services/file_export_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/media_mime_type.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../../data/models/online_gallery/gallery_prompt_projection.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/services/online_gallery/artist_chain_parser.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import '../../providers/online_gallery_prompt_tag_settings_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/pending_prompt_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../../services/gallery_prompt_projection_service.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/online_gallery/gallery_detail_dialog.dart';
import 'online_gallery_screen_controller.dart';
import 'online_gallery_utils.dart';

class OnlineGalleryDetailLauncher {
  OnlineGalleryDetailLauncher({
    required this.context,
    required this.ref,
    this.controller,
  });

  final BuildContext context;
  final WidgetRef ref;
  final OnlineGalleryScreenController? controller;
  static final Set<String> _standalonePendingDetails = <String>{};

  OnlineGalleryNotifier get _galleryNotifier =>
      ref.read(onlineGalleryNotifierProvider.notifier);

  Future<void> show(
    BuildContext context,
    GalleryItem item, {
    GalleryDetail? preloadedDetail,
  }) async {
    final pendingDetails =
        controller?.pendingGalleryDetails ?? _standalonePendingDetails;
    if (!pendingDetails.add(item.stableKey)) return;
    try {
      final detail =
          preloadedDetail ??
          await _loadGalleryDetailWithProgress(context, item);
      if (detail == null) return;
      if (item.sourceId == GallerySourceId.quickTagCloud) {
        try {
          await ref
              .read(onlineGalleryNotifierProvider.notifier)
              .recordQuickTagCloudViewed(item);
        } catch (error, stack) {
          AppLogger.e(
            'Failed to record QuickTagCloud history',
            error,
            stack,
            'OnlineGallery',
          );
        }
      }
      if (!context.mounted) return;
      final l10n = context.l10n;
      final galleryState = ref.read(onlineGalleryNotifierProvider);
      final projection = const GalleryPromptProjectionService().project(
        item: item,
        detail: detail,
        promptTagSettings: ref.read(onlineGalleryPromptTagSettingsProvider),
        outputFilter: ref.read(onlineGalleryOutputFilterProvider),
      );
      final stableKey = item.stableKey;
      final isFavorited = ref
          .read(onlineGalleryNotifierProvider.notifier)
          .isFavorited(item);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => GalleryDetailDialog(
          item: item,
          detail: detail,
          isFavorited: isFavorited,
          favoriteLoading: galleryState.favoriteLoadingPostKeys.contains(
            stableKey,
          ),
          canToggleFavorite: true,
          labels: GalleryDetailDialogLabels(
            sourceName: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_sourceQuickTagCloud
                : item.sourceId.label,
            untitled: l10n.onlineGallery_codexUntitled,
            codex: l10n.onlineGallery_codexLabel,
            category: l10n.common_category,
            positivePrompt: l10n.onlineGallery_codexPrompt,
            negativePrompt: l10n.onlineGallery_codexNegativePrompt,
            characterPrompts: l10n.onlineGallery_codexCharacterPrompts,
            note: l10n.onlineGallery_codexNote,
            rawTags: l10n.onlineGallery_tags,
            artists: l10n.onlineGallery_artists,
            characters: l10n.onlineGallery_characters,
            copyrights: l10n.onlineGallery_copyrights,
            general: l10n.onlineGallery_general,
            metadata: l10n.onlineGallery_metadata,
            tagContextMenuTooltip: l10n.onlineGallery_tagContextMenuTooltip,
            outputFilteredTagTooltip:
                l10n.onlineGallery_outputFilteredTagTooltip,
            author: l10n.onlineGallery_codexAuthor,
            imageFile: l10n.onlineGallery_codexImageFile,
            originalFile: l10n.onlineGallery_codexOriginalFile,
            declaredSource: l10n.onlineGallery_codexDeclaredSource,
            contributors: l10n.onlineGallery_codexContributors,
            noImage: l10n.onlineGallery_codexNoImage,
            noImageDescription: l10n.onlineGallery_codexNoImageDescription,
            imageLoadFailed: l10n.detail_imageLoadFailed,
            retry: l10n.common_retry,
            zoomHint: l10n.onlineGallery_pinchToZoom,
            copyActions: l10n.common_copy,
            copyPositive: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexCopyPositive
                : l10n.localGallery_copyPrompt,
            copyNegative: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexCopyNegative
                : l10n.prompt_negativePrompt,
            copyCharacter: l10n.onlineGallery_codexCopyCharacter,
            copyAll: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexCopyAll
                : l10n.onlineGallery_copyFullPrompt,
            addFavorite: l10n.common_favorite,
            removeFavorite: l10n.common_unfavorite,
            openSource: l10n.onlineGallery_codexOpenSource,
            sendToGenerate: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexSendToGeneration
                : l10n.onlineGallery_sendToTextToImage,
            addToQueue: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexAddToQueue
                : l10n.onlineGallery_addToQueue,
            downloadOriginal: item.sourceId == GallerySourceId.quickTagCloud
                ? l10n.onlineGallery_codexDownloadOriginal
                : l10n.common_download,
            previousImage: l10n.onlineGallery_previousPage,
            nextImage: l10n.onlineGallery_nextPage,
            close: l10n.common_close,
            emptyValue: l10n.common_emptyValue,
            imageCounter: (current, total) => '$current / $total',
            multipleImages: l10n.onlineGallery_multipleImages,
            views: l10n.onlineGallery_views,
            favoriteCount: l10n.onlineGallery_favCount,
            rating: l10n.onlineGallery_ratingLabel,
            score: l10n.onlineGallery_score,
            copyMetadata: l10n.onlineGallery_copyFullMetadata,
            downloadAll: l10n.onlineGallery_downloadAllMedia,
            sendToReverse: l10n.onlineGallery_sendToReversePrompt,
            copyArtistChain: l10n.onlineGallery_copyArtistChain,
            copyFullPrompt: l10n.onlineGallery_copyFullPrompt,
            copyRawArtistFragments: l10n.onlineGallery_copyRawArtistFragments,
            noArtistChain: l10n.onlineGallery_noArtistChain,
          ),
          onCopyPrompt: () => unawaited(
            _copyCodexText(
              projection.positivePrompt,
              l10n.onlineGallery_codexCopyPositive,
            ),
          ),
          onCopyNegativePrompt: () => unawaited(
            _copyCodexText(
              projection.negativePrompt,
              l10n.onlineGallery_codexCopyNegative,
            ),
          ),
          onCopyCharacter: (character) {
            final index = detail.characterPrompts.indexOf(character);
            final projected =
                index >= 0 && index < projection.characterPrompts.length
                ? projection.characterPrompts[index]
                : character;
            unawaited(
              _copyCodexText(
                _buildCharacterCodexCopyText(projected),
                l10n.onlineGallery_codexCopyCharacter,
              ),
            );
          },
          onCopyAll: () => unawaited(
            _copyCodexText(
              _buildCodexCopyText(projection),
              l10n.onlineGallery_codexCopyAll,
            ),
          ),
          onToggleFavorite: () => toggleFavorite(context, item),
          onOpenSource: () => unawaited(
            _openCodexSource(
              context,
              detail.sourceUrl?.trim().isNotEmpty == true
                  ? detail.sourceUrl
                  : item.postUrl,
            ),
          ),
          onSendToGenerate: () {
            _sendCodexDetailToGeneration(context, item, projection);
          },
          onAddToQueue: () => _addCodexDetailToQueue(context, item, projection),
          onDownloadCurrentOriginal: (media) =>
              _downloadCodexMedia(context, item, media),
          onTagSearch: (tag) {
            controller?.searchController.text = tag;
            _galleryNotifier.search(tag);
          },
          onBlacklistChanged: () => _galleryNotifier.refresh(),
          onCopyMetadata: (media) => unawaited(
            _copyCodexText(
              _galleryMediaMetadata(media),
              l10n.onlineGallery_copyFullMetadata,
            ),
          ),
          onDownloadAll: (media) =>
              _downloadGalleryMediaBatch(context, item, media),
          onSendToReverse: (media) =>
              _sendGalleryMediaToReverse(context, item, media),
          onCopyArtistChain:
              item.sourceId == GallerySourceId.aiTag &&
                  item.focusedMediaId != null
              ? (media) => unawaited(
                  _copyCodexText(
                    ArtistChainParser.parse(media.prompt).formattedText,
                    l10n.onlineGallery_copyArtistChain,
                  ),
                )
              : null,
          onCopyFullPrompt:
              item.sourceId == GallerySourceId.aiTag &&
                  item.focusedMediaId != null
              ? (media) => unawaited(
                  _copyCodexText(
                    _buildCodexCopyText(
                      const GalleryPromptProjectionService().project(
                        item: item,
                        detail: detail,
                        currentMedia: media,
                        promptTagSettings: ref.read(
                          onlineGalleryPromptTagSettingsProvider,
                        ),
                        outputFilter: ref.read(
                          onlineGalleryOutputFilterProvider,
                        ),
                      ),
                      negativeLabel:
                          l10n.onlineGallery_negativePromptCopyHeading,
                    ),
                    l10n.onlineGallery_copyFullPrompt,
                  ),
                )
              : null,
          onCopyRawArtistFragments:
              item.sourceId == GallerySourceId.aiTag &&
                  item.focusedMediaId != null
              ? (media) => unawaited(
                  _copyCodexText(
                    ArtistChainParser.parse(media.prompt).rawText,
                    l10n.onlineGallery_copyRawArtistFragments,
                  ),
                )
              : null,
          hasArtistChain:
              item.sourceId == GallerySourceId.aiTag &&
                  item.focusedMediaId != null
              ? (media) => ArtistChainParser.parse(media.prompt).isNotEmpty
              : null,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        AppToast.error(
          context,
          '${context.l10n.onlineGallery_loadFailed}: $error',
        );
      }
    } finally {
      pendingDetails.remove(item.stableKey);
    }
  }

  Future<GalleryDetail?> _loadGalleryDetailWithProgress(
    BuildContext context,
    GalleryItem item,
  ) async {
    final shown = Completer<BuildContext>();
    final cancelled = Completer<void>();
    var dismissRequested = false;
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!shown.isCompleted) shown.complete(dialogContext);
        return AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Text(context.l10n.common_loading),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!cancelled.isCompleted) cancelled.complete();
                dismissRequested = true;
                Navigator.of(dialogContext, rootNavigator: true).pop();
              },
              child: Text(context.l10n.common_cancel),
            ),
          ],
        );
      },
    );
    unawaited(
      dialogFuture.whenComplete(() {
        if (!cancelled.isCompleted) cancelled.complete();
      }),
    );

    final dialogContext = await shown.future;
    try {
      final detail = await Future.any<GalleryDetail?>([
        _galleryNotifier.loadDetail(item),
        cancelled.future.then<GalleryDetail?>((_) => null),
      ]);
      if (detail == null) _galleryNotifier.cancelDetail(item);
      return detail;
    } finally {
      if (!dismissRequested && dialogContext.mounted) {
        dismissRequested = true;
        Navigator.of(dialogContext, rootNavigator: true).pop();
      }
      await dialogFuture;
    }
  }

  String _galleryMediaMetadata(GalleryMedia media) {
    final raw = media.rawMetadata?.trim() ?? '';
    if (raw.isNotEmpty) return raw;
    return const JsonEncoder.withIndent('  ').convert(media.metadata);
  }

  Future<void> _sendGalleryMediaToReverse(
    BuildContext dialogContext,
    GalleryItem item,
    GalleryMedia media,
  ) async {
    final url = media.displayUrl.isNotEmpty
        ? media.displayUrl
        : (media.downloadUrl.isNotEmpty ? media.downloadUrl : media.previewUrl);
    if (url.isEmpty) {
      AppToast.info(dialogContext, dialogContext.l10n.onlineGallery_noImageUrl);
      return;
    }
    try {
      final file = await OnlineGalleryImageCacheManager.instance.getSingleFile(
        url,
        key: onlineGalleryImageCacheKeyForUrl(url),
        headers: onlineGalleryImageHeadersForUrl(url),
      );
      await ref
          .read(reversePromptProvider.notifier)
          .addImage(
            await file.readAsBytes(),
            name: '${item.sourceId.key}_${item.sourceWorkId}',
          );
      if (!context.mounted || !dialogContext.mounted) return;
      Navigator.of(dialogContext, rootNavigator: true).pop();
      context.go('/');
      AppToast.success(context, context.l10n.onlineGallery_sentToReversePrompt);
    } catch (error) {
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_reversePromptSendFailed('$error'),
        );
      }
    }
  }

  Future<void> _downloadGalleryMediaBatch(
    BuildContext dialogContext,
    GalleryItem item,
    List<GalleryMedia> mediaItems,
  ) async {
    final directory = await FileExportService.pickExportDirectory(
      dialogTitle: dialogContext.l10n.onlineGallery_chooseDownloadDirectory,
    );
    if (directory == null) return;
    try {
      for (final media in mediaItems) {
        final url = media.downloadUrl.isNotEmpty
            ? media.downloadUrl
            : (media.displayUrl.isNotEmpty
                  ? media.displayUrl
                  : media.previewUrl);
        if (url.isEmpty) continue;
        final file = await OnlineGalleryImageCacheManager.instance
            .getSingleFile(
              url,
              key: onlineGalleryImageCacheKeyForUrl(url),
              headers: onlineGalleryImageHeadersForUrl(url),
            );
        final safeWorkId = item.sourceWorkId.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]+'),
          '_',
        );
        final safeMediaId = media.id.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]+'),
          '_',
        );
        final extension = resolveGalleryDownloadExtension(media, url);
        await FileExportService.writeFileToDirectory(
          directory: directory,
          sourcePath: file.path,
          fileName:
              '${item.sourceId.key}_${safeWorkId}_$safeMediaId.$extension',
          mimeType: mediaMimeTypeForExtension(extension),
        );
      }
      if (dialogContext.mounted) {
        AppToast.success(
          dialogContext,
          dialogContext.l10n.onlineGallery_savedFiles(mediaItems.length),
        );
      }
    } catch (error) {
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_downloadFailed('$error'),
        );
      }
    }
  }

  Future<void> _copyCodexText(String text, String label) async {
    final value = text.trim();
    if (value.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) AppToast.success(context, '$label ✓');
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.gallery_copyFailed('$error'));
      }
    }
  }

  String _buildCharacterCodexCopyText(GalleryCharacterPrompt character) {
    final blocks = <String>[];
    final prompt = character.prompt.trim();
    final negative = character.negativePrompt.trim();
    if (prompt.isNotEmpty) blocks.add(prompt);
    if (negative.isNotEmpty) {
      blocks.add(
        '${context.l10n.onlineGallery_codexNegativePrompt}:\n$negative',
      );
    }
    return blocks.join('\n\n');
  }

  Future<void> _openCodexSource(
    BuildContext dialogContext,
    String? rawUrl,
  ) async {
    final url = rawUrl == null ? null : Uri.tryParse(rawUrl.trim());
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_codexOpenSourceFailed,
        );
      }
      return;
    }
    try {
      final opened = await launchUrl(url);
      if (!opened && dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_codexOpenSourceFailed,
        );
      }
    } catch (error, stack) {
      AppLogger.e(
        'Failed to open QuickTagCloud source',
        error,
        stack,
        'OnlineGallery',
      );
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_actionFailed('$error'),
        );
      }
    }
  }

  String _buildCodexCopyText(
    GalleryPromptProjection projection, {
    String? negativeLabel,
  }) {
    final blocks = <String>[];
    final prompt = projection.positivePrompt.trim();
    final negative = projection.negativePrompt.trim();
    if (prompt.isNotEmpty) blocks.add(prompt);
    final l10n = context.l10n;
    final resolvedNegativeLabel =
        negativeLabel ?? l10n.onlineGallery_codexNegativePrompt;
    if (negative.isNotEmpty) {
      blocks.add('$resolvedNegativeLabel:\n$negative');
    }
    for (var index = 0; index < projection.characterPrompts.length; index++) {
      final character = projection.characterPrompts[index];
      final content = <String>[
        if (character.prompt.trim().isNotEmpty) character.prompt.trim(),
        if (character.negativePrompt.trim().isNotEmpty)
          '$resolvedNegativeLabel: ${character.negativePrompt.trim()}',
      ].join('\n');
      if (content.isNotEmpty) {
        blocks.add(
          '${character.label.isEmpty ? '${l10n.onlineGallery_codexCharacterPrompts} ${index + 1}' : character.label}:\n$content',
        );
      }
    }
    return blocks.join('\n\n');
  }

  List<CharacterPrompt> _codexCharacters(
    GalleryItem item,
    GalleryPromptProjection projection,
  ) {
    return [
      for (var index = 0; index < projection.characterPrompts.length; index++)
        CharacterPrompt(
          id: 'codex-${item.stableKey}-$index',
          name: projection.characterPrompts[index].label,
          prompt: projection.characterPrompts[index].prompt,
          negativePrompt: projection.characterPrompts[index].negativePrompt,
          positionMode: CharacterPositionMode.aiChoice,
        ),
    ];
  }

  void _sendCodexDetailToGeneration(
    BuildContext dialogContext,
    GalleryItem item,
    GalleryPromptProjection projection,
  ) {
    ref
        .read(characterPromptNotifierProvider.notifier)
        .replaceAll(_codexCharacters(item, projection));
    ref
        .read(pendingPromptNotifierProvider.notifier)
        .set(
          prompt: projection.positivePrompt,
          negativePrompt: projection.negativePrompt,
        );
    Navigator.of(dialogContext, rootNavigator: true).pop();
    context.go('/');
    AppToast.info(context, context.l10n.onlineGallery_sentToTextToImage);
  }

  Future<void> _addCodexDetailToQueue(
    BuildContext dialogContext,
    GalleryItem item,
    GalleryPromptProjection projection,
  ) async {
    final prompt = projection.positivePrompt.trim();
    final negativePrompt = projection.negativePrompt.trim();
    final hasCharacterPrompt = projection.characterPrompts.any(
      (character) =>
          character.prompt.trim().isNotEmpty ||
          character.negativePrompt.trim().isNotEmpty,
    );
    if (prompt.isEmpty && negativePrompt.isEmpty && !hasCharacterPrompt) return;
    try {
      final success = await ref
          .read(replicationQueueNotifierProvider.notifier)
          .add(
            ReplicationTask.create(
              prompt: prompt,
              negativePrompt: negativePrompt,
              applyNegativePrompt: negativePrompt.isNotEmpty,
              thumbnailUrl: item.previewUrl,
              source: ReplicationTaskSource.online,
              characterPrompts: [
                for (final character in projection.characterPrompts)
                  ReplicationCharacterPromptSnapshot(
                    prompt: character.prompt,
                    negativePrompt: character.negativePrompt,
                  ),
              ],
            ),
          );
      if (!dialogContext.mounted) return;
      if (success) {
        final count = ref.read(
          replicationQueueNotifierProvider.select((state) => state.count),
        );
        AppToast.success(
          dialogContext,
          dialogContext.l10n.onlineGallery_addedToQueueWithCount(count),
        );
      } else {
        AppToast.warning(
          dialogContext,
          dialogContext.l10n.onlineGallery_queueFullMax,
        );
      }
    } catch (error, stack) {
      AppLogger.e(
        'Failed to add QuickTagCloud entry to queue',
        error,
        stack,
        'OnlineGallery',
      );
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_actionFailed('$error'),
        );
      }
    }
  }

  Future<void> _downloadCodexMedia(
    BuildContext dialogContext,
    GalleryItem item,
    GalleryMedia media,
  ) async {
    final url = media.downloadUrl;
    try {
      final file = await OnlineGalleryImageCacheManager.instance.getSingleFile(
        url,
        key: onlineGalleryImageCacheKeyForUrl(url),
        headers: onlineGalleryImageHeadersForUrl(url),
      );
      if (!dialogContext.mounted) return;
      final safeWorkId = item.sourceWorkId.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]+'),
        '_',
      );
      final extension = resolveGalleryDownloadExtension(media, url);
      final safeMediaId = media.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final savedLocation = await FileExportService.saveFileFromPath(
        sourcePath: file.path,
        fileName: '${item.sourceId.key}_${safeWorkId}_$safeMediaId.$extension',
        dialogTitle: dialogContext.l10n.onlineGallery_chooseDownloadDirectory,
        mimeType: mediaMimeTypeForExtension(extension),
        allowedExtensions: [extension],
      );
      if (savedLocation == null) return;
      if (dialogContext.mounted) {
        AppToast.success(
          dialogContext,
          dialogContext.l10n.onlineGallery_savedFiles(1),
        );
      }
    } catch (error) {
      if (dialogContext.mounted) {
        AppToast.error(
          dialogContext,
          dialogContext.l10n.onlineGallery_downloadFailed(error.toString()),
        );
      }
    }
  }

  /// 处理收藏切换
  Future<bool> toggleFavorite(BuildContext context, DanbooruPost post) async {
    final wasFavorited = _galleryNotifier.isFavorited(post);
    try {
      final success = await _galleryNotifier.toggleFavorite(post);
      if (context.mounted) {
        if (success) {
          AppToast.info(
            context,
            wasFavorited
                ? context.l10n.onlineGallery_unfavorited
                : context.l10n.onlineGallery_favorited,
          );
        } else {
          AppToast.error(
            context,
            context.l10n.onlineGallery_actionFailed(
              context.l10n.onlineGallery_sourceRequestFailed,
            ),
          );
        }
      }
      return success;
    } catch (error, stack) {
      AppLogger.e(
        'Failed to toggle online gallery favorite',
        error,
        stack,
        'OnlineGallery',
      );
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.onlineGallery_actionFailed('$error'),
        );
      }
      return false;
    }
  }
}
