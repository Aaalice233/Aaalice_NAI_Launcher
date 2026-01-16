import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_multi_select_provider.g.dart';

/// 多选状态
class MultiSelectState {
  final Set<int> selectedPostIds;
  final bool isSelectionMode;

  const MultiSelectState({
    this.selectedPostIds = const {},
    this.isSelectionMode = false,
  });

  MultiSelectState copyWith({
    Set<int>? selectedPostIds,
    bool? isSelectionMode,
  }) {
    return MultiSelectState(
      selectedPostIds: selectedPostIds ?? this.selectedPostIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
    );
  }
}

@riverpod
class MultiSelectNotifier extends _$MultiSelectNotifier {
  @override
  MultiSelectState build() {
    return const MultiSelectState();
  }

  void toggleSelection(int postId) {
    final current = state.selectedPostIds;
    if (current.contains(postId)) {
      state = state.copyWith(
        selectedPostIds: current.where((id) => id != postId).toSet(),
        isSelectionMode: current.length > 1,
      );
    } else {
      state = state.copyWith(
        selectedPostIds: {...current, postId},
        isSelectionMode: true,
      );
    }
  }

  void selectAll(Iterable<int> postIds) {
    state = state.copyWith(
      selectedPostIds: postIds.toSet(),
      isSelectionMode: postIds.isNotEmpty,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedPostIds: {},
      isSelectionMode: false,
    );
  }
}
