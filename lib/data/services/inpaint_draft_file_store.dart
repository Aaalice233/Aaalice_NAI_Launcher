import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/inpaint/inpaint_draft.dart';
import 'inpaint_draft_repository.dart';

/// Owns atomic file replacement and integrity checks for inpaint draft assets.
class InpaintDraftFileStore {
  static final Map<String, Future<void>> _pendingOperations = {};

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
    verifyBytes(await file.readAsBytes(), expected, label);
  }

  void verifyBytes(List<int> bytes, InpaintDraftAsset expected, String label) {
    if (bytes.length != expected.sizeBytes ||
        sha256.convert(bytes).toString() != expected.sha256) {
      throw InpaintDraftIntegrityException('$label checksum or size mismatch');
    }
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null ||
        decoded.width != expected.width ||
        decoded.height != expected.height) {
      throw InpaintDraftIntegrityException('$label dimensions mismatch');
    }
  }

  InpaintDraftAsset inspectImage(Uint8List bytes, {required String label}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw InpaintDraftIntegrityException('$label is not a supported image');
    }
    return InpaintDraftAsset(
      sha256: sha256.convert(bytes).toString(),
      sizeBytes: bytes.length,
      width: decoded.width,
      height: decoded.height,
    );
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
