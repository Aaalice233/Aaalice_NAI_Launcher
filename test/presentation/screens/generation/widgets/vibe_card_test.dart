import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/vibe_card.dart';
import 'package:nai_launcher/presentation/widgets/common/editable_double_field.dart';

void main() {
  testWidgets('参考强度滑条保持官网范围，但数值输入不设上下限', (tester) async {
    double? changedStrength;
    final vibe = VibeReference(
      displayName: 'test',
      vibeEncoding: 'encoded',
      rawImageData: Uint8List.fromList(const [1, 2, 3]),
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: -2.4,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.naiv4vibe,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (value) => changedStrength = value,
              onInfoExtractedChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final strengthSlider = tester.widget<Slider>(find.byType(Slider).at(0));
    final strengthField = tester.widget<EditableDoubleField>(
      find.byType(EditableDoubleField).at(0),
    );

    expect(strengthSlider.min, 0.01);
    expect(strengthSlider.max, 1.0);
    expect(strengthSlider.value, 0.01);
    expect(strengthSlider.divisions, 99);
    expect(strengthField.min, isNull);
    expect(strengthField.max, isNull);

    await tester.enterText(find.byType(TextField).at(0), '3.25');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(changedStrength, 3.25);
  });

  test('参考强度只拒绝非有限数值', () {
    expect(VibeReference.sanitizeStrength(4.2), 4.2);
    expect(VibeReference.sanitizeStrength(-3.1), -3.1);
    expect(
      VibeReference.sanitizeStrength(double.infinity),
      VibeReference.defaultStrength,
    );
  });

  testWidgets('没有原图数据时不显示信息提取调节项', (tester) async {
    final vibe = VibeReference(
      displayName: 'encoded-only',
      vibeEncoding: 'encoded',
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.4,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.naiv4vibe,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (_) {},
              onInfoExtractedChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('信息提取'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(EditableDoubleField), findsOneWidget);
  });

  testWidgets('启用开关会回传当前卡片的新状态', (tester) async {
    final vibe = VibeReference(
      displayName: 'toggle-test',
      vibeEncoding: 'encoded',
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.4,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.naiv4vibe,
    );
    bool? nextEnabled;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (_) {},
              onInfoExtractedChanged: (_) {},
              onEnabledChanged: (value) => nextEnabled = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('vibe-enabled-switch-0')));
    await tester.pump();

    expect(nextEnabled, isFalse);
  });

  testWidgets('关闭的 Vibe 卡片会降低整体透明度', (tester) async {
    final vibe = VibeReference(
      displayName: 'disabled-test',
      vibeEncoding: 'encoded',
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.4,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.naiv4vibe,
      enabled: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (_) {},
              onInfoExtractedChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('vibe-card-enabled-opacity-0')),
    );

    expect(opacity.opacity, lessThan(1.0));
  });
}
