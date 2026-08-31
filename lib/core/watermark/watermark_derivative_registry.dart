import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants/storage_keys.dart';
import '../storage/local_storage_service.dart';

class WatermarkDerivativeLink {
  const WatermarkDerivativeLink({
    required this.outputPath,
    required this.sourcePath,
    required this.createdAt,
  });

  final String outputPath;
  final String sourcePath;
  final DateTime createdAt;
}

/// App-private association between a derivative and its original.
///
/// Paths never enter image metadata and this storage key is intentionally absent
/// from cloud-sync allowlists.
class WatermarkDerivativeRegistry {
  WatermarkDerivativeRegistry(this._storage);

  static const _maxEntries = 500;
  final LocalStorageService _storage;

  WatermarkDerivativeLink? find(String outputPath) {
    final entries = _read();
    final outputKey = _pathKey(outputPath);
    final value = entries[outputKey] ?? entries[outputPath];
    if (value is! Map) return null;
    final source = value['source'];
    final createdAt = value['createdAt'];
    if (source is! String || source.isEmpty || createdAt is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return null;
    return WatermarkDerivativeLink(
      outputPath: outputKey,
      sourcePath: source,
      createdAt: parsed,
    );
  }

  bool isDerivative(String path) =>
      find(path) != null || looksLikeDerivativePath(path);

  static bool looksLikeDerivativePath(String path) => RegExp(
    r'_watermarked(?:[-_]\d+)?$',
    caseSensitive: false,
  ).hasMatch(p.basenameWithoutExtension(path));

  Future<void> register({
    required String outputPath,
    required String sourcePath,
  }) async {
    final outputKey = _pathKey(outputPath);
    final sourceValue = _normalizedPath(sourcePath);
    if (outputKey.isEmpty ||
        sourceValue.isEmpty ||
        outputKey == _pathKey(sourceValue)) {
      return;
    }
    final entries = _read();
    entries.remove(outputPath);
    entries[outputKey] = {
      'source': sourceValue,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _write(entries);
  }

  Future<void> relocatePath({
    required String oldPath,
    required String newPath,
  }) async {
    final oldKey = _pathKey(oldPath);
    final newKey = _pathKey(newPath);
    if (oldKey.isEmpty || newKey.isEmpty || oldKey == newKey) return;
    final entries = _read();
    var changed = false;
    final outputValue = entries.remove(oldKey) ?? entries.remove(oldPath);
    if (outputValue != null) {
      entries[newKey] = outputValue;
      changed = true;
    }
    final normalizedNewPath = _normalizedPath(newPath);
    for (final entry in entries.entries.toList()) {
      final value = entry.value;
      if (value is! Map ||
          _pathKey(value['source']?.toString() ?? '') != oldKey) {
        continue;
      }
      entries[entry.key] = {
        ...Map<String, Object?>.from(value),
        'source': normalizedNewPath,
      };
      changed = true;
    }
    if (changed) await _write(entries);
  }

  Future<void> remove(String outputPath) async {
    final entries = _read()
      ..remove(outputPath)
      ..remove(_pathKey(outputPath));
    await _write(entries);
  }

  Future<void> _write(Map<String, Object?> entries) {
    final sorted = entries.entries.toList()
      ..sort((a, b) {
        final aValue = a.value;
        final bValue = b.value;
        final aTime = aValue is Map
            ? aValue['createdAt']?.toString() ?? ''
            : '';
        final bTime = bValue is Map
            ? bValue['createdAt']?.toString() ?? ''
            : '';
        return bTime.compareTo(aTime);
      });
    final bounded = <String, Object?>{};
    for (final entry in sorted) {
      final value = entry.value;
      final source = value is Map ? value['source'] : null;
      if (source is! String || source.isEmpty) continue;
      bounded[entry.key] = value;
      if (bounded.length == _maxEntries) break;
    }
    return _storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      jsonEncode(bounded),
    );
  }

  Map<String, Object?> _read() {
    final encoded = _storage.getSetting<Object?>(
      StorageKeys.watermarkDerivativeRegistryV1,
    );
    if (encoded is! String || encoded.isEmpty) return {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return {};
      return Map<String, Object?>.from(decoded);
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  String _pathKey(String path) {
    final normalized = _normalizedPath(path);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  String _normalizedPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed.contains('://')) return trimmed;
    return p.normalize(p.absolute(trimmed));
  }
}
