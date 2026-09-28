import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/card_drag_resource.dart';

void main() {
  test(
    'preparation is lazy, ordered, and shared by all native readers',
    () async {
      final prepared = <String>[];
      final resources = [
        for (final id in ['a', 'b', 'c'])
          CardDragResource(
            id: id,
            fileName: '$id.png',
            prepare: () async {
              prepared.add(id);
              return Uint8List.fromList(id.codeUnits);
            },
          ),
      ];
      final session = CardDragPreparation(resources);
      resources.clear();
      expect(prepared, isEmpty);
      final results = await Future.wait([
        session.bytesAt(2),
        session.bytesAt(0),
      ]);
      expect(prepared, ['a', 'b', 'c']);
      expect(results, [
        Uint8List.fromList([99]),
        Uint8List.fromList([97]),
      ]);
      await session.bytesAt(1);
      expect(prepared, ['a', 'b', 'c']);
    },
  );

  test('a failed member prevents successful-looking partial exports', () async {
    final failure = StateError('missing original');
    final session = CardDragPreparation([
      CardDragResource(
        id: 'a',
        fileName: 'a.png',
        prepare: () async => Uint8List(1),
      ),
      CardDragResource(
        id: 'b',
        fileName: 'b.png',
        prepare: () async => throw failure,
      ),
    ]);
    await expectLater(session.bytesAt(0), throwsA(same(failure)));
    await expectLater(session.bytesAt(1), throwsA(same(failure)));
  });
}
