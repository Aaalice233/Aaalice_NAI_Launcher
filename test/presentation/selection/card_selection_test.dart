import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/selection/card_selection.dart';

class _Owner with CardSelectionCommands {
  @override
  SelectionModeState state = const SelectionModeState();
}

void main() {
  test('ranges keep the anchor in the current presented ordering', () {
    final owner = _Owner()..enterAndSelect('b');
    owner.selectRange('d', ['a', 'b', 'c', 'd']);
    expect(owner.state.selectedIds, {'b', 'c', 'd'});
    expect(owner.state.lastSelectedId, 'b');
    owner.selectRange('a', ['a', 'b', 'c', 'd']);
    expect(owner.state.selectedIds, {'a', 'b', 'c', 'd'});
    owner.clearSelection();
    expect(owner.state.lastSelectedId, isNull);
  });

  test(
    'page selection retains unloaded IDs and deletion removes only known IDs',
    () {
      final owner = _Owner()..enterAndSelect('page1');
      owner.selectAll(['page2a', 'page2b']);
      owner.removeDeleted(['page2b']);
      expect(owner.state.selectedIds, {'page1', 'page2a'});
      expect(
        CardSelection.targets(owner.state, 'page2a', ['page2a', 'page2b']),
        ['page2a', 'page1'],
      );
      expect(CardSelection.targets(owner.state, 'other', ['other']), ['other']);
      expect(owner.state.selectedIds, {'page1', 'page2a'});
    },
  );

  test(
    'independent pages do not share selections and exit clears the anchor',
    () {
      final a = _Owner()..enterAndSelect('a');
      final b = _Owner()..enterAndSelect('b');
      a.exit();
      expect(a.state.isActive, isFalse);
      expect(a.state.selectedIds, isEmpty);
      expect(a.state.lastSelectedId, isNull);
      expect(b.state.selectedIds, {'b'});
    },
  );
}
