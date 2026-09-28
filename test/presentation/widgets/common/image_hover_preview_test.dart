import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/image_hover_preview.dart';

void main() {
  group('resolveImageHoverPreviewMediaLayout', () {
    test('preserves ordinary portrait and landscape ratios', () {
      final portrait = resolveImageHoverPreviewMediaLayout(
        sourceAspectRatio: 2 / 3,
        width: 320,
        maxHeight: 600,
      );
      final landscape = resolveImageHoverPreviewMediaLayout(
        sourceAspectRatio: 3 / 2,
        width: 320,
        maxHeight: 600,
      );

      expect(portrait.size, const Size(320, 480));
      expect(portrait.isCropped, isFalse);
      expect(landscape.size, const Size(320, 320 / 1.5));
      expect(landscape.isCropped, isFalse);
    });

    test('crops extreme ratios without reducing media width', () {
      final tall = resolveImageHoverPreviewMediaLayout(
        sourceAspectRatio: 1 / 3,
        width: 320,
        maxHeight: 420,
      );
      final wide = resolveImageHoverPreviewMediaLayout(
        sourceAspectRatio: 4,
        width: 320,
        maxHeight: 420,
      );

      expect(tall.size, const Size(320, 420));
      expect(tall.fit, BoxFit.cover);
      expect(tall.alignment, Alignment.topCenter);
      expect(tall.isCropped, isTrue);
      expect(wide.size, const Size(320, 150));
      expect(wide.fit, BoxFit.cover);
      expect(wide.alignment, Alignment.center);
      expect(wide.isCropped, isTrue);
    });

    test('uses safe fallback ratio and honors a very small height', () {
      final unknown = resolveImageHoverPreviewMediaLayout(
        sourceAspectRatio: double.nan,
        width: 80,
        maxHeight: 60,
      );

      expect(unknown.size, const Size(80, 60));
      expect(unknown.fit, BoxFit.cover);
      expect(unknown.isCropped, isTrue);
    });
  });

  testWidgets('surface exposes reusable media and footer slots', (
    tester,
  ) async {
    ImageHoverPreviewMediaLayout? capturedLayout;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ImageHoverPreviewSurface(
            sourceAspectRatio: 2 / 3,
            maxWidth: 320,
            maxHeight: 500,
            mediaBuilder: (context, layout) {
              capturedLayout = layout;
              return const ColoredBox(
                key: ValueKey('shared-preview-media'),
                color: Colors.blue,
              );
            },
            footer: const SizedBox(
              key: ValueKey('custom-preview-footer'),
              height: 40,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('shared-preview-media')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-preview-footer')), findsOneWidget);
    expect(capturedLayout!.size.width, 320);
    expect(capturedLayout!.size.height, 460);
    expect(tester.takeException(), isNull);
  });
}
