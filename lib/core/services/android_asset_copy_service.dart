import 'dart:io';

import 'package:flutter/services.dart';

import '../platform/platform_capabilities.dart';

/// Streams large Flutter assets into app-owned files without loading the
/// complete payload into the Dart heap on Android.
class AndroidAssetCopyService {
  AndroidAssetCopyService._();

  static const MethodChannel _channel = MethodChannel(
    'com.aaalice.nai_launcher/asset_copy',
  );

  static Future<void> copyAssetToFile({
    required String assetKey,
    required File target,
  }) async {
    if (!PlatformCapabilities.operatingSystem.isAndroid) {
      throw UnsupportedError('Native asset streaming is Android-only.');
    }

    final copiedLength = await _channel.invokeMethod<int>('copyAssetToPath', {
      'assetKey': assetKey,
      'targetPath': target.path,
    });
    if (copiedLength == null || copiedLength <= 0 || !await target.exists()) {
      throw const FileSystemException('Android asset copy produced no file.');
    }
  }
}
