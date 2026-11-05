import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/window_state_persistence.dart';
import 'package:nai_launcher/core/windowing/desktop_window_state_controller.dart';
import 'package:nai_launcher/core/windowing/desktop_window_state_observer.dart';

class _FakeWindowStatePlatform implements DesktopWindowStatePlatform {
  Rect bounds = const Rect.fromLTWH(20, 30, 1200, 800);
  bool minimized = false;

  @override
  Future<DesktopWindowStateReading> readState() async =>
      DesktopWindowStateReading(
        bounds: minimized ? const Rect.fromLTWH(-32000, -32000, 0, 0) : bounds,
        maximized: false,
        minimized: minimized,
        scaleFactor: 1.25,
      );
}

const _focusSwitch = [AppLifecycleState.inactive, AppLifecycleState.resumed];

const _leaveScreen = [AppLifecycleState.inactive, AppLifecycleState.hidden];

const _initialBounds = Rect.fromLTWH(10, 10, 1000, 700);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWindowStatePlatform platform;
  late List<WindowStateSnapshot> writes;
  late int logFlushes;
  late DesktopWindowStateObserver observer;

  setUp(() {
    platform = _FakeWindowStatePlatform();
    writes = [];
    logFlushes = 0;
    final controller = DesktopWindowStateController(
      initialState: const WindowStateSnapshot(
        normalBounds: _initialBounds,
        maximized: false,
      ),
      platform: platform,
      persist: (snapshot) async => writes.add(snapshot),
    );
    observer = DesktopWindowStateObserver(
      controller,
      flushLogs: () async => logFlushes++,
    );
  });

  Future<void> enter(List<AppLifecycleState> states) async {
    for (final state in states) {
      await observer.didChangeAppLifecycleState(state);
    }
  }

  Future<void> minimize() async {
    platform.minimized = true;
    await enter(_leaveScreen);
  }

  Future<void> restore() async {
    platform.minimized = false;
    await enter(_focusSwitch);
  }

  test('minimizing saves the window state once', () async {
    await minimize();
    await enter([AppLifecycleState.paused, AppLifecycleState.detached]);

    expect(writes.single.normalBounds, _initialBounds);
    expect(logFlushes, 1);
  });

  test('switching window focus writes nothing', () async {
    for (var round = 0; round < 3; round++) {
      await enter(_focusSwitch);
    }

    expect(writes, isEmpty);
    expect(logFlushes, 0);
  });

  test('repeated minimize and restore rewrites nothing', () async {
    for (var round = 0; round < 5; round++) {
      await minimize();
      await restore();
    }

    expect(writes, hasLength(1));
  });

  test('hiding to the tray saves the current normal bounds', () async {
    platform.bounds = const Rect.fromLTWH(200, 120, 1300, 860);

    await enter(_leaveScreen);

    expect(writes.single.normalBounds, platform.bounds);
  });
}
