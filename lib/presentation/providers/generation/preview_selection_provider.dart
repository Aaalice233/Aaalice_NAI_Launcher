import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../history_click_behavior_provider.dart';
import '../image_generation_provider.dart';

part 'preview_selection_provider.g.dart';

@Riverpod(keepAlive: true)
class GenerationPreviewSelection extends _$GenerationPreviewSelection {
  @override
  String? build() {
    ref.listen(imageGenerationNotifierProvider, (previous, next) {
      if (previous?.status != GenerationStatus.generating &&
          next.status == GenerationStatus.generating) {
        state = null;
        return;
      }

      final selectedId = state;
      if (selectedId == null || next.displayImages.isEmpty) return;
      final previousDisplayIds = previous?.displayImages
          .map((image) => image.id)
          .toList(growable: false);
      final nextDisplayIds = next.displayImages
          .map((image) => image.id)
          .toList(growable: false);
      if (!_sameIds(previousDisplayIds, nextDisplayIds) &&
          !nextDisplayIds.contains(selectedId)) {
        state = null;
      }
    });
    ref.listen(historyClickBehaviorNotifierProvider, (previous, next) {
      if (next == HistoryClickBehavior.openDetail) state = null;
    });
    return null;
  }

  void select(String imageId) => state = imageId;

  void clear() => state = null;

  void selectNext() => _move(1);

  void selectPrevious() => _move(-1);

  void _move(int delta) {
    final images = ref.read(imageGenerationNotifierProvider).mergedPanelImages;
    if (images.isEmpty) return;
    if (state == null) {
      state = images.first.id;
      return;
    }

    final currentIndex = images.indexWhere((image) => image.id == state);
    if (currentIndex < 0) {
      state = images.first.id;
      return;
    }
    final targetIndex = (currentIndex + delta).clamp(0, images.length - 1);
    state = images[targetIndex].id;
  }
}

bool _sameIds(List<String>? previous, List<String> next) {
  if (previous == null || previous.length != next.length) return false;
  for (var index = 0; index < next.length; index++) {
    if (previous[index] != next[index]) return false;
  }
  return true;
}

@Riverpod(keepAlive: true)
FocusNode generationPreviewFocusNode(Ref ref) {
  final node = FocusNode(debugLabel: 'generation-preview');
  ref.onDispose(node.dispose);
  return node;
}
