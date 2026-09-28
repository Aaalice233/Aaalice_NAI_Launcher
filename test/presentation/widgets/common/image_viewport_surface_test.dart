import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/screens/generation/widgets/img2img_source_preview.dart';
import 'package:nai_launcher/presentation/widgets/common/image_viewport_surface.dart';
import 'package:nai_launcher/presentation/widgets/common/transparency_background.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/online_gallery_image_placeholder.dart';

void main() {
  final source = Uint8List.fromList(
    img.encodePng(img.Image(width: 8, height: 12)),
  );

  for (final brightness in Brightness.values) {
    testWidgets('source surround stays dark at every width in $brightness', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 240));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: Scaffold(
              body: Img2ImgSourcePreview(
                sourceBytes: source,
                imageWidth: 8,
                imageHeight: 12,
              ),
            ),
          ),
        );
        final surround = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(Img2ImgSourcePreview),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(surround.color, const Color(0xFF141414));
        expect(
          tester.getSize(find.byType(Img2ImgSourcePreview)),
          Size(width, 240),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('unavailable image remains readable in $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            body: OnlineGalleryImagePlaceholder(failed: true),
          ),
        ),
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.image_not_supported_outlined),
      );
      final background = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(OnlineGalleryImagePlaceholder),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(background.color, ImageViewportSurface.background);
      final contrast =
          (icon.color!.computeLuminance() + 0.05) /
          (background.color.computeLuminance() + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('explicit transparency backdrop stays above the surround', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ImageViewportSurface(
            child: Stack(
              fit: StackFit.expand,
              children: [TransparencyBackgroundLayer(style: '#ffffff')],
            ),
          ),
        ),
      ),
    );
    final backdrop = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(TransparencyBackgroundLayer),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(backdrop.color, Colors.white);
    expect(find.byType(ImageViewportSurface), findsOneWidget);
  });
}
