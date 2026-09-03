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

  testWidgets('random-mode switch thumb animates between off and on', (
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

    final thumb = find.byKey(const ValueKey('random-mode-switch-thumb'));
    final offCenter = tester.getCenter(thumb);

    enabled.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final movingCenter = tester.getCenter(thumb);
    await tester.pumpAndSettle();
    final onCenter = tester.getCenter(thumb);

    expect(movingCenter.dx, greaterThan(offCenter.dx));
    expect(movingCenter.dx, lessThan(onCenter.dx));
    expect(find.byIcon(Icons.casino_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'random-mode switch reaches its state immediately with reduced motion',
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

      final align = tester.widget<AnimatedAlign>(
        find.byKey(const ValueKey('random-mode-switch-thumb-position')),
      );
      expect(align.duration, Duration.zero);
      expect(align.alignment, Alignment.centerRight);
      expect(find.byIcon(Icons.casino_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'labeled random-mode switch stays usable in a narrow mobile row',
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
              body: SizedBox(
                width: 160,
                child: RandomModeToggle(enabled: false, showLabel: true),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('random-mode-switch-track')), findsOne);
      expect(find.text('随机提示词'), findsOne);
      expect(
        tester.getSize(find.byType(RandomModeToggle)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
