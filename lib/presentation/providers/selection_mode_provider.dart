import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selection_mode_provider.g.dart';

/// 多选模式状态
class SelectionModeState {
  final bool isActive;
  final Set<String> selectedIds;
  final String? lastSelectedId;

  const SelectionModeState({
    this.isActive = false,
    this.selectedIds = const {},
    this.lastSelectedId,
  });

  SelectionModeState copyWith({
    bool? isActive,
    Set<String>? selectedIds,
    String? lastSelectedId,
  }) {
    return SelectionModeState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
      lastSelectedId: lastSelectedId ?? this.lastSelectedId,
    );
  }

  /// 选中数量
  int get selectedCount => selectedIds.length;

  /// 是否有选中项
  bool get hasSelection => selectedIds.isNotEmpty;

  /// 检查指定 ID 是否被选中
  bool isSelected(String id) => selectedIds.contains(id);
}

/// 在线画廊多选状态管理
@riverpod
class OnlineGallerySelectionNotifier extends _$OnlineGallerySelectionNotifier {
  @override
  SelectionModeState build() => const SelectionModeState();

  void enter() => _update(state.copyWith(isActive: true));
  void exit() => _update(const SelectionModeState());

  void toggle(String id) {
    final newIds = state.selectedIds.contains(id)
        ? state.selectedIds.difference({id})
        : state.selectedIds.union({id});
    _update(state.copyWith(selectedIds: newIds));
  }

  void select(String id) {
    if (!state.selectedIds.contains(id)) {
      _update(state.copyWith(selectedIds: {...state.selectedIds, id}));
    }
  }

  void deselect(String id) {
    if (state.selectedIds.contains(id)) {
      _update(state.copyWith(selectedIds: state.selectedIds.difference({id})));
    }
  }

  void selectAll(List<String> ids) {
    _update(state.copyWith(selectedIds: {...state.selectedIds, ...ids}));
  }

  void clearSelection() => _update(state.copyWith(selectedIds: {}));

  void enterAndSelect(String id) {
    _update(state.copyWith(isActive: true, selectedIds: {...state.selectedIds, id}));
  }

  void _update(SelectionModeState newState) => state = newState;
}

/// 本地画廊多选状态管理
@riverpod
class LocalGallerySelectionNotifier extends _$LocalGallerySelectionNotifier {
  @override
  SelectionModeState build() => const SelectionModeState();

  void enter() => _update(state.copyWith(isActive: true));
  void exit() => _update(const SelectionModeState());

  void toggle(String id) {
    final newIds = state.selectedIds.contains(id)
        ? state.selectedIds.difference({id})
        : state.selectedIds.union({id});
    _update(state.copyWith(selectedIds: newIds, lastSelectedId: id));
  }

  void select(String id) {
    final newIds = state.selectedIds.contains(id)
        ? state.selectedIds
        : {...state.selectedIds, id};
    _update(state.copyWith(selectedIds: newIds, lastSelectedId: id));
  }

  void deselect(String id) {
    if (state.selectedIds.contains(id)) {
      _update(state.copyWith(selectedIds: state.selectedIds.difference({id})));
    }
  }

  void selectAll(List<String> ids) {
    _update(state.copyWith(selectedIds: {...state.selectedIds, ...ids}));
  }

  void clearSelection() => _update(state.copyWith(selectedIds: {}, lastSelectedId: null));

  void enterAndSelect(String id) {
    _update(state.copyWith(
      isActive: true,
      selectedIds: {...state.selectedIds, id},
      lastSelectedId: id,
    ),);
  }

  /// 范围选择（Shift+点击）
  void selectRange(String currentId, List<String> allIds) {
    final anchorId = state.lastSelectedId;

    // 如果没有锚点或找不到位置，直接选中当前项
    final anchorIndex = anchorId != null ? allIds.indexOf(anchorId) : -1;
    final currentIndex = allIds.indexOf(currentId);

    if (anchorIndex == -1 || currentIndex == -1) {
      select(currentId);
      return;
    }

    // 确定范围并选中
    final start = anchorIndex < currentIndex ? anchorIndex : currentIndex;
    final end = anchorIndex < currentIndex ? currentIndex : anchorIndex;
    final rangeIds = allIds.sublist(start, end + 1);

    _update(state.copyWith(
      selectedIds: {...state.selectedIds, ...rangeIds},
      lastSelectedId: currentId,
    ),);
  }

  void _update(SelectionModeState newState) => state = newState;
}
