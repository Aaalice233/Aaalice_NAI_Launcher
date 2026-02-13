import 'dart:convert';
import 'dart:io';

import 'config/test_constants.dart';

void main() async {
  final file = File('test_results/summary.json');
  final json = jsonDecode(await file.readAsString());

  final resultsByFile = json['resultsByFile'] as List;

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
