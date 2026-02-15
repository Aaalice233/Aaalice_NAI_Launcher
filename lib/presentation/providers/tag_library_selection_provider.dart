import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tag_library_selection_provider.g.dart';

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

/// 词库多选状态管理
@riverpod
class TagLibrarySelectionNotifier extends _$TagLibrarySelectionNotifier {
  @override
  SelectionModeState build() => const SelectionModeState();

  /// 进入多选模式
  void enter() {
    state = state.copyWith(isActive: true);
  }

  /// 退出多选模式
  void exit() {
    state = const SelectionModeState();
  }

  /// 切换指定项的选中状态
  void toggle(String id) {
    final newIds = state.selectedIds.contains(id)
        ? state.selectedIds.difference({id})
        : state.selectedIds.union({id});
    state = state.copyWith(selectedIds: newIds, lastSelectedId: id);
  }

  /// 选中指定项
  void select(String id) {
    if (!state.selectedIds.contains(id)) {
      final newIds = Set<String>.from(state.selectedIds)..add(id);
      state = state.copyWith(selectedIds: newIds, lastSelectedId: id);
    } else {
      // 即使已经选中，也更新 lastSelectedId
      state = state.copyWith(lastSelectedId: id);
    }
  }

  /// 取消选中指定项
  void deselect(String id) {
    if (state.selectedIds.contains(id)) {
      final newIds = Set<String>.from(state.selectedIds)..remove(id);
      state = state.copyWith(selectedIds: newIds);
    }
  }

  /// 全选（传入当前页面所有有效 ID）
  void selectAll(List<String> ids) {
    final newIds = Set<String>.from(state.selectedIds)..addAll(ids);
    state = state.copyWith(selectedIds: newIds);
  }

  /// 清除选择
  void clearSelection() {
    state = state.copyWith(selectedIds: {}, lastSelectedId: null);
  }

  /// 进入多选模式并选中指定项（用于长按触发）
  void enterAndSelect(String id) {
    final newIds = Set<String>.from(state.selectedIds)..add(id);
    state = state.copyWith(isActive: true, selectedIds: newIds, lastSelectedId: id);
  }

  /// 范围选择（Shift+点击）
  /// [currentId] 当前点击的项 ID
  /// [allIds] 当前页面所有可见的 ID 列表（按显示顺序）
  void selectRange(String currentId, List<String> allIds) {
    final anchorId = state.lastSelectedId;

    // 如果没有上次选中的项，则直接选中当前项
    if (anchorId == null) {
      select(currentId);
      return;
    }

    // 查找锚点和当前项在列表中的位置
    final anchorIndex = allIds.indexOf(anchorId);
    final currentIndex = allIds.indexOf(currentId);

    // 如果找不到任一ID，则直接选中当前项
    if (anchorIndex == -1 || currentIndex == -1) {
      select(currentId);
      return;
    }

    // 确定范围
    final start = anchorIndex < currentIndex ? anchorIndex : currentIndex;
    final end = anchorIndex < currentIndex ? currentIndex : anchorIndex;

    // 选中范围内的所有项
    final rangeIds = allIds.sublist(start, end + 1);
    final newIds = {...state.selectedIds, ...rangeIds};

    state = state.copyWith(selectedIds: newIds, lastSelectedId: currentId);
  }
}
