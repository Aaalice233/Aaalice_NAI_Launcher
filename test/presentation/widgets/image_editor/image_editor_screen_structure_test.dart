import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image editor screen keeps support UI split out of the main source', () {
    final source = File(
      'lib/presentation/widgets/image_editor/image_editor_screen.dart',
    );
    final lineCount = source.readAsLinesSync().length;

    expect(lineCount, lessThanOrEqualTo(2000));
  });
}
