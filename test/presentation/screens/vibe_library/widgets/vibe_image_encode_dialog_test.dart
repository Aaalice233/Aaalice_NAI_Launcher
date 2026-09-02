import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart';

void main() {
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'Vibe encoding form uses the adaptive surface and stays actionable at ${width.toInt()}px',
      (tester) async {
        await _setViewport(tester, Size(width, 800));
        await tester.pumpWidget(_wrapLauncher());
        await tester.tap(find.text('打开编码配置'));
        await tester.pumpAndSettle();

        final surfaceKey = switch (width) {
          < 600 => 'adaptive-full-screen-form',
          < 840 => 'adaptive-centered-form',
          _ => 'adaptive-side-sheet',
        };
        final surface = find.byKey(ValueKey(surfaceKey));
        expect(surface, findsOneWidget);
        final surfaceRect = tester.getRect(surface);
        expect(surfaceRect.left, greaterThanOrEqualTo(0));
        expect(surfaceRect.right, lessThanOrEqualTo(width));
        if (width >= 840) {
          expect(surfaceRect.width, lessThanOrEqualTo(400));
        }
        expect(find.text('编码将消耗 2 Anlas'), findsOneWidget);
        expect(find.text('开始编码'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    '320px 3x text with SafeArea and IME keeps all encoding fields and actions reachable',
    (tester) async {
      await _setViewport(
        tester,
        const Size(320, 720),
        padding: const FakeViewPadding(top: 24, bottom: 24),
        viewInsets: const FakeViewPadding(bottom: 220),
      );
      VibeImageEncodeConfig? result;
      await tester.pumpWidget(
        _wrapLauncher(textScale: 3, onResult: (value) => result = value),
      );
      await tester.tap(find.text('打开编码配置'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsAtLeastNWidgets(3));
      expect(find.text('编码将消耗 2 Anlas'), findsOneWidget);
      final confirm = find.text('开始编码');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result?.name, 'encoded-vibe.png');
      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('V3 raw-image mode remains a local save action', (tester) async {
    await _setViewport(tester, const Size(600, 800));
    await tester.pumpWidget(_wrapLauncher(encodeImage: false));
    await tester.tap(find.text('打开编码配置'));
    await tester.pumpAndSettle();

    expect(find.text('保存到库'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('开始编码'), findsNothing);
    expect(find.text('编码将消耗 2 Anlas'), findsNothing);
  });

  testWidgets('cancel preserves nullable async result', (tester) async {
    await _setViewport(tester, const Size(320, 720));
    VibeImageEncodeConfig? result;
    await tester.pumpWidget(_wrapLauncher(onResult: (value) => result = value));
    await tester.tap(find.text('打开编码配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(VibeImageEncodeDialog), findsNothing);
  });
}

Future<void> _setViewport(
  WidgetTester tester,
  Size size, {
  FakeViewPadding? padding,
  FakeViewPadding? viewInsets,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding ?? const FakeViewPadding();
  tester.view.viewInsets = viewInsets ?? const FakeViewPadding();
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}

Widget _wrapLauncher({
  double textScale = 1,
  bool encodeImage = true,
  ValueChanged<VibeImageEncodeConfig?>? onResult,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              final result = await VibeImageEncodeDialog.show(
                context: context,
                imageBytes: Uint8List(0),
                fileName: 'encoded-vibe.png',
                encodeImage: encodeImage,
              );
              onResult?.call(result);
            },
            child: const Text('打开编码配置'),
          ),
        ),
      ),
    ),
  );
}
