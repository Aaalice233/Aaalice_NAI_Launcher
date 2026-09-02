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
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/watermark/watermark_editor_controls.dart';
import 'package:nai_launcher/presentation/screens/watermark/watermark_editor_launcher.dart';
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

  testWidgets(
    'launcher uses shared adaptive form surfaces and preserves back',
    (tester) async {
      for (final scenario in <({double width, String surfaceKey})>[
        (width: 320, surfaceKey: 'adaptive-full-screen-form'),
        (width: 700, surfaceKey: 'adaptive-centered-form'),
        (width: 1200, surfaceKey: 'adaptive-side-sheet'),
      ]) {
        await tester.binding.setSurfaceSize(Size(scenario.width, 760));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [localStorageServiceProvider.overrideWithValue(storage)],
            child: MaterialApp(
              key: ValueKey(scenario.width),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(size: Size(scenario.width, 760)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () => WatermarkEditorLauncher.open(
                      context: context,
                      sourceBytes: _pngBytes(480, 320),
                      sourceFileName: 'source.png',
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final surface = find.byKey(ValueKey(scenario.surfaceKey));
        expect(surface, findsOneWidget);
        expect(find.byType(WatermarkEditorScreen), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        if (scenario.width >= 840) {
          expect(tester.getSize(surface).width, lessThanOrEqualTo(960));
          expect(tester.getSize(surface).width, lessThan(scenario.width));
        }
        expect(tester.takeException(), isNull);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(surface, findsNothing);
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );

  testWidgets('compact launcher respects large text, IME, and SafeArea', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      top: 24,
      bottom: 16,
      left: 8,
      right: 8,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => WatermarkEditorLauncher.open(
                  context: context,
                  sourceBytes: _pngBytes(480, 320),
                  sourceFileName: 'source.png',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final surface = find.byKey(const ValueKey('adaptive-full-screen-form'));
    final rect = tester.getRect(surface);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(rect.left, greaterThanOrEqualTo(8));
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(rect.right, lessThanOrEqualTo(352));
    expect(rect.bottom, lessThanOrEqualTo(400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('HSV picker uses adaptive form in worst compact viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    var changes = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: WatermarkEditorControls(
            settings: const WatermarkSettings(),
            layout: const WatermarkSettings().universalLayout,
            selectedLayer: WatermarkEditableLayer.text,
            logoAvailable: false,
            preserveMetadata: false,
            onOpenMetadataSettings: () {},
            onSettingsChanged: (_) => changes++,
            onLayoutChanged: (_) {},
            onSelectedLayerChanged: (_) {},
            onChooseLogo: () {},
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Color Picker'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Color Picker'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    final form = find.byKey(const ValueKey('watermark-color-form'));
    expect(form, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Confirm'),
      200,
      scrollable: find.descendant(
        of: form,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(changes, 0);
  });

  testWidgets('font picker identifies every preview by family name', (
    tester,
  ) async {
    const settings = WatermarkSettings();
    await tester.binding.setSurfaceSize(const Size(420, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WatermarkEditorControls(
            settings: settings,
            layout: settings.universalLayout,
            selectedLayer: WatermarkEditableLayer.text,
            logoAvailable: false,
            preserveMetadata: false,
            onOpenMetadataSettings: () {},
            onSettingsChanged: (_) {},
            onLayoutChanged: (_) {},
            onSelectedLayerChanged: (_) {},
            onChooseLogo: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('LXGW ZhenKai GB'), findsWidgets);
    expect(find.text('Ma Shan Zheng'), findsOneWidget);
    expect(find.text('Great Vibes'), findsOneWidget);
    expect(find.text('Allura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Uint8List _pngBytes(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(35, 48, 70, 255));
  return Uint8List.fromList(img.encodePng(image));
}
