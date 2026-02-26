#!/usr/bin/env dart
// ignore_for_file: avoid_print, avoid_relative_lib_imports

/// 本地画廊元数据提取测试脚本
library test_metadata_extraction;
/// 
/// 用途：验证本地画廊中 PNG 图片的元数据提取情况
/// 功能：
/// - 遍历本地画廊目录
/// - 对所有 PNG 文件尝试提取元数据
/// - 统计有/无元数据的图片数量
/// - 列出无元数据的图片文件名
/// 
/// 运行方式：
/// dart tools/test_metadata_extraction.dart [--path <自定义路径>]

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

// 导入项目中的元数据解析器
// 注意：此脚本需要在项目根目录下运行，以正确解析导入
import '../lib/data/services/metadata/unified_metadata_parser.dart';
import '../lib/core/constants/storage_keys.dart';

/// 测试统计结果
class TestResult {
  final int totalImages;
  final int withMetadata;
  final int withoutMetadata;
  final List<String> filesWithoutMetadata;
  final Map<String, int> sourceFormatCounts;
  final List<MetadataDetail> metadataDetails;

  TestResult({
    required this.totalImages,
    required this.withMetadata,
    required this.withoutMetadata,
    required this.filesWithoutMetadata,
    required this.sourceFormatCounts,
    required this.metadataDetails,
  });

  double get metadataPercentage => 
      totalImages > 0 ? (withMetadata / totalImages * 100) : 0;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=' * 60);
    buffer.writeln('本地画廊元数据提取测试报告');
    buffer.writeln('=' * 60);
    buffer.writeln();
    buffer.writeln('总图片数: $totalImages');
    buffer.writeln('有元数据: $withMetadata (${metadataPercentage.toStringAsFixed(1)}%)');
    buffer.writeln('无元数据: $withoutMetadata');
    buffer.writeln();
    
    if (sourceFormatCounts.isNotEmpty) {
      buffer.writeln('元数据来源分布:');
      sourceFormatCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..forEach((e) {
          buffer.writeln('  ${e.key}: ${e.value}');
        });
      buffer.writeln();
    }
    
    if (filesWithoutMetadata.isNotEmpty) {
      buffer.writeln('无元数据的文件列表:');
      buffer.writeln('-' * 40);
      for (final file in filesWithoutMetadata) {
        buffer.writeln('  - $file');
      }
      buffer.writeln();
    }
    
    buffer.writeln('=' * 60);
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'totalImages': totalImages,
    'withMetadata': withMetadata,
    'withoutMetadata': withoutMetadata,
    'metadataPercentage': metadataPercentage,
    'sourceFormatCounts': sourceFormatCounts,
    'filesWithoutMetadata': filesWithoutMetadata,
    'metadataDetails': metadataDetails.map((d) => d.toJson()).toList(),
  };
}

/// 元数据详情
class MetadataDetail {
  final String filename;
  final bool hasMetadata;
  final String? sourceFormat;
  final String? prompt;
  final String? model;
  final String? software;
  final Duration? parseTime;

  MetadataDetail({
    required this.filename,
    required this.hasMetadata,
    this.sourceFormat,
    this.prompt,
    this.model,
    this.software,
    this.parseTime,
  });

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'hasMetadata': hasMetadata,
    'sourceFormat': sourceFormat,
    'prompt': prompt?.substring(0, prompt!.length > 100 ? 100 : prompt!.length),
    'model': model,
    'software': software,
    'parseTimeMs': parseTime?.inMilliseconds,
  };
}

/// 获取画廊根路径
/// 
/// 1. 首先检查命令行参数 --path
/// 2. 然后从 Hive 配置中读取 image_save_path
/// 3. 最后使用默认路径 (Documents/NAI_Launcher/images)
Future<String?> getGalleryRootPath(List<String> args) async {
  // 1. 检查命令行参数
  final pathIndex = args.indexOf('--path');
  if (pathIndex != -1 && pathIndex + 1 < args.length) {
    final customPath = args[pathIndex + 1];
    print('使用命令行指定的路径: $customPath');
    return customPath;
  }

  // 2. 从 Hive 配置中读取
  try {
    // 初始化 Hive
    final appDir = await getApplicationDocumentsDirectory();
    final hivePath = p.join(appDir.path, 'NAI_Launcher', 'hive');
    Hive.init(hivePath);
    
    // 打开 settings box
    final settingsBox = await Hive.openBox<dynamic>('settings');
    final customPath = settingsBox.get(StorageKeys.imageSavePath) as String?;
    await settingsBox.close();
    
    if (customPath != null && customPath.isNotEmpty) {
      print('从配置读取的路径: $customPath');
      return customPath;
    }
  } catch (e) {
    print('读取配置失败: $e');
  }

  // 3. 使用默认路径
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final defaultPath = p.join(appDir.path, 'NAI_Launcher', 'images');
    print('使用默认路径: $defaultPath');
    return defaultPath;
  } catch (e) {
    print('获取默认路径失败: $e');
  }

  return null;
}

/// 递归获取所有 PNG 文件
Future<List<File>> findPngFiles(Directory dir) async {
  final files = <File>[];
  
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (ext == '.png') {
          files.add(entity);
        }
      }
    }
  } catch (e) {
    print('扫描目录时出错: $e');
  }
  
  return files;
}

/// 测试元数据提取
Future<TestResult> testMetadataExtraction(String rootPath) async {
  final dir = Directory(rootPath);
  if (!dir.existsSync()) {
    throw Exception('目录不存在: $rootPath');
  }

  print('正在扫描 PNG 文件...');
  final pngFiles = await findPngFiles(dir);
  print('找到 ${pngFiles.length} 个 PNG 文件');
  print('');

  int withMetadata = 0;
  int withoutMetadata = 0;
  final filesWithoutMetadata = <String>[];
  final sourceFormatCounts = <String, int>{};
  final metadataDetails = <MetadataDetail>[];

  // 用于显示进度
  final total = pngFiles.length;
  final progressInterval = total > 100 ? total ~/ 10 : 1;

  for (var i = 0; i < pngFiles.length; i++) {
    final file = pngFiles[i];
    final relativePath = p.relative(file.path, from: rootPath);

    // 显示进度
    if ((i + 1) % progressInterval == 0 || i == 0 || i == total - 1) {
      final percent = ((i + 1) / total * 100).toStringAsFixed(1);
      stdout.write('\r进度: $percent% (${i + 1}/$total)');
    }

    // 使用 UnifiedMetadataParser 提取元数据
    final result = UnifiedMetadataParser.parseFromFile(
      file.path,
      useGradualRead: true,
      useCache: false, // 测试时不使用缓存
    );

    if (result.success && result.metadata != null) {
      withMetadata++;
      
      // 统计来源格式
      final source = result.sourceFormat ?? 'Unknown';
      sourceFormatCounts[source] = (sourceFormatCounts[source] ?? 0) + 1;

      // 记录详情（只记录前100个有元数据的文件，避免内存占用过大）
      if (metadataDetails.length < 100) {
        metadataDetails.add(MetadataDetail(
          filename: relativePath,
          hasMetadata: true,
          sourceFormat: result.sourceFormat,
          prompt: result.metadata!.prompt,
          model: result.metadata!.model,
          software: result.metadata!.software,
          parseTime: result.parseTime,
        ),);
      }
    } else {
      withoutMetadata++;
      filesWithoutMetadata.add(relativePath);

      // 记录详情（只记录前100个无元数据的文件）
      if (metadataDetails.length < 100) {
        metadataDetails.add(MetadataDetail(
          filename: relativePath,
          hasMetadata: false,
          parseTime: result.parseTime,
        ),);
      }
    }
  }

  stdout.writeln(); // 换行
  stdout.writeln();

  return TestResult(
    totalImages: pngFiles.length,
    withMetadata: withMetadata,
    withoutMetadata: withoutMetadata,
    filesWithoutMetadata: filesWithoutMetadata,
    sourceFormatCounts: sourceFormatCounts,
    metadataDetails: metadataDetails,
  );
}

/// 保存详细报告到文件
Future<void> saveDetailedReport(TestResult result, String outputPath) async {
  final file = File(outputPath);
  final json = const JsonEncoder.withIndent('  ').convert(result.toJson());
  await file.writeAsString(json);
  print('详细报告已保存到: $outputPath');
}

/// 打印使用说明
void printUsage() {
  print('''
用法: dart tools/test_metadata_extraction.dart [选项]

选项:
  --path <路径>     指定画廊目录路径（覆盖配置中的路径）
  --output <路径>   保存详细报告到 JSON 文件
  --help            显示此帮助信息

示例:
  dart tools/test_metadata_extraction.dart
  dart tools/test_metadata_extraction.dart --path D:\\MyImages
  dart tools/test_metadata_extraction.dart --output report.json
''');
}

Future<void> main(List<String> args) async {
  // 检查帮助参数
  if (args.contains('--help') || args.contains('-h')) {
    printUsage();
    return;
  }

  print('=' * 60);
  print('本地画廊元数据提取测试');
  print('=' * 60);
  print('');

  // 获取画廊路径
  final rootPath = await getGalleryRootPath(args);
  if (rootPath == null) {
    print('错误: 无法确定画廊路径');
    print('请使用 --path 参数指定路径，或确保应用配置正确');
    exit(1);
  }

  print('扫描目录: $rootPath');
  print('');

  // 检查目录是否存在
  final dir = Directory(rootPath);
  if (!dir.existsSync()) {
    print('错误: 目录不存在: $rootPath');
    print('');
    print('可能的解决方案:');
    print('  1. 使用 --path 指定正确的路径');
    print('  2. 在应用中配置正确的图片保存位置');
    print('  3. 确保目录已被创建');
    exit(1);
  }

  // 执行测试
  final stopwatch = Stopwatch()..start();
  
  try {
    final result = await testMetadataExtraction(rootPath);
    stopwatch.stop();

    print('测试完成! 耗时: ${stopwatch.elapsed.inSeconds} 秒');
    print('');
    print(result);

    // 保存详细报告（如果指定了 --output）
    final outputIndex = args.indexOf('--output');
    if (outputIndex != -1 && outputIndex + 1 < args.length) {
      final outputPath = args[outputIndex + 1];
      await saveDetailedReport(result, outputPath);
    }

    // 根据结果返回退出码
    if (result.totalImages == 0) {
      print('警告: 未找到任何 PNG 文件');
      exit(2);
    } else if (result.withoutMetadata == result.totalImages) {
      print('警告: 所有图片都未检测到元数据');
      exit(3);
    } else if (result.metadataPercentage < 50) {
      print('提示: 少于一半的图片有元数据，建议检查图片来源');
      exit(0);
    }

  } catch (e, stack) {
    print('测试失败: $e');
    if (args.contains('--verbose')) {
      print(stack);
    }
    exit(1);
  }
}
