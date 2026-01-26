import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';
import 'package:nai_launcher/presentation/widgets/local_image_card.dart';

void main() {
  group('Local Gallery Selection State Flow Integration Tests', () {
    setUpAll(() async {
      // Initialize Hive for testing
      Hive.init('./test_hive_integration_selection');
      await Hive.openBox(StorageKeys.localFavoritesBox);
      await Hive.openBox(StorageKeys.tagsBox);
    });

    tearDownAll(() async {
      await Hive.close();
    });

    testWidgets('Enter selection mode and toggle single item', (tester) async {
      final container = ProviderContainer();
      final imageRecord = LocalImageRecord(
        path: '/test/image1.png',
        modifiedAt: DateTime.now(),
        size: 1024,
      );

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final selectionMode = ref.watch(
                    localGallerySelectionNotifierProvider
                        .select((state) => state.isActive),
                  );
                  final isSelected = ref.watch(
                    localGallerySelectionNotifierProvider.select(
                      (state) => state.selectedIds.contains(imageRecord.path),
                    ),
                  );
                  return LocalImageCard(
                    record: imageRecord,
                    itemWidth: 200,
                    aspectRatio: 1.0,
                    selectionMode: selectionMode,
                    isSelected: isSelected,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Find the card
      expect(find.byType(LocalImageCard), findsOneWidget);

      // Initial state - not in selection mode
      var selectionState = container.read(localGallerySelectionNotifierProvider);
      expect(selectionState.isActive, isFalse);
      expect(selectionState.selectedIds, isEmpty);

      // Programmatically enter selection mode and select item (testing provider flow)
      final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
      notifier.enterAndSelect(imageRecord.path);
      await tester.pumpAndSettle();

      // Verify selection mode is active and item is selected
      selectionState = container.read(localGallerySelectionNotifierProvider);
      expect(
        selectionState.isActive,
        isTrue,
        reason: 'Should be in selection mode',
      );
      expect(
        selectionState.selectedIds.contains(imageRecord.path),
        isTrue,
        reason: 'Image should be selected',
      );
      expect(selectionState.lastSelectedId, imageRecord.path);
    });

    testWidgets('Toggle multiple items in sequence', (tester) async {
      final container = ProviderContainer();
      final image1 = LocalImageRecord(
        path: '/test/image1.png',
        modifiedAt: DateTime.now(),
        size: 1024,
      );
      final image2 = LocalImageRecord(
        path: '/test/image2.png',
        modifiedAt: DateTime.now(),
        size: 1024,
      );
      final image3 = LocalImageRecord(
        path: '/test/image3.png',
        modifiedAt: DateTime.now(),
        size: 1024,
      );

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      final selectionMode = ref.watch(
                        localGallerySelectionNotifierProvider
                            .select((state) => state.isActive),
                      );
                      final isSelected = ref.watch(
                        localGallerySelectionNotifierProvider.select(
                          (state) => state.selectedIds.contains(image1.path),
                        ),
                      );
                      return LocalImageCard(
                        key: const Key('image1'),
                        record: image1,
                        itemWidth: 200,
                        aspectRatio: 1.0,
                        selectionMode: selectionMode,
                        isSelected: isSelected,
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final selectionMode = ref.watch(
                        localGallerySelectionNotifierProvider
                            .select((state) => state.isActive),
                      );
                      final isSelected = ref.watch(
                        localGallerySelectionNotifierProvider.select(
                          (state) => state.selectedIds.contains(image2.path),
                        ),
                      );
                      return LocalImageCard(
                        key: const Key('image2'),
                        record: image2,
                        itemWidth: 200,
                        aspectRatio: 1.0,
                        selectionMode: selectionMode,
                        isSelected: isSelected,
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final selectionMode = ref.watch(
                        localGallerySelectionNotifierProvider
                            .select((state) => state.isActive),
                      );
                      final isSelected = ref.watch(
                        localGallerySelectionNotifierProvider.select(
                          (state) => state.selectedIds.contains(image3.path),
                        ),
                      );
                      return LocalImageCard(
                        key: const Key('image3'),
                        record: image3,
                        itemWidth: 200,
                        aspectRatio: 1.0,
                        selectionMode: selectionMode,
                        isSelected: isSelected,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter selection mode
      final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
      notifier.enter();
      await tester.pumpAndSettle();

      // Toggle first image
      notifier.toggle(image1.path);
      await tester.pumpAndSettle();

      var selectionState = container.read(localGallerySelectionNotifierProvider);
      expect(selectionState.selectedIds.length, 1);
      expect(selectionState.selectedIds.contains(image1.path), isTrue);

      // Toggle second image
      notifier.toggle(image2.path);
      await tester.pumpAndSettle();

      selectionState = container.read(localGallerySelectionNotifierProvider);
      expect(selectionState.selectedIds.length, 2);
      expect(selectionState.selectedIds.contains(image2.path), isTrue);

      // Toggle third image
      notifier.toggle(image3.path);
      await tester.pumpAndSettle();

      selectionState = container.read(localGallerySelectionNotifierProvider);
      expect(selectionState.selectedIds.length, 3);
      expect(selectionState.selectedIds.contains(image3.path), isTrue);
    });

    testWidgets('Perform range selection (Shift+click)', (tester) async {
      final container = ProviderContainer();
      final allIds = [
        '/test/image1.png',
        '/test/image2.png',
        '/test/image3.png',
        '/test/image4.png',
        '/test/image5.png',
      ];

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final selectionMode = ref.watch(
                    localGallerySelectionNotifierProvider
                        .select((state) => state.isActive),
                  );
                  final selectedCount = ref.watch(
                    localGallerySelectionNotifierProvider
                        .select((s) => s.selectedIds.length),
                  );
                  return Center(
                    child: Text(
                      'Selection Mode: $selectionMode, Count: $selectedCount',
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter selection mode
      final selectionNotifier =
          container.read(localGallerySelectionNotifierProvider.notifier);
      selectionNotifier.enter();
      await tester.pumpAndSettle();

      // Select first item
      selectionNotifier.select(allIds[0]);
      await tester.pumpAndSettle();

      var state = container.read(localGallerySelectionNotifierProvider);
      expect(state.selectedIds.length, 1);
      expect(state.lastSelectedId, allIds[0]);

      // Perform range selection from index 0 to index 3
      selectionNotifier.selectRange(allIds[3], allIds);
      await tester.pumpAndSettle();

      state = container.read(localGallerySelectionNotifierProvider);
      expect(
        state.selectedIds.length,
        4,
        reason: 'Should select 4 items (0-3)',
      );
      expect(state.selectedIds.contains(allIds[0]), isTrue);
      expect(state.selectedIds.contains(allIds[1]), isTrue);
      expect(state.selectedIds.contains(allIds[2]), isTrue);
      expect(state.selectedIds.contains(allIds[3]), isTrue);
      expect(
        state.selectedIds.contains(allIds[4]),
        isFalse,
        reason: 'Last item should not be selected',
      );
    });

    testWidgets('Select all items in current page', (tester) async {
      final container = ProviderContainer();
      final ids = List.generate(10, (index) => '/test/image$index.png');

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(localGallerySelectionNotifierProvider);
                  return Center(
                    child: Text('Selected: ${state.selectedIds.length}/${ids.length}'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter selection mode
      final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
      notifier.enter();
      await tester.pumpAndSettle();

      // Select all
      notifier.selectAll(ids);
      await tester.pumpAndSettle();

      final state = container.read(localGallerySelectionNotifierProvider);
      expect(state.selectedIds.length, ids.length);
      for (final id in ids) {
        expect(state.selectedIds.contains(id), isTrue);
      }
    });

    testWidgets('Clear selection', (tester) async {
      final container = ProviderContainer();
      final ids = List.generate(5, (index) => '/test/image$index.png');

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(localGallerySelectionNotifierProvider);
                  return Center(
                    child: Text('Selected: ${state.selectedIds.length}'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter selection mode and select items
      final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
      notifier.enter();
      notifier.selectAll(ids);
      await tester.pumpAndSettle();

      var state = container.read(localGallerySelectionNotifierProvider);
      expect(state.selectedIds.length, 5);

      // Clear selection
      notifier.clearSelection();
      await tester.pumpAndSettle();

      state = container.read(localGallerySelectionNotifierProvider);
      expect(state.selectedIds.length, 0);
      expect(state.lastSelectedId, isNull);
    });

    testWidgets('Exit selection mode', (tester) async {
      final container = ProviderContainer();
      final imageRecord = LocalImageRecord(
        path: '/test/image1.png',
        modifiedAt: DateTime.now(),
        size: 1024,
      );

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final selectionMode = ref.watch(
                    localGallerySelectionNotifierProvider
                        .select((state) => state.isActive),
                  );
                  final isSelected = ref.watch(
                    localGallerySelectionNotifierProvider.select(
                      (state) => state.selectedIds.contains(imageRecord.path),
                    ),
                  );
                  return LocalImageCard(
                    record: imageRecord,
                    itemWidth: 200,
                    aspectRatio: 1.0,
                    selectionMode: selectionMode,
                    isSelected: isSelected,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Enter selection mode and select item
      final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
      notifier.enterAndSelect(imageRecord.path);
      await tester.pumpAndSettle();

      var state = container.read(localGallerySelectionNotifierProvider);
      expect(state.isActive, isTrue);
      expect(state.selectedIds, isNotEmpty);

      // Exit selection mode
      notifier.exit();
      await tester.pumpAndSettle();

      state = container.read(localGallerySelectionNotifierProvider);
      expect(state.isActive, isFalse);
      expect(state.selectedIds, isEmpty);
      expect(state.lastSelectedId, isNull);
    });

    testWidgets('Only affected cards rebuild on selection change', (tester) async {
      final container = ProviderContainer();
      final image1 = LocalImageRecord(
        path: '/test/image1.png',
        modifiedAt: DateTime.now(),
        size: 1024,
      );
      final image2 = LocalImageRecord(
        path: '/test/image2.png',
        modifiedAt: DateTime.now(),
        size: 1024,
      );

      int buildCount1 = 0;
      int buildCount2 = 0;

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  _TestImageCard(
                    key: const Key('card1'),
                    record: image1,
                    onBuild: () => buildCount1++,
                  ),
                  _TestImageCard(
                    key: const Key('card2'),
                    record: image2,
                    onBuild: () => buildCount2++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Initial pump to trigger first build
      await tester.pump();
      expect(buildCount1, equals(1), reason: 'Card 1 should build once initially');
      expect(buildCount2, equals(1), reason: 'Card 2 should build once initially');

      // Enter selection mode
      final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
      notifier.enter();
      await tester.pump();

      // Both cards should rebuild because selectionMode changed
      expect(buildCount1, equals(2),
          reason: 'Card 1 should rebuild when selection mode changes');
      expect(buildCount2, equals(2),
          reason: 'Card 2 should rebuild when selection mode changes');

      final beforeToggleBuildCount1 = buildCount1;
      final beforeToggleBuildCount2 = buildCount2;

      // Toggle only image1
      notifier.toggle(image1.path);
      await tester.pump();

      // Only card 1 should rebuild because only its selection state changed
      expect(
        buildCount1,
        equals(beforeToggleBuildCount1 + 1),
        reason: 'Card 1 should rebuild when its selection changes',
      );
      expect(
        buildCount2,
        equals(beforeToggleBuildCount2),
        reason: 'Card 2 should NOT rebuild when other card selection changes',
      );
    });

    testWidgets('Selection state updates correctly with rapid toggles',
        (tester) async {
      final container = ProviderContainer();
      final imageId = '/test/image1.png';

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final isSelected = ref.watch(
                    localGallerySelectionNotifierProvider.select(
                      (state) => state.selectedIds.contains(imageId),
                    ),
                  );
                  return Center(
                    child: Text('Selected: $isSelected'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
      notifier.enter();

      // Rapid toggles
      for (var i = 0; i < 10; i++) {
        notifier.toggle(imageId);
        await tester.pump();

        final state = container.read(localGallerySelectionNotifierProvider);

        // State should alternate between selected and not selected
        final expectedSelected = i % 2 == 0;
        expect(
          state.selectedIds.contains(imageId),
          expectedSelected,
          reason: 'Toggle $i: Should be $expectedSelected',
        );
      }

      await tester.pumpAndSettle();
    });
  });
}

/// Test widget that tracks build count
class _TestImageCard extends StatelessWidget {
  final LocalImageRecord record;
  final VoidCallback onBuild;

  const _TestImageCard({
    super.key,
    required this.record,
    required this.onBuild,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // Call onBuild to track Consumer rebuilds
        onBuild();

        // Watch isActive separately to trigger rebuild when selection mode changes
        final isActive = ref.watch(
          localGallerySelectionNotifierProvider.select((state) => state.isActive),
        );
        // Watch isSelected separately to trigger rebuild only when this card's selection changes
        final isSelected = ref.watch(
          localGallerySelectionNotifierProvider.select(
            (state) => state.selectedIds.contains(record.path),
          ),
        );

        return Container(
          width: 100,
          height: 100,
          color: isSelected ? Colors.blue : Colors.grey,
          child: Text('${record.path}\nActive: $isActive'),
        );
      },
    );
  }
}
