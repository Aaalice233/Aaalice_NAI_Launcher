import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/derivatives/derivative_registry.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/watermark/watermark_render_service.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/derivatives/derivative_copy_saver.dart';
import 'package:nai_launcher/presentation/screens/watermark/watermark_editor_controls.dart';
import 'package:nai_launcher/presentation/screens/watermark/watermark_editor_launcher.dart';
import 'package:nai_launcher/presentation/screens/watermark/watermark_editor_screen.dart';

import '../../../helpers/adaptive_panel_expectations.dart';
import '../../../helpers/editor_exit.dart';
import '../../../helpers/labeled_rows_expectations.dart';
import '../../../helpers/pending_derivative_copy_saver.dart';

void main() {
  late Directory directory;
  late LocalStorageService storage;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('watermark-editor-test');
    Hive.init(directory.path);
    // 内存后端：落盘写一旦从 widget test 的 FakeAsync 时钟发起就不会完成，会锁死 box
    await Hive.openBox<dynamic>(StorageKeys.settingsBox, bytes: Uint8List(0));
    storage = LocalStorageService();
  });

  setUp(() => Hive.box<dynamic>(StorageKeys.settingsBox).clear());

  tearDownAll(() async {
    // 有界等待：box 被锁死时快速失败，不把整个测试分片拖到看门狗超时
    await Hive.close().timeout(const Duration(seconds: 10));
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
        (width: 320, surfaceKey: 'adaptive-bottom-sheet'),
        (width: 700, surfaceKey: 'adaptive-centered-form'),
        (width: 1200, surfaceKey: 'adaptive-centered-form'),
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

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    final rect = tester.getRect(surface);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(rect.left, greaterThanOrEqualTo(8));
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(rect.right, lessThanOrEqualTo(352));
    expect(rect.bottom, lessThanOrEqualTo(420));
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

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    final form = find.byKey(const ValueKey('watermark-color-form'));
    expect(form, findsOneWidget);
    expectPanelHeaderScrollsWithContent(tester);
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

  testWidgets('ratio slider speaks its name and the displayed percentage', (
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
    await tester.scrollUntilVisible(
      find.text('Opacity'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // 名称与读数只落在滑块自身节点；外包 Semantics 会多出一个读数不同的容器节点
    final named = find.semantics.byPredicate(
      (node) => node.label == 'Opacity' && node.value.isNotEmpty,
    );
    expect(named, findsOne);
    final node = named.evaluate().single;
    expect(node.flagsCollection.isSlider, isTrue);
    expect(node.value, '82%');
    expect(find.text('82%'), findsOneWidget);
  });

  testWidgets('auto placement switch is global and keeps the anchor', (
    tester,
  ) async {
    WatermarkSettings? changed;
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _controlsApp(
        settings: const WatermarkSettings(),
        selectedLayer: WatermarkEditableLayer.logo,
        onSettingsChanged: (value) => changed = value,
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Auto placement'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Auto placement'));
    await tester.pump();

    expect(changed?.autoPlacement, isTrue);
    expect(
      changed?.universalLayout.textPlacement.anchor,
      WatermarkAnchor.bottomRight,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('text auto grayscale replaces the color picker with a slider', (
    tester,
  ) async {
    WatermarkSettings? changed;
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _controlsApp(
        settings: const WatermarkSettings(),
        selectedLayer: WatermarkEditableLayer.text,
        onSettingsChanged: (value) => changed = value,
      ),
    );

    expect(find.text('Tone difference'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Auto grayscale'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Auto grayscale'));
    await tester.pump();
    expect(changed?.textStyle.autoTone, isTrue);
    expect(changed?.logoStyle.autoTone, isFalse);

    await tester.pumpWidget(
      _controlsApp(
        settings: changed!,
        selectedLayer: WatermarkEditableLayer.text,
        onSettingsChanged: (value) => changed = value,
      ),
    );
    await tester.pump();

    final colorTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Color Picker'),
        matching: find.byType(ListTile),
      ),
    );
    expect(colorTile.enabled, isFalse);
    expect(find.text('Color is set by auto grayscale'), findsOneWidget);
    expect(find.text('Tone difference'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logo auto grayscale is switched separately', (tester) async {
    WatermarkSettings? changed;
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _controlsApp(
        settings: const WatermarkSettings(
          logoStyle: WatermarkLogoStyle(enabled: true),
        ),
        selectedLayer: WatermarkEditableLayer.logo,
        onSettingsChanged: (value) => changed = value,
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Auto grayscale'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Auto grayscale'));
    await tester.pump();

    expect(changed?.logoStyle.autoTone, isTrue);
    expect(changed?.textStyle.autoTone, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const ['en', 'ja']) {
    for (final width in labeledRowWidths) {
      for (final scale in labeledRowTextScales) {
        final scenario = '$locale ${width.toInt()} ${scale}x';
        testWidgets('$scenario ratio sliders keep labels whole and reachable', (
          tester,
        ) async {
          const settings = WatermarkSettings();
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
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
          // 字体与锚点下拉框在窄屏大字号下的既有溢出不属于滑块行，行内越界由逐项边界断言覆盖
          tester.takeException();

          final l10n = lookupAppLocalizations(Locale(locale));
          await expectLabeledSliderRows(
            tester,
            labels: [
              l10n.watermark_letterSpacing,
              l10n.watermark_stroke,
              l10n.watermark_shadow,
              l10n.watermark_opacity,
              l10n.watermark_size,
              l10n.watermark_margin,
            ],
            labelsSingleLine: locale != 'en',
            readouts: const ['82%'],
            lazyScrollable: find.byType(Scrollable).first,
            reason: scenario,
          );
          tester.takeException();
        });
      }
    }
  }

  group('save copy', () {
    late ui.Image preview;

    setUpAll(() async {
      preview = await WatermarkRenderService.decodePreview(
        _pngBytes(48, 32),
        requireStatic: true,
      );
    });
    tearDownAll(() => preview.dispose());

    testWidgets('stalled follow-up steps never hold the editor once written', (
      tester,
    ) async {
      final pending = PendingDerivativeCopySaver(DerivativeKind.watermark);
      addTearDown(pending.releaseAll);
      final closed = await _openForSave(tester, storage, pending, preview);
      final output = pending.outputPathFor('source_watermarked.png');

      await tester.tap(find.text('Save copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Watermarked copy saved'), findsOneWidget);
      expect(pending.writes, [output]);
      expect(pending.admissions, [
        [output],
      ]);
      expect(pending.indexing.isCompleted, isFalse);

      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.byType(WatermarkEditorScreen), findsNothing);
      expect(closed.isCompleted, isTrue);
      expect(await closed.future, output);
      expect(tester.takeException(), isNull);
    });

    testWidgets('follow-up failures still surface after the editor closed', (
      tester,
    ) async {
      final pending = PendingDerivativeCopySaver(DerivativeKind.watermark);
      addTearDown(pending.releaseAll);
      await _openForSave(tester, storage, pending, preview);
      await tester.tap(find.text('Save copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.byType(WatermarkEditorScreen), findsNothing);

      pending.indexing.complete(GalleryIndexAdmission.failed);
      pending.rescanning.complete('refreshFailed');
      pending.publishing.completeError(StateError('media store'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.watermark_galleryRefreshFailed), findsOneWidget);
      expect(
        find.text(l10n.watermark_systemGalleryExportFailed),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final exit in EditorExit.values) {
      testWidgets('${exit.name} during a stalled render leaves and writes '
          'nothing', (tester) async {
        final pending = PendingDerivativeCopySaver(DerivativeKind.watermark);
        addTearDown(pending.releaseAll);
        final rendering = Completer<WatermarkRenderResult>();
        final closed = await _openForSave(
          tester,
          storage,
          pending,
          preview,
          renderCopy: (request, {cancellationToken}) => rendering.future,
        );

        await tester.tap(find.text('Save copy'));
        await tester.pump();
        expect(find.text('Rendering full-resolution image…'), findsOneWidget);

        await exit.perform(tester);
        await tester.pump();
        expect(closed.isCompleted, isTrue);
        await settleWithin(tester, const Duration(seconds: 2));
        expect(find.byType(WatermarkEditorScreen), findsNothing);
        expect(await closed.future, isNull);

        rendering.complete(_renderResult(Uint8List.fromList([1, 2, 3])));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(pending.writes, isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${exit.name} once writing started leaves and still saves', (
        tester,
      ) async {
        final pending = PendingDerivativeCopySaver(
          DerivativeKind.watermark,
          holdWrites: true,
        );
        addTearDown(pending.releaseAll);
        final closed = await _openForSave(tester, storage, pending, preview);
        final output = pending.outputPathFor('source_watermarked.png');

        await tester.tap(find.text('Save copy'));
        await tester.pump();
        expect(pending.writeRequests, [output]);

        await exit.perform(tester);
        await tester.pump();
        expect(closed.isCompleted, isTrue);
        await settleWithin(tester, const Duration(seconds: 2));
        expect(find.byType(WatermarkEditorScreen), findsNothing);
        expect(await closed.future, isNull);

        pending.writing.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(pending.writes, [output]);
        expect(pending.admissions, [
          [output],
        ]);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.text('Watermarked copy saved\nsource_watermarked.png'),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

WatermarkRenderResult _renderResult(Uint8List bytes) => WatermarkRenderResult(
  bytes: bytes,
  fileName: 'source_watermarked.png',
  width: 48,
  height: 32,
  metadataPreserved: false,
);

/// 推入编辑器路由并等原图载入；返回的 Completer 在编辑器关闭时带上返回值完成。
Future<Completer<String?>> _openForSave(
  WidgetTester tester,
  LocalStorageService storage,
  PendingDerivativeCopySaver pending,
  ui.Image preview, {
  WatermarkRenderOperation? renderCopy,
}) async {
  await tester.binding.setSurfaceSize(const Size(1180, 760));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final closed = Completer<String?>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        derivativeCopySaverProvider(
          DerivativeKind.watermark,
        ).overrideWithValue(pending.saver),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context)
                  .push<String>(
                    MaterialPageRoute(
                      builder: (_) => WatermarkEditorScreen(
                        sourceBytes: _pngBytes(48, 32),
                        sourceFileName: 'source.png',
                        sourcePath: 'source.png',
                        defaultsOnly: false,
                        decodePreview: (_, {requireStatic = false}) async =>
                            preview.clone(),
                        renderCopy:
                            renderCopy ??
                            (request, {cancellationToken}) async =>
                                _renderResult(request.sourceBytes),
                      ),
                    ),
                  )
                  .then(closed.complete),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(find.text('Save copy'), findsOneWidget);
  return closed;
}

Widget _controlsApp({
  required WatermarkSettings settings,
  required WatermarkEditableLayer selectedLayer,
  required ValueChanged<WatermarkSettings> onSettingsChanged,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: WatermarkEditorControls(
      settings: settings,
      layout: settings.universalLayout,
      selectedLayer: selectedLayer,
      logoAvailable: true,
      preserveMetadata: false,
      onOpenMetadataSettings: () {},
      onSettingsChanged: onSettingsChanged,
      onLayoutChanged: (_) {},
      onSelectedLayerChanged: (_) {},
      onChooseLogo: () {},
    ),
  ),
);

Uint8List _pngBytes(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(35, 48, 70, 255));
  return Uint8List.fromList(img.encodePng(image));
}
