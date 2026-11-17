import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _packageDir = 'packages/flutter_inappwebview_windows';

const _processLifetimeMembers = [
  'rohelper_',
  'dispatcher_queue_controller_',
  'graphics_context_',
  'compositor_',
];

void main() {
  group('flutter_inappwebview_windows override', () {
    test('resolves the plugin from the patched in-repo copy', () {
      final pubspec = _readText('pubspec.yaml');
      final lock = _readText('pubspec.lock');

      expect(
        pubspec,
        matches(
          RegExp(
            r'\n  flutter_inappwebview_windows:\n'
            r'    path: packages/flutter_inappwebview_windows\n',
          ),
        ),
      );
      expect(
        _lockEntry(lock, 'flutter_inappwebview_windows'),
        allOf(
          contains('source: path'),
          contains('path: "$_packageDir"'),
          contains('version: "0.6.0+launcher"'),
        ),
      );
    });

    // 副本只对应这一版上游；升级后必须重新同步 windows 实现，否则新旧接口会静默错配
    test(
      'stays paired with the flutter_inappwebview release it was copied for',
      () {
        final lock = _readText('pubspec.lock');

        expect(
          _lockEntry(lock, 'flutter_inappwebview'),
          contains('version: "6.1.5"'),
        );
      },
    );

    test('never destroys process-lifetime WinRT objects at DLL unload', () {
      final header = _readText(
        '$_packageDir/windows/in_app_webview/in_app_webview_manager.h',
      );

      for (final member in _processLifetimeMembers) {
        expect(
          header,
          matches(
            RegExp('inline static [^;]*&\\s*$member\\s*=\\s*\\*new\\s'),
          ),
          reason: '$member must be one static reference to a leaked object',
        );
      }
    });
  });
}

// Windows 检出启用 autocrlf 时工作区是 CRLF，CI 上是 LF
String _readText(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

String _lockEntry(String lock, String package) {
  final start = lock.indexOf('\n  $package:\n');
  expect(start, isNonNegative, reason: '$package missing from pubspec.lock');
  final next = lock.indexOf(RegExp(r'\n  [a-z0-9_]+:\n'), start + 1);
  return lock.substring(start, next < 0 ? lock.length : next);
}
