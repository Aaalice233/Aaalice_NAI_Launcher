/* ============================================
   Coverage Processor Tool
   NovelAI Universal Launcher
   ============================================ */

import 'dart:convert';
import 'dart:io';

/// Coverage data for a single file
class FileCoverage {
  final String filePath;
  final int linesFound;
  final int linesHit;
  final double percentage;

  FileCoverage({
    required this.filePath,
    required this.linesFound,
    required this.linesHit,
    required this.percentage,
  });

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'linesFound': linesFound,
      'linesHit': linesHit,
      'percentage': percentage,
    };
  }
}

/// Coverage data for a module
class ModuleCoverage {
  final String moduleName;
  final List<FileCoverage> files;
  final int totalLinesFound;
  final int totalLinesHit;
  final double percentage;

  ModuleCoverage({
    required this.moduleName,
    required this.files,
    required this.totalLinesFound,
    required this.totalLinesHit,
    required this.percentage,
  });

  Map<String, dynamic> toJson() {
    return {
      'moduleName': moduleName,
      'files': files.map((f) => f.toJson()).toList(),
      'totalLinesFound': totalLinesFound,
      'totalLinesHit': totalLinesHit,
      'percentage': percentage,
    };
  }
}

/// Overall coverage data
class CoverageData {
  final List<ModuleCoverage> modules;
  final int totalLinesFound;
  final int totalLinesHit;
  final double percentage;

  CoverageData({
    required this.modules,
    required this.totalLinesFound,
    required this.totalLinesHit,
    required this.percentage,
  });

  Map<String, dynamic> toJson() {
    return {
      'modules': modules.map((m) => m.toJson()).toList(),
      'totalLinesFound': totalLinesFound,
      'totalLinesHit': totalLinesHit,
      'percentage': percentage,
    };
  }
}

/// Parse lcov.info file and generate coverage JSON
void main(List<String> arguments) {
  // Default input/output paths
  String inputPath = 'coverage/lcov.info';
  String outputPath = 'test_results/coverage.json';

  // Parse command line arguments
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--input' && i + 1 < arguments.length) {
      inputPath = arguments[i + 1];
    } else if (arguments[i] == '--output' && i + 1 < arguments.length) {
      outputPath = arguments[i + 1];
    } else if (arguments[i] == '--help' || arguments[i] == '-h') {
      print('Usage: dart run tool/coverage_processor.dart [options]');
      print('');
      print('Options:');
      print('  --input <path>   Input lcov.info file (default: coverage/lcov.info)');
      print('  --output <path>  Output JSON file (default: test_results/coverage.json)');
      print('  --help, -h       Show this help message');
      print('');
      print('Example:');
      print('  dart run tool/coverage_processor.dart --input coverage/lcov.info --output test_results/coverage.json');
      return;
    }
  }

  try {
    // Read lcov.info file
    final file = File(inputPath);
    if (!file.existsSync()) {
      print('❌ 错误: 找不到文件 $inputPath');
      print('提示: 请先运行 "flutter test --coverage" 生成覆盖率数据');
      exit(1);
    }

    final lines = file.readAsLinesSync();

    // Parse coverage data
    final fileCoverages = _parseLcov(lines);

    if (fileCoverages.isEmpty) {
      print('⚠️  警告: 未找到覆盖率数据');
      exit(0);
    }

    // Group by module
    final moduleMap = <String, List<FileCoverage>>{};
    for (var coverage in fileCoverages) {
      final moduleName = _extractModuleName(coverage.filePath);
      moduleMap.putIfAbsent(moduleName, () => []).add(coverage);
    }

    // Calculate module coverage
    final modules = moduleMap.entries.map((entry) {
      final files = entry.value;
      final totalLinesFound = files.fold<int>(0, (sum, f) => sum + f.linesFound);
      final totalLinesHit = files.fold<int>(0, (sum, f) => sum + f.linesHit);
      final percentage = totalLinesFound > 0
          ? (totalLinesHit / totalLinesFound * 100)
          : 0.0;

      return ModuleCoverage(
        moduleName: entry.key,
        files: files,
        totalLinesFound: totalLinesFound,
        totalLinesHit: totalLinesHit,
        percentage: percentage,
      );
    }).toList();

    // Sort modules by percentage (descending)
    modules.sort((a, b) => b.percentage.compareTo(a.percentage));

    // Calculate overall coverage
    final overallLinesFound = modules.fold<int>(0, (sum, m) => sum + m.totalLinesFound);
    final overallLinesHit = modules.fold<int>(0, (sum, m) => sum + m.totalLinesHit);
    final overallPercentage = overallLinesFound > 0
        ? (overallLinesHit / overallLinesFound * 100)
        : 0.0;

    final coverageData = CoverageData(
      modules: modules,
      totalLinesFound: overallLinesFound,
      totalLinesHit: overallLinesHit,
      percentage: overallPercentage,
    );

    // Write output JSON
    final outputFile = File(outputPath);
    outputFile.createSync(recursive: true);
    outputFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(coverageData.toJson()),
    );

    // Print summary
    print('✅ 覆盖率数据处理完成');
    print('');
    print('总体覆盖率: ${overallPercentage.toStringAsFixed(1)}% ($overallLinesHit/$overallLinesFound 行)');
    print('模块数量: ${modules.length}');
    print('文件数量: ${fileCoverages.length}');
    print('');
    print('各模块覆盖率:');
    for (var module in modules) {
      print('  ${module.moduleName}: ${module.percentage.toStringAsFixed(1)}% (${module.files.length} 个文件)');
    }
    print('');
    print('输出文件: $outputPath');

    // Exit with success code
    exit(0);

  } catch (e, stack) {
    print('❌ 错误: $e');
    print(stack);
    exit(1);
  }
}

/// Parse lcov.info format
List<FileCoverage> _parseLcov(List<String> lines) {
  final fileCoverages = <FileCoverage>[];

  String? currentFile;
  int linesFound = 0;
  int linesHit = 0;

  for (var line in lines) {
    if (line.startsWith('SF:')) {
      // Save previous file if exists
      if (currentFile != null) {
        final percentage = linesFound > 0 ? (linesHit / linesFound * 100) : 0.0;
        fileCoverages.add(FileCoverage(
          filePath: currentFile,
          linesFound: linesFound,
          linesHit: linesHit,
          percentage: percentage,
        ),);
      }

      // Start new file
      currentFile = line.substring(3);
      linesFound = 0;
      linesHit = 0;
    } else if (line.startsWith('LF:')) {
      linesFound = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit = int.parse(line.substring(3));
    } else if (line == 'end_of_record') {
      // Save current file
      if (currentFile != null) {
        final percentage = linesFound > 0 ? (linesHit / linesFound * 100) : 0.0;
        fileCoverages.add(FileCoverage(
          filePath: currentFile,
          linesFound: linesFound,
          linesHit: linesHit,
          percentage: percentage,
        ),);
      }

      // Reset for next file
      currentFile = null;
      linesFound = 0;
      linesHit = 0;
    }
  }

  // Handle last file if not closed properly
  if (currentFile != null) {
    final percentage = linesFound > 0 ? (linesHit / linesFound * 100) : 0.0;
    fileCoverages.add(FileCoverage(
      filePath: currentFile,
      linesFound: linesFound,
      linesHit: linesHit,
      percentage: percentage,
    ),);
  }

  return fileCoverages;
}

/// Extract module name from file path
String _extractModuleName(String filePath) {
  // Convert backslashes to forward slashes (Windows)
  final normalizedPath = filePath.replaceAll('\\', '/');

  // Extract module from lib/XXX/YYY/...
  final libIndex = normalizedPath.indexOf('lib/');
  if (libIndex == -1) {
    return 'Other';
  }

  final afterLib = normalizedPath.substring(libIndex + 4);
  final segments = afterLib.split('/');

  if (segments.isEmpty) {
    return 'Root';
  }

  // First segment after lib/ is the module
  final module = segments[0];

  // Map module names to display names
  final moduleNames = {
    'core': 'Core',
    'data': 'Data Layer',
    'domain': 'Domain Layer',
    'presentation': 'Presentation Layer',
    'widgets': 'Widgets',
  };

  return moduleNames[module] ?? module.toUpperCase();
}
