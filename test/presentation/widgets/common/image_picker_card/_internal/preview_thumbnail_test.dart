import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/common/image_picker_card/_internal/preview_thumbnail.dart';

import '../../../../../helpers/real_async_pump.dart';

void main() {
  late Uint8List wideBytes;

  setUp(() {
    wideBytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 640, height: 320)),
    );
  });

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  Future<void> pumpThumbnail(WidgetTester tester, PreviewThumbnail thumbnail) {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(MaterialApp(home: Center(child: thumbnail)));
  }

  ui.Image? decodedImage(WidgetTester tester) {
    final raw = find.byType(RawImage);
    return raw.evaluate().isEmpty ? null : tester.widget<RawImage>(raw).image;
  }

  testWidgets('字节缩略图按覆盖尺寸等比解码，不压成方形', (tester) async {
    await pumpThumbnail(tester, PreviewThumbnail(imageBytes: wideBytes));

    await pumpUntilRealAsync(tester, () => decodedImage(tester) != null);

    final image = decodedImage(tester)!;
    expect((image.width, image.height), (96, 48));
    expect(tester.getSize(find.byType(RawImage)), const Size(48, 48));
  });

  testWidgets('文件缩略图按覆盖尺寸等比解码，不压成方形', (tester) async {
    final directory = Directory.systemTemp.createTempSync(
      'preview_thumbnail_test_',
    );
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/wide.png')
      ..writeAsBytesSync(wideBytes);

    await pumpThumbnail(tester, PreviewThumbnail(imagePath: file.path));

    await pumpUntilRealAsync(tester, () => decodedImage(tester) != null);

    final image = decodedImage(tester)!;
    expect((image.width, image.height), (96, 48));
    expect(tester.getSize(find.byType(RawImage)), const Size(48, 48));
  });
}
