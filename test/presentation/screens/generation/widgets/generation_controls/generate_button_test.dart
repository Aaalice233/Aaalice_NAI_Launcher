import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_controls/generate_button.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  Future<void> pumpButton(
    WidgetTester tester, {
    required bool isGenerating,
    required bool showCancel,
    int cooldownRemainingSeconds = 0,
    ImageGenerationState generationState = const ImageGenerationState(),
    VoidCallback? onGenerate,
    VoidCallback? onCancel,
    VoidCallback? onSkipCurrent,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Free generation hides the cost badge and avoids unrelated providers.
          isFreeGenerationProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: GenerateButtonWithCost(
                isGenerating: isGenerating,
                showCancel: showCancel,
                generationState: generationState,
                cooldownRemainingSeconds: cooldownRemainingSeconds,
                onGenerate: onGenerate ?? () {},
                onCancel: onCancel ?? () {},
                onSkipCurrent: onSkipCurrent ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('idle: shows generate label and triggers onGenerate on tap', (
    tester,
  ) async {
    var generateCalled = false;
    var cancelCalled = false;
    await pumpButton(
      tester,
      isGenerating: false,
      showCancel: false,
      onGenerate: () => generateCalled = true,
      onCancel: () => cancelCalled = true,
    );

    expect(find.text(l10n.generation_generate), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);

    await tester.tap(find.byType(FilledButton));
    expect(generateCalled, isTrue);
    expect(cancelCalled, isFalse);
  });

  testWidgets('generating: keeps filled style and triggers onCancel on tap', (
    tester,
  ) async {
    var generateCalled = false;
    var cancelCalled = false;
    await pumpButton(
      tester,
      isGenerating: true,
      showCancel: true,
      onGenerate: () => generateCalled = true,
      onCancel: () => cancelCalled = true,
    );

    expect(find.text(l10n.common_cancel), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);

    await tester.tap(find.byType(FilledButton));
    expect(cancelCalled, isTrue);
    expect(generateCalled, isFalse);
  });

  testWidgets('idle and cancel states keep the same button size', (
    tester,
  ) async {
    await pumpButton(tester, isGenerating: false, showCancel: false);
    final idleSize = tester.getSize(find.byType(FilledButton));

    await pumpButton(tester, isGenerating: true, showCancel: true);
    await tester.pumpAndSettle();
    final cancelSize = tester.getSize(find.byType(FilledButton));

    expect(cancelSize, idleSize);
  });

  testWidgets('cooldown: shows countdown and disables generation', (
    tester,
  ) async {
    var generateCalled = false;
    await pumpButton(
      tester,
      isGenerating: false,
      showCancel: false,
      cooldownRemainingSeconds: 8,
      onGenerate: () => generateCalled = true,
    );

    expect(find.text(l10n.generation_cooldownRemaining(8)), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_bottom_outlined), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await tester.tap(find.byType(FilledButton));
    expect(generateCalled, isFalse);
  });

  testWidgets(
    'generating multiple images: shows skip-current progress and cancel',
    (tester) async {
      await pumpButton(
        tester,
        isGenerating: true,
        showCancel: true,
        generationState: const ImageGenerationState(
          currentImage: 2,
          totalImages: 4,
        ),
      );

      expect(
        find.text('${l10n.generation_skipCurrentBatch} 2/4'),
        findsOneWidget,
      );
      expect(find.text(l10n.common_cancel), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'generating multiple images: skip button triggers onSkipCurrent',
    (tester) async {
      var skipCalled = false;
      var cancelCalled = false;
      await pumpButton(
        tester,
        isGenerating: true,
        showCancel: true,
        generationState: const ImageGenerationState(
          currentImage: 2,
          totalImages: 4,
        ),
        onSkipCurrent: () => skipCalled = true,
        onCancel: () => cancelCalled = true,
      );

      await tester.tap(
        find.widgetWithText(
          OutlinedButton,
          '${l10n.generation_skipCurrentBatch} 2/4',
        ),
      );

      expect(skipCalled, isTrue);
      expect(cancelCalled, isFalse);
    },
  );

  testWidgets(
    'generating without cancel (bridge busy): keeps generating label',
    (tester) async {
      await pumpButton(tester, isGenerating: true, showCancel: false);

      expect(find.text(l10n.generation_generating), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    },
  );

  testWidgets('generating without cancel does not trigger onCancel on tap', (
    tester,
  ) async {
    var generateCalled = false;
    var cancelCalled = false;
    await pumpButton(
      tester,
      isGenerating: true,
      showCancel: false,
      onGenerate: () => generateCalled = true,
      onCancel: () => cancelCalled = true,
    );

    await tester.tap(find.byType(FilledButton));

    expect(generateCalled, isFalse);
    expect(cancelCalled, isFalse);
  });
}
