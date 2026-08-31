import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/watermark/watermark_editor_screen.dart';

void main() {
  late Directory directory;
  late LocalStorageService storage;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('watermark-editor-test');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    storage = LocalStorageService();
  });

  setUp(() => Hive.box<dynamic>(StorageKeys.settingsBox).clear());

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final scenario
      in <({Size size, double textScale, double keyboardInset, String name})>[
        (
          size: const Size(360, 640),
          textScale: 1,
          keyboardInset: 0,
          name: 'narrow portrait',
        ),
        (
          size: const Size(412, 915),
          textScale: 1,
          keyboardInset: 0,
          name: 'large phone portrait',
        ),
        (
          size: const Size(600, 720),
          textScale: 1,
          keyboardInset: 0,
          name: 'compact tablet',
        ),
        (
          size: const Size(760, 420),
          textScale: 1,
          keyboardInset: 0,
          name: 'phone landscape',
        ),
        (
          size: const Size(840, 760),
          textScale: 1,
          keyboardInset: 0,
          name: 'medium window',
        ),
        (
          size: const Size(1180, 760),
          textScale: 1,
          keyboardInset: 0,
          name: 'desktop split',
        ),
        (
          size: const Size(1600, 900),
          textScale: 1,
          keyboardInset: 0,
          name: 'wide desktop',
        ),
        (
          size: const Size(700, 760),
          textScale: 2,
          keyboardInset: 0,
          name: 'large text',
        ),
        (
          size: const Size(412, 915),
          textScale: 1,
          keyboardInset: 320,
          name: 'phone keyboard',
        ),
        (
          size: const Size(760, 420),
          textScale: 1,
          keyboardInset: 240,
          name: 'landscape keyboard',
        ),
      ]) {
    testWidgets('${scenario.name} has no overflow', (tester) async {
      await tester.binding.setSurfaceSize(scenario.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                size: scenario.size,
                textScaler: TextScaler.linear(scenario.textScale),
                viewInsets: EdgeInsets.only(bottom: scenario.keyboardInset),
              ),
              child: WatermarkEditorScreen(
                sourceBytes: _pngBytes(480, 320),
                sourceFileName: 'source.png',
                defaultsOnly: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      if (scenario.keyboardInset == 0) {
        expect(find.text('Watermark editor'), findsOneWidget);
      }
      expect(find.byType(WatermarkEditorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Uint8List _pngBytes(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(35, 48, 70, 255));
  return Uint8List.fromList(img.encodePng(image));
}
