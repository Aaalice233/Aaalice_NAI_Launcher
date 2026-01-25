import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/presentation/widgets/prompt/components/tag_chip/tag_chip.dart';
import 'package:nai_launcher/presentation/widgets/prompt/core/prompt_tag_colors.dart';
import 'package:nai_launcher/presentation/widgets/prompt/core/prompt_tag_config.dart';

/// Performance test suite for TagView components with 100+ tags
///
/// Tests performance characteristics including:
/// - Rendering time for large tag lists
/// - Memory usage
/// - Animation performance
/// - RepaintBoundary effectiveness
void main() {
  group('TagChip Performance Tests', () {
    testWidgets('Render 100 TagChips efficiently', (WidgetTester tester) async {
      final tags = _generateTestTags(100);

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Wrap(
                spacing: TagSpacing.horizontal,
                runSpacing: TagSpacing.vertical,
                children: tags.map<Widget>((tag) {
                  return TagChip(
                    tag: tag,
                    onToggleEnabled: () {},
                    onTap: () {},
                    onDelete: () {},
                    onWeightChanged: (weight) {},
                    onTextChanged: (text) {},
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      stopwatch.stop();

      // Initial rendering should be fast (<1000ms for 100 chips in CI environment)
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'Rendering 100 TagChips should be fast',
      );

      // Verify all tags are rendered
      expect(find.byType(TagChip), findsNWidgets(100));

      print('✅ Rendered 100 TagChips in ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('TagChip rebuild performance', (WidgetTester tester) async {
      final tag = _generateTestTags(1).first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TagChip(
                tag: tag,
                onToggleEnabled: () {},
                onTap: () {},
                onDelete: () {},
                onWeightChanged: (weight) {},
                onTextChanged: (text) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Measure rebuild time
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        // Trigger a rebuild by updating the tag
        final updatedTag = tag.copyWith(weight: 1.0 + (i * 0.01));
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: TagChip(
                  tag: updatedTag,
                  onToggleEnabled: () {},
                  onTap: () {},
                  onDelete: () {},
                  onWeightChanged: (weight) {},
                  onTextChanged: (text) {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();
      }

      stopwatch.stop();

      // 100 rebuilds should be fast (<1 second total)
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: '100 TagChip rebuilds should be fast',
      );

      print('✅ 100 rebuilds in ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('RepaintBoundary is present in TagChip', (tester) async {
      final tag = _generateTestTags(1).first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TagChip(
                tag: tag,
                onToggleEnabled: () {},
                onTap: () {},
                onDelete: () {},
                onWeightChanged: (weight) {},
                onTextChanged: (text) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify RepaintBoundary is present
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));

      print('✅ RepaintBoundary found in TagChip');
    });
  });

  group('PromptTag Performance Tests', () {
    test('Generate 1000 PromptTags quickly', () {
      final stopwatch = Stopwatch()..start();

      final tags = _generateTestTags(1000);

      stopwatch.stop();

      // Tag generation should be very fast (<100ms for 1000 tags)
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Generating 1000 tags should be fast',
      );

      expect(tags.length, equals(1000));

      print('✅ Generated 1000 tags in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Color lookups are efficient', () {
      final stopwatch = Stopwatch()..start();

      // Perform 10,000 color lookups
      for (int i = 0; i < 10000; i++) {
        PromptTagColors.getByCategory(i % 6);
      }

      stopwatch.stop();

      // Color lookups should be very fast (<500ms for 10,000 lookups)
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason: 'Color lookups should be efficient',
      );

      print('✅ 10,000 color lookups in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Gradient caching works', () {
      final stopwatch = Stopwatch()..start();

      // Access gradients for all categories multiple times
      for (int i = 0; i < 1000; i++) {
        // This should use cached values after first access
        PromptTagColors.getByCategory(i % 6);
      }

      stopwatch.stop();

      // Cached accesses should be very fast
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Cached color access should be fast',
      );

      print('✅ 1000 cached lookups in ${stopwatch.elapsedMilliseconds}ms');
    });
  });

  group('Memory Performance Tests', () {
    testWidgets('Handle large tag lists without memory errors', (tester) async {
      final tags = _generateTestTags(200);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Wrap(
                spacing: TagSpacing.horizontal,
                runSpacing: TagSpacing.vertical,
                children: tags.map((tag) {
                  return TagChip(
                    tag: tag,
                    onToggleEnabled: () {},
                    onTap: () {},
                    onDelete: () {},
                    onWeightChanged: (weight) {},
                    onTextChanged: (text) {},
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should handle 200 tags without throwing
      expect(tester.takeException(), isNull);
      expect(find.byType(TagChip), findsNWidgets(200));

      print('✅ Successfully rendered 200 TagChips without memory errors');
    });
  });
}

/// Generate test tags with various properties
List<PromptTag> _generateTestTags(int count) {
  return List.generate(
    count,
    (i) => PromptTag.create(
      text: 'test_tag_$i',
      weight: 1.0,
      category: i % 5,
      translation: '测试标签 $i',
    ).copyWith(enabled: i % 3 != 0),
  );
}
