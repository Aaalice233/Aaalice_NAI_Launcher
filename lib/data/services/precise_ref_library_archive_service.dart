import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/enums/precise_ref_type.dart';
import '../models/precise_ref/precise_ref_library_entry.dart';
import 'precise_ref_library_storage_service.dart';

class PreciseRefLibraryArchiveService {
  const PreciseRefLibraryArchiveService(this._storage);

  static const extension = 'naipreciseref';
  static const _format = 'nai-precise-reference-library';
  static const _version = 1;
  static const _manifestPath = 'manifest.json';
  static const _maxEntries = 10000;
  static const _maxManifestBytes = 2 * 1024 * 1024;
  static const _maxImageBytes = 128 * 1024 * 1024;

  final PreciseRefLibraryStorageService _storage;

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
    final manifest = await _preflight(archivePath);
    final imported = <PreciseRefLibraryEntry>[];
    final input = InputFileStream(archivePath);
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBuffer(input);
      final byName = {for (final file in archive.files) file.name: file};
      for (final record in manifest) {
        final resource = record.resource;
        final archiveFile = byName[resource];
        if (archiveFile == null) {
          throw FormatException(
            'Missing precise reference resource: $resource',
          );
        }
        final bytes = _bytes(archiveFile);
        final entry = await _storage.importPortableEntry(
          bytes,
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
        archiveFile.clear();
      }
      return imported;
    } catch (_) {
      for (final entry in imported.reversed) {
        await _storage.deleteEntry(entry.id);
      }
      rethrow;
    } finally {
      await input.close();
    }
  }

  Future<List<_ArchiveRecord>> _preflight(String archivePath) async {
    final input = InputFileStream(archivePath);
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBuffer(input);
      if (archive.files.isEmpty || archive.files.length > _maxEntries + 1) {
        throw const FormatException('Invalid precise reference archive size');
      }
      final names = <String>{};
      for (final file in archive.files) {
        if (!file.isFile || file.isSymbolicLink || !_isSafePath(file.name)) {
          throw FormatException(
            'Unsafe precise reference archive path: ${file.name}',
          );
        }
        if (!names.add(file.name.toLowerCase())) {
          throw FormatException(
            'Duplicate precise reference archive path: ${file.name}',
          );
        }
      }
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
      final records = rawEntries.map(_ArchiveRecord.parse).toList();
      final resources = <String>{};
      final byName = {for (final file in archive.files) file.name: file};
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
        file.clear();
      }
      if (names.length != resources.length + 1) {
        throw const FormatException(
          'Unexpected files in precise reference archive',
        );
      }
      return records;
    } finally {
      await input.close();
    }
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
    final parts = value.split('/');
    return parts.every(
      (part) => part.isNotEmpty && part != '.' && part != '..',
    );
  }

  static bool _isSafeResource(String value) =>
      _isSafePath(value) &&
      RegExp(
        r'^images/[0-9a-f-]+\.(png|jpe?g|webp|gif|bmp)$',
        caseSensitive: false,
      ).hasMatch(value);
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
