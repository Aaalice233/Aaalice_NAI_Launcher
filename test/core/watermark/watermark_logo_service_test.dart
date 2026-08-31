import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/watermark/watermark_logo_service.dart';

void main() {
  test(
    'accepts a decoded static logo whose signature matches its extension',
    () async {
      const service = WatermarkLogoService();
      final bytes = await _pngBytes();

      await expectLater(
        service.validate(bytes, expectedExtension: 'png'),
        completes,
      );
    },
  );

  test('rejects damaged data and extension spoofing', () async {
    const service = WatermarkLogoService();
    final bytes = await _pngBytes();

    await expectLater(
      service.validate(bytes, expectedExtension: 'jpg'),
      throwsA(isA<WatermarkLogoException>()),
    );
    await expectLater(
      service.validate(Uint8List.fromList(const [1, 2, 3])),
      throwsA(isA<WatermarkLogoException>()),
    );
  });
}

Future<Uint8List> _pngBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xff663399),
  );
  final image = await recorder.endRecording().toImage(4, 4);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
