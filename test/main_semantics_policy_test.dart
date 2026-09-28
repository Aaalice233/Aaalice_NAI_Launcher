import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop startup leaves semantics activation to the platform', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      isNot(contains('SemanticsBinding.instance.ensureSemantics()')),
      reason:
          'Forcing semantics at startup exposes every Windows session to '
          'native accessibility-tree updates, even without an assistive client.',
    );
  });

  test('Windows runner blocks the crashing accessibility bridge requests', () {
    final runnerSource = File(
      'windows/runner/win32_window.cpp',
    ).readAsStringSync();
    final cmakeSource = File(
      'windows/runner/CMakeLists.txt',
    ).readAsStringSync();

    expect(runnerSource, contains('SetWindowSubclass'));
    expect(runnerSource, contains('WM_GETOBJECT'));
    expect(runnerSource, contains('OBJID_CLIENT'));
    expect(runnerSource, contains('UiaRootObjectId'));
    expect(cmakeSource, contains('comctl32.lib'));
  });
}
