import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/services/file_export_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/media_mime_type.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import '../../providers/online_gallery_prompt_tag_settings_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../services/gallery_prompt_projection_service.dart';
import '../../widgets/common/app_toast.dart';
import 'online_gallery_utils.dart';

class OnlineGallerySelectionActions {
  OnlineGallerySelectionActions({required this.context, required this.ref});

  final BuildContext context;
  final WidgetRef ref;

  OnlineGalleryNotifier get _galleryNotifier =>
      ref.read(onlineGalleryNotifierProvider.notifier);
  OnlineGallerySelectionNotifier get _selectionNotifier =>
      ref.read(onlineGallerySelectionNotifierProvider.notifier);

  GallerySourceId _activeSource(OnlineGalleryState state) =>
      switch (state.viewMode) {
        GalleryViewMode.search => state.sourceId,
        GalleryViewMode.popular => state.popularSourceId,
        GalleryViewMode.favorites => state.favoritesSourceId,
      };

  Future<String?> _queueThumbnailPath(GalleryMedia media) async {
    final capability = media.capability;
    if (!capability.canPrefetchPreview) return null;
    final previewUrl = capability.previewUrl;
    try {
      final file = await OnlineGalleryImageCacheManager.instance.getSingleFile(
        previewUrl,
        key: onlineGalleryImageCacheKeyForUrl(previewUrl),
        headers: onlineGalleryImageHeadersForUrl(previewUrl),
      );
      return file.path;
    } catch (error) {
      debugPrint('Failed to cache queue thumbnail $previewUrl: $error');
      return null;
    }
  }

  Future<({ReplicationTask? task, bool failed})> _buildReplicationTask(
    GalleryItem post,
    OnlineGalleryPromptTagSettings promptTagSettings,
    OnlineGalleryOutputFilterSettings outputFilter,
  ) async {
    try {
      GalleryDetail? detail;
      if (post.sourceId == GallerySourceId.aiTag ||
          post.sourceId == GallerySourceId.quickTagCloud ||
          post.focusedMediaId != null) {
        detail = await _galleryNotifier.loadDetail(post);
      }
      GalleryMedia? media;
      if (detail != null && detail.media.isNotEmpty) {
        final focusedIndex = post.focusedMediaId == null
            ? -1
            : detail.media.indexWhere(
                (candidate) => candidate.id == post.focusedMediaId,
              );
        media = focusedIndex >= 0
            ? detail.media[focusedIndex]
            : detail.media.first;
      }
      final projection = const GalleryPromptProjectionService().project(
        item: post,
        detail: detail,
        currentMedia: media,
        promptTagSettings: promptTagSettings,
        outputFilter: outputFilter,
      );
      final hasCharacterPrompt = projection.characterPrompts.any(
        (character) =>
            character.prompt.trim().isNotEmpty ||
            character.negativePrompt.trim().isNotEmpty,
      );
      if (projection.positivePrompt.isEmpty &&
          projection.negativePrompt.isEmpty &&
          !hasCharacterPrompt) {
        return (task: null, failed: true);
      }
      final thumbnailPath = await _queueThumbnailPath(media ?? post.cover);
      return (
        task: ReplicationTask.create(
          prompt: projection.positivePrompt,
          negativePrompt: projection.negativePrompt,
          applyNegativePrompt: projection.negativePrompt.isNotEmpty,
          thumbnailUrl: thumbnailPath,
          source: ReplicationTaskSource.online,
          width: media != null && media.width > 0 ? media.width : null,
          height: media != null && media.height > 0 ? media.height : null,
          characterPrompts: [
            for (final character in projection.characterPrompts)
              ReplicationCharacterPromptSnapshot(
                prompt: character.prompt,
                negativePrompt: character.negativePrompt,
                positionX: character.positionX,
                positionY: character.positionY,
              ),
          ],
        ),
        failed: false,
      );
    } catch (error) {
      debugPrint('Failed to resolve ${post.stableKey} for queue: $error');
      return (task: null, failed: true);
    }
  }

  Future<void> addSelectedToQueue() async {
    final selectionState = ref.read(onlineGallerySelectionNotifierProvider);
    final galleryState = ref.read(onlineGalleryNotifierProvider);
    final promptTagSettings = ref.read(onlineGalleryPromptTagSettingsProvider);
    final outputFilter = ref.read(onlineGalleryOutputFilterProvider);

    final selectedPosts = galleryState.posts
        .where((p) => selectionState.selectedIds.contains(p.stableKey))
        .toList();

    if (selectedPosts.isEmpty) return;

    final tasks = <ReplicationTask>[];
    var preparationFailureCount = 0;
    const concurrency = 4;
    for (var start = 0; start < selectedPosts.length; start += concurrency) {
      final batch = selectedPosts.sublist(
        start,
        min(start + concurrency, selectedPosts.length),
      );
      final resolved = await Future.wait(
        batch.map(
          (post) =>
              _buildReplicationTask(post, promptTagSettings, outputFilter),
        ),
      );
      tasks.addAll(resolved.map((result) => result.task).whereType());
      preparationFailureCount += resolved
          .where((result) => result.failed)
          .length;
    }

    if (!context.mounted) return;
    if (tasks.isEmpty) {
      AppToast.warning(
        context,
        context.l10n.onlineGallery_queueBatchCompleted(
          0,
          preparationFailureCount,
          0,
        ),
      );
      _selectionNotifier.exit();
      return;
    }

    final addedCount = await ref
        .read(replicationQueueNotifierProvider.notifier)
        .addAll(tasks);

    if (context.mounted) {
      final queueSkippedCount = tasks.length - addedCount;
      if (preparationFailureCount > 0 || queueSkippedCount > 0) {
        AppToast.warning(
          context,
          context.l10n.onlineGallery_queueBatchCompleted(
            addedCount,
            preparationFailureCount,
            queueSkippedCount,
          ),
        );
      } else {
        AppToast.success(
          context,
          context.l10n.onlineGallery_addedTasksToQueue(addedCount),
        );
      }
      _selectionNotifier.exit();
    }
  }

  /// 批量收藏
  Future<void> favoriteSelected() async {
    final selectionState = ref.read(onlineGallerySelectionNotifierProvider);
    final galleryState = ref.read(onlineGalleryNotifierProvider);
    final source = _activeSource(galleryState);
    final selectedPosts = galleryState.posts
        .where(
          (post) =>
              post.sourceId == source &&
              selectionState.selectedIds.contains(post.stableKey),
        )
        .toList();
    if (selectedPosts.isEmpty) return;

    var count = 0;
    for (final post in selectedPosts) {
      // 检查widget是否仍然挂载，避免在widget disposed后继续操作
      if (!context.mounted) return;

      if (!_galleryNotifier.isFavorited(post)) {
        final success = await _galleryNotifier.toggleFavorite(post);
        if (success) count++;
        if (success && source == GallerySourceId.danbooru) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    if (context.mounted) {
      AppToast.info(context, context.l10n.onlineGallery_favoritedImages(count));
      _selectionNotifier.exit();
    }
  }

  /// 批量下载
  Future<void> downloadSelected() async {
    final selectionState = ref.read(onlineGallerySelectionNotifierProvider);
    final galleryState = ref.read(onlineGalleryNotifierProvider);

    final selectedPosts = galleryState.posts
        .where((p) => selectionState.selectedIds.contains(p.stableKey))
        .toList();

    if (selectedPosts.isEmpty) return;

    String? result;
    try {
      result = await FileExportService.pickExportDirectory(
        dialogTitle: context.l10n.onlineGallery_chooseDownloadDirectory,
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.onlineGallery_selectDownloadDirectoryFailed('$e'),
        );
      }
      return;
    }
    if (result == null) return;

    if (context.mounted) {
      AppToast.info(
        context,
        context.l10n.onlineGallery_downloadSelectedStarted(
          selectedPosts.length,
        ),
      );
      _selectionNotifier.exit();
    }

    final (successCount, failCount, skippedCount) = await _downloadPosts(
      selectedPosts,
      result,
    );

    if (context.mounted) {
      final message = context.l10n
          .onlineGallery_downloadSelectedCompletedWithSkipped(
            successCount,
            failCount,
            skippedCount,
          );
      if (failCount > 0) {
        AppToast.warning(context, message);
      } else if (successCount > 0) {
        AppToast.success(context, message);
      } else {
        AppToast.info(context, message);
      }
    }
  }

  /// AI TAG 普通卡按作品下载全部媒体；媒体焦点卡只下载目标图片。
  Future<(int success, int fail, int skipped)> _downloadPosts(
    List<DanbooruPost> posts,
    String destinationDir,
  ) async {
    final jobs = <_GalleryDownloadJob>[];
    const concurrency = 4;
    for (var start = 0; start < posts.length; start += concurrency) {
      final batch = posts.sublist(
        start,
        min(start + concurrency, posts.length),
      );
      final resolved = await Future.wait(
        batch.map((post) async {
          if (!post.hasValidPreview) return <_GalleryDownloadJob>[];
          if (!post.sourceId.capabilities.supportsMultipleMedia ||
              post.mediaCount <= 1) {
            return [
              _GalleryDownloadJob(post: post, media: post.cover, mediaIndex: 1),
            ];
          }
          if (post.focusedMediaId != null) {
            return [
              _GalleryDownloadJob(
                post: post,
                media: post.cover,
                mediaIndex: (post.focusedMediaIndex ?? 0) + 1,
              ),
            ];
          }
          try {
            final detail = await _galleryNotifier.loadDetail(post);
            return [
              for (var index = 0; index < detail.media.length; index++)
                _GalleryDownloadJob(
                  post: detail.item,
                  media: detail.media[index],
                  mediaIndex: index + 1,
                ),
            ];
          } catch (error) {
            debugPrint(
              'Failed to resolve gallery work ${post.sourceWorkId}: $error',
            );
            return <_GalleryDownloadJob>[];
          }
        }),
      );
      jobs.addAll(resolved.expand((batchJobs) => batchJobs));
    }

    var successCount = 0;
    final skippedCount = posts.where((post) => !post.hasValidPreview).length;
    var failCount = posts
        .where(
          (post) =>
              post.hasValidPreview &&
              post.sourceId.capabilities.supportsMultipleMedia &&
              !jobs.any((job) => job.post.stableKey == post.stableKey),
        )
        .length;
    final progress = ValueNotifier<int>(0);
    BuildContext? progressPanelContext;
    Future<void>? progressPresentation;
    if (context.mounted && jobs.isNotEmpty) {
      progressPresentation = AdaptivePresenter.showPanel<void>(
        context: context,
        barrierDismissible: false,
        allowDragDismissal: false,
        showHeader: false,
        dialogWidth: 480,
        initialChildSize: 0.42,
        minChildSize: 0.32,
        maxChildSize: 0.72,
        builder: (panelContext, scrollController) {
          progressPanelContext = panelContext;
          return _GalleryDownloadProgressPanel(
            progress: progress,
            total: jobs.length,
            scrollController: scrollController,
          );
        },
      );
      await Future<void>.delayed(Duration.zero);
    }

    for (var start = 0; start < jobs.length; start += concurrency) {
      final batch = jobs.sublist(start, min(start + concurrency, jobs.length));
      await Future.wait(
        batch.map((job) async {
          try {
            final url = job.media.downloadUrl;
            if (url.isEmpty) throw StateError('Image URL is empty');
            final file = await OnlineGalleryImageCacheManager.instance
                .getSingleFile(
                  url,
                  key: onlineGalleryImageCacheKeyForUrl(url),
                  headers: onlineGalleryImageHeadersForUrl(url),
                );
            final extension = resolveGalleryDownloadExtension(job.media, url);
            final safeWorkId = job.post.sourceWorkId.replaceAll(
              RegExp(r'[^A-Za-z0-9._-]+'),
              '_',
            );
            final resolvedExtension = extension.isEmpty ? 'webp' : extension;
            await FileExportService.writeFileToDirectory(
              directory: destinationDir,
              sourcePath: file.path,
              fileName:
                  '${job.post.sourceId.key}_${safeWorkId}_p${job.mediaIndex.toString().padLeft(2, '0')}.$resolvedExtension',
              mimeType: mediaMimeTypeForExtension(resolvedExtension),
            );
            successCount++;
          } catch (error) {
            failCount++;
            debugPrint(
              'Download failed for ${job.post.stableKey} media ${job.mediaIndex}: $error',
            );
          } finally {
            progress.value++;
          }
        }),
      );
    }
    if (progressPanelContext?.mounted == true) {
      Navigator.of(progressPanelContext!).pop();
    }
    await progressPresentation;
    progress.dispose();
    return (successCount, failCount, skippedCount);
  }
}

class _GalleryDownloadProgressPanel extends StatelessWidget {
  const _GalleryDownloadProgressPanel({
    required this.progress,
    required this.total,
    required this.scrollController,
  });

  final ValueNotifier<int> progress;
  final int total;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (context, completed, _) => Semantics(
              liveRegion: true,
              value: '$completed / $total',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: completed / total),
                  const SizedBox(height: 12),
                  Text(
                    '$completed / $total',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryDownloadJob {
  const _GalleryDownloadJob({
    required this.post,
    required this.media,
    required this.mediaIndex,
  });

  final GalleryItem post;
  final GalleryMedia media;
  final int mediaIndex;
}
