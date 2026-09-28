import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Windows startup selects hidden caption without removing native frame',
    () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final runnerSource = File(
        'windows/runner/win32_window.cpp',
      ).readAsStringSync();

      expect(mainSource, contains('? TitleBarStyle.hidden'));
      expect(
        mainSource,
        contains('windowButtonVisibility: !Platform.isWindows'),
      );
      expect(runnerSource, contains('WS_OVERLAPPEDWINDOW'));
    },
  );

  test('runner keeps queued child resize stabilization on both messages', () {
    final source = File('windows/runner/win32_window.cpp').readAsStringSync();

    expect(
      RegExp(
        r'case WM_SIZE:\s*\{\s*QueueChildContentResize\(\);',
        multiLine: true,
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'case WM_WINDOWPOSCHANGED:\s*QueueChildContentResize\(\);',
        multiLine: true,
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains('PostMessage(window_handle_,'));
    expect(source, contains('case kResizeChildContentMessage:'));
    expect(source, contains('ResizeChildContent();'));
  });

  test('hot reload explicitly resynchronizes child size and DPI metrics', () {
    final bootstrapSource = File(
      'lib/presentation/screens/splash/app_bootstrap.dart',
    ).readAsStringSync();
    final platformSource = File(
      'lib/core/windowing/windows_native_window_state.dart',
    ).readAsStringSync();
    final nativeSource = File(
      'windows/runner/flutter_window.cpp',
    ).readAsStringSync();
    final windowSource = File(
      'windows/runner/win32_window.cpp',
    ).readAsStringSync();

    expect(bootstrapSource, contains('void reassemble()'));
    expect(bootstrapSource, contains('synchronizeViewMetrics()'));
    expect(
      platformSource,
      contains("invokeMethod<void>('synchronizeViewMetrics')"),
    );
    expect(
      nativeSource,
      contains('call.method_name() == "synchronizeViewMetrics"'),
    );
    expect(nativeSource, contains('SynchronizeChildContentMetrics();'));
    expect(windowSource, contains('SendMessage(child_content_, WM_SIZE'));
    expect(windowSource, contains('IsIconic(window_handle_)'));
  });

  test(
    'runner never forwards minimized or empty client geometry to Flutter',
    () {
      final source = File('windows/runner/win32_window.cpp').readAsStringSync();
      final header = File('windows/runner/win32_window.h').readAsStringSync();

      expect(source, contains('IsIconic(window_handle_)'));
      expect(source, contains('width > 0 && height > 0'));
      expect(source, contains('last_valid_client_rect_ = frame;'));
      expect(source, contains('frame = last_valid_client_rect_;'));
      expect(header, contains('RECT last_valid_client_rect_{};'));
      expect(header, contains('bool has_last_valid_client_rect_ = false;'));
      expect(
        source.indexOf('if (IsIconic(window_handle_))'),
        lessThan(source.indexOf('RECT frame = GetClientArea();')),
      );
    },
  );

  test('window restore uses native physical work areas and atomic state', () {
    final dartSource = File('lib/main.dart').readAsStringSync();
    final nativeSource = File(
      'windows/runner/flutter_window.cpp',
    ).readAsStringSync();

    expect(dartSource, contains('nativePlatform.getWorkAreas()'));
    expect(dartSource, contains('nativePlatform;'));
    expect(dartSource, contains('resolveWindowRestorePlan('));
    expect(
      dartSource,
      contains('WindowsNativeWindowStatePlatform().restore(restorePlan)'),
    );
    expect(nativeSource, contains('EnumDisplayMonitors('));
    expect(nativeSource, contains('GetWindowPlacement(window, &placement)'));
    expect(nativeSource, contains('placement->rcNormalPosition'));
    expect(nativeSource, contains('IsMaximizedPlacement(*placement)'));
    expect(nativeSource, contains('PlacementToScreenRect('));
    expect(nativeSource, contains('ScreenToPlacementRect(screen_bounds)'));
    expect(
      nativeSource,
      contains('SetWindowPlacement(window, &restored_placement)'),
    );
    expect(nativeSource, isNot(contains('ShowWindow(window,')));
    expect(nativeSource, isNot(contains('ShowWindow(window, *maximized')));
    expect(nativeSource, isNot(contains('SetWindowPos(window, nullptr')));
    expect(nativeSource, isNot(contains('SetNextFrameCallback')));
    expect(nativeSource, contains('message == WM_WINDOWPOSCHANGED'));
    expect(nativeSource, contains('message == WM_EXITSIZEMOVE'));
    expect(
      dartSource.indexOf('nativePlatform?.setBoundsChangedHandler'),
      greaterThan(dartSource.indexOf('windowManager.waitUntilReadyToShow')),
    );
    expect(
      dartSource,
      contains('AppWindowListener(stateController, hideOnClose: trayReady)'),
    );
  });

  test('shutdown flushes window state before closing Hive', () {
    final source = File(
      'lib/core/services/desktop_app_shutdown_service.dart',
    ).readAsStringSync();

    expect(
      source.indexOf('await _windowStateFlushHandler?.call();'),
      lessThan(source.indexOf('await Hive.close();')),
    );
  });

  test('Flutter caption closes through prevent-close event, never destroy', () {
    final source = File(
      'lib/core/windowing/desktop_window_controller.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> close() => windowManager.close();'));
    expect(source, isNot(contains('windowManager.destroy()')));
  });

  test('locked window_manager version supports hidden resizable caption API', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();

    expect(pubspec, contains('window_manager: ^0.5.1'));
    expect(
      RegExp(
        r'window_manager:\s+dependency: "direct main"[\s\S]*?version: "0\.5\.2"',
      ).hasMatch(lockfile),
      isTrue,
    );
  });
}
