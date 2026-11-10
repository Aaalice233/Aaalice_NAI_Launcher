import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/core/cache/local_gallery_thumbnail_provider.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store_provider.dart';
import 'package:nai_launcher/data/models/queue/failure_handling_strategy.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_status.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

import 'helpers/app_bootstrap_effects_harness.dart';
import 'helpers/memory_queue_blob_store.dart';
import 'helpers/queue_execution_harness.dart';

final class _ScriptedQueue extends QueueExecutionNotifier {
  _ScriptedQueue(
    this.initial,
    this.calls, {
    this.pauseSettled,
    this.onListenerCountChanged,
  });

  final QueueExecutionStatus initial;
  final List<String> calls;
  final Future<void>? pauseSettled;
  final void Function(int delta)? onListenerCountChanged;

  @override
  QueueExecutionState build() {
    if (onListenerCountChanged case final callback?) {
      ref.onAddListener(() => callback(1));
      ref.onRemoveListener(() => callback(-1));
    }
    return QueueExecutionState(status: initial);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    if (state.isRunning || state.isReady) {
      state = state.copyWith(status: QueueExecutionStatus.paused);
    }
    await pauseSettled;
  }

  @override
  Future<void> stopExecution() async {
    calls.add('stop');
    state = state.copyWith(
      status: QueueExecutionStatus.idle,
      clearCurrentTaskId: true,
    );
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    if (state.isPaused) {
      state = state.copyWith(status: QueueExecutionStatus.running);
    }
  }
}

final class _IdleSubscription extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionState.initial();

  @override
  void setAppVisible(bool isVisible) {}
}

void main() {
  late List<String> calls;
  late ProviderContainer container;

  Future<void> pumpWithQueue(
    WidgetTester tester,
    QueueExecutionStatus status,
  ) async {
    calls = [];
    container = await pumpAppBootstrapEffects(
      tester,
      queue: () => _ScriptedQueue(status, calls),
      overrides: [
        subscriptionNotifierProvider.overrideWith(_IdleSubscription.new),
      ],
    );
    addTearDown(
      () => LocalGalleryThumbnailProvider.setAppLifecycleState(
        AppLifecycleState.resumed,
      ),
    );
  }

  Future<void> enter(
    WidgetTester tester,
    List<AppLifecycleState> states,
  ) async {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
  }

  QueueExecutionStatus queueStatus() =>
      container.read(queueExecutionNotifierProvider).status;

  testWidgets('a queue paused for the background resumes as soon as the '
      'window is visible again, before it regains focus', (tester) async {
    await pumpWithQueue(tester, QueueExecutionStatus.running);

    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]);
    expect(calls, ['pause']);
    expect(queueStatus(), QueueExecutionStatus.paused);

    await enter(tester, const [AppLifecycleState.inactive]);
    expect(calls, ['pause', 'resume']);
    expect(queueStatus(), QueueExecutionStatus.running);

    await enter(tester, const [AppLifecycleState.resumed]);
    expect(calls, ['pause', 'resume']);
  });

  testWidgets('switching focus never pauses or resumes the queue', (
    tester,
  ) async {
    await pumpWithQueue(tester, QueueExecutionStatus.running);

    for (var round = 0; round < 3; round++) {
      await enter(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
    }

    expect(calls, isEmpty);
    expect(queueStatus(), QueueExecutionStatus.running);
  });

  testWidgets('a queue the user paused stays paused after the window returns', (
    tester,
  ) async {
    await pumpWithQueue(tester, QueueExecutionStatus.paused);

    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(calls, isEmpty);
    expect(queueStatus(), QueueExecutionStatus.paused);
  });

  testWidgets('a queue resumed and paused again elsewhere while hidden is '
      'not resumed when the window returns', (tester) async {
    await pumpWithQueue(tester, QueueExecutionStatus.running);
    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]);

    final queue = container.read(queueExecutionNotifierProvider.notifier);
    await queue.resume();
    await queue.pause();
    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(calls, ['pause', 'resume', 'pause']);
    expect(queueStatus(), QueueExecutionStatus.paused);
  });

  testWidgets('a queue stopped while hidden is not resumed when the window '
      'returns', (tester) async {
    await pumpWithQueue(tester, QueueExecutionStatus.running);
    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]);

    await container
        .read(queueExecutionNotifierProvider.notifier)
        .stopExecution();
    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(calls, ['pause', 'stop']);
    expect(queueStatus(), QueueExecutionStatus.idle);
  });

  testWidgets('removing the root while a background pause is settling leaves '
      'no queue listener and reads no ref afterwards', (tester) async {
    calls = [];
    final pauseSettled = Completer<void>();
    final showEffects = ValueNotifier(true);
    var activeListeners = 0;
    addTearDown(showEffects.dispose);
    addTearDown(
      () => LocalGalleryThumbnailProvider.setAppLifecycleState(
        AppLifecycleState.resumed,
      ),
    );
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final inert = Provider<int>((ref) => 0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appBackgroundLifecycleOverrides(
            queue: () => _ScriptedQueue(
              QueueExecutionStatus.running,
              calls,
              pauseSettled: pauseSettled.future,
              onListenerCountChanged: (delta) => activeListeners += delta,
            ),
          ),
          subscriptionNotifierProvider.overrideWith(_IdleSubscription.new),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showEffects,
            builder: (_, show, __) => show
                ? AppBootstrapEffects(
                    anlasWatcher: inert,
                    kritaBridge: inert,
                    mcpServer: inert,
                    cooccurrenceDataPack: inert,
                    cloudSyncLifecycle: () async {},
                    child: const SizedBox.shrink(),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]);
    expect(activeListeners, 1);

    showEffects.value = false;
    // 隐藏期间不出普通帧，要强制一帧才能把根组件卸掉
    tester.binding.scheduleForcedFrame();
    await tester.pump();
    expect(find.byType(AppBootstrapEffects), findsNothing);
    expect(activeListeners, 0);

    pauseSettled.complete();
    await tester.pump();
    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(calls, ['pause']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a queue request that fails while the window is hidden is '
      'settled, and the queue carries on once the window returns', (
    tester,
  ) async {
    final generation = ControlledImageGenerationNotifier();
    final tasks = [
      ReplicationTask.create(prompt: 'flaky'),
      ReplicationTask.create(prompt: 'next'),
    ];
    container = await pumpAppBootstrapEffects(
      tester,
      queue: TestQueueExecutionNotifier.new,
      generationParams: QueueTestGenerationParamsNotifier.new,
      overrides: [
        ...queueEngineOverrides(
          tasks,
          generation,
          localStorage: ConfiguredLocalStorageService(
            retryCount: 3,
            retryIntervalSeconds: 1,
          ),
        ),
        subscriptionNotifierProvider.overrideWith(_IdleSubscription.new),
      ],
    );
    addTearDown(
      () => LocalGalleryThumbnailProvider.setAppLifecycleState(
        AppLifecycleState.resumed,
      ),
    );

    await container.read(queueExecutionNotifierProvider.notifier).startQueue();
    await tester.pump(Duration.zero);
    expect(generation.startedPrompts, ['flaky']);

    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]);
    expect(queueStatus(), QueueExecutionStatus.paused);
    generation.fail(0);
    generation.settle(0);
    await tester.pump(const Duration(seconds: 2));

    await enter(tester, const [AppLifecycleState.inactive]);
    await tester.pump(Duration.zero);
    expect(generation.startedPrompts, ['flaky', 'flaky']);
    expect(queueStatus(), QueueExecutionStatus.running);
  });

  for (final failsWhileHidden in [true, false]) {
    testWidgets(
      failsWhileHidden
          ? 'the final retry fails while hidden and stays paused on return'
          : 'a background pause resumes when the final retry has no failure',
      (tester) async {
        final generation = ControlledImageGenerationNotifier();
        final tasks = [
          ReplicationTask.create(prompt: 'first'),
          ReplicationTask.create(prompt: 'next'),
        ];
        container = await pumpAppBootstrapEffects(
          tester,
          queue: TestQueueExecutionNotifier.new,
          generationParams: QueueTestGenerationParamsNotifier.new,
          overrides: [
            ...queueEngineOverrides(
              tasks,
              generation,
              localStorage: ConfiguredLocalStorageService(
                retryCount: 1,
                retryIntervalSeconds: 0,
              ),
            ),
            replicationQueueBlobStoreProvider.overrideWithValue(
              memoryQueueBlobStore(),
            ),
            subscriptionNotifierProvider.overrideWith(_IdleSubscription.new),
          ],
        );
        addTearDown(
          () => LocalGalleryThumbnailProvider.setAppLifecycleState(
            AppLifecycleState.resumed,
          ),
        );
        final queue = container.read(queueExecutionNotifierProvider.notifier);
        await queue.setFailureStrategy(FailureHandlingStrategy.pauseAndWait);
        await queue.startQueue();
        await tester.pump();
        generation.fail(0);
        generation.settle(0);
        await tester.pump(Duration.zero);
        expect(generation.startedPrompts, ['first', 'first']);

        await enter(tester, const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
        ]);
        expect(queueStatus(), QueueExecutionStatus.paused);
        if (failsWhileHidden) {
          generation.fail(1);
        } else {
          generation.complete(1);
        }
        generation.settle(1);
        await tester.pump();
        expect(queueStatus(), QueueExecutionStatus.paused);

        await enter(tester, const [
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]);
        if (failsWhileHidden) {
          expect(generation.startedPrompts, ['first', 'first']);
          expect(queueStatus(), QueueExecutionStatus.paused);
          final task = container
              .read(replicationQueueNotifierProvider)
              .tasks
              .first;
          expect(task.id, tasks.first.id);
          expect(task.status, ReplicationTaskStatus.failed);
        } else {
          expect(generation.startedPrompts, ['first', 'first', 'next']);
          expect(queueStatus(), QueueExecutionStatus.running);
        }
      },
    );
  }

  testWidgets('a queue request still preparing when the window is hidden is '
      'settled as completed, and the next task runs once the window returns', (
    tester,
  ) async {
    final generation = ControlledImageGenerationNotifier()
      ..preparationGate = Completer<void>();
    final tasks = [
      ReplicationTask.create(prompt: 'first'),
      ReplicationTask.create(prompt: 'second'),
    ];
    container = await pumpAppBootstrapEffects(
      tester,
      queue: TestQueueExecutionNotifier.new,
      generationParams: QueueTestGenerationParamsNotifier.new,
      overrides: [
        ...queueEngineOverrides(tasks, generation),
        subscriptionNotifierProvider.overrideWith(_IdleSubscription.new),
      ],
    );
    addTearDown(
      () => LocalGalleryThumbnailProvider.setAppLifecycleState(
        AppLifecycleState.resumed,
      ),
    );

    await container.read(queueExecutionNotifierProvider.notifier).startQueue();
    await tester.pump(Duration.zero);
    expect(generation.startedPrompts, isEmpty);

    await enter(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]);
    expect(queueStatus(), QueueExecutionStatus.paused);
    generation.preparationGate!.complete();
    await tester.pump(Duration.zero);
    expect(generation.startedPrompts, ['first']);
    generation.complete(0);
    generation.settle(0);
    await tester.pump(const Duration(seconds: 2));
    expect(queueStatus(), QueueExecutionStatus.paused);
    expect(container.read(queueExecutionNotifierProvider).completedCount, 1);

    await enter(tester, const [AppLifecycleState.inactive]);
    await tester.pump(Duration.zero);
    expect(generation.startedPrompts, ['first', 'second']);
    expect(queueStatus(), QueueExecutionStatus.running);
  });
}
