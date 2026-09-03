import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/tag_normalizer.dart';
import 'autocomplete_providers.dart';
import 'zh_dictionary_service.dart';

/// Shared optional Chinese lookup used outside the autocomplete overlay.
class TagTranslationLookup {
  const TagTranslationLookup(this._dictionary) : _resolver = null;

  const TagTranslationLookup.fromResolver(
    Future<Map<String, String>> Function(List<String> tags) resolver,
  ) : _dictionary = null,
      _resolver = resolver;

  final ZhDictionaryService? _dictionary;
  final Future<Map<String, String>> Function(List<String> tags)? _resolver;

  Future<String?> translate(String tag) async {
    final normalized = normalizeTag(tag);
    if (normalized.isEmpty) return null;
    final values = await translateBatch([normalized]);
    return values[normalized];
  }

  Future<Map<String, String>> translateBatch(List<String> tags) async {
    final normalized = tags
        .map(normalizeTag)
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) return const {};
    final resolver = _resolver;
    if (resolver != null) return resolver(normalized);
    return _dictionary!.resolve(normalized, locale: 'zh-CN');
  }

  Future<bool> hasTranslation(String tag) async => await translate(tag) != null;

  static String normalizeTag(String tag) {
    var value = TagNormalizer.normalizeAutocompleteTag(tag).trim();
    final weighted = RegExp(
      r'^[+-]?(?:\d+(?:\.\d+)?|\.\d+)::([\s\S]*?)(?:::)?$',
    ).firstMatch(value);
    if (weighted != null) value = weighted.group(1)?.trim() ?? value;
    value = value
        .replaceFirst(RegExp(r'^[\{\[\(]+'), '')
        .replaceFirst(RegExp(r'[\}\]\)]+$'), '')
        .replaceFirst(RegExp(r'::$'), '')
        .trim();
    return TagNormalizer.normalize(value);
  }
}

final tagTranslationLookupProvider = Provider<TagTranslationLookup>((ref) {
  return TagTranslationLookup(ref.watch(zhDictionaryServiceProvider));
});
