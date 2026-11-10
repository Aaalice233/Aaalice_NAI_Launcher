import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_status.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/queue/task_list_item.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));
  final failedTask = ReplicationTask(
    id: 'thin-mask',
    prompt: 'thin mask prompt',
    createdAt: DateTime(2026),
    status: ReplicationTaskStatus.failed,
    errorMessage: const EmptyInpaintMaskException().toString(),
  );

  testWidgets('failed queue items show the localized empty-mask reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ListView(
          children: [
            FailedTaskListItem(task: failedTask),
            QueueTaskDetailView(task: failedTask),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final summary =
        '${l10n.generation_emptyInpaintMask}\n'
        '${l10n.generation_emptyInpaintMaskHint(8)}';
    expect(
      find.text(summary),
      findsOneWidget,
      reason: 'failed list shows the summary',
    );
    expect(
      find.text('$summary\n\n${failedTask.errorMessage}'),
      findsOneWidget,
      reason: 'detail keeps the original error for troubleshooting',
    );
    expect(tester.takeException(), isNull);
  });

  for (final (errorMessage, title) in [
    (
      'GENERATION_ERROR_INVALID_RESOLUTION|513|768|512|768',
      l10n.generation_invalidResolution,
    ),
    (
      'GENERATION_ERROR_UNSUPPORTED_RANDOM_MODEL|future-model',
      l10n.randomPrompt_unsupportedModel,
    ),
  ]) {
    testWidgets('failed queue items localize the local rejection $title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          FailedTaskListItem(
            task: failedTask.copyWith(errorMessage: errorMessage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(title), findsOneWidget);
      expect(find.text(errorMessage), findsNothing);
    });
  }

  testWidgets('unrecognized queue errors keep their original text', (
    tester,
  ) async {
    const message = 'Invalid generation snapshot: FormatException';
    await tester.pumpWidget(
      _app(
        FailedTaskListItem(task: failedTask.copyWith(errorMessage: message)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}
