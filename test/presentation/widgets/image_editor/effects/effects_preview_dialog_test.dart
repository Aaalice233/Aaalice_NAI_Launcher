import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/effects/editor_effects.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/effects/effects_preview_dialog.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_processing_service.dart';

void main() {
  late Uint8List sourceBytes;
  late _RecordingProcessingService processingService;

  setUp(() {
    sourceBytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );
    processingService = _RecordingProcessingService(sourceBytes);
  });

  testWidgets(
    'removing the dialog immediately does not setState after dispose',
    (tester) async {
      await tester.pumpWidget(_wrapDialog(sourceBytes, processingService));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(processingService.previewCalls, 0);
    },
  );

  testWidgets(
    'the first frame matches the source preview before showing loading',
    (tester) async {
      await tester.pumpWidget(_wrapDialog(sourceBytes, processingService));

      expect(_applyButton(tester).onPressed, isNotNull);
      expect(processingService.previewCalls, 0);

      await tester.pump();

      expect(_applyButton(tester).onPressed, isNull);
      expect(processingService.previewCalls, 0);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('superseded previews never overwrite the newest one', (
    tester,
  ) async {
    final service = _PendingPreviewService();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(_wrapDialog(sourceBytes, service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    for (final index in [1, 2]) {
      await tester.tap(find.byType(ChoiceChip).at(index));
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(service.requests, hasLength(3));
    expect(service.requests.map((request) => request.isCurrent()), [
      false,
      false,
      true,
    ]);

    final newest = _png(3);
    final stale = _png(2);
    service.requests[2].result.complete(
      EditorEffectResult(bytes: newest, width: 3, height: 3),
    );
    service.requests[1].result.complete(null);
    await tester.pump();
    service.requests[0].result.complete(
      EditorEffectResult(bytes: stale, width: 2, height: 2),
    );
    await tester.pump();

    final shown = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<MemoryImage>()
        .map((image) => image.bytes);
    expect(shown, contains(same(newest)));
    expect(shown, isNot(contains(same(stale))));
    expect(_applyButton(tester).onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('320px、3x、IME 与 SafeArea 下全屏且内容和操作可滚动访问', (tester) async {
    await _pumpHost(
      tester,
      sourceBytes,
      processingService,
      size: const Size(320, 900),
      textScaler: const TextScaler.linear(3),
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
      viewInsets: const EdgeInsets.only(bottom: 320),
    );

    await _openDialog(tester);

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(surface, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('effects-preview-frame')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('effects-preview-scroll')),
      findsOneWidget,
    );
    final cancel = find.byKey(const ValueKey('effects-preview-cancel'));
    final apply = find.byKey(const ValueKey('effects-preview-apply'));
    expect(cancel, findsOneWidget);
    expect(apply, findsOneWidget);
    expect(tester.getTopLeft(surface).dy, greaterThanOrEqualTo(24));
    expect(tester.getBottomRight(surface).dy, lessThanOrEqualTo(580));
    expect(tester.getRect(cancel).left, greaterThanOrEqualTo(12));
    expect(tester.getRect(apply).right, lessThanOrEqualTo(308));

    final scroll = find.byKey(const ValueKey('effects-preview-scroll'));
    final scrollable = find.descendant(
      of: scroll,
      matching: find.byType(Scrollable),
    );
    await tester.drag(scroll, const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
  });

  for (final scenario in [
    (
      name: 'Medium',
      size: const Size(700, 800),
      surfaceKey: const ValueKey('adaptive-centered-form'),
    ),
    (
      name: 'Expanded',
      size: const Size(1200, 900),
      surfaceKey: const ValueKey('adaptive-centered-form'),
    ),
  ]) {
    testWidgets('${scenario.name} 使用共享有界呈现', (tester) async {
      await _pumpHost(
        tester,
        sourceBytes,
        processingService,
        size: scenario.size,
      );

      await _openDialog(tester);

      final surface = find.byKey(scenario.surfaceKey);
      expect(surface, findsOneWidget);
      expect(tester.getSize(surface).width, lessThan(scenario.size.width));
      expect(
        find.byKey(const ValueKey('effects-preview-frame')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('取消返回 null，应用返回当前效果选择', (tester) async {
    EditorEffectSelection? result;
    var completed = false;
    await _pumpHost(
      tester,
      sourceBytes,
      processingService,
      size: const Size(700, 800),
      onResult: (value) {
        result = value;
        completed = true;
      },
    );

    await _openDialog(tester);
    await tester.tap(find.byKey(const ValueKey('effects-preview-cancel')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);

    completed = false;
    await _openDialog(tester);
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('effects-preview-apply')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result?.type, EditorEffectType.brightness);
    expect(result?.intensity, 0.25);
  });

  testWidgets('in-place effects are previewed by the editor, not the worker', (
    tester,
  ) async {
    _useTallView(tester);
    final requested = <EditorEffectType>[];
    final rotated = _png(2);
    await tester.pumpWidget(
      _wrapDialog(
        sourceBytes,
        processingService,
        inPlacePreview: (type) async {
          requested.add(type);
          return rotated;
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final workerCalls = processingService.previewCalls;

    await tester.tap(find.text('Rotate Right 90°'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(requested, [EditorEffectType.rotateRight]);
    expect(processingService.previewCalls, workerCalls);
    expect(_applyButton(tester).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('crop without a selection explains why and cannot be applied', (
    tester,
  ) async {
    _useTallView(tester);
    await tester.pumpWidget(
      _wrapDialog(
        sourceBytes,
        processingService,
        inPlacePreview: (_) async => fail('no selection, no preview'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Crop to Selection'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text(
        'Make a selection first; only the pixels inside its bounding box '
        'are kept, in place.',
      ),
      findsOneWidget,
    );
    expect(_applyButton(tester).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _useTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 2400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Uint8List _png(int size) =>
    Uint8List.fromList(img.encodePng(img.Image(width: size, height: size)));

FilledButton _applyButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const ValueKey('effects-preview-apply')),
);

Widget _wrapDialog(
  Uint8List sourceBytes,
  ImageEditorProcessingService processingService, {
  EditorEffectCropRect? cropRect,
  EffectInPlacePreview? inPlacePreview,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: EffectsPreviewDialog(
        sourceBytes: sourceBytes,
        cropRect: cropRect,
        processingService: processingService,
        inPlacePreview: inPlacePreview,
      ),
    ),
  );
}

Future<void> _pumpHost(
  WidgetTester tester,
  Uint8List sourceBytes,
  ImageEditorProcessingService processingService, {
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  ValueChanged<EditorEffectSelection?>? onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: textScaler,
          padding: padding,
          viewPadding: padding,
          viewInsets: viewInsets,
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const ValueKey('open-effects-preview'),
              onPressed: () async {
                final result = await EffectsPreviewDialog.show(
                  context,
                  sourceBytes: sourceBytes,
                  cropRect: null,
                  processingService: processingService,
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-effects-preview')));
  await tester.pumpAndSettle();
}

class _RecordingProcessingService extends ImageEditorProcessingService {
  _RecordingProcessingService(this.bytes);

  final Uint8List bytes;
  int previewCalls = 0;

  @override
  Future<EditorEffectResult?> previewEffect(
    EditorEffectJob job, {
    required bool Function() isCurrent,
  }) async {
    previewCalls++;
    return EditorEffectResult(bytes: bytes, width: 4, height: 4);
  }
}

class _PendingPreviewService extends ImageEditorProcessingService {
  final requests =
      <({Completer<EditorEffectResult?> result, bool Function() isCurrent})>[];

  @override
  Future<EditorEffectResult?> previewEffect(
    EditorEffectJob job, {
    required bool Function() isCurrent,
  }) {
    final result = Completer<EditorEffectResult?>();
    requests.add((result: result, isCurrent: isCurrent));
    return result.future;
  }
}
