import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler_windows/permission_handler_windows.dart';

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
      expect(pubspec, isNot(contains('pluginClass: PermissionHandlerWindowsPlugin')));
      expect(
        Directory('packages/permission_handler_windows/windows').existsSync(),
        isFalse,
      );
    });
  });

  group('PermissionHandlerWindows', () {
    final platform = PermissionHandlerWindows();

    test('answers the public API once registered', () async {
      PermissionHandlerWindows.registerWith();

      // 未注册时公开 API 走方法通道，测试环境里会抛 MissingPluginException
      expect(
        await Permission.location.serviceStatus,
        ServiceStatus.notApplicable,
      );
    });

    test('grants permissions without prompting', () async {
      expect(
        await platform.checkPermissionStatus(Permission.storage),
        PermissionStatus.granted,
      );
      expect(
        await platform.requestPermissions([
          Permission.notification,
          Permission.location,
        ]),
        {
          Permission.notification: PermissionStatus.granted,
          Permission.location: PermissionStatus.granted,
        },
      );
      expect(
        await platform.shouldShowRequestPermissionRationale(Permission.camera),
        isFalse,
      );
      expect(await platform.openAppSettings(), isFalse);
    });

    test('never queries location or bluetooth services', () async {
      for (final permission in [
        Permission.location,
        Permission.locationAlways,
        Permission.locationWhenInUse,
        Permission.bluetooth,
      ]) {
        expect(
          await platform.checkServiceStatus(permission),
          ServiceStatus.notApplicable,
          reason: '$permission',
        );
      }
      expect(
        await platform.checkServiceStatus(Permission.ignoreBatteryOptimizations),
        ServiceStatus.enabled,
      );
    });
  });
}
