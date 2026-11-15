import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef CharacterEditorHeightKey = ({String characterId, bool negative});

/// Keeps user-resized character editors stable while adaptive shells replace
/// their widget subtrees.
final characterEditorHeightProvider =
    NotifierProvider.family<
      CharacterEditorHeightNotifier,
      double?,
      CharacterEditorHeightKey
    >(CharacterEditorHeightNotifier.new);

class CharacterEditorHeightNotifier extends Notifier<double?> {
  CharacterEditorHeightNotifier(this.key);

  final CharacterEditorHeightKey key;

  @override
  double? build() => null;

  void setHeight(double? height) {
    state = height;
  }

  void resizeBy({
    required double delta,
    required double fallbackHeight,
    required double minHeight,
    required double maxHeight,
  }) {
    final currentHeight = (state ?? fallbackHeight).clamp(minHeight, maxHeight);
    state = (currentHeight + delta).clamp(minHeight, maxHeight).toDouble();
  }
}
