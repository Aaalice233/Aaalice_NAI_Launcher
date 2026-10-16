import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'local_gallery_thumbnail_provider.dart';

/// Tells whether the file at a path is still the one that was decoded.
@immutable
class LocalFileIdentity {
  const LocalFileIdentity({
    required this.size,
    required this.modifiedMicros,
    required this.changedMicros,
  });

  /// Returns null when the path is not a regular file.
  static LocalFileIdentity? statSync(String path) =>
      fromStat(FileStat.statSync(path));

  /// Returns null when [stat] does not describe a regular file.
  static LocalFileIdentity? fromStat(FileStat stat) {
    if (stat.type != FileSystemEntityType.file) return null;
    return LocalFileIdentity(
      size: stat.size,
      modifiedMicros: stat.modified.microsecondsSinceEpoch,
      changedMicros: stat.changed.microsecondsSinceEpoch,
    );
  }

  final int size;
  final int modifiedMicros;
  // Creation time on Windows and inode change time on POSIX, which catches a
  // replacement that preserved the modification time.
  final int changedMicros;

  @override
  bool operator ==(Object other) =>
      other is LocalFileIdentity &&
      size == other.size &&
      modifiedMicros == other.modifiedMicros &&
      changedMicros == other.changedMicros;

  @override
  int get hashCode => Object.hash(size, modifiedMicros, changedMicros);

  @override
  String toString() =>
      '$size bytes, modified $modifiedMicros us, changed $changedMicros us';
}

/// Image cache key of [LocalFileImage].
///
/// A null [identity] means the path was not a regular file when resolved.
@immutable
class LocalFileImageKey {
  const LocalFileImageKey({
    required this.path,
    required this.identity,
    required this.scale,
  });

  final String path;
  final LocalFileIdentity? identity;
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is LocalFileImageKey &&
      path == other.path &&
      identity == other.identity &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(path, identity, scale);

  @override
  String toString() =>
      'LocalFileImageKey($path, ${identity ?? 'unknown identity'}, '
      'scale: $scale)';
}

/// Decodes a local file like [FileImage], but keys the image cache by the
/// file's identity, so a file overwritten in place is decoded again instead of
/// reusing the pixels cached for its path.
///
/// The identity is read with a synchronous stat so that a cache hit is painted
/// in the same frame the widget mounts, exactly like [FileImage].
@immutable
class LocalFileImage extends ImageProvider<LocalFileImageKey> {
  const LocalFileImage(this.path, {this.scale = 1.0});

  /// Applies `cacheWidth` / `cacheHeight` the same way [Image.file] does.
  static ImageProvider<Object> withCacheSize(
    String path, {
    int? cacheWidth,
    int? cacheHeight,
    double scale = 1.0,
  }) => ResizeImage.resizeIfNeeded(
    cacheWidth,
    cacheHeight,
    LocalFileImage(path, scale: scale),
  );

  final String path;
  final double scale;

  @override
  Future<LocalFileImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<LocalFileImageKey>(
      LocalFileImageKey(
        path: LocalGallerySourceIdentity.normalizePath(path),
        identity: LocalFileIdentity.statSync(path),
        scale: scale,
      ),
    );
  }

  @override
  ImageStreamCompleter loadImage(
    LocalFileImageKey key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Path: $path'),
        ErrorDescription('Identity: ${key.identity ?? 'unknown'}'),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    LocalFileImageKey key,
    ImageDecoderCallback decode,
  ) async {
    final ui.ImmutableBuffer buffer;
    try {
      buffer = await _read(key);
    } catch (_) {
      // A read can succeed later under the same identity, e.g. once a writer
      // releases the file, so its error must not answer later resolves.
      PaintingBinding.instance.imageCache.evict(key);
      rethrow;
    }
    // Undecodable bytes stay cached: the key changes as soon as the file does.
    return decode(buffer);
  }

  Future<ui.ImmutableBuffer> _read(LocalFileImageKey key) async {
    final file = File(path);
    final lengthInBytes = await file.length();
    if (lengthInBytes == 0) {
      throw StateError('$file is empty and cannot be loaded as an image.');
    }
    // Pixels stored under an unknown identity would be shown again after the
    // file vanishes, so a file that appeared after the stat is not decoded.
    if (key.identity == null) {
      throw StateError('$file appeared after its identity was resolved.');
    }
    return ui.ImmutableBuffer.fromFilePath(file.path);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is LocalFileImage &&
        other.path == path &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(path, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'LocalFileImage')}'
      '("$path", scale: ${scale.toStringAsFixed(1)})';
}
