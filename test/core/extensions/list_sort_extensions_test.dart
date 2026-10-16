import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/extensions/list_sort_extensions.dart';

void main() {
  group('sortByKey', () {
    const names = [
      'beta',
      'Alpha',
      'alpha',
      'ALPHA',
      '',
      'Émile',
      'émile',
      'zeta',
      'Beta',
      '10 vibes',
      '2 vibes',
      'Ärger',
      'aRGER',
    ];

    // 33 项以内走插入排序，更长时走双轴快排，两条路径的并列顺序都要一致
    for (final count in [names.length, 33, 34, 200]) {
      test('大小写混合与同名并列时与比较器里现算小写的顺序完全一致（$count 项）', () {
        final random = Random(count);
        final items = [
          for (var id = 0; id < count; id++)
            (id: id, name: names[random.nextInt(names.length)]),
        ];
        final expected = [...items]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        final keyedIds = <int>[];
        final sorted = [...items]
          ..sortByKey((item) {
            keyedIds.add(item.id);
            return item.name.toLowerCase();
          });

        expect(sorted, expected);
        expect(
          keyedIds..sort(),
          [for (var id = 0; id < count; id++) id],
          reason: '每个元素的键只算一次',
        );
      });
    }

    test('空列表与单元素列表不计算键', () {
      var keyCalls = 0;
      String keyOf(String value) {
        keyCalls++;
        return value;
      }

      expect(<String>[]..sortByKey(keyOf), isEmpty);
      expect(['only']..sortByKey(keyOf), ['only']);
      expect(keyCalls, 0);
    });

    test('数值键按其自身顺序排列', () {
      expect([3, 1, 2]..sortByKey((value) => -value), [3, 2, 1]);
    });
  });
}
