import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 静态检查：lib 内的滑块只能经由 NamedSlider / ThemedSlider 创建。
///
/// Flutter 3.44 起滑块名称只能写进 Slider.label，直接构造 Slider 会漏掉读屏名称、
/// 把名称画成数值气泡，或按区间百分比读数。
void main() {
  test('lib 内不得直接构造 Slider', () {
    expect(
      File(_baseComponent).existsSync(),
      isTrue,
      reason: '未找到 $_baseComponent，请在项目根运行测试',
    );
    final offenders = <String>[];

    for (final file in _sources()) {
      final path = file.path.replaceAll(r'\', '/');
      if (path == _baseComponent) continue;
      final lines = file.readAsStringSync().split(RegExp(r'\r?\n'));
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (line.trimLeft().startsWith('//')) continue;
        if (!_rawSlider.hasMatch(line)) continue;
        offenders.add('  $path:${index + 1}  ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '改用 NamedSlider（沿用局部 SliderTheme）或 ThemedSlider（项目外观），'
          '二者都要求读屏名称和与界面一致的读数：\n'
          '${offenders.join('\n')}',
    );
  });

  test('识别规则只命中直接构造的 Slider', () {
    for (final line in const [
      'child: Slider(',
      'final slider = Slider(',
      'Slider.adaptive(',
      'return const Slider (',
    ]) {
      expect(_rawSlider.hasMatch(line), isTrue, reason: line);
    }
    for (final line in const [
      'child: NamedSlider(',
      'ThemedSlider(',
      'DlssParameterSlider(',
      '_MosaicSlider(',
      'find.byType(Slider)',
      'tester.widget<Slider>(',
    ]) {
      expect(_rawSlider.hasMatch(line), isFalse, reason: line);
    }
  });
}

const _baseComponent = 'lib/presentation/widgets/common/themed_slider.dart';

final _rawSlider = RegExp(r'(?<![\w$])Slider(?:\.adaptive)?\s*\(');

List<File> _sources() {
  final root = Directory('lib');
  expect(root.existsSync(), isTrue, reason: '未找到 lib，请在项目根运行测试');
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}
