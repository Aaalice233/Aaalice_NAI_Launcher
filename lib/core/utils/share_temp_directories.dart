import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';

/// Temporary folders holding images prepared for copy, share and drag-out.
class ShareTempDirectories {
  ShareTempDirectories._();

  static const share = 'nai_launcher_share';
  static const shareCache = 'nai_launcher_share_cache';
  static const dragExport = 'nai_launcher_drag_export';
  static const all = [share, shareCache, dragExport];

  static final Set<String> _resolvedRoots = {};

  static Future<Directory> resolve(String name) async {
    final directory = Directory(
      p.join((await getTemporaryDirectory()).path, name),
    );
    _resolvedRoots.add(p.normalize(directory.absolute.path));
    return directory;
  }

  /// Files the launcher exported itself disappear on exit or the next launch,
  /// so they must never be recorded as where an image came from.
  static bool isTransient(String path) {
    final normalized = p.normalize(File(path).absolute.path);
    return _resolvedRoots.any((root) => p.isWithin(root, normalized));
  }

  /// Removes what earlier runs left behind after a crash or forced exit.
  ///
  /// Only entries last modified before [launchedAt] are touched, so files this
  /// run has already written survive a sweep that starts late.
  static Future<int> sweepPreviousRuns(
    DateTime launchedAt, {
    Directory? root,
  }) async {
    final base = root ?? await getTemporaryDirectory();
    var removed = 0;
    for (final name in all) {
      final directory = Directory(p.join(base.path, name));
      if (!await directory.exists()) continue;
      await for (final entry in directory.list(followLinks: false)) {
        try {
          final stat = await entry.stat();
          if (!stat.modified.isBefore(launchedAt)) continue;
          await entry.delete(recursive: true);
          removed++;
        } on FileSystemException catch (error) {
          // A receiver may still hold the file open; the next launch retries.
          AppLogger.w(
            'Could not remove stale share file ${entry.path}: $error',
            'ShareTemp',
          );
        }
      }
    }
    return removed;
  }
}
