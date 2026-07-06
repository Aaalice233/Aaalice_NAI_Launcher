import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/utils/window_state_persistence.dart';

void main() {
  test(
    'persistWindowStateSnapshot writes window bounds with storage keys',
    () async {
      final values = <String, Object>{};

      await persistWindowStateSnapshot(
        put: (key, value) async {
          values[key] = value;
        },
        snapshot: const WindowStateSnapshot(
          size: Size(1200.5, 800.25),
          position: Offset(32.75, 48.5),
        ),
      );

      expect(values, {
        StorageKeys.windowWidth: 1200.5,
        StorageKeys.windowHeight: 800.25,
        StorageKeys.windowX: 32.75,
        StorageKeys.windowY: 48.5,
      });
    },
  );
}
