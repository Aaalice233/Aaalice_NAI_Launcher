import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runner installs task window lookup before initializing COM', () {
    final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();
    final source = File('windows/runner/main.cpp').readAsStringSync();

    expect(cmake, contains('"task_runner_window_lookup.cpp"'));
    expect(source, contains('#include "task_runner_window_lookup.h"'));

    final singleInstanceIndex = source.indexOf(
      'if (is_another_instance_running)',
    );
    final installIndex = source.indexOf('InstallTaskRunnerWindowLookup();');
    final comIndex = source.indexOf('::CoInitializeEx');

    expect(singleInstanceIndex, greaterThanOrEqualTo(0));
    expect(installIndex, greaterThanOrEqualTo(0));
    expect(comIndex, greaterThanOrEqualTo(0));
    expect(installIndex, greaterThan(singleInstanceIndex));
    expect(installIndex, lessThan(comIndex));
  });

  test('task window lookup is scoped to the plugin and calling thread', () {
    final source = File(
      'windows/runner/task_runner_window_lookup.cpp',
    ).readAsStringSync();

    expect(source, contains('L"super_native_extensions.dll"'));
    expect(source, contains('L"FlutterTaskRunnerWindow"'));
    expect(source, contains('"FindWindowExW"'));
    expect(source, contains('HWND_MESSAGE'));
    expect(source, contains('GetCurrentThreadId()'));
    expect(source, contains('GetWindowThreadProcessId('));
  });

  test('plugin version matches the verified task window lookup contract', () {
    final lockfile = File('pubspec.lock').readAsStringSync();
    final version = RegExp(
      r'^  super_native_extensions:\r?\n(?:    [^\r\n]*\r?\n)*?'
      r'    version: "([^"]+)"\r?$',
      multiLine: true,
    ).firstMatch(lockfile)?.group(1);

    expect(
      version,
      '0.9.1',
      reason:
          '升级插件时要重新确认 super_native_extensions.dll 仍从 USER32.dll 导入 '
          'FindWindowExW、irondash 的 poll_once 仍按类名查找 FlutterTaskRunnerWindow，'
          '确认后再更新这里的版本号。',
    );
  });
}
