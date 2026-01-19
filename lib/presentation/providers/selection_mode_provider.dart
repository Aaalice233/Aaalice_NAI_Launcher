import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selection_mode_provider.g.dart';

/// 多选模式状态
class SelectionModeState {
  final bool isActive;
  final Set<String> selectedIds;

  const SelectionModeState({
    this.isActive = false,
    this.selectedIds = const {},
  });

  SelectionModeState copyWith({
    bool? isActive,
    Set<String>? selectedIds,
  }) {
    return SelectionModeState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
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
    final newIds = Set<String>.from(state.selectedIds);
    if (newIds.contains(id)) {
      newIds.remove(id);
    } else {
      newIds.add(id);
    }
    state = state.copyWith(selectedIds: newIds);
  }

  /// 选中指定项
  void select(String id) {
    if (!state.selectedIds.contains(id)) {
      final newIds = Set<String>.from(state.selectedIds)..add(id);
      state = state.copyWith(selectedIds: newIds);
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
    state = state.copyWith(selectedIds: {});
  }

  /// 进入多选模式并选中指定项（用于长按触发）
  void enterAndSelect(String id) {
    final newIds = Set<String>.from(state.selectedIds)..add(id);
    state = state.copyWith(isActive: true, selectedIds: newIds);
  }
}

/// 本地画廊多选状态管理
@riverpod
class LocalGallerySelectionNotifier extends _$LocalGallerySelectionNotifier {
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
    final newIds = Set<String>.from(state.selectedIds);
    if (newIds.contains(id)) {
      newIds.remove(id);
    } else {
      newIds.add(id);
    }
    state = state.copyWith(selectedIds: newIds);
  }

  /// 选中指定项
  void select(String id) {
    if (!state.selectedIds.contains(id)) {
      final newIds = Set<String>.from(state.selectedIds)..add(id);
      state = state.copyWith(selectedIds: newIds);
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
    state = state.copyWith(selectedIds: {});
  }

  /// 进入多选模式并选中指定项（用于长按触发）
  void enterAndSelect(String id) {
    final newIds = Set<String>.from(state.selectedIds)..add(id);
    state = state.copyWith(isActive: true, selectedIds: newIds);
  }
}
