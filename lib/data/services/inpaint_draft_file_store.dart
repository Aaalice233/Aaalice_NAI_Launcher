import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/utils/exif_orientation.dart';
import '../../core/utils/isolate_pool.dart';
import '../../core/utils/nai_resolution_adapter.dart';
import '../models/inpaint/inpaint_draft.dart';
import 'inpaint_draft_repository.dart';
import 'metadata/hash_calculator.dart';

/// Must decode every pixel: inspection relies on it to reject truncated images.
typedef InpaintDraftImageSizeDecoder =
    Future<(int, int)?> Function(Uint8List bytes);

/// Owns atomic file replacement and integrity checks for inpaint draft assets.
class InpaintDraftFileStore {
  InpaintDraftFileStore({InpaintDraftImageSizeDecoder? decodeImageSize})
    : _decodeImageSize = decodeImageSize ?? _decodeImageSizeInBackground;

  static final Map<String, Future<void>> _pendingOperations = {};

  final InpaintDraftImageSizeDecoder _decodeImageSize;

  Future<void> atomicWriteBytes(File target, List<int> bytes) {
    return _synchronized(
      target.path,
      () => _atomicWriteBytesUnlocked(target, bytes),
    );
  }

  Future<void> recoverAtomicTarget(File target) {
    return _synchronized(target.path, () async {
      final backup = File('${target.path}.bak');
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      if (await target.exists() && await backup.exists()) {
        await backup.delete();
      }
      final parent = target.parent;
      if (!await parent.exists()) return;
      final prefix = '${p.basename(target.path)}.';
      await for (final entity in parent.list()) {
        if (entity is File &&
            p.basename(entity.path).startsWith(prefix) &&
            entity.path.endsWith('.tmp')) {
          await entity.delete();
        }
      }
    });
  }

  Future<T> _synchronized<T>(
    String path,
    Future<T> Function() operation,
  ) async {
    final previous = _pendingOperations[path] ?? Future<void>.value();
    final completer = Completer<void>();
    _pendingOperations[path] = completer.future;
    try {
      await previous;
      return await operation();
    } finally {
      completer.complete();
      if (identical(_pendingOperations[path], completer.future)) {
        _pendingOperations.remove(path);
      }
    }
  }

  Future<void> verifyAsset(
    Directory directory,
    String fileName,
    InpaintDraftAsset expected,
    String label,
  ) async {
    final file = File(p.join(directory.path, fileName));
    await recoverAtomicTarget(file);
    if (!await file.exists()) {
      throw InpaintDraftIntegrityException('$label file is missing');
    }
    await verifyBytes(await file.readAsBytes(), expected, label);
  }

  Future<bool> hasChecksum(Uint8List bytes, InpaintDraftAsset expected) async {
    return bytes.length == expected.sizeBytes &&
        await FileHashCalculator().calculateFromBytesInBackground(bytes) ==
            expected.sha256;
  }

  Future<void> verifyBytes(
    List<int> bytes,
    InpaintDraftAsset expected,
    String label,
  ) async {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    if (!await hasChecksum(data, expected)) {
      throw InpaintDraftIntegrityException('$label checksum or size mismatch');
    }
    // GIF-like headers may report a canvas larger than the decoded frame.
    if (_hasDimensions(NaiResolutionAdapter.readImageSize(data), expected) ||
        _hasDimensions(await _decodeImageSize(data), expected)) {
      return;
    }
    throw InpaintDraftIntegrityException('$label dimensions mismatch');
  }

  Future<InpaintDraftAsset> inspectImage(
    Uint8List bytes, {
    required String label,
  }) async {
    final size = await _decodeImageSize(bytes);
    if (size == null) {
      throw InpaintDraftIntegrityException('$label is not a supported image');
    }
    return InpaintDraftAsset(
      sha256: await FileHashCalculator().calculateFromBytesInBackground(bytes),
      sizeBytes: bytes.length,
      width: size.$1,
      height: size.$2,
    );
  }

  static bool _hasDimensions((int, int)? size, InpaintDraftAsset expected) {
    return size != null &&
        size.$1 == expected.width &&
        size.$2 == expected.height;
  }

  static Future<(int, int)?> _decodeImageSizeInBackground(Uint8List bytes) {
    return ComputeGate().runCompute(_decodeImageSizeSync, bytes);
  }

  static (int, int)? _decodeImageSizeSync(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    return decoded == null ? null : ExifOrientation.uprightSize(bytes, decoded);
  }

  Future<void> _atomicWriteBytesUnlocked(File target, List<int> bytes) async {
    final temporary = File('${target.path}.${const Uuid().v4()}.tmp');
    final backup = File('${target.path}.bak');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await backup.exists()) await backup.delete();
      if (await target.exists()) await target.rename(backup.path);
      await temporary.rename(target.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }
}
