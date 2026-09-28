import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/global_settings_dialog.dart';

void main() {
  testWidgets('global settings adapts from 320 to 1600 with 3x text', (
    tester,
  ) async {
    for (final scenario in [
      (width: 320.0, height: 568.0, keyboard: 220.0),
      (width: 600.0, height: 900.0, keyboard: 0.0),
      (width: 840.0, height: 900.0, keyboard: 0.0),
      (width: 1600.0, height: 900.0, keyboard: 0.0),
    ]) {
      await tester.binding.setSurfaceSize(
        Size(scenario.width, scenario.height),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            randomPresetNotifierProvider.overrideWith(_FixedPresets.new),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(3),
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
                viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
                viewInsets: EdgeInsets.only(bottom: scenario.keyboard),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => GlobalSettingsDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(GlobalSettingsDialog), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=${scenario.width}');

      final cancel = find.widgetWithText(TextButton, '取消');
      await tester.ensureVisible(cancel);
      expect(cancel, findsOneWidget);
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(scenario.height));
      await tester.tap(cancel);
      await tester.pumpAndSettle();
    }
    await tester.binding.setSurfaceSize(null);
  });
}

class _FixedPresets extends RandomPresetNotifier {
  @override
  RandomPresetState build() {
    return const RandomPresetState(
      presets: [RandomPreset(id: 'test', name: 'test')],
      selectedPresetId: 'test',
    );
  }

  @override
  Future<void> updateAlgorithmConfig(config) async {}
}
