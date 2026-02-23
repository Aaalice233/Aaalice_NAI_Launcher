import 'dart:io';

void main() async {
  final file = File('assets/translations/danbooru_zh.csv');
  final lines = await file.readAsLines();
  
  print('Total lines: ${lines.length}');
  print('\n=== First 20 lines ===');
  for (var i = 0; i < 20 && i < lines.length; i++) {
    print('Line $i: ${lines[i]}');
  }
  
  // Check specific tags
  final tagsToCheck = ['looking_at_viewer', 'solo', 'simple_background'];
  
  print('\n=== Checking specific tags ===');
  for (final tag in tagsToCheck) {
    final line = lines.firstWhere(
      (l) => l.startsWith('$tag,'),
      orElse: () => '',
    );
    if (line.isNotEmpty) {
      print('$tag: $line');
    } else {
      print('$tag: NOT FOUND');
    }
  }
}
