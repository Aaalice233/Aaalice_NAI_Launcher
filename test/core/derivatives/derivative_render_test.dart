import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/derivatives/derivative_render.dart';

void main() {
  group('DerivativeRenderCancellationToken', () {
    test('cancel is idempotent and completes whenCancelled', () async {
      final token = DerivativeRenderCancellationToken();
      expect(token.isCancelled, isFalse);
      expect(token.throwIfCancelled, returnsNormally);

      token
        ..cancel()
        ..cancel();

      expect(token.isCancelled, isTrue);
      await expectLater(token.whenCancelled, completes);
      expect(
        token.throwIfCancelled,
        throwsA(isA<DerivativeRenderCancelledException>()),
      );
    });

    test('race passes through work that settles first', () async {
      final token = DerivativeRenderCancellationToken();
      expect(await token.race(Future.value(7)), 7);
      await expectLater(
        token.race(Future<int>.error(StateError('decode'))),
        throwsA(isA<StateError>()),
      );
      token.cancel();
    });

    test('cancel ends a pending race without waiting for the work', () async {
      final token = DerivativeRenderCancellationToken();
      final work = Completer<int>();
      Object? raced;
      unawaited(
        token.race(work.future).then<void>((_) {}, onError: (e) => raced = e),
      );

      token.cancel();
      await pumpEventQueue();

      expect(raced, isA<DerivativeRenderCancelledException>());
      expect(work.isCompleted, isFalse);
      work.complete(1);
    });

    test('abandoned work that fails later is not an unhandled error', () async {
      final token = DerivativeRenderCancellationToken();
      final work = Completer<int>();
      final raced = token.race(work.future);

      token.cancel();
      await expectLater(
        raced,
        throwsA(isA<DerivativeRenderCancelledException>()),
      );
      work.completeError(StateError('late failure'));
      await pumpEventQueue();
    });

    test(
      'racing after cancellation fails at once and drops the work',
      () async {
        final token = DerivativeRenderCancellationToken()..cancel();

        await expectLater(
          token.race(Future<int>.error(StateError('ignored'))),
          throwsA(isA<DerivativeRenderCancelledException>()),
        );
        await pumpEventQueue();
      },
    );

    test('work that settles first is not undone by a later cancel', () async {
      final token = DerivativeRenderCancellationToken();
      final raced = token.race(Future.value('done'));
      await expectLater(raced, completion('done'));

      token.cancel();
      await pumpEventQueue();
      expect(await raced, 'done');
    });
  });
}
