import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/localization_extension.dart';
import '../../data/services/gallery/gallery_image_file_deleter.dart';
import '../providers/local_gallery_provider.dart';
import '../widgets/common/app_toast.dart';

enum GalleryImageDeleteResult {
  deleted,
  cancelled,
  failed,
  alreadyMissing;

  bool get fileIsGone => this == deleted || this == alreadyMissing;
}

Future<List<GalleryImageDeleteResult>> deleteConfirmedGalleryImages(
  WidgetRef ref,
  List<String> paths,
) async {
  final context = ref.context;
  final l10n = context.l10n;
  final gallery = ref.read(localGalleryNotifierProvider.notifier);
  final deleter = GalleryImageFileDeleter(
    ref.read(localStorageServiceProvider),
  );
  final results = <GalleryImageDeleteResult>[];
  final gone = <String>[];
  final failures = <String>[];
  final cleanupErrors = <String>[];
  for (final path in paths) {
    try {
      results.add(
        await deleter.delete(path)
            ? GalleryImageDeleteResult.deleted
            : GalleryImageDeleteResult.alreadyMissing,
      );
    } on GalleryImageCleanupException {
      results.add(GalleryImageDeleteResult.deleted);
      cleanupErrors.add(
        '${p.basename(path)}: ${l10n.localGallery_deleteRegistryCleanupFailed}',
      );
    } on FileSystemException catch (error) {
      results.add(GalleryImageDeleteResult.failed);
      final reason = error is PathAccessException
          ? l10n.localGallery_errorPermissionDenied
          : l10n.localGallery_unknownError;
      failures.add('${p.basename(path)}: $reason');
    }
    if (results.last.fileIsGone) gone.add(path);
  }
  if (gone.isNotEmpty) {
    try {
      await gallery.removeDeletedImages(gone);
    } on Exception {
      cleanupErrors.add(l10n.localGallery_deleteIndexCleanupFailed);
    } on StateError {
      cleanupErrors.add(l10n.localGallery_deleteIndexCleanupFailed);
    }
  }
  if (context.mounted) {
    _showDeletionResult(context, results, failures, cleanupErrors);
  }
  return results;
}

void _showDeletionResult(
  BuildContext context,
  List<GalleryImageDeleteResult> results,
  List<String> failures,
  List<String> cleanupErrors,
) {
  final l10n = context.l10n;
  final count = results
      .where((r) => r == GalleryImageDeleteResult.deleted)
      .length;
  final messages = [
    if (count > 0 && cleanupErrors.isEmpty)
      results.length == 1
          ? l10n.localGallery_imageDeleted
          : l10n.localGallery_deletedImages(count),
    if (results.contains(GalleryImageDeleteResult.alreadyMissing))
      l10n.localGallery_imageFileMissing,
    if (failures.isNotEmpty)
      l10n.localGallery_deleteFailed(failures.join('\n')),
    if (cleanupErrors.isNotEmpty)
      l10n.localGallery_deleteCleanupFailed(cleanupErrors.join('\n')),
  ];
  final message = messages.join('\n');
  if (failures.isNotEmpty || cleanupErrors.isNotEmpty) {
    AppToast.error(context, message);
  } else if (results.contains(GalleryImageDeleteResult.alreadyMissing)) {
    AppToast.info(context, message);
  } else {
    AppToast.success(context, message);
  }
}
