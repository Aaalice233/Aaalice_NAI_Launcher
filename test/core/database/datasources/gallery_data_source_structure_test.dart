import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'gallery data source keeps record models split out of the main source',
    () {
      final source = File(
        'lib/core/database/datasources/gallery_data_source.dart',
      );
      final lineCount = source.readAsLinesSync().length;

      expect(lineCount, lessThanOrEqualTo(2300));
    },
  );
}
