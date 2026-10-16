import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/handlers/vibe_export_handler.dart';

Future<void> _openSelectionForm(
  WidgetTester tester,
  List<VibeReference> vibes,
  void Function(List<VibeReference>) onResult, {
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
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
                ).then(onResult),
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
}

List<CheckboxListTile> _tiles(WidgetTester tester) => tester
    .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
    .toList(growable: false);

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('vibe-embed-selection-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('内容相同但实例不同的 Vibe 各自勾选，只返回被勾选的那一个', (tester) async {
    VibeReference duplicate() => VibeReference(
      displayName: '同一张图',
      vibeEncoding: 'same-encoding',
      thumbnail: Uint8List.fromList(List.filled(32, 7)),
      rawImageData: Uint8List.fromList(List.filled(32, 7)),
    );
    final vibes = [duplicate(), duplicate()];
    List<VibeReference>? result;
    await _openSelectionForm(tester, vibes, (value) => result = value);

    _tiles(tester).last.onChanged!(true);
    await tester.pump();

    expect(_tiles(tester).map((tile) => tile.value), [false, true]);

    await _confirm(tester);

    expect(result, hasLength(1));
    expect(result!.single, same(vibes.last));
  });

  testWidgets('按勾选顺序返回，取消勾选只移除对应项', (tester) async {
    final vibes = List.generate(
      3,
      (index) => VibeReference(
        displayName: 'Vibe $index',
        vibeEncoding: 'encoding-$index',
      ),
    );
    List<VibeReference>? result;
    await _openSelectionForm(tester, vibes, (value) => result = value);

    for (final index in [2, 0, 1]) {
      _tiles(tester)[index].onChanged!(true);
      await tester.pump();
    }
    _tiles(tester)[0].onChanged!(false);
    await tester.pump();

    expect(_tiles(tester).map((tile) => tile.value), [false, true, true]);

    await _confirm(tester);

    expect(result, hasLength(2));
    expect(result![0], same(vibes[2]));
    expect(result![1], same(vibes[1]));
  });

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

    await _openSelectionForm(
      tester,
      vibes,
      (value) => result = value,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
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

    await _confirm(tester);

    expect(result, orderedEquals(vibes));
    expect(tester.takeException(), isNull);
  });
}
