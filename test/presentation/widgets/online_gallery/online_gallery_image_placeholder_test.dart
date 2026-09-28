import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/online_gallery_image_placeholder.dart';

void main() {
  testWidgets('loading placeholder stays empty and fills its reserved space', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 180,
            height: 120,
            child: OnlineGalleryImagePlaceholder(),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    expect(
      tester.getSize(find.byType(OnlineGalleryImagePlaceholder)),
      const Size(180, 120),
    );
  });

  testWidgets('failed image keeps the same low-contrast placeholder geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 180,
            height: 120,
            child: OnlineGalleryImagePlaceholder(failed: true),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(
      tester.getSize(find.byType(OnlineGalleryImagePlaceholder)),
      const Size(180, 120),
    );
  });

  testWidgets('loading placeholder exposes a lightweight loading affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 180,
          height: 120,
          child: OnlineGalleryImagePlaceholder(loading: true),
        ),
      ),
    );

    expect(find.byIcon(Icons.downloading_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
