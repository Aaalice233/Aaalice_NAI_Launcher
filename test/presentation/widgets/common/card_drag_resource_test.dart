import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';
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

  test('members prepare in parallel, bounded by the compute gate', () async {
    final limit = ComputeGate().maxConcurrentTasks;
    var active = 0;
    var peak = 0;
    final resources = [
      for (var i = 0; i < limit * 3; i++)
        CardDragResource(
          id: '$i',
          fileName: '$i.png',
          prepare: () async {
            peak = math.max(peak, ++active);
            await Future<void>.delayed(const Duration(milliseconds: 5));
            active--;
            return Uint8List.fromList([i]);
          },
        ),
    ];
    final session = CardDragPreparation(resources);

    final results = await session.prepare();

    expect(peak, limit);
    expect(results, [
      for (var i = 0; i < limit * 3; i++) Uint8List.fromList([i]),
    ]);
  });

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
