import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/derivatives/derivative_registry.dart';
import 'package:nai_launcher/core/derivatives/derivative_render.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/mosaic/mosaic_settings.dart';
import 'package:nai_launcher/core/mosaic/mosaic_render_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/mosaic_settings_provider.dart';
import 'package:nai_launcher/presentation/screens/derivatives/derivative_copy_saver.dart';
import 'package:nai_launcher/presentation/screens/mosaic/mosaic_editor_canvas.dart';
import 'package:nai_launcher/presentation/screens/mosaic/mosaic_editor_screen.dart';

import '../../../helpers/editor_exit.dart';
import '../../../helpers/labeled_rows_expectations.dart';
import '../../../helpers/pending_derivative_copy_saver.dart';

class _Settings extends MosaicSettingsNotifier {
  @override
  MosaicSettingsState build() => const MosaicSettingsState(
    configuration: MosaicSettings(enabled: true, effect: MosaicEffect.solid),
  );
}

late ui.Image _preview;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = Uint8List.fromList(
    img.encodePng(
      img.Image(width: 80, height: 60)..clear(img.ColorRgb8(200, 100, 50)),
    ),
  );

  setUpAll(() async {
    _preview = await MosaicRenderService.decodePreview(bytes);
  });
  tearDownAll(() => _preview.dispose());

  for (final shape in [MosaicShape.roundedRectangle, MosaicShape.ellipse]) {
    for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      for (final corner in [
        const Offset(-1, -1),
        const Offset(1, -1),
        const Offset(-1, 1),
        const Offset(1, 1),
      ]) {
        testWidgets(
          '$shape $kind resizes from corner $corner after press delay',
          (tester) async {
            var region = MosaicRegion(
              id: 'resize',
              left: .25,
              top: .25,
              width: .5,
              height: .5,
              shape: shape,
            );
            String? selected = region.id;
            var transforms = 0;
            var created = 0;
            await tester.pumpWidget(
              MaterialApp(
                home: Center(
                  child: SizedBox(
                    width: 320,
                    height: 240,
                    child: StatefulBuilder(
                      builder: (context, setState) => MosaicEditorCanvas(
                        source: _preview,
                        processed: null,
                        settings: const MosaicSettings(),
                        regions: [region],
                        selectedId: selected,
                        drawShape: shape,
                        selectionColor: Colors.blue,
                        backgroundColor: Colors.black,
                        onSelected: (value) => setState(() => selected = value),
                        onBeginRegionTransform: () => transforms++,
                        onRegionChanged: (value) =>
                            setState(() => region = value),
                        onRegionCreated: (_, __, ___) => created++,
                        onFocusRequested: () {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            final center = tester.getCenter(find.byType(MosaicEditorCanvas));
            final start = center + Offset(80 * corner.dx, 60 * corner.dy);
            final gesture = await tester.startGesture(start, kind: kind);
            await tester.pump(const Duration(milliseconds: 150));
            await gesture.moveBy(corner * 30);
            await tester.pump();
            await gesture.moveBy(corner * 20);
            await tester.pump();
            await gesture.up();
            await tester.pump();
            expect(selected, 'resize');
            expect(transforms, 1);
            expect(created, 0);
            expect(region.width, closeTo(.5 + 50 / 320, .00001));
            expect(region.height, closeTo(.5 + 50 / 240, .00001));
            expect(
              corner.dx < 0 ? region.left + region.width : region.left,
              closeTo(corner.dx < 0 ? .75 : .25, .00001),
            );
            expect(
              corner.dy < 0 ? region.top + region.height : region.top,
              closeTo(corner.dy < 0 ? .75 : .25, .00001),
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  testWidgets(
    'saving freezes the displayed mask and cancellation restores editing',
    (tester) async {
      final pending = Completer<MosaicRenderResult>();
      MosaicRenderRequest? request;
      await _mount(
        tester,
        bytes,
        const Size(1180, 900),
        1,
        renderCopy: (value, {cancellationToken}) {
          request = value;
          return pending.future;
        },
      );
      try {
        await tester.tap(find.widgetWithIcon(FilledButton, Icons.save_alt));
        await tester.pump();
        expect(request, isNotNull);
        expect(
          tester
              .widget<AbsorbPointer>(
                find
                    .ancestor(
                      of: find.byType(MosaicEditorCanvas),
                      matching: find.byType(AbsorbPointer),
                    )
                    .first,
              )
              .absorbing,
          isTrue,
        );
        final canvasBefore = tester.widget<MosaicEditorCanvas>(
          find.byType(MosaicEditorCanvas),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pump();
        final canvasAfter = tester.widget<MosaicEditorCanvas>(
          find.byType(MosaicEditorCanvas),
        );
        expect(canvasAfter.regions, same(canvasBefore.regions));
        expect(canvasAfter.regions, same(request!.regions));
        pending.completeError(const DerivativeRenderCancelledException());
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AbsorbPointer>(
                find
                    .ancestor(
                      of: find.byType(MosaicEditorCanvas),
                      matching: find.byType(AbsorbPointer),
                    )
                    .first,
              )
              .absorbing,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      } finally {
        if (!pending.isCompleted) {
          pending.completeError(const DerivativeRenderCancelledException());
        }
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'editor at $width with ${scale}x text keeps controls reachable',
        (tester) async {
          await _mount(tester, bytes, Size(width, 900), scale);
          expect(find.byType(MosaicEditorCanvas), findsOneWidget);
          expect(find.text('Redaction editor'), findsOneWidget);
          expect(find.byTooltip('Undo'), findsOneWidget);
          final save = find.widgetWithIcon(FilledButton, Icons.save_alt);
          expect(save.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          final scrollable = find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first;
          final fullImage = find.widgetWithIcon(
            OutlinedButton,
            Icons.fullscreen,
          );
          await tester.scrollUntilVisible(
            fullImage,
            250,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          expect(fullImage.hitTestable(), findsOneWidget);
          await tester.tap(fullImage);
          await tester.pump();
          final canvas = tester.widget<MosaicEditorCanvas>(
            find.byType(MosaicEditorCanvas),
          );
          expect(canvas.regions.last.coversFullImage, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final locale in const ['en', 'ja']) {
    for (final width in labeledRowWidths) {
      for (final scale in labeledRowTextScales) {
        final scenario = '$locale ${width.toInt()} ${scale}x';
        testWidgets('$scenario mask sliders keep labels whole and reachable', (
          tester,
        ) async {
          await _mount(tester, bytes, Size(width, 900), scale, locale: locale);
          expect(tester.takeException(), isNull, reason: scenario);
          final l10n = lookupAppLocalizations(Locale(locale));
          await expectLabeledSliderRows(
            tester,
            labels: [
              l10n.mosaic_opacity,
              l10n.mosaic_cornerRadius,
              l10n.mosaic_brushSize,
            ],
            labelsSingleLine: locale != 'en',
            lazyScrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
            reason: scenario,
          );
          expect(tester.takeException(), isNull, reason: scenario);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  for (final inset in [0.0, 200.0]) {
    testWidgets(
      'short landscape with keyboard inset $inset has usable actions',
      (tester) async {
        await _mount(
          tester,
          bytes,
          const Size(760, 420),
          1,
          keyboardInset: inset,
        );
        expect(find.byType(MosaicEditorCanvas), findsOneWidget);
        expect(
          find.widgetWithIcon(FilledButton, Icons.save_alt).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'edge-spanning brush can be dragged without invalid clamp ranges',
    (tester) async {
      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      });
      addTearDown(image!.dispose);
      MosaicRegion? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 240,
              child: MosaicEditorCanvas(
                source: image,
                processed: null,
                settings: const MosaicSettings(effect: MosaicEffect.solid),
                regions: const [
                  MosaicRegion(
                    id: 'edge',
                    left: 0,
                    top: 0,
                    width: 1,
                    height: 1,
                    shape: MosaicShape.brush,
                    points: [
                      MosaicPoint(0, 0),
                      MosaicPoint(0.5, 0.5),
                      MosaicPoint(1, 1),
                    ],
                  ),
                ],
                selectedId: 'edge',
                drawShape: MosaicShape.brush,
                selectionColor: Colors.blue,
                backgroundColor: Colors.white,
                onSelected: (_) {},
                onBeginRegionTransform: () {},
                onRegionChanged: (region) => changed = region,
                onRegionCreated: (_, __, ___) {},
                onFocusRequested: () {},
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(MosaicEditorCanvas));
      final gesture = await tester.startGesture(center - const Offset(20, 0));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 20));
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(changed, isNotNull);
      expect(changed!.points.first.x, 0);
      expect(changed!.points.last.x, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  group('save copy', () {
    testWidgets('stalled follow-up steps never hold the editor once written', (
      tester,
    ) async {
      final pending = PendingDerivativeCopySaver(DerivativeKind.mosaic);
      addTearDown(pending.releaseAll);
      final settings = _RecordingSettings();
      final closed = await _openForSave(tester, bytes, pending, settings);
      final output = pending.outputPathFor('source_redacted.png');

      await tester.tap(find.widgetWithIcon(FilledButton, Icons.save_alt));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Redacted copy saved'), findsOneWidget);
      expect(pending.writes, [output]);
      expect(pending.admissions, [
        [output],
      ]);
      expect(pending.indexing.isCompleted, isFalse);
      expect(settings.remembered, hasLength(1));

      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.byType(MosaicEditorScreen), findsNothing);
      expect(closed.isCompleted, isTrue);
      expect(await closed.future, output);
      expect(tester.takeException(), isNull);
    });

    testWidgets('follow-up failures still surface after the editor closed', (
      tester,
    ) async {
      final pending = PendingDerivativeCopySaver(DerivativeKind.mosaic);
      addTearDown(pending.releaseAll);
      await _openForSave(tester, bytes, pending, _RecordingSettings());
      await tester.tap(find.widgetWithIcon(FilledButton, Icons.save_alt));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.byType(MosaicEditorScreen), findsNothing);

      pending.indexing.complete(GalleryIndexAdmission.failed);
      pending.rescanning.complete('refreshFailed');
      pending.publishing.completeError(StateError('media store'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.mosaic_galleryRefreshFailed), findsOneWidget);
      expect(find.text(l10n.mosaic_systemGalleryExportFailed), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final exit in EditorExit.values) {
      testWidgets('${exit.name} during a stalled render leaves and writes '
          'nothing', (tester) async {
        final pending = PendingDerivativeCopySaver(DerivativeKind.mosaic);
        addTearDown(pending.releaseAll);
        final settings = _RecordingSettings();
        final rendering = Completer<MosaicRenderResult>();
        final closed = await _openForSave(
          tester,
          bytes,
          pending,
          settings,
          renderCopy: (request, {cancellationToken}) => rendering.future,
        );

        await tester.tap(find.widgetWithIcon(FilledButton, Icons.save_alt));
        await tester.pump();
        expect(find.text('Saving…'), findsOneWidget);

        await exit.perform(tester);
        await tester.pump();
        expect(closed.isCompleted, isTrue);
        await settleWithin(tester, const Duration(seconds: 2));
        expect(find.byType(MosaicEditorScreen), findsNothing);
        expect(await closed.future, isNull);

        rendering.complete(_renderResult(bytes));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(pending.writes, isEmpty);
        expect(settings.remembered, isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${exit.name} once writing started leaves and still saves', (
        tester,
      ) async {
        final pending = PendingDerivativeCopySaver(
          DerivativeKind.mosaic,
          holdWrites: true,
        );
        addTearDown(pending.releaseAll);
        final settings = _RecordingSettings();
        final closed = await _openForSave(tester, bytes, pending, settings);
        final output = pending.outputPathFor('source_redacted.png');

        await tester.tap(find.widgetWithIcon(FilledButton, Icons.save_alt));
        await tester.pump();
        expect(pending.writeRequests, [output]);

        await exit.perform(tester);
        await tester.pump();
        expect(closed.isCompleted, isTrue);
        await settleWithin(tester, const Duration(seconds: 2));
        expect(find.byType(MosaicEditorScreen), findsNothing);
        expect(await closed.future, isNull);

        pending.writing.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(pending.writes, [output]);
        expect(pending.admissions, [
          [output],
        ]);
        expect(settings.remembered, hasLength(1));
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.text('Redacted copy saved\nsource_redacted.png'),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

MosaicRenderResult _renderResult(Uint8List bytes) => MosaicRenderResult(
  bytes: bytes,
  fileName: 'source_redacted.png',
  width: 80,
  height: 60,
  metadataPreserved: false,
);

class _RecordingSettings extends _Settings {
  final remembered = <MosaicSettings>[];

  @override
  Future<void> saveDefaults([MosaicSettings? configuration]) async {
    remembered.add(configuration ?? state.configuration);
  }
}

/// 推入编辑器路由并等原图载入；返回的 Completer 在编辑器关闭时带上返回值完成。
Future<Completer<String?>> _openForSave(
  WidgetTester tester,
  Uint8List bytes,
  PendingDerivativeCopySaver pending,
  _RecordingSettings settings, {
  MosaicRenderOperation? renderCopy,
}) async {
  await tester.binding.setSurfaceSize(const Size(1180, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final closed = Completer<String?>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mosaicSettingsProvider.overrideWith(() => settings),
        derivativeCopySaverProvider(
          DerivativeKind.mosaic,
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
                      builder: (_) => MosaicEditorScreen(
                        sourceBytes: bytes,
                        sourceFileName: 'source.png',
                        sourcePath: 'source.png',
                        defaultsOnly: false,
                        decodePreview: (_) async => _preview.clone(),
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
  await tester.pumpAndSettle(
    const Duration(milliseconds: 20),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
  expect(find.widgetWithIcon(FilledButton, Icons.save_alt), findsOneWidget);
  return closed;
}

Future<void> _mount(
  WidgetTester tester,
  Uint8List bytes,
  Size size,
  double scale, {
  double keyboardInset = 0,
  String locale = 'en',
  MosaicRenderOperation renderCopy = MosaicRenderService.render,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mosaicSettingsProvider.overrideWith(_Settings.new)],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: MosaicEditorScreen(
              sourceBytes: bytes,
              sourceFileName: 'source.png',
              defaultsOnly: false,
              decodePreview: (_) async => _preview.clone(),
              renderCopy: renderCopy,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 20),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}
