import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/common/decoded_memory_image.dart';
import 'package:nai_launcher/presentation/widgets/common/selectable_image_card.dart';

void main() {
  final transparentResults = <String, Uint8List>{
    'PNG': _halfTransparentPng(const Color(0xff0000ff)),
    'WebP': base64Decode(
      'UklGRiQAAABXRUJQVlA4TBcAAAAvD8ADEA8QMf/zHwyxYDJ/6e4MIvofuQA=',
    ),
  };

  for (final entry in transparentResults.entries) {
    testWidgets(
      '${entry.key} transparent completion atomically replaces the opaque preview',
      (tester) => _verifyAtomicReplacement(tester, entry.value),
    );
  }
}

Future<void> _verifyAtomicReplacement(
  WidgetTester tester,
  Uint8List transparentResult,
) async {
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);

  final boundaryKey = GlobalKey();
  final opaquePreview = _opaquePng(const Color(0xffff0000));

  await tester.pumpWidget(
    _buildCard(
      boundaryKey: boundaryKey,
      imageBytes: opaquePreview,
      imageIdentity: 'previous-result',
    ),
  );
  await tester.pumpAndSettle();

  await tester.pumpWidget(
    _buildCard(
      boundaryKey: boundaryKey,
      imageBytes: transparentResult,
      imageIdentity: 'new-transparent-result',
      completionPlaceholderBytes: opaquePreview,
    ),
  );

  expect(
    find.byType(DecodedMemoryImage),
    findsOneWidget,
    reason: 'The previous preview and completed image must never be layered',
  );

  var sawCompletedFrame = false;
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 10));
    final pixels = (await tester.runAsync(() => _captureCard(boundaryKey)))!;
    final opaqueHalf = pixels.pixelAt(16, 32);
    final transparentHalf = pixels.pixelAt(48, 32);

    if (_isCloseTo(opaqueHalf, const Color(0xff0000ff))) {
      sawCompletedFrame = true;
      expect(
        _isCloseTo(transparentHalf, const Color(0xff00ff00)),
        isTrue,
        reason:
            'The completed frame was visible while its transparent half '
            'still exposed the previous opaque preview: $transparentHalf',
      );
      break;
    }
  }

  expect(sawCompletedFrame, isTrue);
  await tester.pumpAndSettle();

  final finalPixels = (await tester.runAsync(() => _captureCard(boundaryKey)))!;
  expect(
    _isCloseTo(finalPixels.pixelAt(16, 32), const Color(0xff0000ff)),
    isTrue,
  );
  expect(
    _isCloseTo(finalPixels.pixelAt(48, 32), const Color(0xff00ff00)),
    isTrue,
  );
}

Widget _buildCard({
  required GlobalKey boundaryKey,
  required Uint8List imageBytes,
  required Object imageIdentity,
  Uint8List? completionPlaceholderBytes,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 64,
              height: 64,
              child: SelectableImageCard(
                imageBytes: imageBytes,
                imageIdentity: imageIdentity,
                completionPlaceholderBytes: completionPlaceholderBytes,
                underlay: const ColoredBox(color: Color(0xff00ff00)),
                enableSelection: false,
                enableContextMenu: false,
                enableHoverScale: false,
                enableGlossEffect: false,
                hoverEffectsEnabled: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Uint8List _opaquePng(Color color) {
  final image = img.Image(width: 16, height: 16, numChannels: 4);
  img.fill(image, color: _imageColor(color));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _halfTransparentPng(Color color) {
  final image = img.Image(width: 16, height: 16, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  img.fillRect(image, x1: 0, y1: 0, x2: 7, y2: 15, color: _imageColor(color));
  return Uint8List.fromList(img.encodePng(image));
}

img.ColorRgba8 _imageColor(Color color) {
  return img.ColorRgba8(
    (color.r * 255).round(),
    (color.g * 255).round(),
    (color.b * 255).round(),
    (color.a * 255).round(),
  );
}

Future<_CapturedPixels> _captureCard(GlobalKey boundaryKey) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return _CapturedPixels(
      byteData!.buffer.asUint8List(),
      image.width,
      image.height,
    );
  } finally {
    image.dispose();
  }
}

bool _isCloseTo(Color actual, Color expected) {
  return (actual.r - expected.r).abs() <= 0.04 &&
      (actual.g - expected.g).abs() <= 0.04 &&
      (actual.b - expected.b).abs() <= 0.04 &&
      (actual.a - expected.a).abs() <= 0.04;
}

class _CapturedPixels {
  const _CapturedPixels(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;

  Color pixelAt(int x, int y) {
    assert(x >= 0 && x < width && y >= 0 && y < height);
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      bytes[offset + 3],
      bytes[offset],
      bytes[offset + 1],
      bytes[offset + 2],
    );
  }
}
