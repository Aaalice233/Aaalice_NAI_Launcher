import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 直接用 FileType.image 调插件会绕开 pickImageFiles 对压缩的关闭
void main() {
  const allowedFile = 'lib/core/platform/image_file_picker.dart';

  test('只有共享入口可以直接使用 FileType.image', () {
    final offenders = <String>[];

    for (final file in _sources()) {
      final path = file.path.replaceAll(r'\', '/');
      if (path == allowedFile) continue;
      for (final line in _imagePickerLines(file.readAsStringSync())) {
        offenders.add('  $path:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '改用 core/platform/image_file_picker.dart 的 pickImageFiles，'
          '它会关闭 Android 上的图片压缩：\n${offenders.join('\n')}',
    );
  });

  test('识别规则跳过注释，只命中代码里的 FileType.image', () {
    expect(_imagePickerLines('pickFiles(type: FileType.image)'), [1]);
    expect(_imagePickerLines('final a = 1;\r\n  type: FileType.image,\r\n'), [
      2,
    ]);
    expect(_imagePickerLines('/// 见 [FileType.image] 的默认值'), isEmpty);
    expect(_imagePickerLines('  // type: FileType.image,'), isEmpty);
    expect(_imagePickerLines('pickFiles(type: FileType.custom)'), isEmpty);
    expect(_imagePickerLines('FileType.imageLike'), isEmpty);
  });
}

final _imageFileType = RegExp(r'\bFileType\.image\b');

// 行号从 1 开始；行注释里的提及不算
List<int> _imagePickerLines(String source) {
  final lines = source.split('\n');
  final hits = <int>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final comment = line.indexOf('//');
    final code = comment < 0 ? line : line.substring(0, comment);
    if (_imageFileType.hasMatch(code)) hits.add(i + 1);
  }
  return hits;
}

List<File> _sources() {
  final root = Directory('lib');
  expect(root.existsSync(), isTrue, reason: '未找到 lib，请在项目根运行测试');
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !file.path.endsWith('.g.dart'))
      .where((file) => !file.path.endsWith('.freezed.dart'))
      .toList();
}
