import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/models/gallery/nai_image_metadata.dart';
import '../utils/image_save_utils.dart';
import 'file_export_service.dart';

/// An image to export. A copy already saved to the gallery is exported as the
/// file itself; the bytes are only loaded when that file is unavailable.
class ImageSaveAsSource {
  ImageSaveAsSource({
    required Uint8List bytes,
    String? filePath,
    NaiImageMetadata? metadata,
    bool preserveOriginalBytes = false,
  }) : this.deferred(
         loadBytes: () async => bytes,
         filePath: filePath,
         metadata: metadata,
         preserveOriginalBytes: preserveOriginalBytes,
       );

  const ImageSaveAsSource.deferred({
    required this.loadBytes,
    this.filePath,
    this.metadata,
    this.preserveOriginalBytes = false,
  });

  final Future<Uint8List> Function() loadBytes;
  final String? filePath;
  final NaiImageMetadata? metadata;
  final bool preserveOriginalBytes;
}

/// Exports copies to user-chosen locations without touching the gallery or
/// the image's saved path. Unsaved images are written exactly as the gallery
/// Save would write them.
class ImageSaveAsService {
  ImageSaveAsService._();

  static const String mimeType = 'image/png';
  static const List<String> _allowedExtensions = ['png'];

  /// Returns the saved location, or null when the user cancels the dialog.
  static Future<String?> saveOne(
    ImageSaveAsSource source, {
    required String dialogTitle,
    bool preventOverwrite = false,
    DateTime? now,
  }) async {
    final sourcePath = await _existingFilePath(source);
    if (sourcePath != null) {
      return FileExportService.saveFileFromPath(
        sourcePath: sourcePath,
        fileName: p.basename(sourcePath),
        dialogTitle: dialogTitle,
        mimeType: mimeType,
        allowedExtensions: _allowedExtensions,
        preventOverwrite: preventOverwrite,
      );
    }
    final prepared = await _prepareBytes(source, now: now);
    return FileExportService.saveBytes(
      bytes: prepared.bytes,
      fileName: prepared.fileName,
      dialogTitle: dialogTitle,
      mimeType: mimeType,
      allowedExtensions: _allowedExtensions,
      preventOverwrite: preventOverwrite,
    );
  }

  /// Writes into [directory] from [FileExportService.pickExportDirectory];
  /// name conflicts get a `(n)` suffix instead of overwriting.
  static Future<String> writeToDirectory(
    ImageSaveAsSource source, {
    required String directory,
    DateTime? now,
  }) async {
    final sourcePath = await _existingFilePath(source);
    if (sourcePath != null) {
      return FileExportService.writeFileToDirectory(
        directory: directory,
        sourcePath: sourcePath,
        fileName: p.basename(sourcePath),
        mimeType: mimeType,
      );
    }
    final prepared = await _prepareBytes(source, now: now);
    return FileExportService.writeBytesToDirectory(
      directory: directory,
      bytes: prepared.bytes,
      fileName: prepared.fileName,
      mimeType: mimeType,
    );
  }

  // A gallery copy deleted after generation still exports from memory.
  static Future<String?> _existingFilePath(ImageSaveAsSource source) async {
    final filePath = source.filePath;
    if (filePath == null || filePath.isEmpty) return null;
    return await File(filePath).exists() ? filePath : null;
  }

  static Future<({Uint8List bytes, String fileName})> _prepareBytes(
    ImageSaveAsSource source, {
    DateTime? now,
  }) async {
    final original = await source.loadBytes();
    if (original.isEmpty) {
      throw StateError('Image bytes are unavailable for export');
    }
    final prepared = await ImageSaveUtils.prepareResultBytes(
      imageBytes: original,
      preserveOriginalBytes: source.preserveOriginalBytes,
      metadata: source.metadata,
    );
    final filePath = source.filePath;
    final fileName = filePath != null && filePath.isNotEmpty
        ? p.basename(filePath)
        : ImageSaveUtils.galleryFileName(
            seed: await prepared.resolveSeed(),
            now: now,
          );
    return (bytes: prepared.bytes, fileName: fileName);
  }
}
