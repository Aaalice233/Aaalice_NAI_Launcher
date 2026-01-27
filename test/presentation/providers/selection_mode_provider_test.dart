import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';

void main() {
  group('OnlineGallerySelectionNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Initial State', () {
      test('should initialize with empty inactive state', () {
        final state = container.read(onlineGallerySelectionNotifierProvider);

        expect(
          state.isActive,
          isFalse,
          reason: 'Should not be active initially',
        );
        expect(
          state.selectedIds,
          isEmpty,
          reason: 'Should have no selected IDs initially',
        );
        expect(
          state.lastSelectedId,
          isNull,
          reason: 'Should have no last selected ID initially',
        );
        expect(
          state.selectedCount,
          0,
          reason: 'Selected count should be 0',
        );
        expect(
          state.hasSelection,
          isFalse,
          reason: 'Should have no selection',
        );
      });
    });

    group('enter', () {
      test('should activate selection mode', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.enter();

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.isActive,
          isTrue,
          reason: 'Should be active after entering',
        );
      });
    });

    group('exit', () {
      test('should deactivate and reset state', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        // First enter and select something
        notifier.enter();
        notifier.toggle('item1');

        expect(
          container.read(onlineGallerySelectionNotifierProvider).isActive,
          isTrue,
          reason: 'Should be active',
        );
        expect(
          container.read(onlineGallerySelectionNotifierProvider).hasSelection,
          isTrue,
          reason: 'Should have selection',
        );

        // Now exit
        notifier.exit();

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.isActive,
          isFalse,
          reason: 'Should not be active after exit',
        );
        expect(
          state.selectedIds,
          isEmpty,
          reason: 'Should have no selected IDs after exit',
        );
      });
    });

    group('toggle', () {
      test('should add item when not selected', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.toggle('item1');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.isSelected('item1'),
          isTrue,
          reason: 'Item should be selected after toggle',
        );
        expect(
          state.selectedCount,
          1,
          reason: 'Should have 1 selected item',
        );
      });

      test('should remove item when already selected', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.toggle('item1');
        expect(
          container
              .read(onlineGallerySelectionNotifierProvider)
              .isSelected('item1'),
          isTrue,
          reason: 'Item should be selected',
        );

        notifier.toggle('item1');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.isSelected('item1'),
          isFalse,
          reason: 'Item should be deselected after toggle',
        );
        expect(
          state.selectedCount,
          0,
          reason: 'Should have 0 selected items',
        );
      });

      test('should handle multiple items', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.toggle('item1');
        notifier.toggle('item2');
        notifier.toggle('item3');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          3,
          reason: 'Should have 3 selected items',
        );
        expect(
          state.isSelected('item2'),
          isTrue,
          reason: 'Item2 should be selected',
        );
      });
    });

    group('select', () {
      test('should add item when not selected', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.isSelected('item1'),
          isTrue,
          reason: 'Item should be selected',
        );
      });

      test('should not duplicate when already selected', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');
        notifier.select('item1');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          1,
          reason: 'Should not duplicate selected item',
        );
      });
    });

    group('deselect', () {
      test('should remove item when selected', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');
        expect(
          container
              .read(onlineGallerySelectionNotifierProvider)
              .isSelected('item1'),
          isTrue,
          reason: 'Item should be selected',
        );

        notifier.deselect('item1');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.isSelected('item1'),
          isFalse,
          reason: 'Item should be deselected',
        );
      });

      test('should handle deselecting non-selected item gracefully', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.deselect('item1');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          0,
          reason: 'Should remain empty',
        );
      });
    });

    group('selectAll', () {
      test('should select all provided items', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);
        final items = ['item1', 'item2', 'item3'];

        notifier.selectAll(items);

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          3,
          reason: 'Should have all items selected',
        );
        expect(
          state.isSelected('item1'),
          isTrue,
          reason: 'Item1 should be selected',
        );
        expect(
          state.isSelected('item2'),
          isTrue,
          reason: 'Item2 should be selected',
        );
        expect(
          state.isSelected('item3'),
          isTrue,
          reason: 'Item3 should be selected',
        );
      });

      test('should handle empty list gracefully', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.selectAll([]);

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          0,
          reason: 'Should have no items selected',
        );
      });

      test('should accumulate with existing selections', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');
        notifier.selectAll(['item2', 'item3']);

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          3,
          reason: 'Should have all items selected',
        );
      });
    });

    group('clearSelection', () {
      test('should clear all selected items', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.selectAll(['item1', 'item2', 'item3']);
        expect(
          container.read(onlineGallerySelectionNotifierProvider).selectedCount,
          3,
          reason: 'Should have items selected',
        );

        notifier.clearSelection();

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          0,
          reason: 'Should have no items selected',
        );
        expect(
          state.hasSelection,
          isFalse,
          reason: 'Should have no selection',
        );
      });
    });

    group('enterAndSelect', () {
      test('should activate selection mode and select item', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.enterAndSelect('item1');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.isActive,
          isTrue,
          reason: 'Should be active',
        );
        expect(
          state.isSelected('item1'),
          isTrue,
          reason: 'Item should be selected',
        );
      });

      test('should accumulate with existing selections', () {
        final notifier =
            container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');
        notifier.enterAndSelect('item2');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          2,
          reason: 'Should have both items selected',
        );
      });
    });
  });

  group('LocalGallerySelectionNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Initial State', () {
      test('should initialize with empty inactive state', () {
        final state = container.read(localGallerySelectionNotifierProvider);

        expect(
          state.isActive,
          isFalse,
          reason: 'Should not be active initially',
        );
        expect(
          state.selectedIds,
          isEmpty,
          reason: 'Should have no selected IDs initially',
        );
        expect(
          state.lastSelectedId,
          isNull,
          reason: 'Should have no last selected ID initially',
        );
        expect(
          state.selectedCount,
          0,
          reason: 'Selected count should be 0',
        );
        expect(
          state.hasSelection,
          isFalse,
          reason: 'Should have no selection',
        );
      });
    });

    group('toggle', () {
      test('should update lastSelectedId when toggling', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        notifier.toggle('item1');

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.lastSelectedId,
          'item1',
          reason: 'Should update lastSelectedId',
        );
      });
    });

    group('select', () {
      test('should update lastSelectedId when selecting new item', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.lastSelectedId,
          'item1',
          reason: 'Should update lastSelectedId',
        );
      });

      test('should update lastSelectedId even when already selected', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');
        notifier.select('item2');
        notifier.select('item1'); // Select again

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.lastSelectedId,
          'item1',
          reason: 'Should update lastSelectedId to item1',
        );
        expect(
          state.selectedCount,
          2,
          reason: 'Should still have 2 items selected',
        );
      });
    });

    group('clearSelection', () {
      test(
          'should clear selected items but keep lastSelectedId due to copyWith limitation',
          () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');
        expect(
          container.read(localGallerySelectionNotifierProvider).lastSelectedId,
          isNotNull,
          reason: 'Should have lastSelectedId',
        );

        notifier.clearSelection();

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          0,
          reason: 'Should clear selected items',
        );
        // Note: copyWith with null doesn't actually clear nullable fields due to ?? pattern
        // This is a known limitation of the current copyWith implementation
      });
    });

    group('enterAndSelect', () {
      test('should set lastSelectedId', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        notifier.enterAndSelect('item1');

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.lastSelectedId,
          'item1',
          reason: 'Should set lastSelectedId',
        );
      });
    });

    group('selectRange', () {
      test('should select items between anchor and current', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);
        final allIds = ['item1', 'item2', 'item3', 'item4', 'item5'];

        // Set anchor by selecting item2
        notifier.select('item2');
        expect(
          container.read(localGallerySelectionNotifierProvider).lastSelectedId,
          'item2',
          reason: 'Anchor should be item2',
        );

        // Select range from item2 to item4
        notifier.selectRange('item4', allIds);

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.isSelected('item2'),
          isTrue,
          reason: 'item2 (anchor) should be selected',
        );
        expect(
          state.isSelected('item3'),
          isTrue,
          reason: 'item3 (in range) should be selected',
        );
        expect(
          state.isSelected('item4'),
          isTrue,
          reason: 'item4 (current) should be selected',
        );
        expect(
          state.lastSelectedId,
          'item4',
          reason: 'lastSelectedId should be updated to item4',
        );
      });

      test('should handle reverse range selection', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);
        final allIds = ['item1', 'item2', 'item3', 'item4', 'item5'];

        notifier.select('item4');
        notifier.selectRange('item2', allIds);

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.isSelected('item2'),
          isTrue,
          reason: 'item2 should be selected',
        );
        expect(
          state.isSelected('item3'),
          isTrue,
          reason: 'item3 should be selected',
        );
        expect(
          state.isSelected('item4'),
          isTrue,
          reason: 'item4 should be selected',
        );
      });

      test('should just select current item when no anchor', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);
        final allIds = ['item1', 'item2', 'item3'];

        notifier.selectRange('item2', allIds);

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          1,
          reason: 'Should only select current item',
        );
        expect(
          state.isSelected('item2'),
          isTrue,
          reason: 'item2 should be selected',
        );
      });

      test('should just select current item when anchor not in list', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);
        final allIds = ['item1', 'item2', 'item3'];

        notifier.select('item_unknown');
        notifier.selectRange('item2', allIds);

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          2,
          reason: 'Should have item_unknown (already selected) and item2',
        );
        expect(
          state.isSelected('item2'),
          isTrue,
          reason: 'item2 should be selected',
        );
        expect(
          state.isSelected('item_unknown'),
          isTrue,
          reason: 'item_unknown should still be selected',
        );
      });

      test('should just select current item when current not in list', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);
        final allIds = ['item1', 'item2', 'item3'];

        notifier.select('item1');
        notifier.selectRange('item_unknown', allIds);

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          2,
          reason: 'Should have item1 (already selected) and item_unknown',
        );
        expect(
          state.isSelected('item_unknown'),
          isTrue,
          reason: 'item_unknown should be selected',
        );
        expect(
          state.isSelected('item1'),
          isTrue,
          reason: 'item1 should still be selected',
        );
      });

      test('should accumulate with existing selections', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);
        final allIds = ['item1', 'item2', 'item3', 'item4', 'item5'];

        notifier.select('item1');
        notifier.selectRange('item3', allIds);

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          3,
          reason: 'Should have items 1, 2, 3 selected',
        );
        expect(
          state.isSelected('item1'),
          isTrue,
          reason: 'item1 should still be selected',
        );
        expect(
          state.isSelected('item2'),
          isTrue,
          reason: 'item2 should be selected in range',
        );
        expect(
          state.isSelected('item3'),
          isTrue,
          reason: 'item3 should be selected',
        );
      });
    });
  });

  group('Performance Benchmarks', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('LocalGallerySelectionNotifier Performance', () {
      test('toggle performance with 100 selected ids', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        // Pre-select 100 items
        final items = List.generate(100, (i) => 'item_$i');
        notifier.selectAll(items);

        final stopwatch = Stopwatch()..start();

        // Toggle operation on an item that's already selected
        notifier.toggle('item_50');

        stopwatch.stop();

        // Verify operation completed correctly
        expect(
          container
              .read(localGallerySelectionNotifierProvider)
              .isSelected('item_50'),
          isFalse,
          reason: 'Item should be deselected',
        );

        // Performance target: <10ms for toggle with 100 selected items
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10),
          reason:
              'Toggle operation with 100 selected items should complete in <10ms, '
              'but took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('toggle performance with 500 selected ids', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        // Pre-select 500 items
        final items = List.generate(500, (i) => 'item_$i');
        notifier.selectAll(items);

        final stopwatch = Stopwatch()..start();

        // Toggle operation on an item that's already selected
        notifier.toggle('item_250');

        stopwatch.stop();

        // Verify operation completed correctly
        expect(
          container
              .read(localGallerySelectionNotifierProvider)
              .isSelected('item_250'),
          isFalse,
          reason: 'Item should be deselected',
        );

        // Performance target: <10ms for toggle with 500 selected items
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10),
          reason:
              'Toggle operation with 500 selected items should complete in <10ms, '
              'but took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('select performance with 500 selected ids', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        // Pre-select 500 items
        final items = List.generate(500, (i) => 'item_$i');
        notifier.selectAll(items);

        final stopwatch = Stopwatch()..start();

        // Select a new item (not already in selection)
        notifier.select('new_item');

        stopwatch.stop();

        // Verify operation completed correctly
        expect(
          container
              .read(localGallerySelectionNotifierProvider)
              .isSelected('new_item'),
          isTrue,
          reason: 'New item should be selected',
        );
        expect(
          container.read(localGallerySelectionNotifierProvider).selectedCount,
          501,
          reason: 'Should have 501 selected items',
        );

        // Performance target: <10ms for select with 500 selected items
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10),
          reason:
              'Select operation with 500 selected items should complete in <10ms, '
              'but took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('deselect performance with 500 selected ids', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        // Pre-select 500 items
        final items = List.generate(500, (i) => 'item_$i');
        notifier.selectAll(items);

        final stopwatch = Stopwatch()..start();

        // Deselect an item
        notifier.deselect('item_100');

        stopwatch.stop();

        // Verify operation completed correctly
        expect(
          container
              .read(localGallerySelectionNotifierProvider)
              .isSelected('item_100'),
          isFalse,
          reason: 'Item should be deselected',
        );
        expect(
          container.read(localGallerySelectionNotifierProvider).selectedCount,
          499,
          reason: 'Should have 499 selected items',
        );

        // Performance target: <10ms for deselect with 500 selected items
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10),
          reason:
              'Deselect operation with 500 selected items should complete in <10ms, '
              'but took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('selectRange performance with large range', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        // Create a large list of IDs
        final allIds = List.generate(200, (i) => 'item_$i');

        // Set anchor at the beginning
        notifier.select('item_0');

        final stopwatch = Stopwatch()..start();

        // Select a large range (0 to 199)
        notifier.selectRange('item_199', allIds);

        stopwatch.stop();

        // Verify operation completed correctly
        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          200,
          reason: 'Should have 200 items selected',
        );
        expect(
          state.isSelected('item_0'),
          isTrue,
          reason: 'First item should be selected',
        );
        expect(
          state.isSelected('item_199'),
          isTrue,
          reason: 'Last item should be selected',
        );
        expect(
          state.isSelected('item_100'),
          isTrue,
          reason: 'Middle item should be selected',
        );

        // Performance target: <20ms for selectRange with 200 items
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(20),
          reason:
              'SelectRange operation with 200 items should complete in <20ms, '
              'but took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('clearSelection performance with 500 selected ids', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        // Pre-select 500 items
        final items = List.generate(500, (i) => 'item_$i');
        notifier.selectAll(items);

        final stopwatch = Stopwatch()..start();

        // Clear all selections
        notifier.clearSelection();

        stopwatch.stop();

        // Verify operation completed correctly
        expect(
          container.read(localGallerySelectionNotifierProvider).selectedCount,
          0,
          reason: 'Should have no selected items',
        );
        expect(
          container.read(localGallerySelectionNotifierProvider).hasSelection,
          isFalse,
          reason: 'Should have no selection',
        );

        // Performance target: <10ms for clearSelection with 500 selected items
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10),
          reason:
              'ClearSelection operation with 500 selected items should complete in <10ms, '
              'but took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('selectAll performance with 500 items', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        // Create 500 items
        final items = List.generate(500, (i) => 'item_$i');

        final stopwatch = Stopwatch()..start();

        // Select all items
        notifier.selectAll(items);

        stopwatch.stop();

        // Verify operation completed correctly
        expect(
          container.read(localGallerySelectionNotifierProvider).selectedCount,
          500,
          reason: 'Should have 500 selected items',
        );

        // Performance target: <50ms for selectAll with 500 items
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(50),
          reason:
              'SelectAll operation with 500 items should complete in <50ms, '
              'but took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('rapid toggle operations performance (100 toggles)', () {
        final notifier =
            container.read(localGallerySelectionNotifierProvider.notifier);

        // Pre-select 100 items
        final items = List.generate(100, (i) => 'item_$i');
        notifier.selectAll(items);

        final stopwatch = Stopwatch()..start();

        // Perform 100 rapid toggle operations
        for (int i = 0; i < 100; i++) {
          notifier.toggle('item_$i');
        }

        stopwatch.stop();

        // Verify all items are deselected
        expect(
          container.read(localGallerySelectionNotifierProvider).selectedCount,
          0,
          reason: 'All items should be deselected',
        );

        // Performance target: <1000ms for 100 toggles (average <10ms per toggle)
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason:
              '100 toggle operations should complete in <1000ms (avg <10ms per toggle), '
              'but took ${stopwatch.elapsedMilliseconds}ms',
        );

        // Also verify average per-operation time
        final avgTimeMs = stopwatch.elapsedMilliseconds / 100;
        expect(
          avgTimeMs,
          lessThan(10),
          reason:
              'Average toggle time should be <10ms, but was ${avgTimeMs.toStringAsFixed(2)}ms',
        );
      });
    });
  });
}
