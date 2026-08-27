import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_detail_coordinator.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';

GalleryItem _item(int id) => GalleryItem(id: id, site: 'danbooru');
GalleryDetail _detail(GalleryItem item, [String? marker]) =>
    GalleryDetail(item: item, media: const [], description: marker);

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected queued detail request was not started');
}

void main() {
  test('limits active detail requests to four', () async {
    var active = 0;
    var maxActive = 0;
    final gates = <Completer<GalleryDetail>>[];
    final coordinator = OnlineGalleryDetailCoordinator(
      loader: (item, _) {
        active++;
        if (active > maxActive) maxActive = active;
        final gate = Completer<GalleryDetail>();
        gates.add(gate);
        return gate.future.whenComplete(() => active--);
      },
    );

    final futures = [for (var i = 0; i < 6; i++) coordinator.request(_item(i))];
    expect(coordinator.activeCount, 4);
    expect(maxActive, 4);

    for (var index = 0; index < futures.length; index++) {
      await _waitUntil(() => gates.length > index);
      gates[index].complete(_detail(_item(index)));
    }
    expect(await Future.wait(futures), hasLength(6));
    expect(maxActive, 4);
  });

  test(
    'representative media keeps work-scoped identity and detail dedup',
    () async {
      final gate = Completer<GalleryDetail>();
      var calls = 0;
      final coordinator = OnlineGalleryDetailCoordinator(
        loader: (item, _) {
          calls++;
          return gate.future;
        },
      );
      final first = _item(
        7,
      ).copyWith(focusedMediaId: '7:0', focusedMediaIndex: 0);
      final second = _item(
        7,
      ).copyWith(focusedMediaId: '7:1', focusedMediaIndex: 1);

      final firstFuture = coordinator.request(first);
      final secondFuture = coordinator.request(second);

      expect(first.stableKey, second.stableKey);
      expect(first.stableKey, first.detailStableKey);
      expect(identical(firstFuture, secondFuture), isTrue);
      expect(calls, 1);
      gate.complete(_detail(first));
      await Future.wait([firstFuture, secondFuture]);
    },
  );

  test('interactive request upgrades queued visible detail', () async {
    final started = <int>[];
    final gates = <Completer<GalleryDetail>>[];
    final coordinator = OnlineGalleryDetailCoordinator(
      maxConcurrent: 1,
      loader: (item, _) {
        started.add(item.id);
        final gate = Completer<GalleryDetail>();
        gates.add(gate);
        return gate.future;
      },
    );

    final first = coordinator.request(_item(1));
    final visible = coordinator.request(
      _item(2),
      priority: GalleryDetailPriority.visible,
    );
    final upgraded = coordinator.request(_item(2));
    expect(identical(visible, upgraded), isTrue);

    gates[0].complete(_detail(_item(1)));
    await Future<void>.delayed(Duration.zero);
    expect(started, [1, 2]);
    gates[1].complete(_detail(_item(2)));
    await Future.wait([first, upgraded]);
  });

  test(
    'completed cache is TTL bounded LRU and failures remain retryable',
    () async {
      var now = DateTime(2026);
      var calls = 0;
      final coordinator = OnlineGalleryDetailCoordinator(
        maxCompletedEntries: 2,
        completedTtl: const Duration(hours: 24),
        now: () => now,
        loader: (item, _) async {
          calls++;
          if (item.id == 9 && calls == 1) throw StateError('failed');
          return _detail(item, 'call-$calls');
        },
      );

      await coordinator.request(_item(1));
      await coordinator.request(_item(2));
      await coordinator.request(_item(3));
      expect(coordinator.completedCount, 2);
      await coordinator.request(_item(1));
      expect(calls, 4);

      final failing = OnlineGalleryDetailCoordinator(
        loader: (item, _) async {
          calls++;
          if (calls == 5) throw StateError('failed');
          return _detail(item);
        },
      );
      await expectLater(failing.request(_item(9)), throwsStateError);
      await failing.request(_item(9));
      expect(calls, 6);

      now = now.add(const Duration(hours: 24));
      expect(coordinator.completedCount, 0);
    },
  );

  test(
    'cancels an interactive detail request and keeps it retryable',
    () async {
      final item = _item(4);
      var calls = 0;
      final coordinator = OnlineGalleryDetailCoordinator(
        loader: (requested, cancelToken) async {
          calls++;
          if (calls == 1) {
            throw await cancelToken.whenCancel;
          }
          return _detail(requested, 'retry');
        },
      );

      final cancelled = coordinator.request(item);
      coordinator.cancel(item);

      await expectLater(cancelled, throwsA(isA<DioException>()));
      expect((await coordinator.request(item)).description, 'retry');
      expect(calls, 2);
    },
  );

  test(
    'obsolete force-refresh failure cannot remove the newer request',
    () async {
      final item = _item(1);
      final oldGate = Completer<GalleryDetail>();
      final newGate = Completer<GalleryDetail>();
      var calls = 0;
      final coordinator = OnlineGalleryDetailCoordinator(
        loader: (_, __) => calls++ == 0 ? oldGate.future : newGate.future,
      );

      final oldFuture = coordinator.request(item);
      final newFuture = coordinator.request(item, forceRefresh: true);
      final oldFailure = expectLater(oldFuture, throwsStateError);
      oldGate.completeError(StateError('obsolete'));
      newGate.complete(_detail(item, 'new'));

      await oldFailure;
      expect((await newFuture).description, 'new');
      expect((await coordinator.request(item)).description, 'new');
      expect(calls, 2);
    },
  );
}
