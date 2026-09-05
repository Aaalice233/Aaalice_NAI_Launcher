import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PortableThumbnailMutation {
  PortableThumbnailMutation(this.path, this._target, this._backups);

  final String? path;
  final File? _target;
  final Map<File, File> _backups;

  Future<void> commit() async {
    for (final backup in _backups.values) {
      if (await backup.exists()) await backup.delete();
    }
  }

  Future<void> rollback() async {
    if (_target != null && await _target.exists()) await _target.delete();
    for (final entry in _backups.entries) {
      if (await entry.value.exists() && !await entry.key.exists()) {
        await entry.value.rename(entry.key.path);
      }
    }
  }
}

class TagLibraryPortableThumbnailStore {
  const TagLibraryPortableThumbnailStore();

  static const directoryName = 'tag_library_thumbnails';

  static final _entryIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,191}$');
  static final _extensionPattern = RegExp(r'^\.(png|jpe?g|webp|gif|bmp)$');

  static bool isValidEntryId(String value) => _entryIdPattern.hasMatch(value);

  static bool isSupportedExtension(String value) =>
      _extensionPattern.hasMatch(value.toLowerCase());

  static Future<Directory> resolveDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, directoryName));
  }

  Future<PortableThumbnailMutation> stage(
    String entryId, {
    required String? extension,
    required Stream<List<int>>? bytes,
    String? existingPath,
  }) async {
    if (!isValidEntryId(entryId)) {
      throw const FormatException('Invalid tag library entry ID');
    }
    final safeExtension = extension?.toLowerCase();
    if (safeExtension != null && !isSupportedExtension(safeExtension)) {
      throw const FormatException('Unsupported tag library thumbnail');
    }
    if ((safeExtension == null) != (bytes == null)) {
      throw ArgumentError('Thumbnail extension and bytes must match');
    }
    final directory = await resolveDirectory();
    await directory.create(recursive: true);
    final target = safeExtension == null
        ? null
        : File(p.join(directory.path, '$entryId$safeExtension'));
    final token = DateTime.now().microsecondsSinceEpoch;
    final existing = <String, File>{
      if (existingPath?.isNotEmpty == true)
        p.normalize(existingPath!): File(existingPath),
      await for (final entity in directory.list())
        if (entity is File &&
            p.basenameWithoutExtension(entity.path) == entryId &&
            isSupportedExtension(p.extension(entity.path)))
          p.normalize(entity.path): entity,
    };
    final backups = <File, File>{};
    File? staged;
    try {
      for (final file in existing.values) {
        if (!await file.exists()) continue;
        final backup = File('${file.path}.cloud-backup-$token');
        await file.rename(backup.path);
        backups[file] = backup;
      }
      if (target != null) {
        staged = File('${target.path}.cloud-import-$token');
        final sink = staged.openWrite(mode: FileMode.writeOnly);
        try {
          await sink.addStream(bytes!);
          await sink.flush();
        } finally {
          await sink.close();
        }
        await staged.rename(target.path);
      }
      return PortableThumbnailMutation(target?.path, target, backups);
    } catch (_) {
      if (staged != null && await staged.exists()) await staged.delete();
      await PortableThumbnailMutation(null, target, backups).rollback();
      rethrow;
    }
  }
}
