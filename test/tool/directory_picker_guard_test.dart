import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 直接调用 FilePicker.platform.getDirectoryPath 会绕过 Windows 独立 isolate 与单飞防重入保护
void main() {
  const allowedFile = 'lib/core/platform/directory_picker.dart';

  test('只有共享入口可以直接调用 getDirectoryPath', () {
    final offenders = <String>[];

    for (final file in _sources()) {
      final path = file.path.replaceAll(r'\', '/');
      if (path == allowedFile) continue;
      for (final line in _directoryPickerLines(file.readAsStringSync())) {
        offenders.add('  $path:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '改用 core/platform/directory_picker.dart 的 pickDirectoryPath，'
          '它会处理 Windows 独立线程、主窗口挂载与单飞防重入：\n${offenders.join('\n')}',
    );
  });

  test('识别规则跳过注释，只命中代码里的 .getDirectoryPath(', () {
    expect(
      _directoryPickerLines(
        'FilePicker.platform.getDirectoryPath(dialogTitle: "x")',
      ),
      [1],
    );
    expect(
      _directoryPickerLines(
        'final a = 1;\r\n  return picker.getDirectoryPath();\r\n',
      ),
      [2],
    );
    expect(_directoryPickerLines('/// 调用 [getDirectoryPath('), isEmpty);
    expect(
      _directoryPickerLines('  // FilePicker.platform.getDirectoryPath('),
      isEmpty,
    );
    expect(
      _directoryPickerLines('pickDirectoryPath(dialogTitle: "x")'),
      isEmpty,
    );
  });
}

final _directoryPickerCall = RegExp(r'\.getDirectoryPath\s*\(');

// 行号从 1 开始；行注释里的提及不算
List<int> _directoryPickerLines(String source) {
  final lines = source.split('\n');
  final hits = <int>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final comment = line.indexOf('//');
    final code = comment < 0 ? line : line.substring(0, comment);
    if (_directoryPickerCall.hasMatch(code)) hits.add(i + 1);
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
