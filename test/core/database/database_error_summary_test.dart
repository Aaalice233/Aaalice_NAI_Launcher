import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/database_error_summary.dart';

import '../../helpers/database_error_probe.dart';

void main() {
  test('keeps the ffi result code but drops the SQL arguments', () async {
    final error = await databaseErrorCarrying('secret lighthouse keeper');

    expect(error.toString(), contains('lighthouse'));
    expect(databaseErrorSummary(error), 'DatabaseException(resultCode: 2067)');
  });

  test('other errors keep only their type', () {
    expect(
      databaseErrorSummary(const FormatException('bad', '{"p":"secret"}', 4)),
      'FormatException',
    );
  });
}
