import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action.dart';

void main() {
  test(
    'menu and button share busy state and prevent duplicate execution',
    () async {
      final runner = ImageCardActionRunner();
      addTearDown(runner.dispose);
      final pending = Completer<void>();
      var calls = 0;
      final action = ImageCardAction(
        id: ImageCardActionId.copy,
        icon: Icons.copy,
        label: 'Copy',
        invoke: () {
          calls++;
          return pending.future;
        },
      );
      final button = action.bind(runner);
      final menu = action.bind(runner);
      final execution = button.invoke();
      expect(menu.isLoading, isTrue);
      expect(menu.canInvoke, isFalse);
      await menu.invoke();
      expect(calls, 1);
      pending.complete();
      await execution;
      expect(menu.canInvoke, isTrue);
    },
  );

  test(
    'a confirmed menu action survives replacement of its source card',
    () async {
      final runner = ImageCardActionRunner();
      var calls = 0;
      final action = ImageCardAction(
        id: ImageCardActionId.copy,
        icon: Icons.copy,
        label: 'Copy',
        invoke: () => calls++,
      ).bind(runner);
      runner.dispose();
      await action.invoke();
      expect(calls, 1);
    },
  );

  test(
    'failed actions clear busy state and preserve the original failure',
    () async {
      final runner = ImageCardActionRunner();
      addTearDown(runner.dispose);
      final failure = StateError('export failed');
      final action = ImageCardAction(
        id: ImageCardActionId.export,
        icon: Icons.save,
        label: 'Export',
        invoke: () => throw failure,
      ).bind(runner);
      await expectLater(action.invoke(), throwsA(same(failure)));
      expect(action.isLoading, isFalse);
    },
  );

  test(
    'batch results keep per-target successes and original failures',
    () async {
      final failure = StateError('missing');
      final visited = <String>[];
      final result = await ImageCardBatchResult.execute(['a', 'b', 'c'], (
        id,
      ) async {
        visited.add(id);
        if (id == 'b') throw failure;
      });
      expect(visited, ['a', 'b', 'c']);
      expect(result.succeeded, ['a', 'c']);
      expect(result.failures['b']?.error, same(failure));
    },
  );
}
