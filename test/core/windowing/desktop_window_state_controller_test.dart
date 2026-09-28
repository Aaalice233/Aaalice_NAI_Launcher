import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/window_state_persistence.dart';
import 'package:nai_launcher/core/windowing/desktop_window_state_controller.dart';

class _FakeWindowStatePlatform implements DesktopWindowStatePlatform {
  Rect bounds = const Rect.fromLTWH(20, 30, 1200, 800);
  bool maximized = false;
  bool minimized = false;
  int reads = 0;

  @override
  Future<DesktopWindowStateReading> readState() async {
    reads++;
    return DesktopWindowStateReading(
      bounds: bounds,
      maximized: maximized,
      minimized: minimized,
      scaleFactor: 1.25,
    );
  }
}

void main() {
  late _FakeWindowStatePlatform platform;
  late List<WindowStateSnapshot> writes;
  late DesktopWindowStateController controller;

  setUp(() {
    platform = _FakeWindowStatePlatform();
    writes = [];
    controller = DesktopWindowStateController(
      initialState: const WindowStateSnapshot(
        normalBounds: Rect.fromLTWH(10, 10, 1000, 700),
        maximized: false,
      ),
      platform: platform,
      persist: (snapshot) async => writes.add(snapshot),
    );
  });

  test('captures the final normal bounds', () async {
    await controller.captureCurrentState();

    expect(writes.single.normalBounds, platform.bounds);
    expect(writes.single.maximized, isFalse);
  });

  test('maximized state keeps the last normal bounds', () async {
    await controller.recordMaximized();
    platform.maximized = true;
    platform.bounds = const Rect.fromLTWH(0, 0, 1920, 1040);
    await controller.captureCurrentState();

    expect(
      controller.state.normalBounds,
      const Rect.fromLTWH(10, 10, 1000, 700),
    );
    expect(controller.state.maximized, isTrue);
  });

  test('minimized state never overwrites normal bounds', () async {
    platform.minimized = true;
    platform.bounds = const Rect.fromLTWH(-32000, -32000, 0, 0);

    await controller.flush();

    expect(
      controller.state.normalBounds,
      const Rect.fromLTWH(10, 10, 1000, 700),
    );
    expect(writes.single.normalBounds, const Rect.fromLTWH(10, 10, 1000, 700));
  });

  test('unmaximize records restored normal bounds', () async {
    await controller.recordMaximized();
    platform.bounds = const Rect.fromLTWH(40, 50, 1300, 850);

    await controller.recordUnmaximized();

    expect(controller.state.normalBounds, platform.bounds);
    expect(controller.state.maximized, isFalse);
    expect(writes.last.normalBounds, platform.bounds);
  });

  test('a state event invalidates an older in-flight capture', () async {
    final gate = Completer<void>();
    final controlled = DesktopWindowStateController(
      initialState: controller.state,
      platform: _ControlledWindowStatePlatform(platform, gate),
      persist: (snapshot) async => writes.add(snapshot),
    );

    final capture = controlled.captureCurrentState();
    await Future<void>.delayed(Duration.zero);
    await controlled.recordMaximized();
    platform.bounds = const Rect.fromLTWH(0, 0, 1920, 1040);
    platform.maximized = true;
    gate.complete();
    await capture;

    expect(
      controlled.state.normalBounds,
      const Rect.fromLTWH(10, 10, 1000, 700),
    );
    expect(controlled.state.maximized, isTrue);
  });

  test('flush retries a persistence failure from its own capture', () async {
    var attempts = 0;
    final retrying = DesktopWindowStateController(
      initialState: controller.state,
      platform: platform,
      persist: (snapshot) async {
        attempts++;
        if (attempts == 1) throw StateError('disk full');
        writes.add(snapshot);
      },
    );

    await retrying.flush();

    expect(attempts, 2);
    expect(writes.single.normalBounds, platform.bounds);
  });

  test('flush retries a previous persistence failure', () async {
    var attempts = 0;
    final retrying = DesktopWindowStateController(
      initialState: controller.state,
      platform: platform,
      persist: (snapshot) async {
        attempts++;
        if (attempts == 1) throw StateError('disk full');
        writes.add(snapshot);
      },
    );

    await expectLater(
      retrying.recordMaximized(),
      throwsA(isA<WindowStatePersistenceException>()),
    );
    platform.maximized = true;
    await retrying.flush();

    expect(attempts, 2);
    expect(writes.single.maximized, isTrue);
  });
}

class _ControlledWindowStatePlatform implements DesktopWindowStatePlatform {
  _ControlledWindowStatePlatform(this.delegate, this.gate);

  final _FakeWindowStatePlatform delegate;
  final Completer<void> gate;

  @override
  Future<DesktopWindowStateReading> readState() async {
    await gate.future;
    return delegate.readState();
  }
}
