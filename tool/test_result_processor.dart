#!/usr/bin/env dart
// 测试结果处理器 CLI 工具
// 用法: dart run tool/test_result_processor.dart <test_json_file> [options]

import 'dart:convert';
import 'dart:io';

import 'config/test_constants.dart' as constants;

void main(List<String> args) async {
  // 显示帮助信息
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(0);
  }

  // 解析参数
  final inputPath = args[0];
  final outputPath = args.length > 1 && !args[1].startsWith('-')
      ? args[1]
      : 'test_results/summary.json';

  // 验证输入文件
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    print('❌ 错误: 测试结果文件不存在 - $inputPath');
    print('   请先运行: flutter test --reporter json > $inputPath');
    exit(1);
  }

  print('正在处理测试结果: $inputPath');

  try {
    // 读取并解析测试结果
    final results = await _processTestResults(inputFile);

    // 生成摘要
    final summary = _generateSummary(results);

    // 输出摘要到控制台
    _printSummary(summary);

    // 保存 JSON 输出
    final outputFile = File(outputPath);
    await outputFile.writeAsString(
      jsonEncode(summary),
    );
    print('\n✅ 摘要已保存到: $outputPath');

    // 根据测试结果返回适当的退出码
    final summaryData = summary['summary'] as Map<String, dynamic>;
    final success = summaryData['success'] as bool;
    exit(success ? 0 : 1);
  } catch (e, stack) {
    print('❌ 处理失败: $e');
    print(stack);
    exit(1);
  }
}

void _printUsage() {
  print('测试结果处理器 - 解析 Flutter 测试 JSON 输出并生成结构化结果\n');
  print('用法:');
  print(
      '  dart run tool/test_result_processor.dart <input_file> [output_file]\n',);
  print('参数:');
  print('  input_file   Flutter 测试 JSON 输出文件路径');
  print(
      '               (通过: flutter test --reporter json > test_results/output.json 生成)',);
  print('  output_file  输出摘要 JSON 文件路径 (默认: test_results/summary.json)\n');
  print('选项:');
  print('  -h, --help   显示此帮助信息\n');
  print('示例:');
  print('  dart run tool/test_result_processor.dart test_results/output.json');
  print(
      '  dart run tool/test_result_processor.dart test_results/bug_test_output.json test_results/bug_summary.json\n',);
}

Future<Map<String, dynamic>> _processTestResults(File inputFile) async {
  final lines = await inputFile.readAsLines();

  int totalTests = 0;
  int passedTests = 0;
  int failedTests = 0;
  int skippedTests = 0;
  final testResults = <Map<String, dynamic>>[];
  final testFiles = <String>{};
  final errors = <Map<String, dynamic>>[];

  // 使用共享的 BUG 测试文件列表 (用于分类)
  const bugTestIdMap = constants.bugIdMap;

  final Map<int, Map<String, dynamic>> runningTests = {};

  for (final line in lines) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;

      // 跟踪测试开始
      if (json['type'] == 'testStart') {
        final testID = json['test']['id'] as int;
        final testUrl = json['test']['url'] as String? ?? '';
        final rootUrl = json['test']['root_url'] as String? ?? '';
        final testName = json['test']['name'] as String? ?? 'Unknown';
        final suiteID = json['suiteID'] as int?;

        // 过滤 "loading" 测试
        if (testName.startsWith('loading ')) {
          continue;
        }

        // 确定实际的测试文件 URL
        final actualUrl =
            (testUrl.contains('package:flutter_test') && rootUrl.isNotEmpty)
                ? rootUrl
                : (testUrl.isNotEmpty ? testUrl : rootUrl);

        // 提取测试文件名
        final testFile =
            actualUrl.isNotEmpty ? actualUrl.split('/').last : 'unknown';

        // 检测是否为 BUG 测试
        String? bugId;
        for (final entry in bugTestIdMap.entries) {
          if (actualUrl.contains(entry.key)) {
            bugId = entry.value;
            break;
          }
        }

        runningTests[testID] = {
          'testID': testID,
          'suiteID': suiteID,
          'file': testFile,
          'name': testName,
          'url': actualUrl,
          'bugId': bugId,
          'status': 'running',
          'startTime': DateTime.now().toIso8601String(),
        };

        testFiles.add(testFile);
      }

      // 跟踪测试结果
      if (json['type'] == 'testDone') {
        final testID = json['testID'] as int;
        final result = json['result'] as String? ?? 'error';
        final hidden = json['hidden'] as bool? ?? false;
        final time = json['time'] as int? ?? 0;

        if (runningTests.containsKey(testID)) {
          final test = runningTests[testID]!;
          test['status'] = hidden ? 'skipped' : result;
          test['duration'] = time;
          test['endTime'] = DateTime.now().toIso8601String();

          if (hidden) {
            skippedTests++;
          } else if (result == 'success') {
            passedTests++;
          } else {
            failedTests++;
            // 记录错误信息
            if (json['error'] != null) {
              test['error'] = json['error'];
              errors.add({
                'testID': testID,
                'file': test['file'],
                'name': test['name'],
                'error': json['error'],
                'stackTrace': json['stackTrace'],
              });
            }
          }

          totalTests++;
          testResults.add(test);
          runningTests.remove(testID);
        }
      }
    } catch (e) {
      // 跳过无效的 JSON 行
      continue;
    }
  }

  // 计算通过率
  final passRate = totalTests > 0 ? (passedTests / totalTests * 100) : 0.0;
  final success = passRate >= 90.0;

  // 按文件分组结果
  final resultsByFile = <String, Map<String, dynamic>>{};
  for (final test in testResults) {
    final file = test['file'] as String? ?? 'unknown';
    if (!resultsByFile.containsKey(file)) {
      resultsByFile[file] = {
        'file': file,
        'total': 0,
        'passed': 0,
        'failed': 0,
        'skipped': 0,
        'tests': <Map<String, dynamic>>[],
      };
    }

    final fileResults = resultsByFile[file]!;
    fileResults['total'] = (fileResults['total'] as int) + 1;
    final status = test['status'] as String? ?? 'unknown';

    if (status == 'success') {
      fileResults['passed'] = (fileResults['passed'] as int) + 1;
    } else if (status == 'skipped') {
      fileResults['skipped'] = (fileResults['skipped'] as int) + 1;
    } else if (status == 'error' || status == 'failure') {
      fileResults['failed'] = (fileResults['failed'] as int) + 1;
    }

    (fileResults['tests'] as List<Map<String, dynamic>>).add(test);
  }

  return {
    'totalTests': totalTests,
    'passedTests': passedTests,
    'failedTests': failedTests,
    'skippedTests': skippedTests,
    'passRate': passRate,
    'passRateThreshold': 90.0,
    'success': success,
    'timestamp': DateTime.now().toIso8601String(),
    'testFiles': testFiles.toList(),
    'resultsByFile': resultsByFile.values.toList(),
    'allTests': testResults,
    'errors': errors,
  };
}

Map<String, dynamic> _generateSummary(Map<String, dynamic> results) {
  return {
    'summary': {
      'totalTests': results['totalTests'],
      'passedTests': results['passedTests'],
      'failedTests': results['failedTests'],
      'skippedTests': results['skippedTests'],
      'passRate': results['passRate'],
      'passRateThreshold': results['passRateThreshold'],
      'success': results['success'],
      'timestamp': results['timestamp'],
    },
    'testFiles': results['testFiles'],
    'resultsByFile': results['resultsByFile'],
    'errors': results['errors'],
  };
}

void _printSummary(Map<String, dynamic> summary) {
  final summaryData = summary['summary'] as Map<String, dynamic>;

  print('\n=== 测试结果摘要 ===\n');
  print('总测试数: ${summaryData['totalTests']}');
  print('通过: ${summaryData['passedTests']}');
  print('失败: ${summaryData['failedTests']}');
  print('跳过: ${summaryData['skippedTests']}');
  print('通过率: ${(summaryData['passRate'] as num).toStringAsFixed(2)}%');
  print('目标: >90%');
  print('状态: ${summaryData['success'] == true ? "✅ PASS" : "❌ FAIL"}\n');

  // 打印按文件分组的结果
  final resultsByFile = summary['resultsByFile'] as List<dynamic>;
  if (resultsByFile.isNotEmpty) {
    print('=== 按测试文件分组 ===\n');
    for (final fileResult in resultsByFile) {
      final fileData = fileResult as Map<String, dynamic>;
      final file = fileData['file'] as String? ?? 'unknown';
      final total = fileData['total'] as int? ?? 0;
      final passed = fileData['passed'] as int? ?? 0;
      final failed = fileData['failed'] as int? ?? 0;
      final skipped = fileData['skipped'] as int? ?? 0;

      print('$file:');
      print('  总计: $total, 通过: $passed, 失败: $failed, 跳过: $skipped');

      // 打印失败的测试
      if (failed > 0) {
        final tests = fileData['tests'] as List<dynamic>;
        final failedTests = tests.where((t) {
          final test = t as Map<String, dynamic>;
          final status = test['status'] as String? ?? '';
          return status == 'error' || status == 'failure';
        });

        if (failedTests.isNotEmpty) {
          print('  失败的测试:');
          for (final test in failedTests) {
            final testName = test['name'] as String? ?? 'Unknown';
            print('    - $testName');
            if (test['error'] != null) {
              final error = test['error'] as String? ?? '';
              final errorPreview =
                  error.length > 100 ? '${error.substring(0, 100)}...' : error;
              print('      错误: $errorPreview');
            }
          }
        }
      }
      print('');
    }
  }

  // 打印错误摘要
  final errors = summary['errors'] as List<dynamic>;
  if (errors.isNotEmpty) {
    print('=== 错误摘要 ===\n');
    print('总错误数: ${errors.length}\n');
  }
}
