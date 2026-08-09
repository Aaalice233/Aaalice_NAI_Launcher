import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/tag_normalizer.dart';
import 'autocomplete_providers.dart';
import 'zh_dictionary_service.dart';

/// Shared optional Chinese lookup used outside the autocomplete overlay.
class TagTranslationLookup {
  const TagTranslationLookup(this._dictionary);

  final ZhDictionaryService _dictionary;

  Future<String?> translate(String tag) async {
    final normalized = TagNormalizer.normalize(tag);
    final values = await _dictionary.resolve([normalized], locale: 'zh-CN');
    return values[normalized];
  }

  Future<Map<String, String>> translateBatch(List<String> tags) {
    return _dictionary.resolve(
      tags.map(TagNormalizer.normalize).toList(growable: false),
      locale: 'zh-CN',
    );
  }

  Future<bool> hasTranslation(String tag) async => await translate(tag) != null;
}

final tagTranslationLookupProvider = Provider<TagTranslationLookup>((ref) {
  return TagTranslationLookup(ref.watch(zhDictionaryServiceProvider));
});
