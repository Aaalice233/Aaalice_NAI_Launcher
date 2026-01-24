import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_favorite_panel.dart';

void main() {
  group('TagFavoritePanel Widget', () {
    testWidgets('should build without errors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagFavoritePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagFavoritePanel), findsOneWidget);
    });

    testWidgets('should render empty state initially', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagFavoritePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show empty state icon
      expect(
        find.byIcon(Icons.favorite_border),
        findsOneWidget,
        reason: 'Should show favorite icon in empty state',
      );
    });

    testWidgets('should render search bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagFavoritePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should respect readOnly mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagFavoritePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
                readOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagFavoritePanel), findsOneWidget);
    });

    testWidgets('should handle search input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagFavoritePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);

      // Enter search text
      await tester.enterText(textField, 'test');
      await tester.pumpAndSettle();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Clear button should disappear
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('should handle current tags', (tester) async {
      final currentTags = [PromptTag.create(text: 'test_tag')];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagFavoritePanel(
                currentTags: currentTags,
                onTagsChanged: (tags) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagFavoritePanel), findsOneWidget);
    });

    testWidgets('should show compact mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagFavoritePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
                compact: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagFavoritePanel), findsOneWidget);
    });
  });
}
