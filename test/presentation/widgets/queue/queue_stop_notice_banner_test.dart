import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/widgets/queue/execution_stats_panel.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final textScale in [1.0, 3.0]) {
      testWidgets('队列停止原因在 ${width.toInt()} 宽、$textScale 倍文字下完整可读且可关闭', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer(
          overrides: [
            queueExecutionNotifierProvider.overrideWith(
              _StoppedQueueExecutionNotifier.new,
            ),
            replicationQueueNotifierProvider.overrideWith(
              _EmptyQueueNotifier.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('zh'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(child: ExecutionStatsPanel()),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final message = find.text(l10n.queue_stoppedStorageWriteFailed);
        expect(message, findsOneWidget);
        final notice = find.byKey(const ValueKey('queue-stop-notice'));
        final scheme = Theme.of(tester.element(notice)).colorScheme;
        expect(tester.widget<Material>(notice).color, scheme.errorContainer);
        expect(
          tester.widget<Text>(message).style?.color,
          scheme.onErrorContainer,
        );
        final noticeRect = tester.getRect(notice);
        expect(noticeRect.left, greaterThanOrEqualTo(0));
        expect(noticeRect.right, lessThanOrEqualTo(width));

        final dismiss = find.byKey(const ValueKey('queue-stop-notice-dismiss'));
        final dismissSize = tester.getSize(dismiss);
        expect(dismissSize.width, greaterThanOrEqualTo(40));
        expect(dismissSize.height, greaterThanOrEqualTo(40));
        await tester.tap(dismiss);
        await tester.pump();

        expect(notice, findsNothing);
        expect(
          container.read(queueExecutionNotifierProvider).stopNotice,
          isNull,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _StoppedQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() =>
      const QueueExecutionState(stopNotice: QueueStopNotice.storageWriteFailed);
}

class _EmptyQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();
}
