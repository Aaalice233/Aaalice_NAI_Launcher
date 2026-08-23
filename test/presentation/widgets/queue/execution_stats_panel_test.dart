import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/widgets/queue/execution_stats_panel.dart';

void main() {
  testWidgets('队列执行和加入当前任务按钮保持同一行', (tester) async {
    await tester.binding.setSurfaceSize(const Size(460, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          queueExecutionNotifierProvider.overrideWith(
            _RunningQueueExecutionNotifier.new,
          ),
          replicationQueueNotifierProvider.overrideWith(
            _QueueWithTaskNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ExecutionStatsPanel(onAddCurrentTask: _doNothing),
          ),
        ),
      ),
    );
    await tester.pump();

    final pauseButton = find.ancestor(
      of: find.text('暂停队列'),
      matching: find.byType(FilledButton),
    );
    final addButton = find.byKey(const Key('queue-add-current-task'));

    expect(pauseButton, findsOneWidget);
    expect(addButton, findsOneWidget);
    expect(tester.getTopLeft(pauseButton).dy, tester.getTopLeft(addButton).dy);
    expect(
      tester.getSize(pauseButton).height,
      tester.getSize(addButton).height,
    );
    expect(tester.takeException(), isNull);
  });
}

void _doNothing() {}

class _RunningQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState(
    status: QueueExecutionStatus.running,
    totalTasksInSession: 1,
  );
}

class _QueueWithTaskNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() =>
      ReplicationQueueState(tasks: [ReplicationTask.create(prompt: 'test')]);
}
