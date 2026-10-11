import '../../../core/autocomplete/tag_translation_port.dart';
import 'prompt_assistant_service.dart';

class PromptAssistantTagTranslation implements TagTranslationPort {
  const PromptAssistantTagTranslation(this._service);

  final PromptAssistantService _service;

  @override
  int get promptVersion => PromptAssistantService.tagTranslationPromptVersion;

  @override
  String routeFingerprint() => _service.translateRouteFingerprint();

  @override
  Future<Map<String, String>> translateTags(
    List<String> canonicalTags, {
    required String sessionId,
  }) async {
    final result = await _service.translateTags(
      canonicalTags,
      sessionId: sessionId,
    );
    return result.translations;
  }

  @override
  Future<void> cancelTask({required String sessionId}) =>
      _service.cancelCurrentTask(sessionId: sessionId);
}
