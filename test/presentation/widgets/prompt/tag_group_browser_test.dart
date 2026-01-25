import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_group_browser.dart';

void main() {
  group('TagGroupBrowser Widget', () {
    testWidgets('should build without errors', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagGroupBrowser(
                onTagsChanged: _onTagsChanged,
                selectedTags: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Widget should render
      expect(find.byType(TagGroupBrowser), findsOneWidget);
    });

    testWidgets('should render search bar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagGroupBrowser(
                onTagsChanged: _onTagsChanged,
                selectedTags: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have search field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should respect readOnly mode', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagGroupBrowser(
                onTagsChanged: _onTagsChanged,
                selectedTags: [],
                readOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagGroupBrowser), findsOneWidget);
    });

    testWidgets('should handle selected tags', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagGroupBrowser(
                onTagsChanged: _onTagsChanged,
                selectedTags: ['red hair', 'blue eyes'],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagGroupBrowser), findsOneWidget);
    });

    testWidgets('should handle search input', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagGroupBrowser(
                onTagsChanged: _onTagsChanged,
                selectedTags: [],
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
  });
}

void _onTagsChanged(List<String> tags) {}
