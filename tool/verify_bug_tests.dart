import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('test_results/summary.json');
  final json = jsonDecode(await file.readAsString());

  final resultsByFile = json['resultsByFile'] as List;
  final bugTestFiles = [
    'vibe_encoding_test.dart',
    'sampler_test.dart',
    'seed_provider_test.dart',
    'auth_api_test.dart',
    'sidebar_state_test.dart',
    'query_parser_test.dart',
    'prompt_autofill_test.dart',
    'character_bar_test.dart',
  ];

  final bugIdMap = {
    'vibe_encoding_test.dart': 'BUG-001',
    'sampler_test.dart': 'BUG-002',
    'seed_provider_test.dart': 'BUG-003',
    'auth_api_test.dart': 'BUG-004/005',
    'sidebar_state_test.dart': 'BUG-006',
    'query_parser_test.dart': 'BUG-007',
    'prompt_autofill_test.dart': 'BUG-008',
    'character_bar_test.dart': 'BUG-009',
  };

  print('=== BUG Tests Verification ===\n');

  var allPassed = true;
  var totalBugTests = 0;
  var passedBugTests = 0;

  for (final result in resultsByFile) {
    final file = result['file'] as String;
    if (bugTestFiles.contains(file)) {
      final bugId = bugIdMap[file] ?? 'UNKNOWN';
      final total = result['total'] as int;
      final passed = result['passed'] as int;
      final failed = result['failed'] as int;

      totalBugTests += total;
      passedBugTests += passed;

      final status = failed == 0 ? '✅ PASS' : '❌ FAIL';
      print('$status $bugId ($file): $passed/$total passed');

      if (failed > 0) {
        allPassed = false;
      }
    }
  }

  print('\n=== Summary ===');
  print('Total BUG Tests: $totalBugTests');
  print('Passed: $passedBugTests');
  print('Failed: ${totalBugTests - passedBugTests}');
  print('Pass Rate: ${(passedBugTests / totalBugTests * 100).toStringAsFixed(2)}%');
  print('\n${allPassed ? '✅ All BUG tests PASSED!' : '❌ Some BUG tests FAILED!'}');
}
