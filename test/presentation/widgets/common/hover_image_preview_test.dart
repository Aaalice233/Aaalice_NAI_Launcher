import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/hover_image_preview.dart';

void main() {
  final imageBytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );

  testWidgets('悬浮预览使用请求尺寸并保持在视口内', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 100,
              height: 100,
              child: HoverImagePreview(
                imageBytes: imageBytes,
                previewMaxSize: 520,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(HoverImagePreview)));
    await tester.pump();

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('hover-image-preview-overlay')),
    );
    expect(overlayRect.width, 520);
    expect(overlayRect.height, 520);
    expect(overlayRect.left, greaterThanOrEqualTo(16));
    expect(overlayRect.top, greaterThanOrEqualTo(16));
    expect(overlayRect.right, lessThanOrEqualTo(1184));
    expect(overlayRect.bottom, lessThanOrEqualTo(784));
  });

  testWidgets('空间不足时缩小预览而不是超出视口', (tester) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 100,
              height: 100,
              child: HoverImagePreview(
                imageBytes: imageBytes,
                previewMaxSize: 520,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(HoverImagePreview)));
    await tester.pump();

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('hover-image-preview-overlay')),
    );
    expect(overlayRect.width, lessThan(520));
    expect(overlayRect.left, greaterThanOrEqualTo(16));
    expect(overlayRect.top, greaterThanOrEqualTo(16));
    expect(overlayRect.right, lessThanOrEqualTo(484));
    expect(overlayRect.bottom, lessThanOrEqualTo(384));
  });
}
