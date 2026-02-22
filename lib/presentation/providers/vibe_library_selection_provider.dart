import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'selection_mode_provider.dart';

part 'vibe_library_selection_provider.g.dart';

/// Vibe库多选状态管理
@riverpod
class VibeLibrarySelectionNotifier extends _$VibeLibrarySelectionNotifier {
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
    state = state.copyWith(selectedIds: ids.toSet());
  }

  /// 进入并选中
  void enterAndSelect(String id) {
    state = SelectionModeState(
      isActive: true,
      selectedIds: {id},
    );
  }

  /// 清空选择
  void clearSelection() {
    state = state.copyWith(selectedIds: {});
  }

  /// 检查是否选中
  bool isSelected(String id) => state.selectedIds.contains(id);
}
