import 'dart:io';

import 'package:flutter/services.dart';

class AndroidAppInstallException implements Exception {
  final String message;
  final Object? originalError;

  const AndroidAppInstallException(this.message, {this.originalError});

  @override
  String toString() =>
      'AndroidAppInstallException: $message${originalError == null ? '' : ' ($originalError)'}';
}

/// Opens a verified APK with Android's package installer.
///
/// The native side accepts only files in this app's private update cache and
/// requests the per-app unknown-sources permission when Android requires it.
class AndroidAppInstallerService {
  const AndroidAppInstallerService();

  static const _channel = MethodChannel(
    'com.aaalice.nai_launcher/app_installer',
  );

  Future<void> installApk(String apkPath) async {
    if (!Platform.isAndroid) {
      throw const AndroidAppInstallException(
        'APK installation is available only on Android',
      );
    }

    try {
      final launched = await _channel.invokeMethod<bool>('installApk', {
        'path': apkPath,
      });
      if (launched != true) {
        throw const AndroidAppInstallException(
          'Android did not open the package installer',
        );
      }
    } on PlatformException catch (error) {
      throw AndroidAppInstallException(
        error.message ?? 'Unable to open the Android package installer',
        originalError: error,
      );
    } on MissingPluginException catch (error) {
      throw AndroidAppInstallException(
        'Android package installer integration is unavailable',
        originalError: error,
      );
    }
  }
}
