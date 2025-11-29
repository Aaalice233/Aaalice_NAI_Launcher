// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final file = File(
    r'C:\Users\Administrator\AppData\Roaming\com.example\nai_launcher\tag_cache\danbooru_tags.csv',
  );

  final lines = await file.readAsLines();
  print('Header: ${lines.first}');
  
  final categories = <String, int>{};
  
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    final parts = _parseCsvLine(line);
    if (parts.length >= 2) {
      final cat = parts[1];
      categories[cat] = (categories[cat] ?? 0) + 1;
    }
  }
  
  print('\nCategories:');
  categories.forEach((k, v) => print('  $k: $v'));
  
  // 打印一些示例
  print('\n=== Sample from each category ===');
  for (final cat in categories.keys) {
    print('\nCategory $cat:');
    var count = 0;
    for (var i = 1; i < lines.length && count < 5; i++) {
      final parts = _parseCsvLine(lines[i]);
      if (parts.length >= 2 && parts[1] == cat) {
        print('  ${parts[0]} (count: ${parts.length > 2 ? parts[2] : "?"})');
        count++;
      }
    }
  }
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  var inQuotes = false;
  var current = StringBuffer();

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      result.add(current.toString());
      current = StringBuffer();
    } else {
      current.write(char);
    }
  }
  result.add(current.toString());

  return result;
}

