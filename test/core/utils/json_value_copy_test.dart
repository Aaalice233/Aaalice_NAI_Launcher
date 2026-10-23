import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/json_value_copy.dart';

Map<Object?, Object?> _decoded() =>
    jsonDecode('{"entry":{"source":"a.png","tags":["x",{"k":1}]},"n":2}')
        as Map<Object?, Object?>;

void main() {
  test('frozen copy rejects edits at every nesting level', () {
    final frozen = deepFrozenJsonMap(_decoded());
    final entry = frozen['entry']! as Map;
    final tags = entry['tags']! as List;

    expect(() => frozen['n'] = 3, throwsUnsupportedError);
    expect(() => entry['source'] = 'b.png', throwsUnsupportedError);
    expect(() => tags.add('y'), throwsUnsupportedError);
    expect(() => (tags[1] as Map)['k'] = 2, throwsUnsupportedError);
    expect(frozen, _decoded());
  });

  test('mutable copy shares no collection with a frozen source', () {
    final frozen = deepFrozenJsonMap(_decoded());
    final copy = deepMutableJsonMap(frozen);
    final entry = copy['entry']! as Map;
    final tags = entry['tags']! as List;

    entry['source'] = 'b.png';
    tags.add('y');
    (tags[1] as Map)['k'] = 2;
    copy['n'] = 3;

    expect(frozen, _decoded());
    expect(copy, {
      'entry': {
        'source': 'b.png',
        'tags': [
          'x',
          {'k': 2},
          'y',
        ],
      },
      'n': 3,
    });
  });

  test('keys are stringified', () {
    expect(deepFrozenJsonMap({1: 'a'}).keys, ['1']);
    expect(deepMutableJsonMap({1: 'a'}).keys, ['1']);
  });
}
