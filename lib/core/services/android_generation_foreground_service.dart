import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Keeps an active image-generation request in Android's foreground-service
/// execution class after the user backgrounds the app.
class AndroidGenerationForegroundService {
  AndroidGenerationForegroundService._();

  static const MethodChannel _channel = MethodChannel(
    'com.aaalice.nai_launcher/generation_service',
  );

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<void> start() async {
    if (!isSupported) return;
    final notificationStatus = await ph.Permission.notification.status;
    if (notificationStatus.isDenied) {
      await ph.Permission.notification.request();
    }
    await _channel.invokeMethod<void>('start');
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('stop');
  }
}
