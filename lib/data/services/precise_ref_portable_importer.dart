import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:path/path.dart' as p;

import '../../core/enums/precise_ref_type.dart';
import '../../core/storage/storage_file_system.dart';
import '../../core/utils/image_file_signature.dart';
import '../models/precise_ref/precise_ref_library_entry.dart';

class PreciseRefImageCodec {
  const PreciseRefImageCodec._();

  static String detectExtension(Uint8List bytes) =>
      detectImageExtensionFromHeader(bytes) ??
      (throw const InvalidPreciseRefImageException());
}

class InvalidPreciseRefImageException implements Exception {
  const InvalidPreciseRefImageException();

  @override
  String toString() => 'Unsupported or corrupt image data';
}

class PreciseRefPortableImporter {
  const PreciseRefPortableImporter({
    required this.entries,
    required this.thumbnails,
    required this.fileSystem,
  });

  final Box<PreciseRefLibraryEntry> entries;
  final LazyBox<Uint8List> thumbnails;
  final StorageFileSystem fileSystem;

  Future<PreciseRefLibraryEntry> import({
    required Stream<List<int>> bytes,
    required int expectedLength,
    required String directory,
    required String id,
    required String name,
    required PreciseRefType type,
    bool? preferSameOutfit,
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
      preferSameOutfit: preferSameOutfit,
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
