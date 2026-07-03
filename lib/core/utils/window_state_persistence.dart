import 'dart:ui';

import '../constants/storage_keys.dart';

typedef WindowStatePut = Future<void> Function(String key, Object value);

class WindowStateSnapshot {
  const WindowStateSnapshot({required this.size, required this.position});

  final Size size;
  final Offset position;
}

Future<void> persistWindowStateSnapshot({
  required WindowStatePut put,
  required WindowStateSnapshot snapshot,
}) async {
  await put(StorageKeys.windowWidth, snapshot.size.width);
  await put(StorageKeys.windowHeight, snapshot.size.height);
  await put(StorageKeys.windowX, snapshot.position.dx);
  await put(StorageKeys.windowY, snapshot.position.dy);
}
