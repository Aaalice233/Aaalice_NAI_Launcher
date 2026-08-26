import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

/// The resize behavior used while decoding a local gallery image.
enum LocalGalleryThumbnailFit { cover, contain }

/// A quantized physical-pixel target for a local gallery image.
@immutable
class LocalGalleryThumbnailTarget {
  const LocalGalleryThumbnailTarget({
    required this.width,
    required this.height,
  });

  static const int bucketSize = 32;
  static const int maximumDimension = 2048;

  final int width;
  final int height;

  factory LocalGalleryThumbnailTarget.fromLogicalSize({
    required double logicalWidth,
    required double logicalHeight,
    required double devicePixelRatio,
  }) {
    if (!logicalWidth.isFinite || logicalWidth <= 0) {
      throw ArgumentError.value(logicalWidth, 'logicalWidth');
    }
    if (!logicalHeight.isFinite || logicalHeight <= 0) {
      throw ArgumentError.value(logicalHeight, 'logicalHeight');
    }
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) {
      throw ArgumentError.value(devicePixelRatio, 'devicePixelRatio');
    }

    int quantize(double value) {
      final physicalPixels = value.ceil().clamp(1, maximumDimension);
      return ((physicalPixels + bucketSize - 1) ~/ bucketSize * bucketSize)
          .clamp(1, maximumDimension);
    }

    return LocalGalleryThumbnailTarget(
      width: quantize(logicalWidth * devicePixelRatio),
      height: quantize(logicalHeight * devicePixelRatio),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LocalGalleryThumbnailTarget &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Stable source identity used by Flutter's LRU image cache.
///
/// The scanner already persists size and modification time. Including both in
/// the provider key prevents a replaced file from reusing decoded pixels from
/// an older file at the same path.
@immutable
class LocalGallerySourceIdentity {
  const LocalGallerySourceIdentity({
    required this.path,
    required this.size,
    required this.modifiedAtMillis,
  });

  factory LocalGallerySourceIdentity.fromRecord({
    required String path,
    required int size,
    required DateTime modifiedAt,
  }) {
    var normalizedPath = p.normalize(p.absolute(path));
    if (Platform.isWindows) normalizedPath = normalizedPath.toLowerCase();
    return LocalGallerySourceIdentity(
      path: normalizedPath,
      size: size,
      modifiedAtMillis: modifiedAt.millisecondsSinceEpoch,
    );
  }

  final String path;
  final int size;
  final int modifiedAtMillis;

  @override
  bool operator ==(Object other) =>
      other is LocalGallerySourceIdentity &&
      path == other.path &&
      size == other.size &&
      modifiedAtMillis == other.modifiedAtMillis;

  @override
  int get hashCode => Object.hash(path, size, modifiedAtMillis);
}

@immutable
class LocalGalleryThumbnailKey {
  const LocalGalleryThumbnailKey({
    required this.source,
    required this.target,
    required this.fit,
  });

  final LocalGallerySourceIdentity source;
  final LocalGalleryThumbnailTarget target;
  final LocalGalleryThumbnailFit fit;

  @override
  bool operator ==(Object other) =>
      other is LocalGalleryThumbnailKey &&
      source == other.source &&
      target == other.target &&
      fit == other.fit;

  @override
  int get hashCode => Object.hash(source, target, fit);

  @override
  String toString() =>
      'LocalGalleryThumbnailKey(${source.path}, ${source.size}, '
      '${source.modifiedAtMillis}, ${target.width}×${target.height}, '
      '${fit.name})';
}

class _LocalGalleryDecodeJob {
  _LocalGalleryDecodeJob({required this.key, required this.loader});

  final LocalGalleryThumbnailKey key;
  final Future<ui.Codec> Function() loader;
  final Completer<ui.Codec> completer = Completer<ui.Codec>();
  bool cancelled = false;
}

class _LocalGalleryDecodeScheduler {
  _LocalGalleryDecodeScheduler._();

  static final instance = _LocalGalleryDecodeScheduler._();
  static const maximumConcurrentDecodes = 4;

  final Queue<_LocalGalleryDecodeJob> _queue = Queue();
  final Map<LocalGalleryThumbnailKey, Set<_LocalGalleryDecodeJob>> _jobs = {};
  int _active = 0;

  int get activeDecodes => _active;
  int get queuedDecodes => _queue.length;

  Future<ui.Codec> schedule(
    LocalGalleryThumbnailKey key,
    Future<ui.Codec> Function() loader,
  ) {
    final job = _LocalGalleryDecodeJob(key: key, loader: loader);
    _jobs.putIfAbsent(key, () => <_LocalGalleryDecodeJob>{}).add(job);
    _queue.add(job);
    _drain();
    return job.completer.future;
  }

  void cancel(LocalGalleryThumbnailKey key) {
    final jobs = _jobs[key];
    if (jobs == null) return;
    for (final job in jobs) {
      job.cancelled = true;
    }
    _queue.removeWhere((job) {
      if (!job.cancelled) return false;
      _abandonCancelled(job);
      return true;
    });
  }

  void _drain() {
    while (_active < maximumConcurrentDecodes && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      if (job.cancelled) {
        _abandonCancelled(job);
        continue;
      }
      _active++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_LocalGalleryDecodeJob job) async {
    try {
      final codec = await job.loader();
      if (job.cancelled) {
        codec.dispose();
        _abandonCancelled(job);
      } else if (!job.completer.isCompleted) {
        job.completer.complete(codec);
      }
    } catch (error, stackTrace) {
      if (job.cancelled) {
        _abandonCancelled(job);
      } else if (!job.completer.isCompleted) {
        job.completer.completeError(error, stackTrace);
      }
    } finally {
      _removeJob(job);
      _active--;
      _drain();
    }
  }

  void _abandonCancelled(_LocalGalleryDecodeJob job) {
    // The ImageStream has already been evicted and usually disposed. Leaving
    // its unreachable Future incomplete avoids reporting cancellation as a
    // decode failure while ensuring no frame can repopulate the cache.
    _removeJob(job);
  }

  void _removeJob(_LocalGalleryDecodeJob job) {
    final jobs = _jobs[job.key];
    jobs?.remove(job);
    if (jobs != null && jobs.isEmpty) _jobs.remove(job.key);
  }
}

/// Decodes a local image directly to the physical pixels needed by its card.
///
/// No derivative is written to the gallery or application cache directory.
/// Flutter's bounded [ImageCache] owns the decoded result using LRU semantics.
class LocalGalleryThumbnailProvider
    extends ImageProvider<LocalGalleryThumbnailKey> {
  static const int maximumDecodedDimension = 4096;

  const LocalGalleryThumbnailProvider({
    required this.source,
    required this.target,
    this.fit = LocalGalleryThumbnailFit.cover,
  });

  final LocalGallerySourceIdentity source;
  final LocalGalleryThumbnailTarget target;
  final LocalGalleryThumbnailFit fit;

  LocalGalleryThumbnailKey get cacheKey =>
      LocalGalleryThumbnailKey(source: source, target: target, fit: fit);

  @override
  Future<LocalGalleryThumbnailKey> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture(cacheKey);

  @override
  ImageStreamCompleter loadImage(
    LocalGalleryThumbnailKey key,
    ImageDecoderCallback decode,
  ) {
    final completer = MultiFrameImageStreamCompleter(
      codec: _LocalGalleryDecodeScheduler.instance.schedule(
        key,
        () => _loadAsync(key, decode),
      ),
      scale: 1,
      debugLabel: key.toString(),
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Path: ${key.source.path}'),
        ErrorDescription(
          'Source identity: ${key.source.size} bytes, '
          '${key.source.modifiedAtMillis} ms',
        ),
        ErrorDescription(
          'Decode target: ${key.target.width}×${key.target.height} '
          '(${key.fit.name})',
        ),
      ],
    );
    completer.addEphemeralErrorListener((_, __) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    });
    return completer;
  }

  Future<ui.Codec> _loadAsync(
    LocalGalleryThumbnailKey key,
    ImageDecoderCallback decode,
  ) async {
    final file = File(key.source.path);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw FileSystemException(
        'Local gallery image is unavailable',
        file.path,
      );
    }
    if (stat.size == 0) {
      throw StateError('${file.path} is empty and cannot be decoded.');
    }

    // Refuse to populate an old cache key after a source replacement. The next
    // gallery scan supplies the new identity and starts a fresh request.
    final statModifiedMillis = stat.modified.millisecondsSinceEpoch;
    if (key.source.size > 0 &&
        (stat.size != key.source.size ||
            statModifiedMillis != key.source.modifiedAtMillis)) {
      throw StateError('Local gallery image changed while it was displayed.');
    }

    final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    final afterReadStat = await file.stat();
    if (afterReadStat.type != FileSystemEntityType.file ||
        afterReadStat.size != stat.size ||
        afterReadStat.modified != stat.modified ||
        afterReadStat.changed != stat.changed) {
      buffer.dispose();
      throw StateError('Local gallery image changed while it was decoded.');
    }
    return decode(
      buffer,
      getTargetSize: (intrinsicWidth, intrinsicHeight) => _decodeTarget(
        intrinsicWidth: intrinsicWidth,
        intrinsicHeight: intrinsicHeight,
        target: key.target,
        fit: key.fit,
      ),
    );
  }

  static ui.TargetImageSize calculateDecodeTarget({
    required int intrinsicWidth,
    required int intrinsicHeight,
    required LocalGalleryThumbnailTarget target,
    required LocalGalleryThumbnailFit fit,
  }) => _decodeTarget(
    intrinsicWidth: intrinsicWidth,
    intrinsicHeight: intrinsicHeight,
    target: target,
    fit: fit,
  );

  static ui.TargetImageSize _decodeTarget({
    required int intrinsicWidth,
    required int intrinsicHeight,
    required LocalGalleryThumbnailTarget target,
    required LocalGalleryThumbnailFit fit,
  }) {
    if (intrinsicWidth <= 0 || intrinsicHeight <= 0) {
      return ui.TargetImageSize(width: target.width, height: target.height);
    }

    final widthScale = target.width / intrinsicWidth;
    final heightScale = target.height / intrinsicHeight;
    final requestedScale = fit == LocalGalleryThumbnailFit.cover
        ? math.max(widthScale, heightScale)
        : math.min(widthScale, heightScale);
    var scale = math.min(1.0, requestedScale);
    final longestDecodedDimension = math.max(
      intrinsicWidth * scale,
      intrinsicHeight * scale,
    );
    if (longestDecodedDimension > maximumDecodedDimension) {
      scale *= maximumDecodedDimension / longestDecodedDimension;
    }
    return ui.TargetImageSize(
      width: math.max(1, (intrinsicWidth * scale).ceil()),
      height: math.max(1, (intrinsicHeight * scale).ceil()),
    );
  }
}

/// Gallery-owned view of the shared Flutter image cache.
class LocalGalleryThumbnailMemoryCache {
  LocalGalleryThumbnailMemoryCache._();

  static final instance = LocalGalleryThumbnailMemoryCache._();

  static const maximumTrackedKeys = 4096;

  final Set<LocalGalleryThumbnailKey> _knownKeys = {};
  final Map<LocalGalleryThumbnailProvider, LocalGalleryThumbnailKey>
  _pendingProviders = HashMap.identity();
  final Map<LocalGalleryThumbnailKey, int> _pendingOwnerCounts = {};

  void register(LocalGalleryThumbnailProvider provider) {
    final key = provider.cacheKey;
    if (!_pendingProviders.containsKey(provider)) {
      _pendingProviders[provider] = key;
      _pendingOwnerCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    _knownKeys.remove(key);
    _knownKeys.add(key);
    while (_knownKeys.length > maximumTrackedKeys) {
      final oldest = _knownKeys.first;
      _LocalGalleryDecodeScheduler.instance.cancel(oldest);
      PaintingBinding.instance.imageCache.evict(oldest);
      _knownKeys.remove(oldest);
      _removePendingOwners(oldest);
    }
  }

  void releasePendingOwner(LocalGalleryThumbnailProvider provider) {
    _releasePendingOwner(provider);
  }

  bool isPending(LocalGalleryThumbnailProvider provider) => PaintingBinding
      .instance
      .imageCache
      .statusForKey(provider.cacheKey)
      .pending;

  Future<void> cancelPending(LocalGalleryThumbnailProvider provider) async {
    final key = _releasePendingOwner(provider);
    if (key == null || _pendingOwnerCounts.containsKey(key)) return;
    _LocalGalleryDecodeScheduler.instance.cancel(key);
    if (PaintingBinding.instance.imageCache.statusForKey(key).pending) {
      PaintingBinding.instance.imageCache.evict(key);
    }
    _knownKeys.remove(key);
  }

  int clear() {
    var removed = 0;
    for (final key in _knownKeys) {
      _LocalGalleryDecodeScheduler.instance.cancel(key);
      if (PaintingBinding.instance.imageCache.evict(key)) removed++;
    }
    _knownKeys.clear();
    _pendingProviders.clear();
    _pendingOwnerCounts.clear();
    return removed;
  }

  LocalGalleryThumbnailKey? _releasePendingOwner(
    LocalGalleryThumbnailProvider provider,
  ) {
    final key = _pendingProviders.remove(provider);
    if (key == null) return null;
    final owners = _pendingOwnerCounts[key];
    if (owners == null || owners <= 1) {
      _pendingOwnerCounts.remove(key);
    } else {
      _pendingOwnerCounts[key] = owners - 1;
    }
    return key;
  }

  void _removePendingOwners(LocalGalleryThumbnailKey key) {
    _pendingProviders.removeWhere((_, pendingKey) => pendingKey == key);
    _pendingOwnerCounts.remove(key);
  }

  LocalGalleryThumbnailMemoryStatistics get statistics {
    var trackedEntries = 0;
    var pendingEntries = 0;
    for (final key in _knownKeys) {
      final status = PaintingBinding.instance.imageCache.statusForKey(key);
      if (status.tracked) trackedEntries++;
      if (status.pending) pendingEntries++;
    }
    return LocalGalleryThumbnailMemoryStatistics(
      trackedEntries: trackedEntries,
      sharedCacheBytes: PaintingBinding.instance.imageCache.currentSizeBytes,
      sharedCacheLimitBytes:
          PaintingBinding.instance.imageCache.maximumSizeBytes,
      pendingEntries: pendingEntries,
      activeDecodes: _LocalGalleryDecodeScheduler.instance.activeDecodes,
      queuedDecodes: _LocalGalleryDecodeScheduler.instance.queuedDecodes,
    );
  }
}

@immutable
class LocalGalleryThumbnailMemoryStatistics {
  const LocalGalleryThumbnailMemoryStatistics({
    required this.trackedEntries,
    required this.sharedCacheBytes,
    required this.sharedCacheLimitBytes,
    required this.pendingEntries,
    required this.activeDecodes,
    required this.queuedDecodes,
  });

  final int trackedEntries;

  /// Exact bytes retained by Flutter's shared LRU cache.
  final int sharedCacheBytes;
  final int sharedCacheLimitBytes;
  final int pendingEntries;
  final int activeDecodes;
  final int queuedDecodes;
}
