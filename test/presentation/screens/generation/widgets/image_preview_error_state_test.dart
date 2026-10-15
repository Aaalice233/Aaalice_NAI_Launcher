import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/image_preview.dart';

class _FailedImageGenerationNotifier extends ImageGenerationNotifier {
  _FailedImageGenerationNotifier(this.message);

  final String message;

  @override
  ImageGenerationState build() => ImageGenerationState(
    status: GenerationStatus.error,
    errorMessage: message,
  );
}

class _DefaultShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

void main() {
  final emptyMaskMessage = const EmptyInpaintMaskException().toString();

  // Locales are covered by generation_error_l10n_test; English wraps widest.
  const locale = Locale('en');

  for (final size in const [
    Size(320, 480),
    Size(600, 480),
    Size(840, 600),
    Size(1180, 700),
    Size(1600, 900),
  ]) {
    for (final textScale in const [1.0, 3.0]) {
      testWidgets('empty inpaint mask error is localized '
          '(${size.width.toInt()}, ${textScale}x)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = ProviderContainer(
          overrides: [
            imageGenerationNotifierProvider.overrideWith(
              () => _FailedImageGenerationNotifier(emptyMaskMessage),
            ),
            shortcutConfigNotifierProvider.overrideWith(
              _DefaultShortcutConfigNotifier.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: const Scaffold(body: ImagePreviewWidget()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(locale);
        expect(find.text(l10n.generation_emptyInpaintMask), findsOneWidget);
        expect(
          find.text(l10n.generation_emptyInpaintMaskHint(8)),
          findsOneWidget,
        );
        expect(
          find.textContaining(EmptyInpaintMaskException.errorCode),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
