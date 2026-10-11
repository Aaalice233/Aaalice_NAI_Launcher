import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 静态检查：lib 内的同一个调用不得同时传 cacheWidth 与 cacheHeight。
///
/// 两边都给时 Flutter 按 ResizeImagePolicy.exact 解码，不保留原图宽高比，
/// 非方形图会被压扁后再铺进控件。
void main() {
  test('lib 内不得同时传 cacheWidth 与 cacheHeight', () {
    final offenders = <String>[];

    for (final file in _sources()) {
      final path = file.path.replaceAll(r'\', '/');
      for (final line in _bothCacheDimensionLines(file.readAsStringSync())) {
        offenders.add('  $path:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '内存字节改用 DecodedMemoryImage，其他 provider 用 '
          'BoxFitResizeImage.resizeIfNeeded 按 BoxFit 等比解码；'
          '只限一条边时只传 cacheWidth 或 cacheHeight：\n'
          '${offenders.join('\n')}',
    );
  });

  test('识别规则只命中同一调用里同时出现的两个尺寸', () {
    for (final source in const [
      'Image.memory(bytes, cacheWidth: w, cacheHeight: h)',
      'Image.memory(\n  bytes,\n  cacheHeight: h,\n  fit: BoxFit.cover,\n'
          '  cacheWidth: w,\n)',
      'LocalFileImage.withCacheSize(path, cacheWidth: size(a, b), '
          'cacheHeight: size)',
    ]) {
      expect(_bothCacheDimensionLines(source), isNotEmpty, reason: source);
    }
    for (final source in const [
      'Image.memory(bytes, cacheWidth: w)',
      'LocalFileImage.withCacheSize(path, cacheHeight: h)',
      'Outer(cacheHeight: h, child: Image.memory(bytes, cacheWidth: w))',
      'ResizeImage(provider, width: w, height: h)',
      '// Image.memory(bytes, cacheWidth: w, cacheHeight: h)',
    ]) {
      expect(_bothCacheDimensionLines(source), isEmpty, reason: source);
    }
  });
}

final _cacheHeightArgument = RegExp(r'(?<![\w$])cacheHeight\s*:');
final _cacheWidthArgument = RegExp(r'^\s*cacheWidth\s*:');

/// 返回同时带两个尺寸参数的调用中 cacheHeight 所在的行号。
List<int> _bothCacheDimensionLines(String source) {
  final lines = <int>[];
  for (final match in _cacheHeightArgument.allMatches(source)) {
    final lineStart = source.lastIndexOf('\n', match.start) + 1;
    if (source.substring(lineStart, match.start).contains('//')) continue;

    final open = _enclosingOpenParen(source, match.start);
    if (open == null) continue;
    final arguments = _topLevelArguments(source, open);
    if (arguments.any(_cacheWidthArgument.hasMatch)) {
      lines.add('\n'.allMatches(source.substring(0, match.start)).length + 1);
    }
  }
  return lines;
}

int? _enclosingOpenParen(String source, int index) {
  var depth = 0;
  for (var i = index - 1; i >= 0; i--) {
    final char = source[i];
    if (char == ')' || char == ']' || char == '}') depth++;
    if (char == '(' || char == '[' || char == '{') {
      if (depth == 0) return char == '(' ? i : null;
      depth--;
    }
  }
  return null;
}

/// 按顶层逗号切分 [open] 处括号内的实参。
List<String> _topLevelArguments(String source, int open) {
  final arguments = <String>[];
  var depth = 0;
  var start = open + 1;
  for (var i = open + 1; i < source.length; i++) {
    final char = source[i];
    if (char == '(' || char == '[' || char == '{') depth++;
    if (char == ')' || char == ']' || char == '}') {
      if (depth == 0) {
        arguments.add(source.substring(start, i));
        break;
      }
      depth--;
    }
    if (char == ',' && depth == 0) {
      arguments.add(source.substring(start, i));
      start = i + 1;
    }
  }
  return arguments;
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
