import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vibe library screen keeps layout helpers split out', () {
    final source = File(
      'lib/presentation/screens/vibe_library/vibe_library_screen.dart',
    );
    final lineCount = source.readAsLinesSync().length;

    expect(lineCount, lessThanOrEqualTo(2000));
  });
}
