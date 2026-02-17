// ignore_for_file: avoid_print, avoid_relative_lib_imports

import '../lib/core/utils/nai_prompt_formatter.dart';
import '../lib/core/utils/sd_to_nai_converter.dart';

/// 测试用例
class TestCase {
  final String input;
  final String expected;
  final String description;

  TestCase(this.input, this.expected, this.description);
}

void main() {
  final testCases = [
    // 基础功能
    TestCase(
      '1girl, blue eyes',
      '1girl, blue_eyes',
      '基础：空格转下划线',
    ),
    TestCase(
      '1girl，blue eyes',
      '1girl, blue_eyes',
      '基础：中文逗号转英文',
    ),

    // 用户反馈的问题场景
    TestCase(
      '， 1girl',
      '1girl',
      '问题场景：中文逗号+空格开头',
    ),
    TestCase(
      'wrist_cuffs, ， 1girl, ',
      'wrist_cuffs, 1girl',
      '问题场景：中间有空的中文逗号',
    ),
    TestCase(
      'tag1， small breast， blue eyes',
      'tag1, small_breast, blue_eyes',
      '问题场景：多个中文逗号+空格',
    ),
    TestCase(
      'white_thighhighs， 1girl, ',
      'white_thighhighs, 1girl',
      '问题场景：用户反馈的具体case',
    ),

    // 边界情况
    TestCase(
      '',
      '',
      '边界：空字符串',
    ),
    TestCase(
      '   ',
      '',
      '边界：纯空格',
    ),
    TestCase(
      ',,,',
      '',
      '边界：纯逗号',
    ),
    TestCase(
      '1girl',
      '1girl',
      '边界：单个标签无逗号',
    ),
    TestCase(
      '  1girl  ',
      '1girl',
      '边界：首尾空格',
    ),

    // 全角空格
    TestCase(
      '1girl,　blue eyes', // 全角空格
      '1girl, blue_eyes',
      '全角空格：标签内全角空格',
    ),
    TestCase(
      '　1girl　,　blue eyes　', // 全角空格
      '1girl, blue_eyes',
      '全角空格：多处全角空格',
    ),

    // 连续空格
    TestCase(
      '1girl,  blue   eyes',
      '1girl, blue_eyes',
      '连续空格：多个空格压缩',
    ),

    // 复杂场景
    TestCase(
      'masterpiece, best quality， 1girl, blue eyes, small breast',
      'masterpiece, best_quality, 1girl, blue_eyes, small_breast',
      '复杂：混合中英文逗号和空格',
    ),
    TestCase(
      '  masterpiece  ，  1girl  ，  ',
      'masterpiece, 1girl',
      '复杂：大量多余空格和空标签',
    ),

    // 特殊字符（应保留）
    TestCase(
      '{1girl}, [blue eyes]',
      '{1girl}, [blue_eyes]',
      '特殊：括号内的空格也转换',
    ),
    TestCase(
      '1girl:1.2, blue eyes:0.8',
      '1girl:1.2, blue_eyes:0.8',
      '特殊：带权重的标签',
    ),

    // 下划线标签（不应重复处理）
    TestCase(
      'wrist_cuffs, blue_eyes',
      'wrist_cuffs, blue_eyes',
      '已有下划线：保持不变',
    ),
    TestCase(
      'wrist_cuffs, small breast',
      'wrist_cuffs, small_breast',
      '混合：已有下划线+需转换',
    ),

    // 尖括号别名（内部空格应保留）
    TestCase(
      '1girl, <沟通兔>, flat chest',
      '1girl, <沟通兔>, flat_chest',
      '别名：尖括号内容保留',
    ),
    TestCase(
      '1girl, <test alias>, blue eyes',
      '1girl, <test alias>, blue_eyes',
      '别名：尖括号内空格保留',
    ),
    TestCase(
      '1girl， <沟通兔>， flat_chest',
      '1girl, <沟通兔>, flat_chest',
      '别名：中文逗号+尖括号',
    ),
  ];

  print('========================================');
  print('NaiPromptFormatter.format 测试');
  print('========================================\n');

  var passed = 0;
  var failed = 0;

  for (final tc in testCases) {
    final result = NaiPromptFormatter.format(tc.input);
    final success = result == tc.expected;

    if (success) {
      passed++;
      print('✓ PASS: ${tc.description}');
    } else {
      failed++;
      print('✗ FAIL: ${tc.description}');
      print('  输入: "${tc.input}"');
      print('  期望: "${tc.expected}"');
      print('  实际: "$result"');
    }
  }

  print('\n========================================');
  print('测试结果: $passed 通过, $failed 失败');
  print('========================================');

  if (failed > 0) {
    print('\n请检查失败的测试用例！');
  }

  // 测试 SdToNaiConverter
  print('\n========================================');
  print('SdToNaiConverter.convert 测试');
  print('========================================\n');

  final sdTestCases = [
    // 重构后：无SD语法时直接返回原文，不做任何处理
    TestCase(
      'white_thighhighs， 1girl, ',
      'white_thighhighs， 1girl, ', // 直接返回原文
      'SD转换：无SD语法时不做处理',
    ),
    TestCase(
      '1girl， blue eyes',
      '1girl， blue eyes', // 直接返回原文
      'SD转换：无SD语法时不做空格转换',
    ),
    TestCase(
      'tag1, tag2, tag3',
      'tag1, tag2, tag3', // 直接返回原文
      'SD转换：普通文本不做处理',
    ),
    // 有SD语法时执行转换
    TestCase(
      '(long hair:1.5)',
      '1.5::long_hair::',
      'SD转换：括号权重转换',
    ),
    TestCase(
      '(blue eyes)',
      '1.1::blue_eyes::',
      'SD转换：简单括号转换',
    ),
  ];

  var sdPassed = 0;
  var sdFailed = 0;

  for (final tc in sdTestCases) {
    final result = SdToNaiConverter.convert(tc.input);
    final success = result == tc.expected;

    if (success) {
      sdPassed++;
      print('✓ PASS: ${tc.description}');
    } else {
      sdFailed++;
      print('✗ FAIL: ${tc.description}');
      print('  输入: "${tc.input}"');
      print('  期望: "${tc.expected}"');
      print('  实际: "$result"');
    }
  }

  print('\n========================================');
  print('SD转换测试结果: $sdPassed 通过, $sdFailed 失败');
  print('========================================');
}
