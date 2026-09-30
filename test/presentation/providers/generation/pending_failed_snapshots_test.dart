import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/providers/generation/pending_failed_snapshots.dart';

void main() {
  test('lands above the capture-time head while later results stay on top', () {
    final pending = PendingFailedSnapshots();
    final older = [_image('b'), _image('a')];

    final id = pending.reserve(older);
    final history = [_image('new'), ...older];
    final landed = PendingFailedSnapshots.insert(
      history,
      _image(id),
      pending.take(id)!,
    );

    expect(_ids(landed), ['new', id, 'b', 'a']);
  });

  test('skips removed floor items and falls to the end when none remain', () {
    final pending = PendingFailedSnapshots();
    final first = pending.reserve([_image('b'), _image('a')]);
    final second = pending.reserve(const []);

    expect(
      _ids(
        PendingFailedSnapshots.insert(
          [_image('new'), _image('a')],
          _image(first),
          pending.take(first)!,
        ),
      ),
      ['new', first, 'a'],
    );
    expect(
      _ids(
        PendingFailedSnapshots.insert(
          [_image('new')],
          _image(second),
          pending.take(second)!,
        ),
      ),
      ['new', second],
    );
  });

  test('keeps capture order when later reservations land first', () {
    final pending = PendingFailedSnapshots();
    final history = [_image('old')];
    final lower = pending.reserve(history);
    final upper = pending.reserve(history);

    var landed = PendingFailedSnapshots.insert(
      history,
      _image(upper),
      pending.take(upper)!,
    );
    landed = PendingFailedSnapshots.insert(
      landed,
      _image(lower),
      pending.take(lower)!,
    );

    expect(_ids(landed), [upper, lower, 'old']);
  });

  test('restored entries sink below every reservation', () {
    final pending = PendingFailedSnapshots();
    final id = pending.reserve(const []);

    pending.placeBelowAll(['restored']);
    final landed = PendingFailedSnapshots.insert(
      [_image('new'), _image('restored')],
      _image(id),
      pending.take(id)!,
    );

    expect(_ids(landed), ['new', id, 'restored']);
  });

  test('discarded reservations cannot land', () {
    final pending = PendingFailedSnapshots();
    final id = pending.reserve(const []);

    pending.discardAll();

    expect(pending.take(id), isNull);
  });

  test('settled waits for every tracked landing', () async {
    final pending = PendingFailedSnapshots();
    final landing = Completer<void>();
    pending.track(landing.future);

    var settled = false;
    final wait = pending.settled().then((_) => settled = true);
    await pumpEventQueue();
    expect(settled, isFalse);

    landing.complete();
    await wait;
    expect(settled, isTrue);
  });

  test(
    'a failed landing is reported once and does not break settled',
    () async {
      final errors = <Object>[];
      await runZonedGuarded(() async {
        final pending = PendingFailedSnapshots();
        pending.track(Future<void>.error(StateError('landing failed')));
        await pending.settled();
        await pumpEventQueue();
      }, (error, _) => errors.add(error));

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    },
  );
}

GeneratedImage _image(String id) =>
    GeneratedImage(id: id, bytes: Uint8List(0), width: 1, height: 1);

List<String> _ids(List<GeneratedImage> images) =>
    images.map((image) => image.id).toList();
