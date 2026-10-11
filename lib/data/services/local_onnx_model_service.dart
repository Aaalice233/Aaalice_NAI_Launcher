import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import 'local_onnx_tagger_labels.dart';

enum LocalOnnxModelKind {
  wd14Tagger,
  clTagger,
  clTaggerV2,
  animeTimmEva02,
  pixaiTagger,
  unknown,
}

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

  static const int _archiveFileCountLimit = 64;
  static const int _archiveExpandedBytesLimit = 4 * 1024 * 1024 * 1024;
  static const int _archiveEntryBytesLimit = 2 * 1024 * 1024 * 1024;

  // 共用模型目录按模型分文件夹，HF 导出（如 cl_tagger_v2/v2_01a）还会再按版本分一层。
  static const int _modelScanDepth = 2;

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

  Future<int> importTaggerSelections(
    List<LocalOnnxImportSource> sources,
  ) async {
    if (sources.isEmpty) return 0;
    if (!sources.any(
      (source) => p.extension(source.name).toLowerCase() == '.zip',
    )) {
      return importTaggerFiles(sources);
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final extractionDirectory = Directory(
      p.join(
        temporaryDirectory.path,
        'onnx-tagger-import-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final expandedSources = <LocalOnnxImportSource>[];
    var extractionCreated = false;
    try {
      for (var index = 0; index < sources.length; index++) {
        final source = sources[index];
        if (p.extension(source.name).toLowerCase() != '.zip') {
          expandedSources.add(source);
          continue;
        }
        extractionCreated = true;
        expandedSources.addAll(
          await _extractTaggerArchiveInBackground(
            source,
            p.join(extractionDirectory.path, '$index'),
          ),
        );
      }
      return await importTaggerFiles(expandedSources);
    } finally {
      if (extractionCreated && await extractionDirectory.exists()) {
        await extractionDirectory.delete(recursive: true);
      }
    }
  }

  // GB 级模型包可能解压数分钟，占着 ComputeGate 许可会挡住前台解码，所以用独立 isolate；
  // 闭包只捕获参数，避免把持有存储的服务实例带进后台 isolate
  static Future<List<LocalOnnxImportSource>> _extractTaggerArchiveInBackground(
    LocalOnnxImportSource source,
    String outputPath,
  ) => Isolate.run(
    () => _extractTaggerArchive(source, Directory(outputPath)),
    debugName: 'onnx-archive-extract',
  );

  static Future<List<LocalOnnxImportSource>> _extractTaggerArchive(
    LocalOnnxImportSource source,
    Directory outputDirectory,
  ) async {
    final sourceFile = File(source.path);
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'Selected model archive is unavailable',
        source.path,
      );
    }

    final input = InputFileStream(source.path);
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBuffer(input);
    } catch (error) {
      input.closeSync();
      throw FormatException('Invalid ONNX model ZIP: $error');
    }

    if (archive.files.isEmpty ||
        archive.files.length > _archiveFileCountLimit) {
      for (final entry in archive.files) {
        entry.closeSync();
      }
      input.closeSync();
      throw const FormatException('ONNX model ZIP has an invalid file count');
    }

    final extracted = <LocalOnnxImportSource>[];
    final selectedNames = <String>{};
    final budget = _OnnxArchiveExtractionBudget(
      entryBytesLimit: _archiveEntryBytesLimit,
      expandedBytesLimit: _archiveExpandedBytesLimit,
    );
    try {
      for (final entry in archive.files) {
        final source = await _extractTaggerArchiveEntry(
          entry,
          outputDirectory: outputDirectory,
          selectedNames: selectedNames,
          budget: budget,
        );
        if (source != null) extracted.add(source);
      }
    } finally {
      for (final entry in archive.files) {
        entry.closeSync();
      }
      input.closeSync();
    }
    if (extracted.isEmpty) {
      throw const FormatException(
        'ONNX model ZIP contains no supported model files',
      );
    }
    return extracted;
  }

  static Future<LocalOnnxImportSource?> _extractTaggerArchiveEntry(
    ArchiveFile entry, {
    required Directory outputDirectory,
    required Set<String> selectedNames,
    required _OnnxArchiveExtractionBudget budget,
  }) async {
    if (entry.isSymbolicLink) {
      throw FormatException(
        'Symbolic links are not allowed in ONNX model ZIPs: ${entry.name}',
      );
    }
    if (!entry.isFile) return null;

    final fileName = _sanitizeImportedFileName(entry.name);
    if (!_isSupportedImportFile(fileName)) return null;
    budget.reserveDeclared(entry.size, entry.name);
    if (!selectedNames.add(fileName.toLowerCase())) {
      throw FormatException(
        'Duplicate model file name in ONNX model ZIP: $fileName',
      );
    }

    await outputDirectory.create(recursive: true);
    final outputPath = p.join(outputDirectory.path, fileName);
    final output = OutputFileStream(outputPath, bufferSize: 64 * 1024);
    try {
      entry.clear();
      entry.decompress(output);
      await output.close();
    } catch (error) {
      await output.close();
      throw FormatException(
        'Cannot extract ${entry.name} from ONNX model ZIP: $error',
      );
    }
    if (output.length != entry.size) {
      throw FormatException(
        'ONNX model ZIP entry has an invalid size: ${entry.name}',
      );
    }
    return LocalOnnxImportSource(name: fileName, path: outputPath);
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
        LocalOnnxModelKind.clTaggerV2,
        LocalOnnxModelKind.animeTimmEva02,
        LocalOnnxModelKind.pixaiTagger,
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
    await for (final entity in _listModelCandidates(directory)) {
      if (entity is! File) continue;
      if (p.extension(entity.path).toLowerCase() != '.onnx') continue;

      final relativePath = p.relative(entity.path, from: directory.path);
      final labelsPath = await _findLabelsFile(entity.path, relativePath);
      final kind = await _inferKind(entity.path, relativePath, labelsPath);
      if (!allowedKinds.contains(kind)) continue;

      result.add(
        LocalOnnxModelDescriptor(
          name: relativePath,
          path: entity.path,
          kind: kind,
          labelsPath: labelsPath,
        ),
      );
    }

    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  // 跳过隐藏目录：托管目录的 .import-* 里是未提交的暂存副本
  Stream<FileSystemEntity> _listModelCandidates(
    Directory directory, {
    int depth = 0,
  }) async* {
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! Directory) {
          yield entity;
        } else if (depth < _modelScanDepth &&
            !p.basename(entity.path).startsWith('.')) {
          yield* _listModelCandidates(entity, depth: depth + 1);
        }
      }
    } on FileSystemException catch (error) {
      // 一个读不了的子文件夹不应让整份模型列表失败
      if (depth == 0) rethrow;
      AppLogger.w(
        'Skipping unreadable ONNX model folder ${directory.path}: $error',
        'LocalOnnxModelService',
      );
    }
  }

  static String _sanitizeImportedFileName(String value) {
    final baseName = p
        .basename(value)
        .replaceAll(RegExp(r'[\x00-\x1f/\\]'), '_');
    if (baseName.isEmpty || baseName == '.' || baseName == '..') {
      throw const FormatException('Invalid model file name');
    }
    return baseName;
  }

  static bool _isSupportedImportFile(String fileName) {
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

  Future<LocalOnnxModelKind> _inferKind(
    String filePath,
    String relativePath,
    String? labelsPath,
  ) async {
    final lowerPath = filePath.toLowerCase();
    // 宽泛关键字只看根目录以下的路径，避免根目录名（如 ComfyUI-WD14-Tagger）误伤
    final lower = p.withoutExtension(relativePath).toLowerCase();
    final lowerLabels = labelsPath?.toLowerCase() ?? '';
    if (lowerPath.contains('cl_tagger_v2') ||
        lowerPath.contains('cl-tagger-v2') ||
        lowerLabels.endsWith('model_vocabulary.json')) {
      return LocalOnnxModelKind.clTaggerV2;
    }
    if (lowerPath.contains('eva02_large_patch14')) {
      return LocalOnnxModelKind.animeTimmEva02;
    }
    // 只看文件名与所在目录名，上层分类文件夹叫 pixai 不应波及其中所有模型
    final nameHint =
        '${p.basename(p.dirname(filePath))}/${p.basename(filePath)}'
            .toLowerCase();
    if (nameHint.contains('pixai') ||
        (labelsPath != null &&
            await OnnxTaggerLabelFiles.sniffFormat(labelsPath) !=
                OnnxTaggerLabelFormat.other)) {
      return LocalOnnxModelKind.pixaiTagger;
    }
    if (lower.contains('wd14') ||
        lower.contains('wd-v1-4') ||
        lower.contains('wd-v1-5') ||
        lower.contains('convnext') ||
        lower.contains('vit') ||
        lower.contains('swinv2')) {
      return LocalOnnxModelKind.wd14Tagger;
    }
    if ((lower.contains('cl') && lower.contains('tagger')) ||
        lowerLabels.endsWith('tag_mapping.json')) {
      return LocalOnnxModelKind.clTagger;
    }
    // 通用 selected_tags.csv 的 PixAI 导出只能靠同目录的预处理声明区分；带同名
    // 标签表的模型自成一套，多模型共用目录时不该被目录级声明改判
    if (labelsPath != null &&
        !_hasDedicatedLabels(filePath, labelsPath) &&
        await _declaresRescalePadPreprocessing(p.dirname(filePath))) {
      return LocalOnnxModelKind.pixaiTagger;
    }
    return LocalOnnxModelKind.unknown;
  }

  static bool _hasDedicatedLabels(String modelPath, String labelsPath) =>
      p.equals(p.withoutExtension(labelsPath), p.withoutExtension(modelPath));

  Future<bool> _declaresRescalePadPreprocessing(String directory) async {
    final preprocess = await _readJsonObject(
      p.join(directory, 'preprocess.json'),
    );
    final stages = preprocess?['stages'];
    if (stages is List &&
        stages.any((stage) => stage is Map && stage['type'] == 'rescale_pad')) {
      return true;
    }
    final processorConfig = await _readJsonObject(
      p.join(directory, 'preprocessor_config.json'),
    );
    return processorConfig?['image_processor_type'] == 'RescalePadProcessor';
  }

  Future<Map<String, dynamic>?> _readJsonObject(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<String?> _findLabelsFile(String onnxPath, String relativePath) async {
    final base = p.withoutExtension(onnxPath);
    final directory = p.dirname(onnxPath);

    if (relativePath.toLowerCase().contains('cl_tagger')) {
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
      'model_vocabulary.json',
      'tags.json',
    ]) {
      final candidate = p.join(directory, name);
      if (await File(candidate).exists()) {
        return candidate;
      }
    }

    // config.json 名字太通用，只认带 tags_split 的 HF 标签器配置
    final config = p.join(directory, 'config.json');
    if (await OnnxTaggerLabelFiles.sniffFormat(config) ==
        OnnxTaggerLabelFormat.splitTagConfig) {
      return config;
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

class _OnnxArchiveExtractionBudget {
  _OnnxArchiveExtractionBudget({
    required this.entryBytesLimit,
    required this.expandedBytesLimit,
  });

  final int entryBytesLimit;
  final int expandedBytesLimit;
  var _declaredBytes = 0;

  void reserveDeclared(int count, String entryName) {
    if (count < 0 || count > entryBytesLimit) {
      throw FormatException('ONNX model ZIP entry is too large: $entryName');
    }
    _declaredBytes += count;
    if (_declaredBytes > expandedBytesLimit) {
      throw const FormatException('Expanded ONNX model ZIP is too large');
    }
  }
}
