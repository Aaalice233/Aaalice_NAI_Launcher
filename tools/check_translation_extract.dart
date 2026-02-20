import 'dart:io';

void main() async {
  final file = File('assets/translations/hf_danbooru_tags.csv');
  final lines = await file.readAsLines();

  // Check specific tags
  final tagsToCheck = [
    '1girl',
    'solo',
    'long_hair',
    'breasts',
    'looking_at_viewer',
    'smile',
    'open_mouth',
    'shirt',
    'skirt',
    'simple_background',
  ];

  print('=== Detailed Chinese extraction check ===\n');
  for (final tag in tagsToCheck) {
    final line = lines.firstWhere(
      (l) => l.startsWith('$tag,'),
      orElse: () => '',
    );
    if (line.isNotEmpty) {
      final parts = _parseCsvLine(line);
      if (parts.length >= 4) {
        final aliases = parts[3];
        final zhTranslations = _extractChineseTranslations(aliases);
        print('$tag:');
        print('  Raw: $aliases');
        print('  Extracted: $zhTranslations');
        print('');
      }
    }
  }
}

List<String> _parseCsvLine(String line) {
  final parts = <String>[];
  var inQuotes = false;
  var current = StringBuffer();

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      parts.add(current.toString());
      current = StringBuffer();
    } else {
      current.write(char);
    }
  }
  parts.add(current.toString());
  return parts;
}

List<String> _extractChineseTranslations(String aliases) {
  final translations = <String>[];

  // Split by comma
  final parts = aliases.split(',');
  for (final part in parts) {
    final trimmed = part.trim();
    // Keep Chinese translations (non-ASCII)
    if (trimmed.isNotEmpty && _containsChinese(trimmed)) {
      translations.add(trimmed);
    }
  }

  return translations;
}

bool _containsChinese(String s) {
  for (var i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    // CJK Unified Ideographs: 4E00-9FFF
    // CJK Extension A: 3400-4DBF
    if ((code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}
