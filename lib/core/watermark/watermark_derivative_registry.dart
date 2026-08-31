import 'dart:convert';
import 'dart:io';

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
    final value = entries[outputPath];
    if (value is! Map) return null;
    final source = value['source'];
    final createdAt = value['createdAt'];
    if (source is! String || source.isEmpty || createdAt is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return null;
    return WatermarkDerivativeLink(
      outputPath: outputPath,
      sourcePath: source,
      createdAt: parsed,
    );
  }

  Future<void> register({
    required String outputPath,
    required String sourcePath,
  }) async {
    if (outputPath.isEmpty || sourcePath.isEmpty || outputPath == sourcePath) {
      return;
    }
    final entries = _read();
    entries[outputPath] = {
      'source': sourcePath,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    final sorted = entries.entries.toList()
      ..sort((a, b) {
        final aTime = (a.value as Map?)?['createdAt']?.toString() ?? '';
        final bTime = (b.value as Map?)?['createdAt']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });
    final bounded = <String, Object?>{};
    for (final entry in sorted.take(_maxEntries)) {
      final value = entry.value;
      final source = value is Map ? value['source'] : null;
      if (source is String && File(source).existsSync()) {
        bounded[entry.key] = value;
      }
    }
    await _storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      jsonEncode(bounded),
    );
  }

  Future<void> remove(String outputPath) async {
    final entries = _read()..remove(outputPath);
    await _storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      jsonEncode(entries),
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
    }
  }
}
