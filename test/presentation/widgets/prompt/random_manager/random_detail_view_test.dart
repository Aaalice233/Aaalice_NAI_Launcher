import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/random_detail_view.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/random_library_manager_state.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/tag_scope.dart';

void main() {
  group('RandomDetailView', () {
    testWidgets('should show no selection placeholder when nothing selected', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RandomDetailView(),
            ),
          ),
        ),
      );

      expect(find.text('Select a node to edit'), findsOneWidget);
      expect(find.text('Click on a preset, category, or tag group'), findsOneWidget);
    });

    testWidgets('should show preset info when preset selected', (tester) async {
      const presetNode = PresetNode('preset1', 'Test Preset');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  // Select the preset
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(selectedNodeProvider.notifier).state = presetNode;
                  });
                  return const RandomDetailView();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Test Preset'), findsOneWidget);
      expect(find.text('Select a category to edit'), findsOneWidget);
    });
  });

  group('RandomDetailView - Source Selector', () {
    testWidgets('should show source selector for category', (tester) async {
      final categoryNode = CategoryNode(
        'preset1',
        const RandomCategory(
          id: 'cat1',
          name: 'Pose',
          key: 'pose',
          groupSelectionMode: SelectionMode.single,
          probability: 1.0,
          shuffle: false,
          scope: TagScope.all,
          genderRestrictionEnabled: false,
          applicableGenders: [],
          unifiedBracketMin: 1,
          unifiedBracketMax: 1,
          groups: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(selectedNodeProvider.notifier).state = categoryNode;
                  });
                  return const RandomDetailView();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Source'), findsOneWidget);
    });

    testWidgets('should show source selector for tag group', (tester) async {
      final tagGroupNode = TagGroupNode(
        'preset1',
        'cat1',
        const RandomTagGroup(
          id: 'tg1',
          name: 'Standing',
          selectionMode: SelectionMode.single,
          probability: 1.0,
          multipleNum: 1,
          shuffle: false,
          bracketMin: 1,
          bracketMax: 1,
          scope: TagScope.all,
          genderRestrictionEnabled: false,
          applicableGenders: [],
          children: [],
          sourceType: TagGroupSourceType.custom,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(selectedNodeProvider.notifier).state = tagGroupNode;
                  });
                  return const RandomDetailView();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Source'), findsOneWidget);
    });
  });

  group('RandomDetailView - Variable Helper', () {
    testWidgets('should display variable helper section', (tester) async {
      final categoryNode = CategoryNode(
        'preset1',
        const RandomCategory(
          id: 'cat1',
          name: 'Pose',
          key: 'pose',
          groupSelectionMode: SelectionMode.single,
          probability: 1.0,
          shuffle: false,
          scope: TagScope.all,
          genderRestrictionEnabled: false,
          applicableGenders: [],
          unifiedBracketMin: 1,
          unifiedBracketMax: 1,
          groups: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(selectedNodeProvider.notifier).state = categoryNode;
                  });
                  return const RandomDetailView();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Variables'), findsOneWidget);
      expect(find.text('Click to insert __variable__'), findsOneWidget);
    });
  });
}
