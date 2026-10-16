import 'dart:async';

import 'package:flutter/painting.dart';

/// 解析 provider 的首帧，5 秒内未出图即以超时失败。
Future<ImageInfo> resolveImageInfo(ImageProvider provider) {
  final stream = provider.resolve(ImageConfiguration.empty);
  return _firstImageInfo(stream.addListener, stream.removeListener);
}

Future<ImageInfo> firstImageInfo(ImageStreamCompleter completer) =>
    _firstImageInfo(completer.addListener, completer.removeListener);

Future<ImageInfo> _firstImageInfo(
  void Function(ImageStreamListener) addListener,
  void Function(ImageStreamListener) removeListener,
) {
  final completer = Completer<ImageInfo>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      removeListener(listener);
      if (!completer.isCompleted) completer.complete(info);
    },
    onError: (Object error, StackTrace? stackTrace) {
      removeListener(listener);
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  addListener(listener);
  return completer.future.timeout(const Duration(seconds: 5));
}
