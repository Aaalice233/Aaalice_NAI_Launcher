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
