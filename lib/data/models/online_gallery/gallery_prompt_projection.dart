import 'gallery_item.dart';

/// Action-ready prompt output derived from an online gallery item.
///
/// This model intentionally contains no source metadata. Projection may filter
/// prompt output, but the source models and their raw metadata remain untouched.
class GalleryPromptProjection {
  const GalleryPromptProjection({
    required this.positivePrompt,
    required this.negativePrompt,
    required this.characterPrompts,
    required this.copyText,
  });

  final String positivePrompt;
  final String negativePrompt;
  final List<GalleryCharacterPrompt> characterPrompts;
  final String copyText;

  bool get hasUsableOutput =>
      positivePrompt.trim().isNotEmpty ||
      negativePrompt.trim().isNotEmpty ||
      characterPrompts.any(
        (character) =>
            character.prompt.trim().isNotEmpty ||
            character.negativePrompt.trim().isNotEmpty,
      );
}
