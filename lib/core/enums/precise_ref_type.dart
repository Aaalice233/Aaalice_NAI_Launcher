enum PreciseRefType {
  /// Use character appearance only
  character,

  /// Use art style only
  style,

  /// Use both character and style
  characterAndStyle,

  costume;

  static List<PreciseRefType> selectable({required bool outfit}) => [
    character,
    style,
    characterAndStyle,
    if (outfit) costume,
  ];
}

String preciseReferenceDescription(
  PreciseRefType type, {
  bool? preferSameOutfit,
  required bool outfitSupported,
}) {
  assert(outfitSupported || type != PreciseRefType.costume);
  return switch (type) {
    PreciseRefType.character =>
      outfitSupported && (preferSameOutfit ?? false)
          ? 'character_mainoutfit'
          : 'character',
    PreciseRefType.style => 'style',
    PreciseRefType.characterAndStyle =>
      outfitSupported && !(preferSameOutfit ?? true)
          ? 'character&style_anyoutfit'
          : 'character&style',
    PreciseRefType.costume => 'costume',
  };
}

typedef PreciseReferenceTypeSettings = ({
  PreciseRefType type,
  bool? preferSameOutfit,
});

PreciseReferenceTypeSettings parsePreciseReferenceDescription(String? value) =>
    switch (value?.trim().toLowerCase()) {
      'style' => (type: PreciseRefType.style, preferSameOutfit: null),
      'character&style' || 'character_and_style' || 'character and style' => (
        type: PreciseRefType.characterAndStyle,
        preferSameOutfit: null,
      ),
      'character&style_anyoutfit' => (
        type: PreciseRefType.characterAndStyle,
        preferSameOutfit: false,
      ),
      'character_mainoutfit' => (
        type: PreciseRefType.character,
        preferSameOutfit: true,
      ),
      'costume' => (type: PreciseRefType.costume, preferSameOutfit: null),
      _ => (type: PreciseRefType.character, preferSameOutfit: null),
    };

extension PreciseRefTypeExtension on PreciseRefType {
  /// Display name key for localization
  /// Use with context.l10n.preciseRef_typeCharacter, etc.
  String get displayNameKey {
    return switch (this) {
      PreciseRefType.character => 'preciseRef_typeCharacter',
      PreciseRefType.style => 'preciseRef_typeStyle',
      PreciseRefType.characterAndStyle => 'preciseRef_typeCharacterAndStyle',
      PreciseRefType.costume => 'preciseRef_typeOutfit',
    };
  }
}
