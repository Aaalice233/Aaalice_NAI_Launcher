import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/generation/generation_error_text.dart';

void main() {
  final emptyMaskMessage = const EmptyInpaintMaskException(
    latentGridSize: 8,
  ).toString();

  const locales = {
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    'en': Locale('en'),
    'ja': Locale('ja'),
  };

  for (final entry in locales.entries) {
    testWidgets('empty inpaint masks read as a localized hint (${entry.key})', (
      tester,
    ) async {
      final context = await _pumpContext(tester, entry.value);
      final l10n = AppLocalizations.of(context)!;

      final (title, hint) = describeGenerationError(context, emptyMaskMessage);

      expect(title, l10n.generation_emptyInpaintMask);
      expect(hint, l10n.generation_emptyInpaintMaskHint(8));
      expect(hint, contains('8'));
      expect(hint, isNot(contains(EmptyInpaintMaskException.errorCode)));
      expect(
        summarizeGenerationError(context, emptyMaskMessage),
        '${l10n.generation_emptyInpaintMask}\n'
        '${l10n.generation_emptyInpaintMaskHint(8)}',
      );
    });
  }

  testWidgets('existing generation error mappings are unchanged', (
    tester,
  ) async {
    final context = await _pumpContext(tester, const Locale('en'));
    final l10n = AppLocalizations.of(context)!;

    expect(describeGenerationError(context, null), (
      l10n.generation_generationFailed,
      null,
    ));
    expect(describeGenerationError(context, 'Cancelled'), (
      l10n.generation_cancelGeneration,
      null,
    ));
    expect(describeGenerationError(context, 'API_ERROR_429|busy'), (
      l10n.api_error_429,
      l10n.api_error_429_hint,
    ));
    expect(describeGenerationError(context, 'API_ERROR_HTTP_418|teapot'), (
      '${l10n.common_error} (HTTP 418)',
      'teapot',
    ));
    expect(
      describeGenerationError(
        context,
        'GENERATION_ERROR_INVALID_RESOLUTION|1080|1920|1088|1920',
      ),
      (
        l10n.generation_invalidResolution,
        l10n.generation_invalidResolutionHint(1080, 1920, 1088, 1920),
      ),
    );
    expect(describeGenerationError(context, 'something broke'), (
      l10n.generation_generationFailed,
      'something broke',
    ));
    expect(
      summarizeGenerationError(context, 'Invalid generation snapshot: x'),
      'Invalid generation snapshot: x',
    );
  });
}

Future<BuildContext> _pumpContext(WidgetTester tester, Locale locale) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}
