import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/selectable_image_card.dart';

void main() {
  testWidgets('linked double click is immediate tap then one double callback', (
    tester,
  ) async {
    var taps = 0;
    var doubles = 0;
    var previewActive = false;

    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) {
            return _card(
              isPreviewActive: previewActive,
              onTap: () {
                taps++;
                setState(() => previewActive = true);
              },
              onDoubleTap: () => doubles++,
            );
          },
        ),
      ),
    );

    final card = find.byType(SelectableImageCard);
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 100));
    expect(taps, 1);
    expect(doubles, 0);

    await tester.tap(card);
    await tester.pump();
    expect(taps, 1);
    expect(doubles, 1);
  });

  testWidgets('legacy path retains duplicate click debounce', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_testApp(_card(onTap: () => taps++)));

    final card = find.byType(SelectableImageCard);
    await tester.tap(card);
    await tester.pump();
    await tester.tap(card);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('modifier bypass allows every rapid legacy click', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _testApp(_card(onTap: () => taps++, allowRepeatedModifierTaps: true)),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final card = find.byType(SelectableImageCard);
    await tester.tap(card);
    await tester.pump();
    await tester.tap(card);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(taps, 2);
  });

  testWidgets('legacy modifier clicks remain debounced unless opted in', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_testApp(_card(onTap: () => taps++)));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final card = find.byType(SelectableImageCard);
    await tester.tap(card);
    await tester.pump();
    await tester.tap(card);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(taps, 1);
  });

  testWidgets('selection border takes priority over preview-active border', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(_card(isPreviewActive: true, isSelected: false)),
    );
    final theme = Theme.of(tester.element(find.byType(SelectableImageCard)));

    expect(_activeBorder(tester).top.color, theme.colorScheme.tertiary);
    expect(_activeBorder(tester).top.width, 2);

    await tester.pumpWidget(
      _testApp(_card(isPreviewActive: true, isSelected: true)),
    );
    await tester.pump();

    expect(_activeBorder(tester).top.color, theme.colorScheme.primary);
    expect(_activeBorder(tester).top.width, 2);
  });

  testWidgets('right-click menu exposes view details', (tester) async {
    await tester.pumpWidget(
      _testApp(
        _card(
          onFullscreen: () {},
          enableSaveAction: false,
          enableCopyAction: false,
        ),
      ),
    );

    await tester.tap(
      find.byType(SelectableImageCard),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('View details'), findsOneWidget);
  });
}

Widget _card({
  VoidCallback? onTap,
  VoidCallback? onDoubleTap,
  VoidCallback? onFullscreen,
  bool isPreviewActive = false,
  bool isSelected = false,
  bool allowRepeatedModifierTaps = false,
  bool enableSaveAction = true,
  bool enableCopyAction = true,
}) {
  return SizedBox(
    width: 120,
    height: 120,
    child: SelectableImageCard(
      key: const ValueKey('image-card'),
      imageBytes: base64Decode(_oneByOnePngBase64),
      imageIdentity: 'image-1',
      isPreviewActive: isPreviewActive,
      isSelected: isSelected,
      allowRepeatedModifierTaps: allowRepeatedModifierTaps,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onFullscreen: onFullscreen,
      enableSelection: false,
      enableSaveAction: enableSaveAction,
      enableCopyAction: enableCopyAction,
    ),
  );
}

Border _activeBorder(WidgetTester tester) {
  final containers = tester.widgetList<AnimatedContainer>(
    find.descendant(
      of: find.byType(SelectableImageCard),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return containers
      .map((container) => container.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.border)
      .whereType<Border>()
      .firstWhere((border) => border.top.width == 2);
}

Widget _testApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

const _oneByOnePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
