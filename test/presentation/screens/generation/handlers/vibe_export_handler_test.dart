import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/handlers/vibe_export_handler.dart';

void main() {
  testWidgets('最窄高字级下可选择并完整返回 16 个 Vibe', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final vibes = List.generate(
      16,
      (index) => VibeReference(
        displayName: '第 ${index + 1} 个很长的 Vibe 名称用于最坏组合验证',
        vibeEncoding: 'encoding-$index',
        strength: 0.6,
        infoExtracted: 0.2,
        sourceType: VibeSourceType.naiv4vibe,
      ),
    );
    List<VibeReference>? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  showVibeEmbedSelectionForm(
                    context: context,
                    vibes: vibes,
                  ).then((value) => result = value),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final selectionList = find.byKey(
      const ValueKey('vibe-embed-selection-list'),
    );
    final selectionScrollable = find.descendant(
      of: selectionList,
      matching: find.byType(Scrollable),
    );
    for (final vibe in vibes) {
      final tile = find.widgetWithText(CheckboxListTile, vibe.displayName);
      await tester.scrollUntilVisible(
        tile,
        100,
        scrollable: selectionScrollable,
      );
      tester.widget<CheckboxListTile>(tile).onChanged!(true);
      await tester.pump();
    }

    await tester.tap(
      find.byKey(const ValueKey('vibe-embed-selection-confirm')),
    );
    await tester.pumpAndSettle();

    expect(result, orderedEquals(vibes));
    expect(tester.takeException(), isNull);
  });
}
