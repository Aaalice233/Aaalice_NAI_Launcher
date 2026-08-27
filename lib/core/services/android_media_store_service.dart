import 'dart:io';

import 'package:flutter/services.dart';

import '../platform/platform_capabilities.dart';
import '../utils/permission_utils.dart';
import 'file_export_service.dart';

/// Publishes user-requested images to Android's shared Pictures collection.
///
/// App-managed gallery files remain in application storage. This service is
/// used only for an explicit save/export action so generated images are also
/// visible to the system gallery and survive app removal.
class AndroidMediaStoreService {
  AndroidMediaStoreService._();

  static const MethodChannel _channel = MethodChannel(
    'com.aaalice.nai_launcher/media_store',
  );

  static Future<String?> savePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!PlatformCapabilities.operatingSystem.isAndroid) {
      return null;
    }
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Image bytes cannot be empty');
    }
    if (!await PermissionUtils.requestLegacyMediaWritePermission()) {
      throw PlatformException(
        code: 'media_permission_denied',
        message: 'Permission to save images was denied',
      );
    }

    return FileExportService.withTemporaryOutput(
      fileName: fileName,
      action: (sourcePath) async {
        await File(sourcePath).writeAsBytes(bytes, flush: true);
        return _channel.invokeMethod<String>('saveImageFromPath', {
          'sourcePath': sourcePath,
          'fileName': fileName,
          'mimeType': 'image/png',
        });
      },
    );
  }
}
