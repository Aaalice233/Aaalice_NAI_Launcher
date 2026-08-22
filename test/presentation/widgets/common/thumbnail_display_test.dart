import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/common/thumbnail_display.dart';

void main() {
  testWidgets('adds decode size hints while image dimensions are loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(devicePixelRatio: 2.5),
          child: ThumbnailDisplay(
            imagePath: 'missing-thumbnail.png',
            width: 120,
            height: 48,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;

    expect(resized.width, 300);
    expect(resized.height, 120);
  });

  testWidgets('adds decode size hints for cropped thumbnails', (tester) async {
    final directory = Directory.systemTemp.createTempSync(
      'thumbnail_display_test_',
    );
    addTearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final imageFile = File('${directory.path}/square.png');
    imageFile.writeAsBytesSync(
      img.encodePng(img.Image(width: 100, height: 100)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: ThumbnailDisplay(
            imagePath: imageFile.path,
            width: 100,
            height: 40,
            scale: 2,
          ),
        ),
      ),
    );

    final resized = await _pumpUntilResizeWidth(tester, 400);

    expect(resized.width, 400);
    expect(resized.height, 400);
  });

  testWidgets('uses the actual viewport ratio when covering the thumbnail', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'thumbnail_display_ratio_test_',
    );
    addTearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final imageFile = File('${directory.path}/landscape.png');
    imageFile.writeAsBytesSync(
      img.encodePng(img.Image(width: 200, height: 100)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: ThumbnailDisplay(
            imagePath: imageFile.path,
            width: 64,
            height: 64,
          ),
        ),
      ),
    );

    final resized = await _pumpUntilResizeWidth(tester, 256);
    final image = tester.widget<Image>(find.byType(Image));

    expect(resized.width, 256);
    expect(resized.height, 128);
    expect(image.width, 128);
    expect(image.height, 64);
  });
}

Future<ResizeImage> _pumpUntilResizeWidth(
  WidgetTester tester,
  int expectedWidth,
) async {
  ResizeImage? latest;

  for (var attempt = 0; attempt < 10; attempt++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 20));
    final image = tester.widget<Image>(find.byType(Image));
    latest = image.image as ResizeImage;
    if (latest.width == expectedWidth) {
      return latest;
    }
  }

  return latest!;
}
