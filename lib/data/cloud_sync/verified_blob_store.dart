import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/cloud_sync/data_source.dart';
import '../../core/cloud_sync/models.dart';
import '../../core/cloud_sync/telemetry.dart';

/// A payload handle whose backing blob was verified by [VerifiedBlobStore].
final class VerifiedBlobPayload extends CloudSyncPayload
    implements VerifiedCloudSyncPayload {
  VerifiedBlobPayload._({
    required super.length,
    required super.sha256,
    required CloudPayloadReader verifiedRead,
    required this.storeRoot,
  }) : super(openRead: verifiedRead);

  final String storeRoot;

  @override
  Future<Uint8List> readBytes() async {
    final builder = BytesBuilder(copy: false);
    var read = 0;
    await for (final chunk in readStream()) {
      read += chunk.length;
      if (read > length) {
        throw const CloudFormatException('record payload length mismatch');
      }
      builder.add(chunk);
    }
    if (read != length) {
      throw const CloudFormatException('record payload length mismatch');
    }
    return builder.takeBytes();
  }
}

/// Process-local content-addressed storage for verified cloud payloads.
///
/// A new store instance deliberately starts with an empty verification cache:
/// the first access after process reconstruction verifies both length and hash.
final class VerifiedBlobStore {
  VerifiedBlobStore(Directory root)
    : root = Directory('${root.path}/blobs'),
      _temporary = Directory('${root.path}/blob-temporary');

  final Directory root;
  final Directory _temporary;
  final Map<String, _VerifiedFileState> _verified = {};
  final Random _random = Random.secure();

  Future<VerifiedBlobPayload> putBytes(List<int> bytes) => putStream(
    () => Stream<List<int>>.value(bytes),
    expectedLength: bytes.length,
  );

  Future<VerifiedBlobPayload> putStream(
    CloudPayloadReader openRead, {
    int? expectedLength,
    String? expectedSha256,
  }) async {
    if (expectedLength != null &&
        (expectedLength < 0 || expectedLength > maxCloudRecordPayloadBytes)) {
      throw const CloudFormatException('record is too large');
    }
    if (expectedSha256 != null &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedSha256)) {
      throw const CloudFormatException('invalid payload checksum');
    }
    await _temporary.create(recursive: true);
    final temporary = File(
      '${_temporary.path}/${DateTime.now().microsecondsSinceEpoch}-'
      '${_random.nextInt(1 << 32).toRadixString(16)}',
    );
    final sink = temporary.openWrite(mode: FileMode.writeOnly);
    Digest? computedDigest;
    CloudSyncTelemetry.recordHashPass();
    final hashing = sha256.startChunkedConversion(
      ChunkedConversionSink.withCallback((digests) {
        computedDigest = digests.single;
      }),
    );
    var length = 0;
    try {
      await for (final chunk in openRead()) {
        length += chunk.length;
        if (length > maxCloudRecordPayloadBytes ||
            (expectedLength != null && length > expectedLength)) {
          throw const CloudFormatException('record payload length mismatch');
        }
        hashing.add(chunk);
        sink.add(chunk);
      }
      hashing.close();
      await sink.flush();
      await sink.close();
      CloudSyncTelemetry.recordLocalWrite(length, flushed: true);
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    final digest = computedDigest.toString();
    if ((expectedLength != null && length != expectedLength) ||
        (expectedSha256 != null && digest != expectedSha256)) {
      await temporary.delete();
      throw const CloudFormatException('record payload verification failed');
    }

    await root.create(recursive: true);
    final target = _file(digest);
    if (await target.exists()) {
      await temporary.delete();
      await _verify(target, length, digest);
    } else {
      try {
        await temporary.rename(target.path);
      } on FileSystemException {
        if (!await target.exists()) rethrow;
        if (await temporary.exists()) await temporary.delete();
        await _verify(target, length, digest);
      }
    }
    _verified[digest] = _VerifiedFileState.fromStat(await target.stat());
    return _handle(length, digest);
  }

  Future<VerifiedBlobPayload> open({
    required int length,
    required String sha256,
  }) async {
    final file = _file(sha256);
    await _verify(file, length, sha256);
    return _handle(length, sha256);
  }

  Future<VerifiedBlobPayload?> tryOpen({
    required int length,
    required String sha256,
  }) async {
    if (!await _file(sha256).exists()) return null;
    return open(length: length, sha256: sha256);
  }

  Future<int> sweep(
    Set<String> liveSha256, {
    Duration gracePeriod = const Duration(days: 7),
  }) async {
    final cutoff = DateTime.now().toUtc().subtract(gracePeriod);
    await _removeExpiredTemporaryFiles(cutoff);
    if (!await root.exists()) return 0;
    final candidates = <File>[];
    await for (final entity in root.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.part') ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(name) ||
          liveSha256.contains(name)) {
        continue;
      }
      final modified = (await entity.lastModified()).toUtc();
      if (modified.isBefore(cutoff)) candidates.add(entity);
    }
    var deleted = 0;
    for (final file in candidates) {
      final name = file.uri.pathSegments.last;
      if (liveSha256.contains(name) || !await file.exists()) continue;
      await file.delete();
      _verified.remove(name);
      deleted++;
    }
    return deleted;
  }

  Future<void> _removeExpiredTemporaryFiles(DateTime cutoff) async {
    if (!await _temporary.exists()) return;
    await for (final entity in _temporary.list()) {
      if (entity is! File) continue;
      final modified = (await entity.lastModified()).toUtc();
      if (modified.isBefore(cutoff) && await entity.exists()) {
        await entity.delete();
      }
    }
  }

  Future<void> assertVerifiedHandle(VerifiedBlobPayload payload) async {
    if (payload.storeRoot != root.absolute.path ||
        !_verified.containsKey(payload.sha256)) {
      throw const CloudFormatException('payload handle is not verified');
    }
    await _verify(_file(payload.sha256), payload.length, payload.sha256);
  }

  VerifiedBlobPayload _handle(int length, String digest) =>
      VerifiedBlobPayload._(
        length: length,
        sha256: digest,
        storeRoot: root.absolute.path,
        verifiedRead: () async* {
          final file = _file(digest);
          final beforeOpen = _VerifiedFileState.fromStat(await file.stat());
          if (beforeOpen.size != length) {
            throw const CloudFormatException(
              'verified blob is missing or truncated',
            );
          }
          final reader = await file.open();
          try {
            final afterOpen = _VerifiedFileState.fromStat(await file.stat());
            if (beforeOpen != afterOpen) {
              throw const CloudFormatException(
                'verified blob changed while opening',
              );
            }
            if (_verified[digest] != afterOpen) {
              CloudSyncTelemetry.recordHashPass();
              final actual =
                  (await sha256.bind(_trackedReader(reader, length)).first)
                      .toString();
              if (actual != digest) {
                _verified.remove(digest);
                throw const CloudFormatException(
                  'verified blob checksum mismatch',
                );
              }
              _verified[digest] = afterOpen;
              await reader.setPosition(0);
            }
            var remaining = length;
            while (remaining > 0) {
              final chunk = await reader.read(min(64 * 1024, remaining));
              if (chunk.isEmpty) {
                throw const CloudFormatException(
                  'verified blob is missing or truncated',
                );
              }
              remaining -= chunk.length;
              yield chunk;
            }
            if (await reader.readByte() != -1) {
              throw const CloudFormatException(
                'verified blob length changed while reading',
              );
            }
          } finally {
            await reader.close();
          }
        },
      );

  Future<void> _verify(File file, int length, String digest) async {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file || stat.size != length) {
      throw const CloudFormatException('verified blob is missing or truncated');
    }
    final state = _VerifiedFileState.fromStat(stat);
    if (_verified[digest] == state) return;
    CloudSyncTelemetry.recordHashPass();
    final actual = (await sha256.bind(_trackedRead(file)).first).toString();
    if (actual != digest) {
      _verified.remove(digest);
      throw const CloudFormatException('verified blob checksum mismatch');
    }
    _verified[digest] = state;
  }

  Stream<List<int>> _trackedRead(File file) async* {
    await for (final chunk in file.openRead()) {
      CloudSyncTelemetry.recordLocalRead(chunk.length);
      yield chunk;
    }
  }

  Stream<List<int>> _trackedReader(RandomAccessFile reader, int length) async* {
    var remaining = length;
    while (remaining > 0) {
      final chunk = await reader.read(min(64 * 1024, remaining));
      if (chunk.isEmpty) {
        throw const CloudFormatException(
          'verified blob is missing or truncated',
        );
      }
      remaining -= chunk.length;
      CloudSyncTelemetry.recordLocalRead(chunk.length);
      yield chunk;
    }
  }

  File _file(String digest) => File('${root.path}/$digest');
}

final class _VerifiedFileState {
  const _VerifiedFileState({
    required this.size,
    required this.modified,
    required this.changed,
  });

  factory _VerifiedFileState.fromStat(FileStat stat) => _VerifiedFileState(
    size: stat.size,
    modified: stat.modified.toUtc(),
    changed: stat.changed.toUtc(),
  );

  final int size;
  final DateTime modified;
  final DateTime changed;

  @override
  bool operator ==(Object other) =>
      other is _VerifiedFileState &&
      other.size == size &&
      other.modified == modified &&
      other.changed == changed;

  @override
  int get hashCode => Object.hash(size, modified, changed);
}
