import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_type_codec.dart';

void main() {
  for (final type in PreciseRefType.values) {
    for (final preference in [null, false, true]) {
      test(
        'portable type round-trip $type $preference and legacy acceptance',
        () {
          final data = encodePreciseRefType(type, preferSameOutfit: preference);
          expect(decodePreciseRefType(data), (
            type: type,
            preferSameOutfit: preference,
          ));
          expect(
            data['type'],
            type == PreciseRefType.costume ? 'character' : type.name,
          );
          expect(data.containsKey('typeV2'), type == PreciseRefType.costume);
          expect(data.containsKey('preferSameOutfit'), preference != null);
          expect([
            'character',
            'style',
            'characterAndStyle',
          ], contains(data['type']));
        },
      );
    }
  }
  test('reads old type names with no additional keys', () {
    for (final type in PreciseRefType.values.take(3)) {
      expect(decodePreciseRefType({'type': type.name}), (
        type: type,
        preferSameOutfit: null,
      ));
    }
  });
  for (final data in [
    {'type': 'unknown'},
    {'type': 'character', 'typeV2': 'unknown'},
    {'type': 'character', 'preferSameOutfit': 1},
  ]) {
    test('rejects malformed settings $data', () {
      expect(() => decodePreciseRefType(data), throwsFormatException);
    });
  }
}
