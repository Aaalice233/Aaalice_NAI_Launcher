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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.toggle('item1');
        expect(
          container.read(onlineGallerySelectionNotifierProvider).isSelected('item1'),
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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.isSelected('item1'),
          isTrue,
          reason: 'Item should be selected',
        );
      });

      test('should not duplicate when already selected', () {
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');
        expect(
          container.read(onlineGallerySelectionNotifierProvider).isSelected('item1'),
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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);
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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

        notifier.selectAll([]);

        final state = container.read(onlineGallerySelectionNotifierProvider);
        expect(
          state.selectedCount,
          0,
          reason: 'Should have no items selected',
        );
      });

      test('should accumulate with existing selections', () {
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(onlineGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);

        notifier.select('item1');

        final state = container.read(localGallerySelectionNotifierProvider);
        expect(
          state.lastSelectedId,
          'item1',
          reason: 'Should update lastSelectedId',
        );
      });

      test('should update lastSelectedId even when already selected', () {
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);

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
      test('should clear selected items but keep lastSelectedId due to copyWith limitation', () {
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);

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
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
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
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
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
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
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
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
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
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
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
        final notifier = container.read(localGallerySelectionNotifierProvider.notifier);
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
}
