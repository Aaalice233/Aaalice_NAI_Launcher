import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/local_gallery_thumbnail_provider.dart';
import 'package:nai_launcher/core/utils/byte_format.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/presentation/widgets/common/image_hover_preview.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_hover_preview.dart';

void main() {
  testWidgets(
    'shows compact full-file preview inside viewport and dismisses it',
    (tester) async {
      final imageFile = File('assets/icons/tray_icon.png');
      final imageStat = (await tester.runAsync(imageFile.stat))!;
      final record = LocalImageRecord(
        path: imageFile.path,
        size: imageStat.size,
        modifiedAt: imageStat.modified,
        metadata: const NaiImageMetadata(
          width: 1024,
          height: 1536,
          model: 'nai-diffusion-4-5-full',
          seed: 123456,
          steps: 28,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: LocalImageHoverPreview(
                record: record,
                hoverDelay: Duration.zero,
                child: const SizedBox(
                  key: ValueKey('hover-target'),
                  width: 120,
                  height: 160,
                ),
              ),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(20, 20));
      await tester.pump();
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('hover-target'))),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      final preview = find.byKey(const ValueKey('local-gallery-hover-preview'));
      expect(preview, findsOneWidget);
      expect(find.byType(ImageHoverPreviewSurface), findsOneWidget);
      expect(find.text('tray_icon.png'), findsOneWidget);
      expect(find.text('1024×1536'), findsOneWidget);
      final modifiedDate =
          '${imageStat.modified.year.toString().padLeft(4, '0')}-'
          '${imageStat.modified.month.toString().padLeft(2, '0')}-'
          '${imageStat.modified.day.toString().padLeft(2, '0')}';
      expect(find.text(formatBytes(imageStat.size)), findsOneWidget);
      expect(find.text(modifiedDate), findsOneWidget);
      final previewImage = tester.widget<Image>(
        find.descendant(
          of: preview,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is LocalGalleryThumbnailProvider,
          ),
        ),
      );
      expect(previewImage.image, isA<LocalGalleryThumbnailProvider>());
      expect(find.text('nai-diffusion-4-5-full'), findsOneWidget);
      expect(find.text('123456'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect({
        tester.getCenter(find.text('1024×1536')).dy,
        tester.getCenter(find.text(formatBytes(imageStat.size))).dy,
        tester.getCenter(find.text(modifiedDate)).dy,
      }, hasLength(1));
      expect({
        tester.getCenter(find.text('nai-diffusion-4-5-full')).dy,
        tester.getCenter(find.text('123456')).dy,
        tester.getCenter(find.text('28')).dy,
      }, hasLength(1));

      final previewRect = tester.getRect(preview);
      expect(previewRect.left, greaterThanOrEqualTo(10));
      expect(previewRect.top, greaterThanOrEqualTo(10));
      expect(previewRect.right, lessThanOrEqualTo(790));
      expect(previewRect.bottom, lessThanOrEqualTo(590));

      await mouse.moveTo(const Offset(20, 20));
      await tester.pump();
      expect(preview, findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
