import '../../data/models/character/character_prompt.dart'
    show CharacterPositionLayout;
import '../../data/models/image/image_params.dart';

/// Resolves the single center used by every request and metadata projection.
/// AI layout preserves valid stored centers for round trips, but replaces stale
/// or malformed values because the server ignores them while `use_coords=false`.
abstract final class CharacterCenterResolver {
  static ({double x, double y}) resolve(
    CharacterPrompt character, {
    required int index,
    required int total,
    required bool useCoords,
  }) {
    final x = character.positionX;
    final y = character.positionY;
    final hasValidCenter =
        x != null &&
        y != null &&
        x.isFinite &&
        y.isFinite &&
        x >= 0 &&
        x <= 1 &&
        y >= 0 &&
        y <= 1;
    if (hasValidCenter) return (x: x, y: y);

    if (useCoords) {
      throw ArgumentError.value(
        character,
        'character',
        'Coordinate mode requires finite x/y centers between 0 and 1',
      );
    }
    final fallback = CharacterPositionLayout.positionForIndex(index, total);
    return (x: fallback.column, y: fallback.row);
  }
}
