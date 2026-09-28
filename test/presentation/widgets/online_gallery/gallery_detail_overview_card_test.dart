import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_detail_overview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('composes optional badge, content, and metadata', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: GalleryDetailOverviewCard(
              icon: Icons.auto_stories_rounded,
              title: 'Codex title',
              subtitle: 'Parent / Category',
              badge: GalleryDetailOverviewBadgeData(
                icon: Icons.shield_rounded,
                label: 'G',
                tooltip: 'Rating',
              ),
              content: Text('Injected content'),
              metadata: [
                GalleryDetailOverviewMetadata(
                  icon: Icons.image_rounded,
                  label: 'Original',
                  value: 'image.png',
                ),
                GalleryDetailOverviewMetadata(
                  icon: Icons.person_rounded,
                  value: 'Contributor · author',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Codex title'), findsOneWidget);
    expect(find.text('Parent / Category'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.byTooltip('Rating'), findsOneWidget);
    expect(find.text('Injected content'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('image.png'), findsOneWidget);
    expect(find.text('Contributor · author'), findsOneWidget);
  });

  testWidgets('keeps long content usable at narrow widths', (tester) async {
    tester.view.physicalSize = const Size(280, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GalleryDetailOverviewCard(
            icon: Icons.auto_stories_rounded,
            title: 'A long codex title that must not push the badge away',
            subtitle: 'Parent / Nested category / Final category',
            badge: GalleryDetailOverviewBadgeData(
              icon: Icons.shield_rounded,
              label: 'G',
              tooltip: 'Rating',
            ),
            metadata: [
              GalleryDetailOverviewMetadata(
                icon: Icons.image_rounded,
                label: 'Original file',
                value: 'a-very-long-image-file-name.png',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('G'), findsOneWidget);
    expect(find.text('a-very-long-image-file-name.png'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('omits optional regions without reserving placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GalleryDetailOverviewCard(
            icon: Icons.info_rounded,
            title: 'Only title',
          ),
        ),
      ),
    );

    expect(find.text('Only title'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);
  });
}
