import 'package:flutter/services.dart';

const _traditionalToSimplifiedAsset = 'assets/data/opencc/TSCharacters.txt';

/// Converts Traditional Chinese input to the Simplified Chinese script used by
/// the optional ffdkj tag dictionary.
class TraditionalChineseConverter {
  TraditionalChineseConverter({Future<String> Function(String)? loadString})
    : _loadString = loadString ?? rootBundle.loadString;

  final Future<String> Function(String) _loadString;
  Future<Map<int, String>>? _mapping;

  Future<String> toSimplified(String input) async {
    if (input.isEmpty) return input;
    final mapping = await (_mapping ??= _loadMapping());
    return input.runes
        .map((rune) => mapping[rune] ?? String.fromCharCode(rune))
        .join();
  }

  Future<Map<int, String>> _loadMapping() async {
    final source = await _loadString(_traditionalToSimplifiedAsset);
    final mapping = <int, String>{};
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separator = trimmed.indexOf('\t');
      if (separator <= 0) continue;
      final traditional = trimmed.substring(0, separator);
      final candidates = trimmed.substring(separator + 1).trim();
      if (traditional.runes.length != 1 || candidates.isEmpty) continue;
      mapping[traditional.runes.single] = candidates.split(' ').first;
    }
    return mapping;
  }
}
