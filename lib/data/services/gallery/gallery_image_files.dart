import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/file_system_error_summary.dart';

class GalleryImageFiles {
  const GalleryImageFiles({this.listDirectory = _listDirectory});

  final Stream<FileSystemEntity> Function(Directory) listDirectory;

  static Stream<FileSystemEntity> _listDirectory(Directory directory) =>
      directory.list(followLinks: false);

  static bool _hasImageExtension(String path) => const {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  }.contains(p.extension(path).toLowerCase());

  static bool isVisibleDirectory(String root, String path) =>
      p.equals(root, path) ||
      (p.isWithin(root, path) &&
          !p.split(p.relative(path, from: root)).any(_isHidden));

  static bool _isHidden(String name) => name.startsWith('.');

  static bool accepts(String root, String path) =>
      _hasImageExtension(path) && isVisibleDirectory(root, p.dirname(path));

  Stream<File> list(
    Directory root, {
    Directory? folder,
    bool recursive = true,
  }) async* {
    final start = folder ?? root;
    if (!isVisibleDirectory(root.path, start.path)) return;
    final pending = [start];
    final skippedByError = <String, int>{};
    var skippedCount = 0;
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      try {
        await for (final entry in listDirectory(current)) {
          if (entry is File && _hasImageExtension(entry.path)) {
            yield entry;
          } else if (recursive &&
              entry is Directory &&
              !_isHidden(p.basename(entry.path))) {
            pending.add(entry);
          }
        }
      } on FileSystemException catch (error) {
        if (identical(current, start)) rethrow;
        skippedCount++;
        skippedByError.update(
          fileSystemErrorSummary(error),
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    if (skippedCount > 0) {
      AppLogger.w(
        '跳过 $skippedCount 个无法读取的图库目录: $skippedByError',
        'GalleryImageFiles',
      );
    }
  }
}
