import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/common/image_card_stream_preview.dart';

void main() {
  testWidgets('transient frames resize without populating the shared cache', (
    tester,
  ) async {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 512, height: 768)),
    );
    ui.Image? previous;
    for (var i = 0; i < 8; i++) {
      await tester.pumpWidget(_app(Uint8List.fromList(bytes)));
      await _until(
        tester,
        () =>
            _painter(tester).previewImage != null &&
            !identical(_painter(tester).previewImage, previous),
      );
      final image = _painter(tester).previewImage!;
      expect(image.width, 200);
      expect(image.height, 300);
      if (previous != null) expect(previous.debugDisposed, isTrue);
      previous = image;
      expect(cache.currentSizeBytes, 0);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(previous!.debugDisposed, isTrue);
    expect(cache.currentSizeBytes, 0);
  });

  testWidgets(
    'burst frames keep only one decoder and the newest pending frame',
    (tester) async {
      final first = await tester.runAsync(() => createTestImage(cache: false));
      final stale = await tester.runAsync(() => createTestImage(cache: false));
      final latest = await tester.runAsync(() => createTestImage(cache: false));
      final calls = <int>[];
      final pending = <Completer<ui.Image>>[];
      Future<ui.Image> decode(
        Uint8List bytes, {
        required int? targetWidth,
        required int? targetHeight,
      }) {
        calls.add(bytes.single);
        final completer = Completer<ui.Image>();
        pending.add(completer);
        return completer.future;
      }

      await tester.pumpWidget(_app(Uint8List.fromList([1]), decoder: decode));
      pending[0].complete(first!);
      await tester.pump();
      expect(_painter(tester).previewImage, same(first));
      await tester.pumpWidget(_app(Uint8List.fromList([2]), decoder: decode));
      await tester.pumpWidget(_app(Uint8List.fromList([3]), decoder: decode));
      await tester.pumpWidget(_app(Uint8List.fromList([4]), decoder: decode));
      expect(calls, [1, 2]);
      expect(_painter(tester).previewImage, same(first));
      pending[1].complete(stale!);
      await tester.pump();
      expect(calls, [1, 2, 4]);
      expect(stale.debugDisposed, isTrue);
      expect(first.debugDisposed, isFalse);
      pending[2].complete(latest!);
      await tester.pump();
      await tester.pump();
      expect(_painter(tester).previewImage, same(latest));
      expect(first.debugDisposed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(latest.debugDisposed, isTrue);
    },
  );

  testWidgets('disposing during decode releases its eventual image', (
    tester,
  ) async {
    final image = await tester.runAsync(() => createTestImage(cache: false));
    final completer = Completer<ui.Image>();
    await tester.pumpWidget(
      _app(
        Uint8List.fromList([1]),
        decoder:
            (bytes, {required int? targetWidth, required int? targetHeight}) =>
                completer.future,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete(image!);
    await tester.pump();
    expect(image.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed replacement retains its frame and later frames recover', (
    tester,
  ) async {
    final first = await tester.runAsync(() => createTestImage(cache: false));
    final last = await tester.runAsync(() => createTestImage(cache: false));
    Future<ui.Image> decode(
      Uint8List bytes, {
      required int? targetWidth,
      required int? targetHeight,
    }) async {
      if (bytes.single == 2) throw const FormatException('invalid frame');
      return bytes.single == 1 ? first! : last!;
    }

    await tester.pumpWidget(_app(Uint8List.fromList([1]), decoder: decode));
    await tester.pump();
    await tester.pumpWidget(_app(Uint8List.fromList([2]), decoder: decode));
    await tester.pump();
    expect(_painter(tester).previewImage, same(first));
    await tester.pumpWidget(_app(Uint8List.fromList([3]), decoder: decode));
    await tester.pump();
    expect(_painter(tester).previewImage, same(last));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(first!.debugDisposed, isTrue);
    expect(last!.debugDisposed, isTrue);
  });

  testWidgets('same bytes re-decode for a larger viewport and device ratio', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 512, height: 768)),
    );
    await tester.pumpWidget(_app(bytes));
    await _until(tester, () => _painter(tester).previewImage != null);
    final first = _painter(tester).previewImage!;
    await tester.pumpWidget(_app(bytes, size: 150, ratio: 2));
    await _until(
      tester,
      () => !identical(_painter(tester).previewImage, first),
    );
    expect(_painter(tester).previewImage!.width, 300);
    expect(_painter(tester).previewImage!.height, 450);
    expect(first.debugDisposed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _app(
  Uint8List bytes, {
  StreamPreviewImageDecoder? decoder,
  double size = 200,
  double ratio = 1,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(devicePixelRatio: ratio),
    child: Center(
      child: SizedBox(
        width: size,
        height: size,
        child: ImageCardStreamPreview(
          previewBytes: bytes,
          imageDecoder: decoder,
        ),
      ),
    ),
  ),
);

ImageCardStreamPreviewPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(ImageCardStreamPreview),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as ImageCardStreamPreviewPainter;

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 50 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(ready(), isTrue, reason: 'Native image decode must finish promptly');
}
