import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/enums/precise_ref_type.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/isolate_pool.dart';
import '../../core/utils/zip_archive_entry.dart';
import '../models/precise_ref/precise_ref_library_entry.dart';
import 'precise_ref_library_storage_service.dart';

class PreciseRefLibraryArchiveService {
  const PreciseRefLibraryArchiveService(
    this._storage, {
    String? stagingRootPath,
  }) : _stagingRootPath = stagingRootPath;

  static const extension = 'naipreciseref';
  static const _format = 'nai-precise-reference-library';
  static const _version = 1;
  static const _manifestPath = 'manifest.json';
  static const _maxEntries = 10000;
  static const _maxManifestBytes = 2 * 1024 * 1024;
  static const _maxImageBytes = 128 * 1024 * 1024;

  final PreciseRefLibraryStorageService _storage;
  final String? _stagingRootPath;

  Future<void> exportToPath({
    required List<PreciseRefLibraryEntry> entries,
    required String outputPath,
  }) async {
    if (entries.isEmpty) {
      throw StateError('No precise references were selected');
    }

    final records = <Map<String, Object?>>[];
    final resources = <String, File>{};
    for (final entry in entries) {
      final source = File(entry.imagePath);
      if (!await source.exists()) {
        throw FileSystemException(
          'Precise reference image is missing',
          entry.imagePath,
        );
      }
      final length = await source.length();
      if (length <= 0 || length > _maxImageBytes) {
        throw FormatException(
          'Invalid precise reference image size: ${entry.id}',
        );
      }
      final resource = 'images/${entry.id}${p.extension(entry.imagePath)}';
      if (resources.containsKey(resource)) {
        throw FormatException(
          'Duplicate precise reference resource: $resource',
        );
      }
      final digest = await sha256.bind(source.openRead()).first;
      resources[resource] = source;
      records.add({
        'id': entry.id,
        'name': entry.name,
        'type': entry.type.name,
        'strength': entry.strength,
        'fidelity': entry.fidelity,
        'isFavorite': entry.isFavorite,
        'usedCount': entry.usedCount,
        'lastUsedAt': entry.lastUsedAt?.toUtc().toIso8601String(),
        'createdAt': entry.createdAt.toUtc().toIso8601String(),
        'resource': resource,
        'length': length,
        'sha256': digest.toString(),
      });
    }

    final output = File(outputPath);
    await output.parent.create(recursive: true);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final staging = File('${output.path}.$suffix.part');
    final manifestFile = File('${output.path}.$suffix.manifest');
    final manifest = jsonEncode({
      'format': _format,
      'version': _version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'entries': records,
    });
    await manifestFile.writeAsString(manifest, encoding: utf8, flush: true);

    final encoder = ZipFileEncoder();
    var opened = false;
    try {
      encoder.create(staging.path);
      opened = true;
      await encoder.addFile(manifestFile, _manifestPath);
      for (final resource in resources.entries) {
        await encoder.addFile(resource.value, resource.key);
      }
      await encoder.close();
      opened = false;
      if (await output.exists()) await output.delete();
      await staging.rename(output.path);
    } finally {
      if (opened) {
        try {
          await encoder.close();
        } on Object {
          // Preserve the original export failure.
        }
      }
      if (await staging.exists()) await staging.delete();
      if (await manifestFile.exists()) await manifestFile.delete();
    }
  }

  Future<List<PreciseRefLibraryEntry>> importFromPath(
    String archivePath,
  ) async {
    final staging = await _createStagingDirectory();
    try {
      final staged = await ComputeGate().runCompute(
        _stageVerifiedResources,
        _ArchiveStagingRequest(
          archivePath: archivePath,
          stagingPath: staging.path,
        ),
        debugLabel: 'precise-ref-archive-import',
      );
      return await _importStaged(staged);
    } finally {
      await _deleteStagingDirectory(staging);
    }
  }

  Future<List<PreciseRefLibraryEntry>> _importStaged(
    List<_StagedResource> staged,
  ) async {
    final imported = <PreciseRefLibraryEntry>[];
    try {
      for (final resource in staged) {
        final record = resource.record;
        final entry = await _storage.importPortableEntryStream(
          File(resource.path).openRead(),
          expectedLength: record.length,
          id: const Uuid().v4(),
          name: record.name,
          type: record.type,
          strength: record.strength,
          fidelity: record.fidelity,
          isFavorite: record.isFavorite,
          usedCount: record.usedCount,
          lastUsedAt: record.lastUsedAt,
          createdAt: record.createdAt,
        );
        imported.add(entry);
      }
      return imported;
    } catch (_) {
      for (final entry in imported.reversed) {
        await _storage.deleteEntry(entry.id);
      }
      rethrow;
    }
  }

  Future<Directory> _createStagingDirectory() async {
    final rootPath = _stagingRootPath;
    final root = rootPath == null
        ? Directory.systemTemp
        : await Directory(rootPath).create(recursive: true);
    return root.createTemp('precise_ref_import_');
  }

  static Future<void> _deleteStagingDirectory(Directory staging) async {
    try {
      if (await staging.exists()) await staging.delete(recursive: true);
    } on FileSystemException catch (error) {
      // 暂存副本只是导入中转，清理失败不能改写已经确定的导入结果
      AppLogger.w(
        'Failed to delete precise reference import staging: $error',
        'PreciseRefLibrary',
      );
    }
  }

  // 按路径在后台读取并落盘暂存，只回传清单与路径，整档字节不跨 isolate 复制
  static Future<List<_StagedResource>> _stageVerifiedResources(
    _ArchiveStagingRequest request,
  ) async {
    final input = InputFileStream(request.archivePath);
    try {
      final archive = ZipDecoder().decodeBuffer(input);
      final fileCount = _countSafeFiles(archive);
      final records = _manifestRecords(archive);
      final resources = <String>{};
      final byName = {for (final file in archive.files) file.name: file};
      final staged = <_StagedResource>[];
      for (final record in records) {
        if (!resources.add(record.resource) ||
            !_isSafeResource(record.resource)) {
          throw FormatException(
            'Invalid precise reference resource: ${record.resource}',
          );
        }
        final file = byName[record.resource];
        if (file == null ||
            file.size != record.length ||
            file.size <= 0 ||
            file.size > _maxImageBytes) {
          throw FormatException(
            'Invalid precise reference resource length: ${record.resource}',
          );
        }
        final bytes = _bytes(file);
        PreciseRefLibraryStorageService.detectImageExtension(bytes);
        if (sha256.convert(bytes).toString() != record.sha256) {
          throw FormatException(
            'Precise reference checksum mismatch: ${record.resource}',
          );
        }
        final path = p.join(request.stagingPath, '${staged.length}.resource');
        await File(path).writeAsBytes(bytes);
        staged.add(_StagedResource(record: record, path: path));
        file.clear();
      }
      if (fileCount != resources.length + 1) {
        throw const FormatException(
          'Unexpected files in precise reference archive',
        );
      }
      return staged;
    } finally {
      await input.close();
    }
  }

  static int _countSafeFiles(Archive archive) {
    if (archive.files.isEmpty) {
      throw const FormatException('Invalid precise reference archive size');
    }
    final names = <String>{};
    for (final file in archive.files) {
      if (file.isSymbolicLink || !_isSafePath(file.name)) {
        throw FormatException(
          'Unsafe precise reference archive path: ${file.name}',
        );
      }
      if (isZipDirectoryEntry(file)) continue;
      if (!names.add(file.name.toLowerCase())) {
        throw FormatException(
          'Duplicate precise reference archive path: ${file.name}',
        );
      }
      // 目录项不占额度，上限只约束清单加资源文件
      if (names.length > _maxEntries + 1) {
        throw const FormatException('Invalid precise reference archive size');
      }
    }
    return names.length;
  }

  static List<_ArchiveRecord> _manifestRecords(Archive archive) {
    final manifestFile = archive.findFile(_manifestPath);
    if (manifestFile == null || manifestFile.size > _maxManifestBytes) {
      throw const FormatException('Invalid precise reference manifest');
    }
    final decoded = jsonDecode(utf8.decode(_bytes(manifestFile)));
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != _format ||
        decoded['version'] != _version ||
        decoded['entries'] is! List) {
      throw const FormatException('Unsupported precise reference archive');
    }
    final rawEntries = decoded['entries']! as List;
    if (rawEntries.isEmpty || rawEntries.length > _maxEntries) {
      throw const FormatException('Invalid precise reference entry count');
    }
    return rawEntries.map(_ArchiveRecord.parse).toList();
  }

  static Uint8List _bytes(ArchiveFile file) {
    final content = file.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    throw FormatException('Invalid archive content: ${file.name}');
  }

  static bool _isSafePath(String value) {
    if (value.isEmpty || value.contains('\u0000') || value.contains('\\')) {
      return false;
    }
    if (value.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(value)) {
      return false;
    }
    final normalized = zipEntryNameMarksDirectory(value)
        ? value.substring(0, value.length - 1)
        : value;
    return normalized.isNotEmpty &&
        normalized
            .split('/')
            .every((part) => part.isNotEmpty && part != '.' && part != '..');
  }

  static bool _isSafeResource(String value) =>
      _isSafePath(value) &&
      RegExp(
        r'^images/[0-9a-f-]+\.(png|jpe?g|webp|gif|bmp)$',
        caseSensitive: false,
      ).hasMatch(value);
}

class _ArchiveStagingRequest {
  const _ArchiveStagingRequest({
    required this.archivePath,
    required this.stagingPath,
  });

  final String archivePath;
  final String stagingPath;
}

class _StagedResource {
  const _StagedResource({required this.record, required this.path});

  final _ArchiveRecord record;
  final String path;
}

class _ArchiveRecord {
  const _ArchiveRecord({
    required this.name,
    required this.type,
    required this.strength,
    required this.fidelity,
    required this.isFavorite,
    required this.usedCount,
    required this.lastUsedAt,
    required this.createdAt,
    required this.resource,
    required this.length,
    required this.sha256,
  });

  final String name;
  final PreciseRefType type;
  final double strength;
  final double fidelity;
  final bool isFavorite;
  final int usedCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final String resource;
  final int length;
  final String sha256;

  factory _ArchiveRecord.parse(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid precise reference entry');
    }
    final typeName = value['type'];
    final type = PreciseRefType.values.cast<PreciseRefType?>().firstWhere(
      (item) => item?.name == typeName,
      orElse: () => null,
    );
    final lastUsedAt = value['lastUsedAt'];
    final createdAt = value['createdAt'];
    final parsedCreatedAt = createdAt is String
        ? DateTime.tryParse(createdAt)?.toUtc()
        : null;
    final parsedLastUsedAt = lastUsedAt is String
        ? DateTime.tryParse(lastUsedAt)?.toUtc()
        : null;
    final sourceId = value['id'];
    final strength = value['strength'];
    final fidelity = value['fidelity'];
    final resource = value['resource'];
    if (sourceId is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(sourceId) ||
        value['name'] is! String ||
        (value['name']! as String).trim().isEmpty ||
        type == null ||
        strength is! num ||
        !strength.toDouble().isFinite ||
        fidelity is! num ||
        !fidelity.toDouble().isFinite ||
        value['isFavorite'] is! bool ||
        value['usedCount'] is! int ||
        (value['usedCount']! as int) < 0 ||
        (lastUsedAt != null && parsedLastUsedAt == null) ||
        parsedCreatedAt == null ||
        resource is! String ||
        p.basenameWithoutExtension(resource).toLowerCase() !=
            sourceId.toLowerCase() ||
        value['length'] is! int ||
        (value['length']! as int) <= 0 ||
        value['sha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['sha256']! as String)) {
      throw const FormatException('Invalid precise reference entry fields');
    }
    return _ArchiveRecord(
      name: (value['name']! as String).trim(),
      type: type,
      strength: (value['strength']! as num).toDouble(),
      fidelity: (value['fidelity']! as num).toDouble(),
      isFavorite: value['isFavorite']! as bool,
      usedCount: value['usedCount']! as int,
      lastUsedAt: parsedLastUsedAt,
      createdAt: parsedCreatedAt,
      resource: resource,
      length: value['length']! as int,
      sha256: value['sha256']! as String,
    );
  }
}
