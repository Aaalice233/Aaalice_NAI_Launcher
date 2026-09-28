import 'package:flutter/foundation.dart';

const _unchangedAnchor = Object();

@immutable
class SelectionModeState {
  const SelectionModeState({
    this.isActive = false,
    this.selectedIds = const {},
    this.lastSelectedId,
  });

  final bool isActive;
  final Set<String> selectedIds;
  final String? lastSelectedId;

  int get selectedCount => selectedIds.length;
  bool get hasSelection => selectedIds.isNotEmpty;
  bool isSelected(String id) => selectedIds.contains(id);

  SelectionModeState copyWith({
    bool? isActive,
    Set<String>? selectedIds,
    Object? lastSelectedId = _unchangedAnchor,
  }) => SelectionModeState(
    isActive: isActive ?? this.isActive,
    selectedIds: selectedIds == null
        ? this.selectedIds
        : Set.unmodifiable(selectedIds),
    lastSelectedId: identical(lastSelectedId, _unchangedAnchor)
        ? this.lastSelectedId
        : lastSelectedId as String?,
  );
}

/// Pure rules shared by page providers and the generation history owner.
abstract final class CardSelection {
  static SelectionModeState toggle(SelectionModeState state, String id) =>
      state.copyWith(
        selectedIds: state.selectedIds.contains(id)
            ? state.selectedIds.difference({id})
            : {...state.selectedIds, id},
        lastSelectedId: id,
      );

  static SelectionModeState select(SelectionModeState state, String id) => state
      .copyWith(selectedIds: {...state.selectedIds, id}, lastSelectedId: id);

  static SelectionModeState range(
    SelectionModeState state,
    String id,
    List<String> orderedIds,
  ) {
    final target = orderedIds.indexOf(id);
    if (target < 0) return state;
    final anchor = orderedIds.indexOf(state.lastSelectedId ?? '');
    if (anchor < 0) return select(state, id);
    final start = anchor < target ? anchor : target;
    final end = anchor < target ? target : anchor;
    return state.copyWith(
      selectedIds: {
        ...state.selectedIds,
        ...orderedIds.sublist(start, end + 1),
      },
    );
  }

  static SelectionModeState remove(
    SelectionModeState state,
    Iterable<String> ids,
  ) {
    final removed = ids.toSet();
    return state.copyWith(
      selectedIds: state.selectedIds.difference(removed),
      lastSelectedId: removed.contains(state.lastSelectedId)
          ? null
          : state.lastSelectedId,
    );
  }

  /// The menu and drag both freeze this ordered target set before asynchronous work.
  static List<String> targets(
    SelectionModeState state,
    String currentId,
    Iterable<String> orderedIds,
  ) {
    if (!state.selectedIds.contains(currentId)) return [currentId];
    final presented = orderedIds.toSet();
    return [
      ...presented.where(state.selectedIds.contains),
      ...state.selectedIds.where((id) => !presented.contains(id)),
    ];
  }
}

mixin CardSelectionCommands {
  SelectionModeState get state;
  set state(SelectionModeState value);

  void enter() => state = state.copyWith(isActive: true);
  void exit() => state = const SelectionModeState();
  void toggle(String id) => state = CardSelection.toggle(state, id);
  void select(String id) => state = CardSelection.select(state, id);
  void deselect(String id) => state = CardSelection.remove(state, [id]);
  void deselectAll(Iterable<String> ids) =>
      state = CardSelection.remove(state, ids);
  void removeDeleted(Iterable<String> ids) =>
      state = CardSelection.remove(state, ids);
  void selectAll(Iterable<String> ids) =>
      state = state.copyWith(selectedIds: {...state.selectedIds, ...ids});
  void replaceSelection(List<String> ids) => state = state.copyWith(
    selectedIds: ids.toSet(),
    lastSelectedId: ids.isEmpty ? null : ids.last,
  );
  void clearSelection() =>
      state = state.copyWith(selectedIds: {}, lastSelectedId: null);
  void enterAndSelect(String id) =>
      state = CardSelection.select(state.copyWith(isActive: true), id);
  void selectRange(String id, List<String> orderedIds) =>
      state = CardSelection.range(state, id, orderedIds);
  bool isSelected(String id) => state.selectedIds.contains(id);
}
