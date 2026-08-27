import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';

enum LocalOnnxModelKind { wd14Tagger, clTagger, unknown }

class LocalOnnxImportSource {
  const LocalOnnxImportSource({required this.name, required this.path});

  final String name;
  final String path;
}

class LocalOnnxModelDescriptor {
  const LocalOnnxModelDescriptor({
    required this.name,
    required this.path,
    required this.kind,
    this.labelsPath,
  });

  final String name;
  final String path;
  final LocalOnnxModelKind kind;
  final String? labelsPath;

  bool get isOnnx => p.extension(path).toLowerCase() == '.onnx';
}

final localOnnxModelServiceProvider = Provider<LocalOnnxModelService>((ref) {
  return LocalOnnxModelService(ref.read(localStorageServiceProvider));
});

class LocalOnnxModelService {
  const LocalOnnxModelService(this._storage);

  final LocalStorageService _storage;

  String get taggerDirectory =>
      _storage.getSetting<String>(StorageKeys.onnxTaggerModelDirectory) ?? '';

  Future<void> setTaggerDirectory(String path) async {
    await _storage.setSetting(StorageKeys.onnxTaggerModelDirectory, path);
  }

  Future<String> getManagedTaggerDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return p.join(supportDirectory.path, 'models', 'onnx_taggers');
  }

  Future<int> importTaggerFiles(List<LocalOnnxImportSource> sources) async {
    if (sources.isEmpty) return 0;

    final managedDirectory = Directory(await getManagedTaggerDirectory());
    await managedDirectory.create(recursive: true);
    await _recoverInterruptedImports(managedDirectory);

    final entries = <_OnnxImportEntry>[];
    final selectedNames = <String>{};
    for (final source in sources) {
      final sourceFile = File(source.path);
      if (!await sourceFile.exists()) {
        throw FileSystemException(
          'Selected model file is unavailable',
          source.path,
        );
      }

      final fileName = _sanitizeImportedFileName(source.name);
      if (!_isSupportedImportFile(fileName)) continue;
      if (!selectedNames.add(fileName.toLowerCase())) {
        throw FormatException('Duplicate imported file name: $fileName');
      }
      entries.add(
        _OnnxImportEntry(
          source: sourceFile,
          fileName: fileName,
          hadDestination: await File(
            p.join(managedDirectory.path, fileName),
          ).exists(),
        ),
      );
    }

    if (entries.isEmpty) {
      throw const FormatException(
        'No supported ONNX model files were selected',
      );
    }
    final hasSelectedModel = entries.any(
      (entry) => p.extension(entry.fileName).toLowerCase() == '.onnx',
    );
    if (!hasSelectedModel && !await _containsOnnxModel(managedDirectory)) {
      throw const FormatException('At least one .onnx model file is required');
    }

    final transaction = Directory(
      p.join(
        managedDirectory.path,
        '.import-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final stagedDirectory = Directory(p.join(transaction.path, 'staged'));
    final backupDirectory = Directory(p.join(transaction.path, 'backup'));
    final manifest = File(p.join(transaction.path, 'manifest.json'));
    await stagedDirectory.create(recursive: true);
    await backupDirectory.create(recursive: true);

    final previousDirectory = taggerDirectory;
    var transactionFinished = false;
    await _writeImportManifest(
      manifest,
      phase: 'staging',
      entries: entries,
      previousDirectory: previousDirectory,
    );

    try {
      for (final entry in entries) {
        final staged = File(p.join(stagedDirectory.path, entry.fileName));
        await entry.source.copy(staged.path);
        if (await staged.length() != await entry.source.length()) {
          throw FileSystemException(
            'Imported model copy is incomplete',
            entry.source.path,
          );
        }
      }

      await _writeImportManifest(
        manifest,
        phase: 'committing',
        entries: entries,
        previousDirectory: previousDirectory,
      );
      for (final entry in entries) {
        final destination = File(p.join(managedDirectory.path, entry.fileName));
        final staged = File(p.join(stagedDirectory.path, entry.fileName));
        final backup = File(p.join(backupDirectory.path, entry.fileName));
        if (await destination.exists()) {
          await destination.rename(backup.path);
        }
        await staged.rename(destination.path);
      }

      await setTaggerDirectory(managedDirectory.path);
      await _writeImportManifest(
        manifest,
        phase: 'committed',
        entries: entries,
        previousDirectory: previousDirectory,
      );
      transactionFinished = true;
      return entries.length;
    } catch (_) {
      await _rollbackImport(
        managedDirectory: managedDirectory,
        transaction: transaction,
        entries: entries,
      );
      if (taggerDirectory != previousDirectory) {
        await setTaggerDirectory(previousDirectory);
      }
      transactionFinished = true;
      rethrow;
    } finally {
      if (transactionFinished && await transaction.exists()) {
        try {
          await transaction.delete(recursive: true);
        } catch (error, stackTrace) {
          AppLogger.e(
            'Failed to clean completed ONNX import transaction',
            error,
            stackTrace,
            'LocalOnnxModelService',
          );
        }
      }
    }
  }

  Future<void> _writeImportManifest(
    File manifest, {
    required String phase,
    required List<_OnnxImportEntry> entries,
    required String previousDirectory,
  }) {
    return manifest.writeAsString(
      jsonEncode({
        'phase': phase,
        'previousDirectory': previousDirectory,
        'entries': [
          for (final entry in entries)
            {
              'fileName': entry.fileName,
              'hadDestination': entry.hadDestination,
            },
        ],
      }),
      flush: true,
    );
  }

  Future<void> _rollbackImport({
    required Directory managedDirectory,
    required Directory transaction,
    required List<_OnnxImportEntry> entries,
  }) async {
    final stagedDirectory = Directory(p.join(transaction.path, 'staged'));
    final backupDirectory = Directory(p.join(transaction.path, 'backup'));
    for (final entry in entries.reversed) {
      final destination = File(p.join(managedDirectory.path, entry.fileName));
      final staged = File(p.join(stagedDirectory.path, entry.fileName));
      final backup = File(p.join(backupDirectory.path, entry.fileName));
      if (await backup.exists()) {
        if (await destination.exists()) await destination.delete();
        await backup.rename(destination.path);
      } else if (!entry.hadDestination &&
          !await staged.exists() &&
          await destination.exists()) {
        await destination.delete();
      }
    }
  }

  Future<void> _recoverInterruptedImports(Directory managedDirectory) async {
    await for (final entity in managedDirectory.list(followLinks: false)) {
      if (entity is! Directory ||
          !p.basename(entity.path).startsWith('.import-')) {
        continue;
      }

      final manifest = File(p.join(entity.path, 'manifest.json'));
      if (!await manifest.exists()) {
        await entity.delete(recursive: true);
        continue;
      }

      late final Map<String, dynamic> data;
      try {
        data =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      } catch (error) {
        throw StateError(
          'Cannot recover interrupted ONNX import ${entity.path}: $error',
        );
      }

      final phase = data['phase'] as String?;
      if (phase == 'committing') {
        final rawEntries = data['entries'];
        if (rawEntries is! List) {
          throw StateError('Invalid ONNX import manifest: ${entity.path}');
        }
        final entries = rawEntries.map((rawEntry) {
          if (rawEntry is! Map ||
              rawEntry['fileName'] is! String ||
              rawEntry['hadDestination'] is! bool) {
            throw StateError('Invalid ONNX import manifest: ${entity.path}');
          }
          final fileName = _sanitizeImportedFileName(
            rawEntry['fileName'] as String,
          );
          return _OnnxImportEntry(
            source: File(''),
            fileName: fileName,
            hadDestination: rawEntry['hadDestination'] as bool,
          );
        }).toList();
        await _rollbackImport(
          managedDirectory: managedDirectory,
          transaction: entity,
          entries: entries,
        );
        final previousDirectory = data['previousDirectory'] as String? ?? '';
        if (taggerDirectory != previousDirectory) {
          await setTaggerDirectory(previousDirectory);
        }
      } else if (phase != 'staging' && phase != 'committed') {
        throw StateError('Invalid ONNX import phase in ${entity.path}');
      }
      await entity.delete(recursive: true);
    }
  }

  Future<int> managedFileCount() async {
    final directory = Directory(await getManagedTaggerDirectory());
    if (!await directory.exists()) return 0;
    await _recoverInterruptedImports(directory);
    return directory
        .list(followLinks: false)
        .where(
          (entity) => entity is File && _isSupportedImportFile(entity.path),
        )
        .length;
  }

  Future<void> clearManagedTaggerFiles() async {
    final managedDirectory = Directory(await getManagedTaggerDirectory());
    if (await managedDirectory.exists()) {
      await managedDirectory.delete(recursive: true);
    }
    if (p.equals(taggerDirectory, managedDirectory.path)) {
      await setTaggerDirectory('');
    }
  }

  Future<List<LocalOnnxModelDescriptor>> scanTaggerModels() async {
    final managedDirectory = Directory(await getManagedTaggerDirectory());
    if (await managedDirectory.exists()) {
      await _recoverInterruptedImports(managedDirectory);
    }
    return _scanModels(
      taggerDirectory,
      allowedKinds: const {
        LocalOnnxModelKind.wd14Tagger,
        LocalOnnxModelKind.clTagger,
        LocalOnnxModelKind.unknown,
      },
    );
  }

  Future<List<LocalOnnxModelDescriptor>> _scanModels(
    String directoryPath, {
    required Set<LocalOnnxModelKind> allowedKinds,
  }) async {
    final trimmed = directoryPath.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final directory = Directory(trimmed);
    if (!await directory.exists()) {
      return const [];
    }

    final result = <LocalOnnxModelDescriptor>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      if (p.extension(entity.path).toLowerCase() != '.onnx') continue;

      final kind = _inferKind(entity.path);
      if (!allowedKinds.contains(kind)) continue;

      result.add(
        LocalOnnxModelDescriptor(
          name: p.basename(entity.path),
          path: entity.path,
          kind: kind,
          labelsPath: await _findLabelsFile(entity.path),
        ),
      );
    }

    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  String _sanitizeImportedFileName(String value) {
    final baseName = p
        .basename(value)
        .replaceAll(RegExp(r'[\x00-\x1f/\\]'), '_');
    if (baseName.isEmpty || baseName == '.' || baseName == '..') {
      throw const FormatException('Invalid model file name');
    }
    return baseName;
  }

  bool _isSupportedImportFile(String fileName) {
    return const {
      '.onnx',
      '.data',
      '.csv',
      '.txt',
      '.json',
    }.contains(p.extension(fileName).toLowerCase());
  }

  Future<bool> _containsOnnxModel(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.onnx') {
        return true;
      }
    }
    return false;
  }

  LocalOnnxModelKind _inferKind(String filePath) {
    final lower = p.basenameWithoutExtension(filePath).toLowerCase();
    if (lower.contains('wd14') ||
        lower.contains('wd-v1-4') ||
        lower.contains('wd-v1-5') ||
        lower.contains('convnext') ||
        lower.contains('vit') ||
        lower.contains('swinv2')) {
      return LocalOnnxModelKind.wd14Tagger;
    }
    if (lower.contains('cl') && lower.contains('tagger')) {
      return LocalOnnxModelKind.clTagger;
    }
    return LocalOnnxModelKind.unknown;
  }

  Future<String?> _findLabelsFile(String onnxPath) async {
    final base = p.withoutExtension(onnxPath);
    final lowerBaseName = p.basenameWithoutExtension(onnxPath).toLowerCase();
    final directory = p.dirname(onnxPath);

    if (lowerBaseName.contains('cl_tagger')) {
      final mapping = p.join(directory, 'tag_mapping.json');
      if (await File(mapping).exists()) {
        return mapping;
      }
    }

    for (final extension in const ['.csv', '.txt', '.json']) {
      final candidate = '$base$extension';
      if (await File(candidate).exists()) {
        return candidate;
      }
    }

    for (final name in const [
      'selected_tags.csv',
      'tags.csv',
      'labels.csv',
      'labels.txt',
      'classes.txt',
      'tag_mapping.json',
    ]) {
      final candidate = p.join(directory, name);
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }
}

class _OnnxImportEntry {
  const _OnnxImportEntry({
    required this.source,
    required this.fileName,
    required this.hadDestination,
  });

  final File source;
  final String fileName;
  final bool hadDestination;
}
