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
              height: 60,
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

  testWidgets('controls stay readable without scaling at 320 to 1000px', (
    tester,
  ) async {
    final storage = _MemoryLocalStorageService({
      StorageKeys.autoSaveImages: false,
      StorageKeys.showRandomPromptTools: true,
    });

    for (final width in [320.0, 640.0, 1000.0]) {
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
              ).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 260,
                child: const GenerationControls(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FittedBox), findsNothing);
      expect(find.text('生成'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
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

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
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
            body: SizedBox(width: 600, height: 80, child: GenerationControls()),
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
  SubscriptionState build() => const SubscriptionState.initial();
}
