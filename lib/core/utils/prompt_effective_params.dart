import '../../data/models/image/image_params.dart';
import 'prompt_edit_document.dart';

/// Produces a request snapshot without changing the persisted editor document.
ImageParams effectivePromptParams(ImageParams params) => params.copyWith(
  prompt: PromptEditDocument.effectiveText(params.prompt),
  negativePrompt: PromptEditDocument.effectiveText(params.negativePrompt),
  characters: params.characters
      .map(
        (character) => character.copyWith(
          prompt: PromptEditDocument.effectiveText(character.prompt),
          negativePrompt: PromptEditDocument.effectiveText(
            character.negativePrompt,
          ),
        ),
      )
      .toList(growable: false),
);
