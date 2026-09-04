import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_notifier.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_controls/batch_settings_button.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_controls/generation_controls.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_controls/random_mode_toggle.dart';
import 'package:nai_launcher/presentation/widgets/anlas/anlas_balance_chip.dart';
import 'package:nai_launcher/presentation/widgets/anlas/opus_usage_chip.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_number_input.dart';
import 'package:nai_launcher/presentation/widgets/generation/auto_save_toggle_chip.dart';

void main() {
  testWidgets('compact controls keep the auto-save toggle visible', (
    tester,
  ) async {
    final storage = _MemoryLocalStorageService({
      StorageKeys.autoSaveImages: false,
      StorageKeys.showRandomPromptTools: true,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          localStorageServiceProvider.overrideWith((ref) => storage),
          kritaBridgeNotifierProvider.overrideWith(
            (ref) => _TestKritaBridgeNotifier(),
          ),
          replicationQueueNotifierProvider.overrideWith(
            _TestReplicationQueueNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _TestQueueExecutionNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _TestSubscriptionNotifier.new,
          ),
          estimatedCostProvider.overrideWith((ref) => 0),
          isFreeGenerationProvider.overrideWith((ref) => true),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 180,
              child: GenerationControls(compact: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AutoSaveToggleChip), findsOneWidget);
    expect(
      tester
          .widget<AutoSaveToggleChip>(find.byType(AutoSaveToggleChip))
          .compact,
      isTrue,
    );
    expect(find.text('自动保存'), findsOneWidget);
    expect(find.byIcon(Icons.playlist_add), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('生成')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.playlist_add), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact footer uses one row when it fits and wraps only when necessary',
    (tester) async {
      final storage = _MemoryLocalStorageService({
        StorageKeys.autoSaveImages: false,
        StorageKeys.showRandomPromptTools: true,
      });

      for (final scenario in const [
        (width: 320.0, textScale: 1.0, singleLine: false),
        (width: 438.0, textScale: 1.0, singleLine: false),
        (width: 475.0, textScale: 1.0, singleLine: false),
        (width: 497.0, textScale: 1.0, singleLine: true),
        (width: 590.0, textScale: 1.0, singleLine: true),
        (width: 700.0, textScale: 1.0, singleLine: true),
        (width: 840.0, textScale: 1.0, singleLine: true),
        (width: 320.0, textScale: 3.0, singleLine: false),
        (width: 475.0, textScale: 3.0, singleLine: false),
        (width: 590.0, textScale: 3.0, singleLine: false),
        (width: 700.0, textScale: 3.0, singleLine: false),
        (width: 840.0, textScale: 3.0, singleLine: true),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
              localStorageServiceProvider.overrideWith((ref) => storage),
              kritaBridgeNotifierProvider.overrideWith(
                (ref) => _TestKritaBridgeNotifier(),
              ),
              replicationQueueNotifierProvider.overrideWith(
                _TestReplicationQueueNotifier.new,
              ),
              queueExecutionNotifierProvider.overrideWith(
                _TestQueueExecutionNotifier.new,
              ),
              subscriptionNotifierProvider.overrideWith(
                _TestSubscriptionNotifier.new,
              ),
              estimatedCostProvider.overrideWith((ref) => 0),
              isFreeGenerationProvider.overrideWith((ref) => true),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scenario.textScale)),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    key: const ValueKey('footer-test-bounds'),
                    width: scenario.width,
                    height: 600,
                    child: const GenerationControls(compact: true),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final footerRect = tester.getRect(
          find.byKey(const ValueKey('footer-test-bounds')),
        );
        final primaryRect = tester.getRect(
          find.byKey(const ValueKey('generation-footer-primary-action')),
        );
        final actionFinders = <Finder>[
          find.byType(AnlasBalanceChip),
          find.byType(RandomModeToggle),
          find.byType(AutoSaveToggleChip),
          find.byType(DraggableNumberInput),
          find.byType(BatchSettingsButton),
        ];
        final actionRects = actionFinders.map(tester.getRect).toList();
        final reason =
            'width=${scenario.width}, textScale=${scenario.textScale}';

        expect(find.byType(FittedBox), findsNothing);
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.text('生成'), findsOneWidget);
        expect(find.text('7,384'), findsOneWidget);
        expect(find.text('自动保存'), findsOneWidget);
        expect(primaryRect.height, greaterThanOrEqualTo(48));
        for (final rect in [primaryRect, ...actionRects]) {
          expect(
            footerRect.inflate(0.01).contains(rect.topLeft) &&
                footerRect.inflate(0.01).contains(rect.bottomRight),
            isTrue,
            reason: '$reason clipped $rect',
          );
        }

        if (scenario.singleLine) {
          for (final rect in actionRects) {
            expect(
              rect.center.dy,
              closeTo(primaryRect.center.dy, 0.01),
              reason: '$reason unexpectedly wrapped',
            );
          }
          final opusRect = tester.getRect(find.byType(OpusUsageChip));
          final anlasRect = tester.getRect(find.byType(AnlasBalanceChip));
          final batchRect = tester.getRect(find.byType(BatchSettingsButton));
          final countRect = tester.getRect(find.byType(DraggableNumberInput));
          final randomRect = tester.getRect(find.byType(RandomModeToggle));
          final autoSaveRect = tester.getRect(find.byType(AutoSaveToggleChip));
          expect(opusRect.left, closeTo(footerRect.left, 0.01), reason: reason);
          expect(
            opusRect.right,
            lessThanOrEqualTo(anlasRect.left),
            reason: reason,
          );
          expect(anlasRect.right, lessThan(primaryRect.left), reason: reason);
          expect(primaryRect.right, lessThan(batchRect.left), reason: reason);
          expect(
            batchRect.right,
            lessThanOrEqualTo(countRect.left),
            reason: reason,
          );
          expect(
            countRect.right,
            lessThanOrEqualTo(randomRect.left),
            reason: reason,
          );
          expect(
            randomRect.right,
            lessThanOrEqualTo(autoSaveRect.left),
            reason: reason,
          );
          expect(
            autoSaveRect.right,
            closeTo(footerRect.right, 0.01),
            reason: reason,
          );
          expect(primaryRect.width, greaterThanOrEqualTo(160), reason: reason);
        } else {
          expect(
            primaryRect.left,
            closeTo(footerRect.left, 0.01),
            reason: reason,
          );
          expect(
            primaryRect.right,
            closeTo(footerRect.right, 0.01),
            reason: reason,
          );
          for (final rect in actionRects) {
            expect(
              rect.top,
              greaterThanOrEqualTo(primaryRect.bottom + 7.9),
              reason: '$reason did not use the centered layered layout',
            );
          }
          if (scenario.textScale == 1 && scenario.width >= 438) {
            for (final rect in actionRects.skip(1)) {
              expect(
                rect.center.dy,
                closeTo(actionRects.first.center.dy, 0.01),
                reason: '$reason split footer actions across multiple rows',
              );
            }
          }
        }
        expect(tester.takeException(), isNull, reason: reason);
      }
    },
  );

  testWidgets('compact footer keeps its rows stable while generating', (
    tester,
  ) async {
    final storage = _MemoryLocalStorageService({
      StorageKeys.autoSaveImages: false,
      StorageKeys.showRandomPromptTools: true,
    });
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          imageGenerationNotifierProvider.overrideWith(
            _TestImageGenerationNotifier.new,
          ),
          localStorageServiceProvider.overrideWith((ref) => storage),
          kritaBridgeNotifierProvider.overrideWith(
            (ref) => _TestKritaBridgeNotifier(),
          ),
          replicationQueueNotifierProvider.overrideWith(
            _TestReplicationQueueNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _TestQueueExecutionNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _TestSubscriptionNotifier.new,
          ),
          estimatedCostProvider.overrideWith((ref) => 0),
          isFreeGenerationProvider.overrideWith((ref) => true),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              locale: Locale('zh'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 475,
                    height: 180,
                    child: GenerationControls(compact: true),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final layoutFinder = find.byKey(
      const ValueKey('generation-footer-adaptive-layout'),
    );
    final primaryFinder = find.byKey(
      const ValueKey('generation-footer-primary-action'),
    );
    final idleLayoutSize = tester.getSize(layoutFinder);
    final idlePrimaryRect = tester.getRect(primaryFinder);

    final generationNotifier =
        container.read(imageGenerationNotifierProvider.notifier)
            as _TestImageGenerationNotifier;
    generationNotifier.setGenerating(true);
    await tester.pumpAndSettle();

    expect(find.text('取消'), findsOneWidget);
    expect(tester.getSize(layoutFinder), idleLayoutSize);
    expect(tester.getRect(primaryFinder), idlePrimaryRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch settings desktop form follows its content height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _MemoryLocalStorageService({}),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(child: BatchSettingsButton(showLabel: true)),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(BatchSettingsButton));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).height, lessThan(480));
    expect(tester.getRect(surface).center.dy, moreOrLessEquals(400));
    expect(tester.widget<ListView>(find.byType(ListView)).shrinkWrap, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch settings uses a scrollable compact form at worst width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _MemoryLocalStorageService({}),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              locale: const Locale('zh'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(3)),
                child: child!,
              ),
              home: const Scaffold(
                body: Center(child: BatchSettingsButton(showLabel: true)),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(BatchSettingsButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('4'));
    await tester.pump();
    expect(container.read(imagesPerRequestProvider), 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-out generate button opens login directly', (
    tester,
  ) async {
    final storage = _MemoryLocalStorageService({
      StorageKeys.autoSaveImages: false,
      StorageKeys.showRandomPromptTools: false,
    });
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SizedBox(
              width: 600,
              height: 180,
              child: GenerationControls(),
            ),
          ),
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
          kritaBridgeNotifierProvider.overrideWith(
            (ref) => _TestKritaBridgeNotifier(),
          ),
          replicationQueueNotifierProvider.overrideWith(
            _TestReplicationQueueNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _TestQueueExecutionNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _TestSubscriptionNotifier.new,
          ),
          estimatedCostProvider.overrideWith((ref) => 0),
          isFreeGenerationProvider.overrideWith((ref) => true),
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

    expect(find.text('登录'), findsOneWidget);
    expect(find.text('生成'), findsNothing);
    expect(find.byIcon(Icons.login_rounded), findsOneWidget);

    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_SCREEN_OPENED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _TestImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();

  void setGenerating(bool value) {
    state = ImageGenerationState(
      status: value ? GenerationStatus.generating : GenerationStatus.idle,
    );
  }
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

class _TestKritaBridgeNotifier extends KritaBridgeNotifier {
  @override
  Future<void> close() async {}
}

class _TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();
}

class _TestQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionState.loaded(
    UserSubscription(
      tier: 1,
      active: true,
      trainingStepsLeft: TrainingStepsInfo(fixedTrainingStepsLeft: 7384),
    ),
  );
}
