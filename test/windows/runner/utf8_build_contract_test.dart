import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows CMake standard settings enable UTF-8 source parsing', () {
    final cmakeSource = File('windows/CMakeLists.txt').readAsStringSync();

    expect(
      cmakeSource,
      matches(
        RegExp(
          r'function\(APPLY_STANDARD_SETTINGS\s+TARGET\)[\s\S]*?'
          r'target_compile_options\(\$\{TARGET\}\s+PRIVATE[^\r\n]*/W4[^\r\n]*/WX[^\r\n]*/utf-8[^\r\n]*\)',
        ),
      ),
    );
  });

  test('DLSS CMake targets enable UTF-8 source parsing', () {
    final dlssCmakeSource = File(
      'windows/dlss/CMakeLists.txt',
    ).readAsStringSync();

    for (final target in [
      'aaalice_dlss_probe',
      'aaalice_nr_bridge',
      'aaalice_dlss_worker',
    ]) {
      expect(
        dlssCmakeSource,
        matches(
          RegExp(
            'target_compile_options\\($target\\s+PRIVATE[^\\r\\n]*/utf-8[^\\r\\n]*\\)',
          ),
        ),
        reason: '$target should pass /utf-8 under MSVC',
      );
    }
  });
}
