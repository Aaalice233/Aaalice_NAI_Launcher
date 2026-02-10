/// Precise reference type for Character Reference feature
///
/// Defines what aspects of the reference image to use:
/// - [character]: Use character appearance only
/// - [style]: Use art style only
/// - [characterAndStyle]: Use both character and style
enum PreciseRefType {
  /// Use character appearance only
  character,

  /// Use art style only
  style,

  /// Use both character and style
  characterAndStyle,
}

/// Extension methods for [PreciseRefType]
extension PreciseRefTypeExtension on PreciseRefType {
  /// Returns API string for the type
  String toApiString() {
    return switch (this) {
      PreciseRefType.character => 'character',
      PreciseRefType.style => 'style',
      PreciseRefType.characterAndStyle => 'character&style',
    };
  }

  /// Display name for UI (will be localized later)
  String get displayName {
    return switch (this) {
      PreciseRefType.character => 'Character',
      PreciseRefType.style => 'Style',
      PreciseRefType.characterAndStyle => 'Character & Style',
    };
  }
}
