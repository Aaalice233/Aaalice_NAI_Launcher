import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/replication_queue_enqueue_result.dart';
import 'package:nai_launcher/data/services/replication_queue_persistence.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/queue/enqueue_result_toast.dart';

void main() {
  final failure = ReplicationQueueWriteException(
    'Failed to save the queue index',
    const FileSystemException('injected'),
  );

  EnqueueResult unsaved({
    List<String> queued = const [],
    List<String> started = const [],
    List<String> failed = const [],
    List<String> withdrawn = const [],
    List<String> removed = const [],
    bool indexSaved = true,
  }) => EnqueueResult.settled(
    queuedTaskIds: queued,
    startedTaskIds: started,
    failedTaskIds: failed,
    withdrawnTaskIds: withdrawn,
    removedTaskIds: removed,
    indexSaved: indexSaved,
    failure: failure,
  );

  group('failure message', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('is absent when every task was saved', () {
      expect(enqueueFailureMessage(l10n, const EnqueueResult.saved([])), null);
      expect(
        enqueueFailureMessage(l10n, const EnqueueResult.saved(['a'])),
        isNull,
      );
    });

    test('says nothing was added when no task was kept', () {
      expect(
        enqueueFailureMessage(l10n, unsaved(withdrawn: ['a'], removed: ['b'])),
        '${l10n.queue_enqueueWithdrawn(1)}\n${l10n.queue_enqueueRemoved(1)}',
      );
    });

    test('counts kept and not-added tasks for a partial save', () {
      expect(
        enqueueFailureMessage(
          l10n,
          unsaved(queued: ['a', 'b'], failed: ['c'], withdrawn: ['d']),
        ),
        '${l10n.queue_enqueueWithdrawn(1)}\n${l10n.queue_enqueueQueued(2)}\n'
        '${l10n.queue_enqueueFailedBeforeSaved(1)}',
      );
      expect(
        enqueueFailureMessage(l10n, unsaved(queued: ['a'], failed: ['b'])),
        '${l10n.queue_enqueueQueued(1)}\n${l10n.queue_enqueueFailedBeforeSaved(1)}',
      );
    });

    test('names started and withdrawn counts together', () {
      expect(
        enqueueFailureMessage(l10n, unsaved(started: ['a'], failed: ['b'])),
        '${l10n.queue_enqueueStartedUnsaved(1)}\n${l10n.queue_enqueueFailedBeforeSaved(1)}',
      );
      expect(
        enqueueFailureMessage(
          l10n,
          unsaved(started: ['a', 'b'], withdrawn: ['c', 'd', 'e']),
        ),
        l10n.queue_enqueueStartedAndWithdrawn(2, 3),
      );
    });

    test('warns when the index is still unsaved', () {
      final message = enqueueFailureMessage(
        l10n,
        unsaved(withdrawn: ['a'], indexSaved: false),
      );

      expect(message, startsWith(l10n.queue_enqueueWithdrawn(1)));
      expect(message, endsWith(l10n.queue_enqueueIndexUnsaved));
    });
  });

  test(
    'enqueue messages exist in every language with the same placeholders',
    () {
      const keys = [
        'queue_enqueueStartedUnsaved',
        'queue_enqueueStartedAndWithdrawn',
        'queue_enqueueQueued',
        'queue_enqueueWithdrawn',
        'queue_enqueueRemoved',
        'queue_enqueueUnexpectedError',
        'queue_enqueueFailedBeforeSaved',
        'queue_enqueueIndexUnsaved',
        'queue_imagesUnavailable',
        'queue_imagesUnavailableHint',
      ];
      final placeholder = RegExp(r'\{(\w+)\}');
      Map<String, Set<String>> placeholdersOf(String language) {
        final arb =
            jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
                as Map<String, dynamic>;
        return {
          for (final key in keys)
            key: {
              for (final match in placeholder.allMatches(arb[key] as String))
                match.group(1)!,
            },
        };
      }

      final english = placeholdersOf('en');
      for (final language in ['zh', 'zh_Hant', 'ja']) {
        expect(placeholdersOf(language), english, reason: language);
      }
      expect(english['queue_enqueueStartedAndWithdrawn'], {
        'started',
        'withdrawn',
      });
    },
  );

  group('toast', () {
    Future<void> showFor(
      WidgetTester tester,
      EnqueueResult result, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => showEnqueueResultToast(
                    context,
                    result,
                    successMessage: 'SUCCESS',
                  ),
                  child: const Text('ENQUEUE'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ENQUEUE'));
      await tester.pump(const Duration(milliseconds: 301));
    }

    Future<void> dismiss(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 301));
      expect(tester.takeException(), isNull);
    }

    testWidgets('a saved enqueue shows the caller message', (tester) async {
      await showFor(tester, const EnqueueResult.saved(['a']));

      expect(find.text('SUCCESS'), findsOneWidget);
      await dismiss(tester);
    });

    testWidgets('an enqueue that accepted nothing reports a full queue', (
      tester,
    ) async {
      await showFor(tester, const EnqueueResult.saved([]));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.onlineGallery_queueFullMax), findsOneWidget);
      expect(find.text('SUCCESS'), findsNothing);
      await dismiss(tester);
    });

    testWidgets('a withdrawn enqueue is not reported as added', (tester) async {
      await showFor(tester, EnqueueResult.withdrawn(const ['a'], failure));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.queue_enqueueWithdrawn(1)), findsOneWidget);
      expect(find.text('SUCCESS'), findsNothing);
      expect(find.textContaining('injected'), findsNothing);
      await dismiss(tester);
    });

    testWidgets('a started enqueue names both counts in Chinese', (
      tester,
    ) async {
      await showFor(
        tester,
        unsaved(started: ['a'], withdrawn: ['b', 'c'], indexSaved: false),
        locale: const Locale('zh'),
      );

      final l10n = lookupAppLocalizations(const Locale('zh'));
      expect(
        find.text(
          '${l10n.queue_enqueueStartedAndWithdrawn(1, 2)}\n'
          '${l10n.queue_enqueueIndexUnsaved}',
        ),
        findsOneWidget,
      );
      expect(find.text('SUCCESS'), findsNothing);
      await dismiss(tester);
    });

    for (final (label, result) in [
      ('failed', unsaved(failed: ['a'])),
      ('removed', unsaved(removed: ['a'])),
      ('partially saved', unsaved(queued: ['a'], withdrawn: ['b'])),
      (
        'all five groups',
        unsaved(
          queued: ['a'],
          started: ['b'],
          failed: ['c'],
          withdrawn: ['d'],
          removed: ['e'],
        ),
      ),
    ]) {
      testWidgets(
        'a $label result reports each group without a success toast',
        (tester) async {
          await showFor(tester, result);
          final message = enqueueFailureMessage(
            lookupAppLocalizations(const Locale('en')),
            result,
          )!;
          expect(find.text(message), findsOneWidget);
          expect(find.text('SUCCESS'), findsNothing);
          await dismiss(tester);
        },
      );
    }
  });
}
