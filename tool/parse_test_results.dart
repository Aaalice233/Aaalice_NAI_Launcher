#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('test_results/bug_test_output.json');
  if (!file.existsSync()) {
    print('❌ Error: test_results/bug_test_output.json not found.');
    print('   Run: flutter test --reporter json > test_results/bug_test_output.json');
    exit(1);
  }
  final lines = await file.readAsLines();

  int totalTests = 0;
  int passedTests = 0;
  int failedTests = 0;
  int skippedTests = 0;

  // BUG test files we're tracking
  final bugTestFiles = {
    'vibe_encoding_test.dart',
    'sampler_test.dart',
    'seed_provider_test.dart',
    'auth_api_test.dart',
    'sidebar_state_test.dart',
    'query_parser_test.dart',
    'prompt_autofill_test.dart',
    'character_bar_test.dart',
  };

  final bugTestResults = <int, Map<String, dynamic>>{};

  for (final line in lines) {
    try {
      final json = jsonDecode(line);

      // Track test start
      if (json['type'] == 'testStart') {
        final testID = json['test']['id'] as int;
        final testUrl = json['test']['url'] as String? ?? '';
        final rootUrl = json['test']['root_url'] as String? ?? '';
        final testName = json['test']['name'] as String? ?? 'Unknown';

        // Check if this is a BUG test (filter out "loading" events)
        // For widget tests, url points to Flutter's test framework, root_url has the actual test file
        final actualUrl = (testUrl.contains('package:flutter_test') && rootUrl.isNotEmpty)
            ? rootUrl
            : (testUrl.isNotEmpty ? testUrl : rootUrl);

        if (!testName.startsWith('loading ') && actualUrl.isNotEmpty) {
          final isBugTest = bugTestFiles.any((file) => actualUrl.contains(file));

          if (isBugTest) {
            totalTests++;
            final testFile = bugTestFiles.firstWhere(
              (file) => actualUrl.contains(file),
              orElse: () => 'unknown',
            );

            bugTestResults[testID] = {
              'testID': testID,
              'file': testFile,
              'name': testName,
              'status': 'running',
            };
          }
        }
      }

      // Track test result
      if (json['type'] == 'testDone') {
        final testID = json['testID'] as int;

        // Find and update the test
        if (bugTestResults.containsKey(testID)) {
          final result = json['result'] as String? ?? 'error';
          final hidden = json['hidden'] as bool? ?? false;

          if (hidden) {
            skippedTests++;
            bugTestResults[testID]!['status'] = 'skipped';
          } else if (result == 'success') {
            passedTests++;
            bugTestResults[testID]!['status'] = 'passed';
          } else {
            failedTests++;
            bugTestResults[testID]!['status'] = 'failed';
            bugTestResults[testID]!['error'] = json['error'];
          }
        }
      }
    } catch (e) {
      // Skip invalid JSON lines
      continue;
    }
  }

  // Calculate pass rate
  final passRate = totalTests > 0 ? (passedTests / totalTests * 100) : 0.0;
  final success = passRate >= 90.0;

  // Print summary
  print('\n=== BUG TEST RESULTS SUMMARY ===\n');
  print('Total BUG Tests: $totalTests');
  print('Passed: $passedTests');
  print('Failed: $failedTests');
  print('Skipped: $skippedTests');
  print('Pass Rate: ${passRate.toStringAsFixed(2)}%');
  print('Target: >90%');
  print('Status: ${success ? "✅ PASS" : "❌ FAIL"}\n');

  // Print results by file
  print('\n=== RESULTS BY TEST FILE ===\n');
  for (final file in bugTestFiles) {
    final fileTests = bugTestResults.entries
        .where((entry) => entry.value['file'] == file)
        .toList();

    if (fileTests.isNotEmpty) {
      final filePassed = fileTests.where((t) => t.value['status'] == 'passed').length;
      final fileFailed = fileTests.where((t) => t.value['status'] == 'failed').length;
      final fileSkipped = fileTests.where((t) => t.value['status'] == 'skipped').length;

      print('$file:');
      print('  Total: ${fileTests.length}, Passed: $filePassed, Failed: $fileFailed, Skipped: $fileSkipped');

      // Print failed tests
      final failed = fileTests.where((t) => t.value['status'] == 'failed');
      if (failed.isNotEmpty) {
        print('  Failed tests:');
        for (final test in failed) {
          final testName = test.value['name'] as String? ?? 'Unknown';
          print('    - $testName');
          if (test.value['error'] != null) {
            print('      Error: ${test.value['error']}');
          }
        }
      }
      print('');
    }
  }

  // Create JSON summary
  final summary = {
    'totalTests': totalTests,
    'passedTests': passedTests,
    'failedTests': failedTests,
    'skippedTests': skippedTests,
    'passRate': passRate,
    'passRateThreshold': 90.0,
    'success': success,
    'timestamp': DateTime.now().toIso8601String(),
  };

  final summaryFile = File('test_results/bug_test_summary.json');
  await summaryFile.writeAsString(jsonEncode(summary));
  print('\n✅ Summary saved to: test_results/bug_test_summary.json\n');

  // Exit with appropriate code
  exit(success ? 0 : 1);
}
