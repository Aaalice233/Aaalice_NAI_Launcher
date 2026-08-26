import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/event_stream.dart';

void main() {
  test(
    'fromEvents closes and completes result when the source errors',
    () async {
      final source = StreamController<int>();
      final wrapped = EventStream<int, int>.fromEvents(
        source.stream,
        () async => 42,
      );
      final events = wrapped.stream.toList();
      final result = expectLater(wrapped.result(), throwsA(isA<StateError>()));

      source
        ..add(1)
        ..addError(StateError('source failed'));
      await source.close();

      expect(await events, [1]);
      await result;
    },
  );
}
