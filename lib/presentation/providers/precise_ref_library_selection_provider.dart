import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'selection_mode_provider.dart';

final preciseRefLibrarySelectionNotifierProvider =
    NotifierProvider.autoDispose<
      PreciseRefLibrarySelectionNotifier,
      SelectionModeState
    >(PreciseRefLibrarySelectionNotifier.new);

class PreciseRefLibrarySelectionNotifier
    extends AutoDisposeNotifier<SelectionModeState> {
  @override
  SelectionModeState build() => const SelectionModeState();

  void enter() => state = state.copyWith(isActive: true);

  void exit() => state = const SelectionModeState();

  void toggle(String id) {
    final selectedIds = Set<String>.from(state.selectedIds);
    selectedIds.contains(id) ? selectedIds.remove(id) : selectedIds.add(id);
    state = state.copyWith(selectedIds: selectedIds);
  }

  void enterAndSelect(String id) {
    state = SelectionModeState(isActive: true, selectedIds: {id});
  }

  void selectAll(Iterable<String> ids) {
    state = state.copyWith(selectedIds: {...state.selectedIds, ...ids});
  }

  void deselectAll(Iterable<String> ids) {
    state = state.copyWith(
      selectedIds: state.selectedIds.difference(ids.toSet()),
    );
  }

  void clearSelection() => state = state.copyWith(selectedIds: const {});
}
