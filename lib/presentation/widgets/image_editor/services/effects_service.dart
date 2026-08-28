import 'package:flutter/foundation.dart';

import '../effects/editor_effects.dart';

class EditorEffectsService {
  const EditorEffectsService();

  Future<EditorEffectResult> apply(EditorEffectJob job) async {
    final message = await compute(
      runEditorEffectJobMessage,
      job.toMessage(),
      debugLabel: 'image_editor_effect',
    );
    return EditorEffectResult.fromMessage(message);
  }
}
