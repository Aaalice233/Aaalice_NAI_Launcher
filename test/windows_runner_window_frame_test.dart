import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runner hides the DWM border while preserving the native frame', () {
    final source = File('windows/runner/win32_window.cpp').readAsStringSync();

    expect(source, contains('WS_OVERLAPPEDWINDOW'));
    expect(source, contains('kDwmWindowAttributeBorderColor = 34'));
    expect(source, contains('kDwmColorNone = 0xFFFFFFFE'));
    expect(
      source,
      contains(
        'DwmSetWindowAttribute(window, kDwmWindowAttributeBorderColor, '
        '&border_color,',
      ),
    );
  });
}
