import '../../../../core/utils/isolate_pool.dart';
import '../effects/editor_effects.dart';

class EditorEffectsService {
  const EditorEffectsService();

  Future<EditorEffectResult> apply(EditorEffectJob job) async {
    final message = await ComputeGate().runCompute(
      runEditorEffectJobMessage,
      job.toMessage(),
      debugLabel: 'image_editor_effect',
    );
    return EditorEffectResult.fromMessage(message);
  }
}
