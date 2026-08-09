import '../../presentation/prompt_assistant/services/prompt_assistant_service.dart';
import 'autocomplete_cache_database.dart';
import 'completion_models.dart';

class LlmTranslationResolver implements TranslationResolver {
  LlmTranslationResolver({
    required PromptAssistantService service,
    required AutocompleteCacheDatabase cache,
    required bool Function() isEnabled,
  }) : _service = service,
       _cache = cache,
       _isEnabled = isEnabled;

  final PromptAssistantService _service;
  final AutocompleteCacheDatabase _cache;
  final bool Function() _isEnabled;

  @override
  Future<Map<String, String>> resolve(
    List<String> canonicalTags, {
    required String locale,
  }) async {
    if (!_isEnabled() || !locale.toLowerCase().startsWith('zh')) {
      return const {};
    }
    final tags = canonicalTags.toSet().take(8).toList(growable: false);
    if (tags.isEmpty) return const {};
    final route = _service.translateRouteFingerprint();
    if (route.isEmpty) {
      throw StateError(
        'Translate route is not configured in Prompt Assistant settings.',
      );
    }
    final cached = await _cache.getAiTranslations(
      tags: tags,
      locale: locale,
      routeFingerprint: route,
      promptVersion: PromptAssistantService.tagTranslationPromptVersion,
    );
    final missing = tags.where((tag) => !cached.containsKey(tag)).toList();
    if (missing.isEmpty) return cached;

    final response = await _service.translateTags(
      missing,
      sessionId: 'autocomplete-tags-${DateTime.now().microsecondsSinceEpoch}',
    );
    await _cache.putAiTranslations(
      translations: response.translations,
      locale: locale,
      routeFingerprint: route,
      promptVersion: PromptAssistantService.tagTranslationPromptVersion,
    );
    return {...cached, ...response.translations};
  }
}
