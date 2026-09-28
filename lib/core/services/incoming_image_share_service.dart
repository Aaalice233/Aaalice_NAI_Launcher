import 'dart:async';

import 'package:flutter/services.dart';

/// Android owns the pending intents so cold-start shares survive Dart startup.
class IncomingImageShareService {
  IncomingImageShareService({
    MethodChannel channel = const MethodChannel(
      'com.aaalice.nai_launcher/image_share',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;
  final _available = StreamController<void>.broadcast();

  Stream<void> get available => _available.stream;

  void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'available') _available.add(null);
    });
  }

  Future<Map<Object?, Object?>?> takeNext() =>
      _channel.invokeMapMethod<Object?, Object?>('takeNext');

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_available.close());
  }
}
