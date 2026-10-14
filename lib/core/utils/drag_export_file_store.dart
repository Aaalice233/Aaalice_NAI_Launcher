import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'file_name_sanitizer.dart';
import 'share_temp_directories.dart';

/// Real files handed to other applications by drag-out, kept until exit.
///
/// Receivers such as browser upload forms may read a dropped path long after
/// the drop, so files are never removed when the drag ends.
class DragExportFileStore {
  DragExportFileStore({Future<Directory> Function()? root})
    : _root =
          root ??
          (() => ShareTempDirectories.resolve(ShareTempDirectories.dragExport));

  static final DragExportFileStore instance = DragExportFileStore();

  final Future<Directory> Function() _root;
  Future<Directory>? _session;

  /// Each file gets its own folder so receivers see the plain [fileName].
  Future<File> write(String fileName, Uint8List bytes) async {
    final session = await (_session ??= _createSession());
    final folder = await session.createTemp('item_');
    final file = File(
      p.join(folder.path, FileNameSanitizer.shareName(fileName)),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> clear() async {
    final session = _session;
    _session = null;
    if (session == null) return;
    final directory = await session;
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<Directory> _createSession() async {
    try {
      final root = await _root();
      await root.create(recursive: true);
      return await root.createTemp('run_');
    } catch (_) {
      _session = null;
      rethrow;
    }
  }
}
