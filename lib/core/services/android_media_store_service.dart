import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../platform/platform_capabilities.dart';
import '../utils/media_mime_type.dart';
import '../utils/permission_utils.dart';
import 'file_export_service.dart';

/// Publishes app-managed images to Android's shared Pictures collection.
///
/// App-managed gallery files remain the source of truth. Publishing makes a
/// separate copy visible to the system gallery and keeps it after app removal.
class AndroidMediaStoreService {
  AndroidMediaStoreService._();

  static const MethodChannel _channel = MethodChannel(
    'com.aaalice.nai_launcher/media_store',
  );

  static Future<String?> savePng({
    required Uint8List bytes,
    required String fileName,
  }) => saveImage(bytes: bytes, fileName: fileName, mimeType: 'image/png');

  static Future<String?> saveImage({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (!PlatformCapabilities.current.isAndroid) return null;
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Image bytes cannot be empty');
    }
    return FileExportService.withTemporaryOutput(
      fileName: fileName,
      action: (sourcePath) async {
        await File(sourcePath).writeAsBytes(bytes, flush: true);
        return saveImageFromPath(
          sourcePath: sourcePath,
          fileName: fileName,
          mimeType: mimeType,
        );
      },
    );
  }

  static Future<String?> saveImageFromPath({
    required String sourcePath,
    required String fileName,
    String? mimeType,
  }) async {
    if (!PlatformCapabilities.current.isAndroid) return null;
    if (!await FileSystemEntity.isFile(sourcePath)) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'Image file does not exist',
      );
    }
    if (!await PermissionUtils.requestLegacyMediaWritePermission()) {
      throw PlatformException(
        code: 'media_permission_denied',
        message: 'Permission to save images was denied',
      );
    }

    final resolvedMimeType =
        mimeType ?? mediaMimeTypeForExtension(p.extension(fileName));
    if (!resolvedMimeType.startsWith('image/')) {
      throw ArgumentError.value(
        resolvedMimeType,
        'mimeType',
        'A valid image MIME type is required',
      );
    }
    return _channel.invokeMethod<String>('saveImageFromPath', {
      'sourcePath': sourcePath,
      'fileName': fileName,
      'mimeType': resolvedMimeType,
    });
  }
}
