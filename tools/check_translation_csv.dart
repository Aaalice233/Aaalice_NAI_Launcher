import 'dart:io';

void main() async {
  final file = File('assets/translations/hf_danbooru_tags.csv');
  final lines = await file.readAsLines();

  print('Total lines: ${lines.length}');
  print('\n=== First 10 lines ===');
  for (var i = 0; i < 10 && i < lines.length; i++) {
    print('Line $i: ${lines[i]}');
  }

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
  ];

  print('\n=== Checking specific tags ===');
  for (final tag in tagsToCheck) {
    final line = lines.firstWhere(
      (l) => l.startsWith('$tag,'),
      orElse: () => '',
    );
    if (line.isNotEmpty) {
      final parts = line.split(',');
      if (parts.length >= 4) {
        print('$tag: ${parts[3]}');
      }
    }
  }

  // Test Chinese extraction
  print('\n=== Testing Chinese extraction ===');
  final testLine = lines[1]; // 1girl line
  final parts = testLine.split(',');
  if (parts.length >= 4) {
    final aliases = parts[3];
    print('Raw aliases: $aliases');
    final zhTranslations = _extractChineseTranslations(aliases);
    print('Extracted Chinese: $zhTranslations');
  }
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
