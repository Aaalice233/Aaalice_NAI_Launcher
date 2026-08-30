import '../../data/models/character/character_prompt.dart'
    show CharacterPositionLayout;
import '../../data/models/image/image_params.dart';

/// Resolves the single center used by every request and metadata projection.
/// Validation belongs at preparation/request boundaries; this function only
/// applies the shared deterministic fallback used when AI layout ignores it.
abstract final class CharacterCenterResolver {
  static ({double x, double y}) resolve(
    CharacterPrompt character, {
    required int index,
    required int total,
  }) {
    if (character.positionX != null && character.positionY != null) {
      return (x: character.positionX!, y: character.positionY!);
    }
    final fallback = CharacterPositionLayout.positionForIndex(index, total);
    return (x: fallback.column, y: fallback.row);
  }
}
