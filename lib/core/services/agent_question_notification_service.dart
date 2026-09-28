import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

final agentQuestionNotificationServiceProvider = Provider((ref) {
  final service = AgentQuestionNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Android notification transport; question ownership stays in the agent.
class AgentQuestionNotificationService {
  AgentQuestionNotificationService({
    bool? supported,
    MethodChannel channel = const MethodChannel(
      'com.aaalice.nai_launcher/agent_questions',
    ),
    Future<bool> Function()? permissionGranted,
  }) : _supported = supported ?? (!kIsWeb && Platform.isAndroid),
       _channel = channel,
       _permissionGranted = permissionGranted ?? _hasPermission {
    if (_supported) _channel.setMethodCallHandler(_handleCall);
  }

  final bool _supported;
  final MethodChannel _channel;
  final Future<bool> Function() _permissionGranted;
  final _opened = StreamController<String>.broadcast();
  Future<void> _pending = Future.value();
  bool _disposed = false;
  Stream<String> get opened => _opened.stream;

  Future<void> _handleCall(MethodCall call) async {
    if (call.method == 'open' && !_disposed) {
      _opened.add(call.arguments as String);
    }
  }

  Future<void> show({
    required String requestId,
    required String title,
    required String message,
    required DateTime expiresAt,
  }) => _serialize(() async {
    if (!await _permissionGranted()) {
      throw StateError('Android notification permission is denied.');
    }
    if (_disposed || !DateTime.now().isBefore(expiresAt)) return;
    await _channel.invokeMethod<void>('show', {
      'requestId': requestId,
      'title': title,
      'message': message,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    });
  });

  Future<void> cancel() =>
      _serialize(() => _channel.invokeMethod<void>('cancel'));

  Future<void> _serialize(Future<void> Function() operation) {
    if (!_supported || _disposed) return Future.value();
    final result = _pending.then((_) => operation());
    // Keep cleanup possible after a failed show, while reporting to its caller.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<bool> _hasPermission() async =>
      (await ph.Permission.notification.status).isGranted;

  void dispose() {
    _disposed = true;
    if (_supported) _channel.setMethodCallHandler(null);
    unawaited(_opened.close());
  }
}
