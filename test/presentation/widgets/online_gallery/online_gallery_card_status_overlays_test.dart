import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/online_gallery_card_status_overlays.dart';

void main() {
  testWidgets('model and media count use separate badges', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnlineGalleryCardStatusOverlays(
            favoriteReadOnly: false,
            favoriteReadOnlyTooltip: 'Favorite',
            mediaCount: 3,
            badgeLabel: 'NAI V5 Full',
            badgeUsesModelColor: true,
          ),
        ),
      ),
    );

    final modelBadge = find.byKey(
      const ValueKey('online-gallery-card-source-badge'),
    );
    final countBadge = find.byKey(
      const ValueKey('online-gallery-card-media-count-badge'),
    );
    expect(modelBadge, findsOneWidget);
    expect(countBadge, findsOneWidget);
    expect(
      find.descendant(of: modelBadge, matching: find.text('3')),
      findsNothing,
    );
    expect(
      find.descendant(of: countBadge, matching: find.text('3')),
      findsOneWidget,
    );

    final decoration = tester.widget<Container>(modelBadge).decoration;
    expect(decoration, isA<BoxDecoration>());
    expect((decoration! as BoxDecoration).color, const Color(0xFF9F1239));
  });
}
