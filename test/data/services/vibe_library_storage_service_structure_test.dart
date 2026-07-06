import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vibe library storage service keeps category helpers split out', () {
    final source = File('lib/data/services/vibe_library_storage_service.dart');
    final lineCount = source.readAsLinesSync().length;

    expect(lineCount, lessThanOrEqualTo(1900));
  });
}
