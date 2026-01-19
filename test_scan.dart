import 'dart:io';

void main() async {
  // 测试路径扫描逻辑
  const testPath = r'E:\Download\图图\NAI';
  final imageDir = Directory(testPath);

  print('=== 测试路径扫描 ===');
  print('测试路径: ${imageDir.path}');
  print('目录存在: ${imageDir.existsSync()}');

  if (!imageDir.existsSync()) {
    print('❌ 目录不存在');
    return;
  }

  // 扫描所有文件
  final allFiles = imageDir.listSync(recursive: false);
  print('\n所有文件数量: ${allFiles.length}');
  for (final item in allFiles) {
    print('  - ${item.path} (类型: ${item.runtimeType})');
  }

  // 过滤 File 类型
  final filesList = allFiles.whereType<File>().toList();
  print('\nFile 类型数量: ${filesList.length}');
  for (final file in filesList) {
    print('  - ${file.path}');
  }

  // 过滤 PNG 文件
  final pngFiles =
      filesList.where((f) => f.path.toLowerCase().endsWith('.png')).toList();
  print('\nPNG 文件数量: ${pngFiles.length}');
  for (final file in pngFiles) {
    print('  - ${file.path}');
  }

  if (pngFiles.isEmpty) {
    print('\n❌ 未找到 PNG 文件');
  } else {
    print('\n✅ 找到 ${pngFiles.length} 个 PNG 文件');
  }
}
