import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

final androidForegroundTaskServiceProvider = Provider(
  (ref) => AndroidForegroundTaskService(),
);

/// Shares Android's foreground execution between generation and Agent runs.
class AndroidForegroundTaskService {
  AndroidForegroundTaskService({
    bool? supported,
    MethodChannel channel = const MethodChannel(
      'com.aaalice.nai_launcher/generation_service',
    ),
    Future<void> Function()? requestNotificationPermission,
  }) : _supported = supported ?? (!kIsWeb && Platform.isAndroid),
       _channel = channel,
       _requestNotificationPermission =
           requestNotificationPermission ?? _requestPermission;

  final bool _supported;
  final MethodChannel _channel;
  final Future<void> Function() _requestNotificationPermission;
  Future<void> _pending = Future<void>.value();
  int _owners = 0;

  /// The returned release is idempotent and belongs to this invocation only.
  Future<Future<void> Function()> acquire() async {
    if (!_supported) return () async {};
    await _serialize(() async {
      if (_owners == 0) {
        await _requestNotificationPermission();
        await _channel.invokeMethod<void>('start');
      }
      _owners++;
    });
    Future<void>? released;
    return () => released ??= _serialize(() async {
      _owners--;
      if (_owners == 0) await _channel.invokeMethod<void>('stop');
    });
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    // A failed platform call must reach its caller without poisoning later
    // owners' cleanup or acquisition.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<void> _requestPermission() async {
    final notificationStatus = await ph.Permission.notification.status;
    if (notificationStatus.isDenied) {
      await ph.Permission.notification.request();
    }
  }
}
