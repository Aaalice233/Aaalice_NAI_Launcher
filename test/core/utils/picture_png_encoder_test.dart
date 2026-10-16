import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/picture_png_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ui.Picture splitPicture() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawRect(
        const ui.Rect.fromLTWH(0, 0, 2, 2),
        ui.Paint()..color = const ui.Color(0xFFFF0000),
      )
      ..drawRect(
        const ui.Rect.fromLTWH(2, 0, 2, 2),
        ui.Paint()..color = const ui.Color(0xFF0000FF),
      );
    return recorder.endRecording();
  }

  test('encodes the picture and releases it', () async {
    final picture = splitPicture();

    final png = img.decodePng(await encodePictureAsPng(picture, 4, 2))!;

    expect((png.width, png.height), (4, 2));
    expect(png.getPixel(0, 0).r, 255);
    expect(png.getPixel(3, 1).b, 255);
    expect(picture.debugDisposed, isTrue);
  });

  test('releases the picture when rasterizing fails', () async {
    final picture = splitPicture();

    await expectLater(encodePictureAsPng(picture, 0, 0), throwsA(anything));

    expect(picture.debugDisposed, isTrue);
  });

  test('resamples only the requested source region', () async {
    final source = await splitPicture().toImage(4, 2);
    addTearDown(source.dispose);

    final png = img.decodePng(
      await resampleImageAsPng(
        source,
        width: 1,
        height: 1,
        sourceRect: const ui.Rect.fromLTWH(2, 0, 2, 2),
        filterQuality: ui.FilterQuality.none,
      ),
    )!;

    expect((png.width, png.height), (1, 1));
    expect(png.getPixel(0, 0).b, 255);
    expect(source.debugDisposed, isFalse);
  });
}
