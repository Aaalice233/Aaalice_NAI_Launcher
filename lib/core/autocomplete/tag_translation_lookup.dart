import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/tag_normalizer.dart';
import 'autocomplete_providers.dart';
import 'zh_dictionary_service.dart';

/// Result of translating a prompt-like, comma-delimited tag document.
class TagTextTranslation {
  const TagTextTranslation({
    required this.text,
    required this.translatedTagCount,
  });

  final String text;
  final int translatedTagCount;

  bool get hasTranslations => translatedTagCount > 0;
}

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

  /// Extracts normalized dictionary keys from prompt-like tag text.
  ///
  /// Unlike a plain comma split, this removes only actual NAI grouping syntax
  /// and keeps tag-internal parentheses such as `blender (medium)` intact.
  static List<String> extractTagKeys(String source) {
    if (source.isEmpty) return const [];
    return source
        .split(RegExp(r'(?<=[,，\r\n])|(?=[,，\r\n])'))
        .where((part) => !_isTagSeparator(part))
        .map(_TranslatableTagSlice.parse)
        .map((slice) => slice.lookupKey)
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  /// Translates each tag payload while preserving weights, grouping syntax,
  /// separators, whitespace, and unmatched source text byte-for-byte.
  ///
  /// Any prompt or tag-library surface can use this ffdkj-backed readable
  /// transformation. The source string is never mutated.
  Future<TagTextTranslation> translateTagText(String source) async {
    if (source.isEmpty) {
      return const TagTextTranslation(text: '', translatedTagCount: 0);
    }

    final parts = source.split(RegExp(r'(?<=[,，\r\n])|(?=[,，\r\n])'));
    final slices = parts
        .where((part) => !_isTagSeparator(part))
        .map(_TranslatableTagSlice.parse)
        .toList(growable: false);
    final translations = await translateBatch(
      slices
          .map((slice) => slice.lookupKey)
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
    );
    var translatedTagCount = 0;
    var sliceIndex = 0;

    final translated = parts.map((part) {
      if (_isTagSeparator(part)) return part;
      final slice = slices[sliceIndex++];
      final translation = translations[slice.lookupKey]?.trim();
      if (translation == null || translation.isEmpty) return part;
      translatedTagCount += 1;
      return slice.replacePayload(translation);
    }).join();

    return TagTextTranslation(
      text: translated,
      translatedTagCount: translatedTagCount,
    );
  }

  static String normalizeTag(String tag) {
    var value = TagNormalizer.stripWeightPrefix(tag.trim()).trim();
    final weighted = RegExp(
      r'^[+-]?(?:\d+(?:\.\d+)?|\.\d+)::([\s\S]*?)(?:::)?$',
    ).firstMatch(value);
    if (weighted != null) value = weighted.group(1)?.trim() ?? value;
    const pairs = {'{': '}', '[': ']', '(': ')'};
    while (value.length >= 2 && pairs[value[0]] == value[value.length - 1]) {
      value = value.substring(1, value.length - 1).trim();
    }
    value = value.replaceFirst(RegExp(r'::$'), '').trim();
    return TagNormalizer.normalize(value);
  }

  static bool _isTagSeparator(String value) =>
      value.isNotEmpty && RegExp(r'^[,，\r\n]+$').hasMatch(value);
}

class _TranslatableTagSlice {
  const _TranslatableTagSlice({
    required this.source,
    required this.prefixEnd,
    required this.suffixStart,
    required this.lookupKey,
  });

  final String source;
  final int prefixEnd;
  final int suffixStart;
  final String lookupKey;

  static final RegExp _weightPrefix = RegExp(
    r'^[+-]?(?:\d+(?:\.\d+)?|\.\d+)::',
  );

  factory _TranslatableTagSlice.parse(String source) {
    if (source.trim().isEmpty) {
      return _TranslatableTagSlice(
        source: source,
        prefixEnd: 0,
        suffixStart: source.length,
        lookupKey: '',
      );
    }
    final leadingLength = source.length - source.trimLeft().length;
    final trailingLength = source.length - source.trimRight().length;
    final contentEnd = source.length - trailingLength;
    var prefixEnd = leadingLength;
    var suffixStart = contentEnd;
    var openingParentheses = 0;

    // Groups can span several comma-delimited tags. Each segment remains
    // independently translatable while retaining the exact group syntax.
    var consumedPrefix = true;
    while (consumedPrefix && prefixEnd < suffixStart) {
      consumedPrefix = false;
      final remaining = source.substring(prefixEnd, suffixStart);
      final weight = _weightPrefix.firstMatch(remaining);
      if (weight != null) {
        prefixEnd += weight.end;
        consumedPrefix = true;
        continue;
      }
      final character = source[prefixEnd];
      if ('[{*'.contains(character)) {
        prefixEnd += 1;
        consumedPrefix = true;
      } else if (character == '(') {
        prefixEnd += 1;
        openingParentheses += 1;
        consumedPrefix = true;
      }
    }

    var consumedSuffix = true;
    while (consumedSuffix && suffixStart > prefixEnd) {
      consumedSuffix = false;
      if (suffixStart - prefixEnd >= 2 &&
          source.substring(suffixStart - 2, suffixStart) == '::') {
        suffixStart -= 2;
        consumedSuffix = true;
        continue;
      }
      final character = source[suffixStart - 1];
      if (']}*'.contains(character)) {
        suffixStart -= 1;
        consumedSuffix = true;
      } else if (character == ')' && openingParentheses > 0) {
        suffixStart -= 1;
        openingParentheses -= 1;
        consumedSuffix = true;
      }
    }

    final payload = source.substring(prefixEnd, suffixStart);
    final lookupKey = TagNormalizer.normalize(
      payload.replaceAll(r'\_', '_').trim(),
    );

    return _TranslatableTagSlice(
      source: source,
      prefixEnd: prefixEnd,
      suffixStart: suffixStart,
      lookupKey: lookupKey,
    );
  }

  String replacePayload(String translation) =>
      '${source.substring(0, prefixEnd)}'
      '$translation'
      '${source.substring(suffixStart)}';
}

final tagTranslationLookupProvider = Provider<TagTranslationLookup>((ref) {
  return TagTranslationLookup(ref.watch(zhDictionaryServiceProvider));
});
