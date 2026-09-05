import 'tag_translation_lookup.dart';

typedef MissingTagTranslator =
    Future<Map<String, String>> Function(List<String> canonicalTags);

/// Translates tag prompts locally first and delegates only unresolved tags.
///
/// Returning `null` means the input looks like prose or requests a non-Chinese
/// target, so the caller should preserve its normal general-purpose flow.
class LocalFirstPromptTranslationPipeline {
  const LocalFirstPromptTranslationPipeline(this._localTranslations);

  final TagTranslationLookup _localTranslations;

  Future<TagTextTranslation?> translate(
    String input, {
    String? targetLanguage,
    required MissingTagTranslator translateMissing,
  }) async {
    if (RegExp(r'[\u3400-\u9fff]').hasMatch(input)) return null;
    final requestedLanguage = targetLanguage?.trim().toLowerCase() ?? '';
    if (requestedLanguage.isNotEmpty &&
        !RegExp(r'(zh|chinese|中文)').hasMatch(requestedLanguage)) {
      return null;
    }

    final plan = await _localTranslations.prepareTagTextTranslation(input);
    if (plan.tagCount == 0 ||
        plan.unresolvedTags.any(
          (tag) => !RegExp(r'^[a-z0-9_():.!+\-]+$').hasMatch(tag),
        )) {
      return null;
    }
    final isTagList = input.contains(RegExp(r'[,，\r\n]'));
    final isSingleCanonicalTag = RegExp(
      r'^[\s{}\[\]()*+\-:.0-9a-zA-Z_\\]+$',
    ).hasMatch(input);
    if (plan.localTranslations.isEmpty && !isTagList && !isSingleCanonicalTag) {
      return null;
    }

    final delegated = plan.unresolvedTags.isEmpty
        ? <String, String>{}
        : await translateMissing(plan.unresolvedTags);
    _localTranslations.addTranslations(delegated);
    return plan.render(delegated);
  }
}
