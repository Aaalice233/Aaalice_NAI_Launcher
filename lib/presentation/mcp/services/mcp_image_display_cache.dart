import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/image_share_sanitizer.dart';
import '../../../data/services/metadata/hash_calculator.dart';

/// Optional, content-addressed files for clients that render Markdown images.
/// Only already-prepared outgoing bytes enter this cache, never source paths.
class McpImageDisplayCache {
  McpImageDisplayCache({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;
  final Map<String, Future<File>> _pending = {};
  Future<void>? _cleanup;

  Future<File> prepare(SanitizedShareImage image) async {
    final digest = await FileHashCalculator().calculateFromBytesInBackground(
      image.bytes,
    );
    final extension = image.mimeType == 'image/jpeg'
        ? 'jpg'
        : image.mimeType.split('/').last;
    final key = '$digest.$extension';
    return _pending.putIfAbsent(
      key,
      () => _write(key, digest, image).whenComplete(() {
        _pending.remove(key);
      }),
    );
  }

  Future<File> _write(
    String key,
    String digest,
    SanitizedShareImage image,
  ) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    await (_cleanup ??= _pruneExpired(directory));
    final target = File(p.join(directory.path, 'image-$key'));
    if (await target.exists()) {
      final cached = await target.readAsBytes();
      if (cached.length == image.bytes.length &&
          await FileHashCalculator().calculateFromBytesInBackground(cached) ==
              digest) {
        return target;
      }
    }
    final staging = File('${target.path}.tmp');
    await staging.writeAsBytes(image.bytes, flush: true);
    if (await target.exists()) await target.delete();
    return staging.rename(target.path);
  }

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join((await getTemporaryDirectory()).path, 'nai_launcher_mcp_display'),
  );

  static Future<void> _pruneExpired(Directory directory) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File ||
          !RegExp(
            r'^image-[a-f0-9]{64}\.(png|jpg|webp|gif)(\.tmp)?$',
          ).hasMatch(p.basename(entry.path))) {
        continue;
      }
      try {
        if ((await entry.lastModified()).isBefore(cutoff)) await entry.delete();
      } on FileSystemException {
        // A stale cache entry must not block a current image response.
      }
    }
  }
}
