import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_controls/random_mode_toggle.dart';

void main() {
  testWidgets('touch policy keeps random-mode control at least 48dp', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InteractionPolicyScope(
            initialPolicy: InteractionPolicy(
              modality: InteractionModality.touch,
              touchAvailable: true,
              precisePointerAvailable: false,
            ),
            child: Scaffold(body: RandomModeToggle(enabled: false)),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(RandomModeToggle));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('random-mode button changes dice and surface between states', (
    tester,
  ) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: enabled,
              builder: (context, value, _) => RandomModeToggle(enabled: value),
            ),
          ),
        ),
      ),
    );

    final surfaceFinder = find.byKey(
      const ValueKey('random-mode-button-surface'),
    );
    final offSurface = tester.widget<AnimatedContainer>(surfaceFinder);
    final offColor = (offSurface.decoration as BoxDecoration).color;
    expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
    expect(find.text('随机提示词'), findsNothing);

    enabled.value = true;
    await tester.pump();
    await tester.pumpAndSettle();
    final onSurface = tester.widget<AnimatedContainer>(surfaceFinder);
    final onColor = (onSurface.decoration as BoxDecoration).color;
    final rotation = tester.widget<AnimatedRotation>(
      find.byKey(const ValueKey('random-mode-dice-rotation')),
    );

    expect(onColor, isNot(offColor));
    expect(rotation.turns, 0.125);
    expect(find.byIcon(Icons.casino_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'random-mode button reaches its state immediately with reduced motion',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(body: RandomModeToggle(enabled: true)),
            ),
          ),
        ),
      );

      final surface = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('random-mode-button-surface')),
      );
      final rotation = tester.widget<AnimatedRotation>(
        find.byKey(const ValueKey('random-mode-dice-rotation')),
      );
      expect(surface.duration, Duration.zero);
      expect(rotation.duration, Duration.zero);
      expect(rotation.turns, 0.125);
      expect(find.byIcon(Icons.casino_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'random-mode button stays compact and text-free at large text scale',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: const Scaffold(
              body: InteractionPolicyScope(
                initialPolicy: InteractionPolicy(
                  modality: InteractionModality.touch,
                  touchAvailable: true,
                  precisePointerAvailable: false,
                ),
                child: Center(child: RandomModeToggle(enabled: false)),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
      expect(find.text('随机提示词'), findsNothing);
      expect(tester.getSize(find.byType(RandomModeToggle)), const Size(48, 48));
      expect(tester.takeException(), isNull);
    },
  );
}
