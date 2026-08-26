import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_detail_text_section.dart';

void main() {
  testWidgets('renders a compact selectable tonal section', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GalleryDetailTextSection(
            title: 'Negative prompt',
            content: 'lowres, blurry',
            accentColor: Colors.red,
          ),
        ),
      ),
    );

    expect(find.text('Negative prompt'), findsOneWidget);
    expect(find.text('lowres, blurry'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
  });
}
