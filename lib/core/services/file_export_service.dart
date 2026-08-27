import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/platform_capabilities.dart';
import '../utils/file_name_sanitizer.dart';

/// Writes generated files through the native document UI on Android.
///
/// Android document destinations are content URIs rather than writable Dart
/// file paths. Large exports are therefore streamed from an app-owned
/// temporary file by the native channel instead of copied through memory.
class FileExportService {
  FileExportService._();

  static const MethodChannel _channel = MethodChannel(
    'com.aaalice.nai_launcher/file_export',
  );

  static bool get _isAndroid => PlatformCapabilities.operatingSystem.isAndroid;

  static Future<String?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String dialogTitle,
    required String mimeType,
    required List<String> allowedExtensions,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Export bytes cannot be empty');
    }

    if (_isAndroid) {
      return _withTemporaryFile(
        bytes: bytes,
        fileName: fileName,
        action: (path) => saveFileFromPath(
          sourcePath: path,
          fileName: fileName,
          dialogTitle: dialogTitle,
          mimeType: mimeType,
          allowedExtensions: allowedExtensions,
        ),
      );
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (outputPath == null) return null;
    final normalizedPath = _ensureExtension(outputPath, allowedExtensions);
    await File(normalizedPath).writeAsBytes(bytes, flush: true);
    return normalizedPath;
  }

  static Future<String?> saveText({
    required String text,
    required String fileName,
    required String dialogTitle,
    required String mimeType,
    required List<String> allowedExtensions,
  }) {
    return saveBytes(
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileName: fileName,
      dialogTitle: dialogTitle,
      mimeType: mimeType,
      allowedExtensions: allowedExtensions,
    );
  }

  static Future<String?> saveFileFromPath({
    required String sourcePath,
    required String fileName,
    required String dialogTitle,
    required String mimeType,
    required List<String> allowedExtensions,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Export source does not exist', sourcePath);
    }

    if (_isAndroid) {
      return _channel.invokeMethod<String>('saveFileFromPath', {
        'sourcePath': sourcePath,
        'fileName': _safeFileName(fileName),
        'mimeType': mimeType,
      });
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (outputPath == null) return null;
    final normalizedPath = _ensureExtension(outputPath, allowedExtensions);
    if (p.equals(source.absolute.path, File(normalizedPath).absolute.path)) {
      return normalizedPath;
    }
    await source.copy(normalizedPath);
    return normalizedPath;
  }

  static Future<String?> pickExportDirectory({required String dialogTitle}) {
    if (_isAndroid) {
      return _channel.invokeMethod<String>('pickExportDirectory');
    }
    return FilePicker.platform.getDirectoryPath(dialogTitle: dialogTitle);
  }

  static Future<String> writeBytesToDirectory({
    required String directory,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Export bytes cannot be empty');
    }

    if (_isAndroid) {
      return _withTemporaryFile(
        bytes: bytes,
        fileName: fileName,
        action: (path) => writeFileToDirectory(
          directory: directory,
          sourcePath: path,
          fileName: fileName,
          mimeType: mimeType,
        ),
      ).then((value) {
        if (value == null) {
          throw const FileSystemException('Android document export failed');
        }
        return value;
      });
    }

    final outputPath = await _createUniqueFilePath(directory, fileName);
    await File(outputPath).writeAsBytes(bytes, flush: true);
    return outputPath;
  }

  static Future<String> writeTextToDirectory({
    required String directory,
    required String text,
    required String fileName,
    required String mimeType,
  }) {
    return writeBytesToDirectory(
      directory: directory,
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  static Future<String> writeFileToDirectory({
    required String directory,
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Export source does not exist', sourcePath);
    }

    if (_isAndroid) {
      final outputUri = await _channel
          .invokeMethod<String>('writeFileToDirectory', {
            'directoryUri': directory,
            'sourcePath': sourcePath,
            'fileName': _safeFileName(fileName),
            'mimeType': mimeType,
          });
      if (outputUri == null) {
        throw const FileSystemException('Android document export failed');
      }
      return outputUri;
    }

    final outputPath = await _createUniqueFilePath(directory, fileName);
    await source.copy(outputPath);
    return outputPath;
  }

  static Future<T> withTemporaryOutput<T>({
    required String fileName,
    required Future<T> Function(String path) action,
  }) async {
    final tempRoot = await getTemporaryDirectory();
    final exportDirectory = Directory(p.join(tempRoot.path, 'exports'));
    await exportDirectory.create(recursive: true);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final temporaryFile = File(
      p.join(exportDirectory.path, '${suffix}_${_safeFileName(fileName)}'),
    );
    try {
      return await action(temporaryFile.path);
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  static Future<String?> _withTemporaryFile({
    required Uint8List bytes,
    required String fileName,
    required Future<String?> Function(String path) action,
  }) {
    return withTemporaryOutput(
      fileName: fileName,
      action: (path) async {
        await File(path).writeAsBytes(bytes, flush: true);
        return action(path);
      },
    );
  }

  static String _safeFileName(String fileName) {
    final leafName = p.basename(fileName);
    final rawExtension = p.extension(leafName);
    final extension = RegExp(r'^\.[A-Za-z0-9]{1,24}$').hasMatch(rawExtension)
        ? rawExtension.toLowerCase()
        : '';
    final baseName = extension.isEmpty
        ? leafName
        : p.basenameWithoutExtension(leafName);
    final safeBaseName = FileNameSanitizer.sanitize(
      baseName,
      fallback: 'export',
      maxLength: 120,
    );
    return '$safeBaseName$extension';
  }

  static String _ensureExtension(
    String outputPath,
    List<String> allowedExtensions,
  ) {
    if (allowedExtensions.isEmpty || p.extension(outputPath).isNotEmpty) {
      return outputPath;
    }
    return '$outputPath.${allowedExtensions.first}';
  }

  static Future<String> _createUniqueFilePath(
    String directory,
    String fileName,
  ) async {
    final outputDirectory = Directory(directory);
    await outputDirectory.create(recursive: true);
    final safeName = _safeFileName(fileName);
    final extension = p.extension(safeName);
    final baseName = p.basenameWithoutExtension(safeName);
    var candidate = p.join(outputDirectory.path, safeName);
    var suffix = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(outputDirectory.path, '$baseName ($suffix)$extension');
      suffix++;
    }
    return candidate;
  }
}
