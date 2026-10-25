import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/json_value_copy.dart';

Map<String, Object?> _decoded() =>
    jsonDecode('{"entry":{"source":"a.png","tags":["x",{"k":1}]},"n":2}')
        as Map<String, Object?>;

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
}
