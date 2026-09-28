import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_maximize_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_generation_controller.dart';

void main() {
  for (final initialWidth in [1180.0, 700.0]) {
    testWidgets(
      '从 ${initialWidth == 1180 ? 'desktop' : 'medium'} 进入 compact 保留 Prompt 最大化状态',
      (tester) async {
        final storage = _MemoryLocalStorageService({
          StorageKeys.mobileGenerationGestureHintCompleted: true,
          StorageKeys.promptMaximized: true,
        });
        await tester.binding.setSurfaceSize(Size(initialWidth, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: Text('WIDE_LAYOUT'))),
          ),
        );

        expect(container.read(promptMaximizeNotifierProvider), isTrue);
        expect(find.byType(_ControllerHarness), findsNothing);

        await tester.binding.setSurfaceSize(const Size(390, 760));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: _ControllerHarness()),
          ),
        );
        await tester.pump();

        expect(find.byType(_ControllerHarness), findsOneWidget);
        expect(container.read(promptMaximizeNotifierProvider), isTrue);
        expect(storage.values[StorageKeys.promptMaximized], isTrue);
      },
    );
  }

  testWidgets('移动端可直接将当前参数加入队列', (tester) async {
    final storage = _MemoryLocalStorageService({
      StorageKeys.mobileGenerationGestureHintCompleted: true,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
          replicationQueueNotifierProvider.overrideWith(
            _TestReplicationQueueNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: _ControllerHarness(showQueueAction: true),
        ),
      ),
    );
    await tester.pump();

    final scope = ProviderScope.containerOf(
      tester.element(find.byType(_ControllerHarness)),
    );
    final paramsNotifier = scope.read(
      generationParamsNotifierProvider.notifier,
    );
    paramsNotifier
      ..updatePrompt('queued prompt')
      ..updateNegativePrompt('queued negative')
      ..updateSize(1024, 768)
      ..updateSteps(35)
      ..updateScale(6.5)
      ..updateSampler('k_dpmpp_2m')
      ..updateSeed(123456)
      ..updateCfgRescale(0.42)
      ..updateUseCoords(true)
      ..updateNSamples(4)
      ..addCharacter(
        const CharacterPrompt(
          prompt: 'character prompt',
          negativePrompt: 'character negative',
          positionX: 0.25,
          positionY: 0.75,
          position: 'B4',
        ),
      );
    await tester.pump();

    final expected = scope.read(generationParamsNotifierProvider);
    final expectedBatchSize = scope.read(imagesPerRequestProvider);
    await tester.tap(find.text('MOBILE_QUEUE'));
    await tester.pump();

    final queueNotifier =
        scope.read(replicationQueueNotifierProvider.notifier)
            as _TestReplicationQueueNotifier;
    expect(queueNotifier.addCallCount, 1);
    final task = queueNotifier.addedTask!;
    expect(task.prompt, expected.prompt);
    expect(task.negativePrompt, expected.negativePrompt);
    expect(task.applyNegativePrompt, isTrue);
    expect(task.source, ReplicationTaskSource.local);
    expect(task.seed, expected.seed);
    expect(task.sampler, expected.sampler);
    expect(task.steps, expected.steps);
    expect(task.cfgScale, expected.scale);
    expect(task.model, expected.model);
    expect(task.width, expected.width);
    expect(task.height, expected.height);
    expect(task.characterPrompts, hasLength(1));
    expect(task.characterPrompts!.single.prompt, 'character prompt');
    expect(task.characterPrompts!.single.negativePrompt, 'character negative');
    expect(task.characterPrompts!.single.positionX, 0.25);
    expect(task.characterPrompts!.single.positionY, 0.75);

    final snapshot = task.generationSnapshot!;
    expect(
      ReplicationTaskGenerationSnapshot.decodeBatchSize(snapshot),
      expectedBatchSize,
    );
    final decoded = ReplicationTaskGenerationSnapshot.decode(snapshot);
    expect(decoded, expected.copyWith(nSamples: 1));
    expect(decoded.prompt, expected.prompt);
    expect(decoded.negativePrompt, expected.negativePrompt);
    expect(decoded.nSamples, 1);
    expect(decoded.model, expected.model);
    expect(decoded.width, 1024);
    expect(decoded.height, 768);
    expect(decoded.steps, 35);
    expect(decoded.scale, 6.5);
    expect(decoded.sampler, 'k_dpmpp_2m');
    expect(decoded.seed, 123456);
    expect(decoded.cfgRescale, 0.42);
    expect(decoded.useCoords, isTrue);
    expect(decoded.characters, hasLength(1));
    expect(decoded.characters.single.prompt, 'character prompt');
    expect(decoded.characters.single.negativePrompt, 'character negative');
    expect(decoded.characters.single.position, 'B4');
    expect(find.text('已加入队列'), findsOneWidget);
    expect(scope.read(replicationQueueNotifierProvider).tasks, [task]);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('未登录且提示词为空时直接进入登录页', (tester) async {
    final storage = _MemoryLocalStorageService({
      StorageKeys.mobileGenerationGestureHintCompleted: true,
    });
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _ControllerHarness(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) =>
              const Scaffold(body: Text('LOGIN_SCREEN_OPENED')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: MaterialApp.router(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('MOBILE_GENERATE'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_SCREEN_OPENED'), findsOneWidget);
    expect(find.text('请输入提示词'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ControllerHarness extends ConsumerStatefulWidget {
  const _ControllerHarness({this.showQueueAction = false});

  final bool showQueueAction;

  @override
  ConsumerState<_ControllerHarness> createState() => _ControllerHarnessState();
}

class _ControllerHarnessState extends ConsumerState<_ControllerHarness> {
  late final MobileGenerationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileGenerationController(ref);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: widget.showQueueAction
              ? () => _controller.addCurrentPromptToQueue(context)
              : () => unawaited(_controller.generate(context)),
          child: Text(
            widget.showQueueAction ? 'MOBILE_QUEUE' : 'MOBILE_GENERATE',
          ),
        ),
      ),
    );
  }
}

class _TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  int addCallCount = 0;
  ReplicationTask? addedTask;

  @override
  ReplicationQueueState build() => const ReplicationQueueState();

  @override
  Future<bool> add(ReplicationTask task) async {
    addCallCount++;
    addedTask = task;
    state = state.copyWith(tasks: [...state.tasks, task]);
    return true;
  }
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _MemoryLocalStorageService extends LocalStorageService {
  _MemoryLocalStorageService(this.values);

  final Map<String, Object?> values;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return values.containsKey(key) ? values[key] as T? : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
