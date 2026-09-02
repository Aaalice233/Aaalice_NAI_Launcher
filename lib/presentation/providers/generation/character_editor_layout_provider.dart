import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef CharacterEditorHeightKey = ({String characterId, bool negative});

/// Keeps user-resized character editors stable while adaptive shells replace
/// their widget subtrees.
final characterEditorHeightProvider =
    StateProvider.family<double?, CharacterEditorHeightKey>((ref, key) => null);
