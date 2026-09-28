import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/utils/window_state_persistence.dart';

void main() {
  test('persists normal bounds and maximized state atomically', () async {
    final values = <String, Object>{};

    await persistWindowStateSnapshot(
      put: (key, value) async => values[key] = value,
      snapshot: const WindowStateSnapshot(
        normalBounds: Rect.fromLTWH(32.75, 48.5, 1200.5, 800.25),
        maximized: true,
      ),
    );

    expect(values.keys, [StorageKeys.windowStateV2]);
    expect(values[StorageKeys.windowStateV2], {
      'version': 2,
      'x': 32.75,
      'y': 48.5,
      'width': 1200.5,
      'height': 800.25,
      'maximized': true,
      'scaleFactor': 1.0,
    });
  });

  test('reads v2 state and rejects malformed snapshots', () {
    final valid = readWindowStateSnapshot(
      storedState: const {
        'version': 2,
        'x': -1200,
        'y': 20,
        'width': 1000,
        'height': 700,
        'maximized': true,
      },
      legacyWidth: null,
      legacyHeight: null,
      legacyX: null,
      legacyY: null,
    );
    expect(valid.normalBounds, const Rect.fromLTWH(-1200, 20, 1000, 700));
    expect(valid.maximized, isTrue);

    final malformed = readWindowStateSnapshot(
      storedState: const {
        'version': 2,
        'x': 10,
        'y': 10,
        'width': -1,
        'height': 700,
        'maximized': true,
      },
      legacyWidth: 1100,
      legacyHeight: 750,
      legacyX: 30,
      legacyY: 40,
    );
    expect(malformed.normalBounds, const Rect.fromLTWH(30, 40, 1100, 750));
    expect(malformed.maximized, isFalse);
  });

  test('migrates legacy logical bounds into native coordinates', () {
    final legacy = readWindowStateSnapshot(
      storedState: null,
      legacyWidth: 1280,
      legacyHeight: 720,
      legacyX: null,
      legacyY: null,
      legacyScale: 1.5,
    );

    expect(legacy.normalBounds, const Rect.fromLTWH(0, 0, 1920, 1080));
    expect(legacy.positionKnown, isFalse);
    expect(legacy.maximized, isFalse);
  });

  test('migrates a secondary-display legacy rect with its own scale', () {
    const primary = Rect.fromLTWH(0, 0, 2880, 1560);
    const secondary = Rect.fromLTWH(-1920, 0, 1920, 1040);
    final legacy = readWindowStateSnapshot(
      storedState: null,
      legacyWidth: 1200,
      legacyHeight: 800,
      legacyX: -1800,
      legacyY: 40,
      legacyScale: 1.5,
      legacyWorkAreaScaleFactors: {primary: 1.5, secondary: 1.0},
    );

    expect(legacy.normalBounds, const Rect.fromLTWH(-1800, 40, 1200, 800));
    expect(legacy.scaleFactor, 1);
  });

  group('resolveWindowRestorePlan', () {
    const primary = Rect.fromLTWH(0, 0, 1920, 1040);
    const secondary = Rect.fromLTWH(-1280, 0, 1280, 984);

    test('keeps a valid secondary-display window on that display', () {
      final plan = resolveWindowRestorePlan(
        snapshot: const WindowStateSnapshot(
          normalBounds: Rect.fromLTWH(-1200, 80, 1000, 700),
          maximized: true,
        ),
        workAreas: const [primary, secondary],
        primaryWorkArea: primary,
      );

      expect(plan.normalBounds, const Rect.fromLTWH(-1200, 80, 1000, 700));
      expect(plan.maximized, isTrue);
    });

    test('centers an off-screen window on the primary work area', () {
      final plan = resolveWindowRestorePlan(
        snapshot: const WindowStateSnapshot(
          normalBounds: Rect.fromLTWH(5000, 4000, 1200, 800),
          maximized: false,
        ),
        workAreas: const [primary, secondary],
        primaryWorkArea: primary,
      );

      expect(plan.normalBounds, const Rect.fromLTWH(360, 120, 1200, 800));
    });

    test('clamps size and position after work-area changes', () {
      final plan = resolveWindowRestorePlan(
        snapshot: const WindowStateSnapshot(
          normalBounds: Rect.fromLTWH(1700, 900, 2400, 1400),
          maximized: false,
        ),
        workAreas: const [primary],
        primaryWorkArea: primary,
      );

      expect(plan.normalBounds, primary);
    });

    test('applies the target display scale to minimum constraints', () {
      final plan = resolveWindowRestorePlan(
        snapshot: const WindowStateSnapshot(
          normalBounds: Rect.fromLTWH(-1200, 40, 10, 10),
          maximized: false,
        ),
        workAreas: const [primary, secondary],
        primaryWorkArea: primary,
        workAreaScaleFactors: {secondary: 1.5},
      );

      expect(plan.normalBounds.width, 1200);
      expect(plan.normalBounds.height, 900);
      expect(secondary.contains(plan.normalBounds.topLeft), isTrue);
    });

    test('preserves logical size when the target display scale changes', () {
      final plan = resolveWindowRestorePlan(
        snapshot: const WindowStateSnapshot(
          normalBounds: Rect.fromLTWH(5000, 4000, 2400, 1600),
          maximized: false,
          scaleFactor: 2,
        ),
        workAreas: const [primary],
        primaryWorkArea: primary,
        workAreaScaleFactors: {primary: 1},
      );

      expect(plan.normalBounds.size, const Size(1200, 800));
      expect(plan.scaleFactor, 1);
    });

    test('uses minimum usable size on a smaller work area', () {
      const small = Rect.fromLTWH(0, 0, 640, 480);
      final plan = resolveWindowRestorePlan(
        snapshot: const WindowStateSnapshot(
          normalBounds: Rect.fromLTWH(0, 0, 1600, 900),
          maximized: false,
          positionKnown: false,
        ),
        workAreas: const [small],
        primaryWorkArea: small,
      );

      expect(plan.normalBounds, const Rect.fromLTWH(0, 0, 800, 600));
    });
  });
}
