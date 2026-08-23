import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_hover_preview.dart';

void main() {
  testWidgets(
    'shows compact full-file preview inside viewport and dismisses it',
    (tester) async {
      final record = LocalImageRecord(
        path: 'assets/icons/tray_icon.png',
        size: 2048,
        modifiedAt: DateTime(2026, 8, 23),
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
      expect(find.text('tray_icon.png'), findsOneWidget);
      expect(find.text('1024×1536'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.text('2026-08-23'), findsOneWidget);
      expect(find.text('123456'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);

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
