import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/launcher_discovery_directory.dart';
import 'package:path/path.dart' as p;

void main() {
  group('resolveLauncherDiscoveryDirectory', () {
    test('prefers APPDATA', () {
      final directory = resolveLauncherDiscoveryDirectory(
        environment: const {
          'APPDATA': r'C:\Users\tester\AppData\Roaming',
          'HOME': r'C:\Users\tester',
        },
      );

      expect(
        directory.path,
        p.join(r'C:\Users\tester\AppData\Roaming', 'nai-launcher'),
      );
    });

    test('falls back to HOME as a dot directory', () {
      final directory = resolveLauncherDiscoveryDirectory(
        environment: const {'HOME': '/home/tester'},
      );

      expect(directory.path, p.join('/home/tester', '.nai-launcher'));
    });

    test('falls back to USERPROFILE when HOME is missing', () {
      final directory = resolveLauncherDiscoveryDirectory(
        environment: const {'USERPROFILE': r'C:\Users\tester'},
      );

      expect(directory.path, p.join(r'C:\Users\tester', '.nai-launcher'));
    });

    test(
      'ignores an empty APPDATA and falls back to the current directory',
      () {
        final directory = resolveLauncherDiscoveryDirectory(
          environment: const {'APPDATA': ''},
        );

        expect(directory.path, p.join(Directory.current.path, '.nai-launcher'));
      },
    );
  });
}
