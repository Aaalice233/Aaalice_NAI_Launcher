import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runner waits for a starting first instance before exiting', () {
    final source = File('windows/runner/main.cpp').readAsStringSync();

    expect(source, contains('kExistingWindowWaitTimeoutMs'));
    expect(source, contains('WaitForExistingFlutterWindow'));
    expect(
      source,
      contains('WakeUpExistingWindow(kExistingWindowWaitTimeoutMs)'),
    );
    expect(source, contains('MessageBoxW'));
    expect(source, contains('already starting'));
  });
}
