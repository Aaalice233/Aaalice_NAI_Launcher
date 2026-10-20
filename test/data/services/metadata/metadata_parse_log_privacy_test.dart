import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

const _secret = 'secret lighthouse keeper';
const _damagedComment = '{"prompt":"$_secret",}';

void main() {
  test('damaged metadata never quotes its text into the log', () {
    final logs = <String>[];
    final inputs = <Map<String, String>>[
      {'Comment': _damagedComment},
      {
        'Comment': jsonEncode({
          'Software': 'NovelAI',
          'Comment': _damagedComment,
        }),
      },
      {'prompt': _damagedComment},
    ];

    runZoned(
      () => inputs.forEach(UnifiedMetadataParser.parseFromTextData),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => logs.add(line),
      ),
    );

    expect(logs, isNotEmpty);
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
