import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 静态检查：分层依赖只能由 presentation 指向 data 和 core，不能反向。
///
/// 反向依赖会把 core/data 绑死在 UI 的 provider 与 widget 上：单测要拖起整棵
/// 界面树，换壳层就得改底层。编译器不管方向，只能扫源码守住。
void main() {
  test('lib/core 与 lib/data 不得 import presentation', () {
    final offenders = <String>[];

    for (final file in _layeredSources()) {
      final path = file.path.replaceAll(r'\', '/');
      final lines = file.readAsStringSync().split(RegExp(r'\r?\n'));
      for (var index = 0; index < lines.length; index++) {
        final uri = _directive.firstMatch(lines[index])?.group(1);
        if (uri == null) continue;
        if (!_pointsToPresentation(path, uri)) continue;
        offenders.add('  $path:${index + 1}  $uri');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'lib/core 与 lib/data 不得依赖 lib/presentation。\n'
          '把纯 UI 移到 presentation，或在 core/data 定义窄接口由上层注入：\n'
          '${offenders.join('\n')}',
    );
  });
}

final _directive = RegExp(r"^\s*(?:import|export)\s+'([^']+)'");

bool _pointsToPresentation(String owner, String uri) {
  if (uri.startsWith('package:nai_launcher/presentation/')) return true;
  if (uri.startsWith('dart:') || uri.startsWith('package:')) return false;

  final segments = owner.split('/')..removeLast();
  for (final segment in uri.split('/')) {
    if (segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  return segments.join('/').startsWith('lib/presentation/');
}

List<File> _layeredSources() {
  final files = <File>[];
  for (final root in [Directory('lib/core'), Directory('lib/data')]) {
    expect(root.existsSync(), isTrue, reason: '未找到 ${root.path}，请在项目根运行测试');
    files.addAll(
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .where((file) => !file.path.endsWith('.freezed.dart')),
    );
  }
  return files;
}
