import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_template_panel.dart';

void main() {
  group('TagTemplatePanel Widget', () {
    testWidgets('should build without errors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagTemplatePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
                selectedTags: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagTemplatePanel), findsOneWidget);
    });

    testWidgets('should render empty state initially', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagTemplatePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
                selectedTags: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show empty state icon
      expect(
        find.byIcon(Icons.bookmark_border),
        findsOneWidget,
        reason: 'Should show bookmark icon in empty state',
      );
    });

    testWidgets('should show add button when not readOnly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagTemplatePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
                selectedTags: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show add button
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should not show add button in readOnly mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagTemplatePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
                selectedTags: [],
                readOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should not show add button
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('should handle selected tags', (tester) async {
      final selectedTags = [PromptTag.create(text: 'tag1')];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagTemplatePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
                selectedTags: selectedTags,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagTemplatePanel), findsOneWidget);
    });

    testWidgets('should handle current tags', (tester) async {
      final currentTags = [PromptTag.create(text: 'tag1')];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagTemplatePanel(
                currentTags: currentTags,
                onTagsChanged: (tags) {},
                selectedTags: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagTemplatePanel), findsOneWidget);
    });

    testWidgets('should show compact mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagTemplatePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
                selectedTags: [],
                compact: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagTemplatePanel), findsOneWidget);
    });

    testWidgets('should show header with icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [],
            home: Scaffold(
              body: TagTemplatePanel(
                currentTags: [],
                onTagsChanged: (tags) {},
                selectedTags: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show bookmark icon in header
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });
  });
}
