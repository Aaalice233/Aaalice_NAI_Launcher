import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

@immutable
class LegacyThumbnailCleanupResult {
  const LegacyThumbnailCleanupResult({
    required this.removedFiles,
    required this.removedBytes,
    required this.preservedFiles,
    required this.failures,
    required this.alreadyCompleted,
  });

  final int removedFiles;
  final int removedBytes;
  final int preservedFiles;
  final int failures;
  final bool alreadyCompleted;
}

/// Removes only derivative files that can be proven to come from the legacy
/// local-gallery `.thumbs` implementation.
class LocalGalleryThumbnailMigration {
  const LocalGalleryThumbnailMigration({this.supportDirectoryProvider});

  final Future<Directory> Function()? supportDirectoryProvider;

  static final _legacyNamePattern = RegExp(
    r'^(.+)\.(micro|small|medium|large)\.thumb\.jpg$',
    caseSensitive: true,
  );

  static const _supportedSourceExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  };

  static const _legacyBounds = <String, (int, int)>{
    'micro': (80, 100),
    'small': (180, 220),
    'medium': (360, 440),
    'large': (720, 880),
  };

  Future<LegacyThumbnailCleanupResult> runOnce(String galleryRoot) async {
    final normalizedRoot = p.normalize(p.absolute(galleryRoot));
    final marker = await _markerFile(normalizedRoot);
    if (await marker.exists()) {
      return const LegacyThumbnailCleanupResult(
        removedFiles: 0,
        removedBytes: 0,
        preservedFiles: 0,
        failures: 0,
        alreadyCompleted: true,
      );
    }

    // Validation parses every recognized legacy JPEG. Keep this one-time work
    // off the UI isolate so a large gallery cannot interrupt startup rendering.
    final result = await Isolate.run(
      () => const LocalGalleryThumbnailMigration().cleanup(normalizedRoot),
    );
    if (result.failures == 0) {
      try {
        await marker.parent.create(recursive: true);
        final temporary = File('${marker.path}.tmp');
        await temporary.writeAsString(
          jsonEncode({
            'schemaVersion': 1,
            'galleryRoot': normalizedRoot,
            'completedAt': DateTime.now().toUtc().toIso8601String(),
            'removedFiles': result.removedFiles,
            'removedBytes': result.removedBytes,
            'preservedFiles': result.preservedFiles,
          }),
          flush: true,
        );
        await temporary.rename(marker.path);
      } catch (error, stackTrace) {
        AppLogger.w(
          'Could not persist local gallery thumbnail migration marker: '
              '$error\n$stackTrace',
          'LocalGalleryThumbnailMigration',
        );
      }
    }
    return result;
  }

  @visibleForTesting
  Future<LegacyThumbnailCleanupResult> cleanup(String galleryRoot) async {
    final root = Directory(p.normalize(p.absolute(galleryRoot)));
    if (!await root.exists()) {
      return const LegacyThumbnailCleanupResult(
        removedFiles: 0,
        removedBytes: 0,
        preservedFiles: 0,
        failures: 1,
        alreadyCompleted: false,
      );
    }

    var removedFiles = 0;
    var removedBytes = 0;
    var preservedFiles = 0;
    var failures = 0;
    final thumbnailDirectories = <Directory>[];

    try {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is Directory && p.basename(entity.path) == '.thumbs') {
          thumbnailDirectories.add(entity);
        }
      }
    } catch (error, stackTrace) {
      failures++;
      AppLogger.w(
        'Legacy thumbnail discovery failed under ${root.path}: '
            '$error\n$stackTrace',
        'LocalGalleryThumbnailMigration',
      );
    }

    // Process deeper directories first so an emptied `.thumbs` directory can
    // be removed without affecting discovery.
    thumbnailDirectories.sort(
      (left, right) => right.path.length.compareTo(left.path.length),
    );
    for (final directory in thumbnailDirectories) {
      try {
        final sourceCandidates = await _indexSourceCandidates(directory.parent);
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is! File) {
            preservedFiles++;
            continue;
          }
          final verified = await _isVerifiedLegacyThumbnail(
            entity,
            sourceCandidates,
          );
          if (!verified) {
            preservedFiles++;
            continue;
          }
          final length = await entity.length();
          await entity.delete();
          removedFiles++;
          removedBytes += length;
        }

        if (await directory.exists() && await directory.list().isEmpty) {
          await directory.delete();
        }
      } catch (error, stackTrace) {
        failures++;
        AppLogger.w(
          'Legacy thumbnail cleanup failed in ${directory.path}: '
              '$error\n$stackTrace',
          'LocalGalleryThumbnailMigration',
        );
      }
    }

    return LegacyThumbnailCleanupResult(
      removedFiles: removedFiles,
      removedBytes: removedBytes,
      preservedFiles: preservedFiles,
      failures: failures,
      alreadyCompleted: false,
    );
  }

  Future<Map<String, List<File>>> _indexSourceCandidates(
    Directory sourceDirectory,
  ) async {
    final candidates = <String, List<File>>{};
    await for (final entity in sourceDirectory.list(followLinks: false)) {
      if (entity is! File ||
          !_supportedSourceExtensions.contains(
            p.extension(entity.path).toLowerCase(),
          )) {
        continue;
      }
      final stem = _normalizedStem(p.basenameWithoutExtension(entity.path));
      candidates.putIfAbsent(stem, () => <File>[]).add(entity);
    }
    return candidates;
  }

  Future<bool> _isVerifiedLegacyThumbnail(
    File thumbnail,
    Map<String, List<File>> sourceCandidates,
  ) async {
    final match = _legacyNamePattern.firstMatch(p.basename(thumbnail.path));
    if (match == null) return false;

    final sourceStem = _normalizedStem(match.group(1)!);
    final sizeName = match.group(2)!;
    final candidates = sourceCandidates[sourceStem];
    if (candidates == null || candidates.isEmpty) return false;

    final thumbnailStat = await thumbnail.stat();
    if (thumbnailStat.type != FileSystemEntityType.file ||
        thumbnailStat.size <= 0 ||
        thumbnailStat.size > 16 * 1024 * 1024) {
      return false;
    }

    var matchesSource = false;
    for (final source in candidates) {
      final sourceStat = await source.stat();
      if (sourceStat.type == FileSystemEntityType.file &&
          !thumbnailStat.modified.isBefore(sourceStat.modified)) {
        matchesSource = true;
        break;
      }
    }
    if (!matchesSource) return false;

    try {
      final decoded = img.decodeJpg(await thumbnail.readAsBytes());
      if (decoded == null) return false;
      final bounds = _legacyBounds[sizeName]!;
      return decoded.width <= bounds.$1 &&
          decoded.height <= bounds.$2 &&
          (decoded.width == bounds.$1 || decoded.height == bounds.$2);
    } on img.ImageException {
      return false;
    }
  }

  String _normalizedStem(String value) =>
      Platform.isWindows ? value.toLowerCase() : value;

  Future<File> _markerFile(String galleryRoot) async {
    final support =
        await (supportDirectoryProvider?.call() ??
            getApplicationSupportDirectory());
    final rootHash = sha256.convert(utf8.encode(galleryRoot)).toString();
    return File(
      p.join(
        support.path,
        'migrations',
        'local_gallery_thumbnails_v2_$rootHash.json',
      ),
    );
  }
}
