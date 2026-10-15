import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows plugin registrant', () {
    test('never registers the native permission_handler plugin', () {
      final plugins = File(
        'windows/flutter/generated_plugins.cmake',
      ).readAsStringSync();
      final registrant = File(
        'windows/flutter/generated_plugin_registrant.cc',
      ).readAsStringSync();

      expect(plugins, isNot(contains('permission_handler_windows')));
      expect(registrant, isNot(contains('PermissionHandlerWindowsPlugin')));
    });

    test('keeps the override package Dart-only', () {
      final pubspec = File(
        'packages/permission_handler_windows/pubspec.yaml',
      ).readAsStringSync();

      expect(pubspec, contains('dartPluginClass: PermissionHandlerWindows'));
      expect(
        pubspec,
        isNot(contains('pluginClass: PermissionHandlerWindowsPlugin')),
      );
      expect(
        Directory('packages/permission_handler_windows/windows').existsSync(),
        isFalse,
      );
    });
  });
}
