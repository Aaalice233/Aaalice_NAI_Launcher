import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action_dispatch.dart';

import '../../../helpers/log_capture.dart';

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

  testWidgets('delete action reports a file failure without its path', (
    tester,
  ) async {
    const path = r'C:\QA\App Folder\precise_refs\reference.png';
    final action = ImageCardAction(
      id: ImageCardActionId.delete,
      icon: Icons.delete,
      label: 'Delete selected references',
      supportsBatch: true,
      invoke: () => throw const FileSystemException(
        'private metadata error',
        path,
        OSError('private OS message', 5),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SizedBox(key: Key('delete-action-context'))),
      ),
    );
    final context = tester.element(
      find.byKey(const Key('delete-action-context')),
    );

    final logs = await captureLogs(
      () => dispatchImageCardAction(context, action),
    );
    final text = logs.join('\n');
    expect(text, contains('Image card action delete failed'));
    expect(text, contains('FileSystemException(errno: 5)'));
    expect(text, isNot(contains(path)));
    expect(text, isNot(contains('private metadata error')));
    expect(text, isNot(contains('private OS message')));

    await tester.pumpAndSettle();
    expect(find.text('Error · Delete selected references'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
