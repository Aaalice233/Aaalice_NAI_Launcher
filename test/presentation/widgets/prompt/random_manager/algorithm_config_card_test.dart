import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/algorithm_config_card.dart';

import '../../../../helpers/ink_expectations.dart';

class _FixedRandomPresetNotifier extends RandomPresetNotifier {
  @override
  RandomPresetState build() => const RandomPresetState(
    presets: [RandomPreset(id: 'preset', name: 'Preset')],
    selectedPresetId: 'preset',
  );
}

void main() {
  testWidgets('标题与季节词库开关的按压反馈画在卡片底色之上', (tester) async {
    tester.view.physicalSize = const Size(840, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _FixedRandomPresetNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: AlgorithmConfigCard()),
          ),
        ),
      ),
    );

    final card = find.byKey(const ValueKey('random-manager-algorithm-card'));
    final theme = Theme.of(tester.element(card));
    final cardFill = sectionSurfaceColor(theme.colorScheme);
    final header = find.byIcon(Icons.tune_rounded);

    final headerPress = await pressAndHold(tester, header);
    expectInkOnTop(tester, card, ink: theme.highlightColor, below: cardFill);
    await headerPress.up();
    await tester.pumpAndSettle();

    final seasonal = find.byType(SwitchListTile);
    await tester.ensureVisible(seasonal);
    await tester.pumpAndSettle();
    final switchPress = await pressAndHold(tester, seasonal);
    expectInkOnTop(tester, card, ink: theme.highlightColor, below: cardFill);
    await switchPress.cancel();
    await tester.pumpAndSettle();
  });
}
