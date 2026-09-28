import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import '../../core/enums/precise_ref_type.dart';
import '../models/precise_ref/precise_ref_library_entry.dart';

class PreciseRefImageCodec {
  const PreciseRefImageCodec._();

  static String detectExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return '.png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return '.webp';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return '.gif';
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return '.bmp';
    }
    throw const InvalidPreciseRefImageException();
  }
}

class InvalidPreciseRefImageException implements Exception {
  const InvalidPreciseRefImageException();

  @override
  String toString() => 'Unsupported or corrupt image data';
}

class PreciseRefLibraryFileSystem {
  const PreciseRefLibraryFileSystem();

  Future<void> writeBytes(String path, Uint8List bytes) async {
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<void> writeStream(String path, Stream<List<int>> bytes) async {
    final sink = File(path).openWrite(mode: FileMode.writeOnly);
    try {
      await sink.addStream(bytes);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();
  Stream<List<int>> openRead(String path) => File(path).openRead();
  Future<int> length(String path) => File(path).length();
  Future<bool> exists(String path) => File(path).exists();
  Future<void> delete(String path) => File(path).delete();

  Future<void> rename(String from, String to) async {
    await File(from).rename(to);
  }

  Stream<FileSystemEntity> list(String directory) =>
      Directory(directory).list();
}

class PreciseRefPortableImporter {
  const PreciseRefPortableImporter({
    required this.entries,
    required this.thumbnails,
    required this.fileSystem,
  });

  final Box<PreciseRefLibraryEntry> entries;
  final LazyBox<Uint8List> thumbnails;
  final PreciseRefLibraryFileSystem fileSystem;

  Future<PreciseRefLibraryEntry> import({
    required Stream<List<int>> bytes,
    required int expectedLength,
    required String directory,
    required String id,
    required String name,
    required PreciseRefType type,
    required double strength,
    required double fidelity,
    required bool isFavorite,
    required int usedCount,
    required DateTime? lastUsedAt,
    required DateTime createdAt,
  }) async {
    final entry = PreciseRefLibraryEntry(
      id: id,
      name: name.trim(),
      imagePath: '',
      typeIndex: type.index,
      strength: strength,
      fidelity: fidelity,
      isFavorite: isFavorite,
      usedCount: usedCount,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
    );
    final staged = p.join(
      directory,
      '${entry.id}.importing-${DateTime.now().microsecondsSinceEpoch}',
    );
    final previous = entries.get(entry.id);
    final previousThumbnail = await thumbnails.get(entry.id);
    String? previousBackup;
    String? targetBackup;
    var finalImageWritten = false;
    String? target;
    try {
      var actualLength = 0;
      final header = <int>[];
      await fileSystem.writeStream(
        staged,
        bytes.map((chunk) {
          actualLength += chunk.length;
          if (actualLength > expectedLength) {
            throw const FormatException('Portable resource length mismatch');
          }
          if (header.length < 12) {
            header.addAll(chunk.take(12 - header.length));
          }
          return chunk;
        }),
      );
      if (actualLength != expectedLength) {
        throw const FormatException('Portable resource length mismatch');
      }
      final extension = PreciseRefImageCodec.detectExtension(
        Uint8List.fromList(header),
      );
      target = p.join(directory, '${entry.id}$extension');
      final portableEntry = entry.copyWith(imagePath: target);
      final previousPath = previous?.imagePath;
      if (previousPath != null && await fileSystem.exists(previousPath)) {
        previousBackup =
            '$previousPath.deleting-${DateTime.now().microsecondsSinceEpoch}';
        await fileSystem.rename(previousPath, previousBackup);
      }
      if (target != previousPath && await fileSystem.exists(target)) {
        targetBackup =
            '$target.deleting-${DateTime.now().microsecondsSinceEpoch}';
        await fileSystem.rename(target, targetBackup);
      }
      await fileSystem.rename(staged, target);
      finalImageWritten = true;
      await entries.put(entry.id, portableEntry);
      await thumbnails.delete(entry.id);
      await _deleteIfExists(previousBackup);
      await _deleteIfExists(targetBackup);
      return portableEntry;
    } catch (_) {
      await _deleteIfExists(staged);
      if (finalImageWritten) await _deleteIfExists(target);
      if (previous == null) {
        await entries.delete(entry.id);
      } else {
        await entries.put(entry.id, previous);
      }
      if (previousThumbnail == null) {
        await thumbnails.delete(entry.id);
      } else {
        await thumbnails.put(entry.id, previousThumbnail);
      }
      await _restore(previousBackup, previous?.imagePath);
      await _restore(targetBackup, target);
      rethrow;
    }
  }

  Future<void> _restore(String? backup, String? target) async {
    if (backup != null &&
        target != null &&
        await fileSystem.exists(backup) &&
        !await fileSystem.exists(target)) {
      await fileSystem.rename(backup, target);
    }
  }

  Future<void> _deleteIfExists(String? path) async {
    if (path != null && await fileSystem.exists(path)) {
      await fileSystem.delete(path);
    }
  }
}
