import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';

void main() {
  test('scope remains available across asynchronous work', () async {
    final token = OperationToken();

    await token.runInScope(() async {
      expect(OperationToken.current, same(token));
      await Future<void>.delayed(Duration.zero);
      expect(OperationToken.current, same(token));
    });

    expect(OperationToken.current, isNull);
  });

  test('removed cancellation listener is not called', () {
    final token = OperationToken();
    var calls = 0;
    final remove = token.addCancellationListener(() => calls++);

    remove();
    remove();
    token.cancel();

    expect(calls, 0);
  });

  test(
    'race cancels the wait and continues observing the source future',
    () async {
      final token = OperationToken();
      final source = Completer<int>();
      final raced = token.race(source.future);

      token.cancel();

      await expectLater(raced, throwsA(isA<OperationCancelledException>()));
      source.completeError(StateError('late source failure'));
      await Future<void>.delayed(Duration.zero);
    },
  );
}
