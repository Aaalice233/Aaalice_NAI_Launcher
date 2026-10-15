import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../data/models/online_gallery/gallery_item.dart';
import '../../providers/online_gallery_state.dart';

typedef GalleryDownloadDetailLoader =
    Future<GalleryDetail> Function(GalleryItem item);

class GalleryDownloadJob {
  const GalleryDownloadJob({
    required this.post,
    required this.media,
    required this.mediaIndex,
  });

  final GalleryItem post;
  final GalleryMedia media;
  final int mediaIndex;
}

class GalleryDownloadPlan {
  const GalleryDownloadPlan({
    required this.jobs,
    required this.skippedCount,
    required this.unresolvedCount,
  });

  final List<GalleryDownloadJob> jobs;
  final int skippedCount;
  final int unresolvedCount;
}

/// 占位封面的条目在下载时经详情取得真实媒体。
bool canDownloadGalleryItem(GalleryItem item) =>
    item.hasValidPreview || item.hasPendingCover;

/// AI TAG 普通卡按作品下载全部媒体；媒体焦点卡只下载目标图片。
Future<GalleryDownloadPlan> planGalleryDownloads(
  List<GalleryItem> posts, {
  required GalleryDownloadDetailLoader loadDetail,
  required int concurrency,
}) async {
  final jobs = <GalleryDownloadJob>[];
  var unresolvedCount = 0;
  for (var start = 0; start < posts.length; start += concurrency) {
    final batch = posts.sublist(start, min(start + concurrency, posts.length));
    final resolved = await Future.wait(
      batch.map((post) => _jobsFor(post, loadDetail)),
    );
    for (final postJobs in resolved) {
      if (postJobs == null) {
        unresolvedCount++;
      } else {
        jobs.addAll(postJobs);
      }
    }
  }
  return GalleryDownloadPlan(
    jobs: List.unmodifiable(jobs),
    skippedCount: posts.where((post) => !canDownloadGalleryItem(post)).length,
    unresolvedCount: unresolvedCount,
  );
}

/// null 表示需要详情但详情失败或没有媒体，计入失败而非跳过。
Future<List<GalleryDownloadJob>?> _jobsFor(
  GalleryItem post,
  GalleryDownloadDetailLoader loadDetail,
) async {
  if (!canDownloadGalleryItem(post)) return const [];
  if (!post.hasPendingCover) {
    if (!post.sourceId.capabilities.supportsMultipleMedia ||
        post.mediaCount <= 1) {
      return [GalleryDownloadJob(post: post, media: post.cover, mediaIndex: 1)];
    }
    if (post.focusedMediaId != null) {
      return [
        GalleryDownloadJob(
          post: post,
          media: post.cover,
          mediaIndex: (post.focusedMediaIndex ?? 0) + 1,
        ),
      ];
    }
  }
  try {
    final detail = await loadDetail(post);
    if (detail.media.isEmpty) return null;
    return [
      for (var index = 0; index < detail.media.length; index++)
        GalleryDownloadJob(
          post: detail.item,
          media: detail.media[index],
          mediaIndex: index + 1,
        ),
    ];
  } catch (error) {
    debugPrint('Failed to resolve gallery work ${post.sourceWorkId}: $error');
    return null;
  }
}
