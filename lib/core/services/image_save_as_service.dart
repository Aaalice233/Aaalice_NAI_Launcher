import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/models/gallery/nai_image_metadata.dart';
import '../save_naming/image_save_naming.dart';
import '../save_naming/save_name_context.dart';
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
    DateTime? createdAt,
    String? imageId,
  }) : this.deferred(
         loadBytes: () async => bytes,
         filePath: filePath,
         metadata: metadata,
         preserveOriginalBytes: preserveOriginalBytes,
         createdAt: createdAt,
         imageId: imageId,
       );

  const ImageSaveAsSource.deferred({
    required this.loadBytes,
    this.filePath,
    this.metadata,
    this.preserveOriginalBytes = false,
    this.createdAt,
    this.imageId,
  });

  final Future<Uint8List> Function() loadBytes;
  final String? filePath;
  final NaiImageMetadata? metadata;
  final bool preserveOriginalBytes;

  /// Generation time used by date fields of the suggested file name; the
  /// export time stands in when unknown.
  final DateTime? createdAt;
  final String? imageId;
}

/// Exports copies to user-chosen locations without touching the gallery or
/// the image's saved path. Unsaved images are written exactly as the gallery
/// Save would write them, and named by the same [ImageSaveNaming] rule.
class ImageSaveAsService {
  ImageSaveAsService._();

  static const String mimeType = 'image/png';
  static const List<String> _allowedExtensions = ['png'];

  /// Returns the saved location, or null when the user cancels the dialog.
  static Future<String?> saveOne(
    ImageSaveAsSource source, {
    required String dialogTitle,
    required ImageSaveNaming naming,
    bool preventOverwrite = false,
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
    final prepared = await _prepareBytes(source, naming: naming);
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
  ///
  /// [index] is the source's position in a multi-image export.
  static Future<String> writeToDirectory(
    ImageSaveAsSource source, {
    required String directory,
    required ImageSaveNaming naming,
    int index = 0,
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
    final prepared = await _prepareBytes(source, naming: naming, index: index);
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
    required ImageSaveNaming naming,
    int index = 0,
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
        : await ImageSaveUtils.galleryFileName(
            bytes: prepared.bytes,
            naming: naming,
            context: prepared.namingContext(
              SaveNameContext(
                createdAt: source.createdAt ?? DateTime.now(),
                imageId: source.imageId,
                index: index,
              ),
            ),
          );
    return (bytes: prepared.bytes, fileName: fileName);
  }
}
