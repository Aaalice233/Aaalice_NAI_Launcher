#!/usr/bin/env dart
// ignore_for_file: avoid_print

/*
预打包数据库生成脚本

从 HuggingFace 下载标签数据并生成预打包的 SQLite 数据库。
生成的数据库将被压缩并输出到 assets/database/ 目录。

使用方法:
dart scripts/build_prebuilt_database.dart
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// 配置
const String _baseUrl =
    'https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main';
const String _translationFileName = 'danbooru_tags.csv';
const String _cooccurrenceFileName = 'danbooru_tags_cooccurrence.csv';
const String _outputDir = 'assets/database';
const String _outputFileName = 'prebuilt_tags.db';
const String _compressedFileName = 'prebuilt_tags.db.gz';

/// 数据库版本号（用于应用内更新检测）
const int _databaseVersion = 1;

/// 进度回调
typedef ProgressCallback = void Function(String stage, double progress, String message);

void main(List<String> args) async {
  print('=' * 60);
  print('预打包标签数据库生成工具');
  print('=' * 60);

  final stopwatch = Stopwatch()..start();

  try {
    // 1. 初始化 SQLite FFI
    print('\n[1/6] 初始化 SQLite FFI...');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // 2. 创建临时目录
    print('\n[2/6] 创建临时目录...');
    final tempDir = await Directory.systemTemp.createTemp('tag_db_build_');
    print('  临时目录: ${tempDir.path}');

    // 3. 准备数据文件（使用本地文件，避免下载）
    print('\n[3/6] 准备标签数据文件...');

    // 使用本地翻译数据
    final localTranslationFile = File('assets/translations/hf_danbooru_tags.csv');
    final translationFile = File('${tempDir.path}/$_translationFileName');
    if (await localTranslationFile.exists()) {
      print('  使用本地翻译数据: ${localTranslationFile.path}');
      await localTranslationFile.copy(translationFile.path);
    } else {
      print('  警告: 未找到本地翻译数据，尝试下载...');
      final dio = Dio();
      dio.options.headers = {'User-Agent': 'NAI-Launcher-Build/1.0'};
      await _downloadFile(
        dio,
        '$_baseUrl/$_translationFileName',
        translationFile,
        '翻译数据',
      );
    }

    // 使用本地共现数据
    final localCooccurrenceFile = File('assets/translations/hf_danbooru_cooccurrence.csv');
    final cooccurrenceFile = File('${tempDir.path}/$_cooccurrenceFileName');
    if (await localCooccurrenceFile.exists()) {
      print('  使用本地共现数据: ${localCooccurrenceFile.path}');
      await localCooccurrenceFile.copy(cooccurrenceFile.path);
    } else {
      print('  警告: 未找到本地共现数据，尝试下载...');
      final dio = Dio();
      dio.options.headers = {'User-Agent': 'NAI-Launcher-Build/1.0'};
      await _downloadFile(
        dio,
        '$_baseUrl/$_cooccurrenceFileName',
        cooccurrenceFile,
        '共现数据',
      );
    }

    // 4. 创建数据库
    print('\n[4/6] 创建 SQLite 数据库...');
    final dbPath = '${tempDir.path}/$_outputFileName';
    final db = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );

    try {
      // 5. 导入 Danbooru 标签数据（新增）
      print('\n[5/7] 导入 Danbooru 标签数据...');
      await _importDanbooruTags(db);

      // 6. 导入翻译数据
      print('\n[6/7] 导入翻译数据...');
      await _importTranslations(db, translationFile);

      // 7. 导入共现数据
      print('\n[7/7] 导入共现数据...');
      await _importCooccurrences(db, cooccurrenceFile);

      // 8. 添加元数据
      await _addMetadata(db);

      print('\n  正在优化数据库...');
      await db.execute('VACUUM');
    } finally {
      await db.close();
    }

    // 8. 创建输出目录
    final outputDir = Directory(_outputDir);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    // 9. 压缩数据库
    print('\n[压缩] 压缩数据库文件...');
    final dbFile = File(dbPath);
    final compressedFile = File('$_outputDir/$_compressedFileName');
    await _compressFile(dbFile, compressedFile);

    // 10. 显示结果
    stopwatch.stop();

    final originalSize = await dbFile.length();
    final compressedSize = await compressedFile.length();
    final compressionRatio = (1 - compressedSize / originalSize) * 100;

    print('\n${'=' * 60}');
    print('生成完成!');
    print('=' * 60);
    print('原始大小: ${_formatBytes(originalSize)}');
    print('压缩后: ${_formatBytes(compressedSize)}');
    print('压缩率: ${compressionRatio.toStringAsFixed(1)}%');
    print('输出文件: ${compressedFile.path}');
    print('耗时: ${_formatDuration(stopwatch.elapsed)}');
    print('=' * 60);

    // 11. 清理临时文件
    print('\n清理临时文件...');
    await tempDir.delete(recursive: true);

    exit(0);
  } catch (e, stack) {
    print('\n\n❌ 错误: $e');
    if (args.contains('--verbose')) {
      print('\n堆栈跟踪:\n$stack');
    }
    exit(1);
  }
}

/// 创建数据库表
Future<void> _createTables(Database db) async {
  // translations 表
  await db.execute('''
    CREATE TABLE IF NOT EXISTS translations (
      tag TEXT PRIMARY KEY,
      zh_translation TEXT NOT NULL,
      source TEXT DEFAULT 'hf_translation',
      last_updated INTEGER NOT NULL
    )
  ''');

  // danbooru_tags 表（新增）
  await db.execute('''
    CREATE TABLE IF NOT EXISTS danbooru_tags (
      tag TEXT PRIMARY KEY,
      category INTEGER NOT NULL DEFAULT 0,
      post_count INTEGER NOT NULL DEFAULT 0,
      last_updated INTEGER NOT NULL
    )
  ''');

  // cooccurrences 表
  await db.execute('''
    CREATE TABLE IF NOT EXISTS cooccurrences (
      tag1 TEXT NOT NULL,
      tag2 TEXT NOT NULL,
      count INTEGER NOT NULL,
      cooccurrence_score REAL DEFAULT 0.0,
      PRIMARY KEY (tag1, tag2)
    )
  ''');

  // metadata 表
  await db.execute('''
    CREATE TABLE IF NOT EXISTS metadata (
      source TEXT NOT NULL PRIMARY KEY
        CHECK (source IN ('translations', 'danbooru_tags', 'cooccurrences', 'unified')),
      last_update INTEGER NOT NULL,
      data_version TEXT NOT NULL
    ) WITHOUT ROWID
  ''');

  // 创建索引
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_cooccurrences_tag1
    ON cooccurrences(tag1)
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_cooccurrences_count
    ON cooccurrences(count DESC)
  ''');

  // danbooru_tags 索引
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_danbooru_tags_post_count
    ON danbooru_tags(post_count DESC)
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_danbooru_tags_category
    ON danbooru_tags(category)
  ''');
}

/// 导入翻译数据
Future<void> _importTranslations(Database db, File file) async {
  final content = await file.readAsString();
  final lines = content.split('\n');

  // 跳过标题行
  final startIndex =
      lines.isNotEmpty && lines[0].contains(',') ? 1 : 0;

  final total = lines.length - startIndex;
  var imported = 0;
  var lastProgress = 0;

  // 使用事务批量插入
  await db.transaction((txn) async {
    final batch = txn.batch();

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length >= 2) {
        final tag = parts[0].trim().toLowerCase();
        final translation = parts[1].trim();

        if (tag.isNotEmpty && translation.isNotEmpty) {
          batch.insert(
            'translations',
            {
              'tag': tag,
              'zh_translation': translation,
              'source': 'hf_translation',
              'last_updated': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      imported++;

      // 每 10000 条提交一次
      if (imported % 10000 == 0) {
        await batch.commit(noResult: true);

        final progress = (imported / total * 100).toInt();
        if (progress > lastProgress) {
          stdout.write('\r  进度: $progress% ($imported / $total)');
          lastProgress = progress;
        }
      }
    }

    // 提交剩余数据
    await batch.commit(noResult: true);
  });

  print('\r  导入完成: $imported 条翻译记录');
}

/// 导入 Danbooru 标签数据
Future<void> _importDanbooruTags(Database db) async {
  // 从 assets 加载本地标签文件
  final tagFile = File('assets/translations/hf_danbooru_tags.csv');

  if (!await tagFile.exists()) {
    print('  警告: 未找到 Danbooru 标签文件，跳过导入');
    return;
  }

  final content = await tagFile.readAsString();
  final lines = content.split('\n');

  // 跳过标题行
  final startIndex = lines.isNotEmpty && lines[0].contains('tag,') ? 1 : 0;
  final total = lines.length - startIndex;

  var imported = 0;
  var lastProgress = 0;

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  await db.transaction((txn) async {
    final batch = txn.batch();

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 解析 CSV，处理引号内的逗号
      final parts = _parseCsvLine(line);
      if (parts.length >= 3) {
        final tag = parts[0].trim().toLowerCase();
        final category = int.tryParse(parts[1].trim()) ?? 0;
        final count = int.tryParse(parts[2].trim()) ?? 0;

        if (tag.isNotEmpty) {
          batch.insert(
            'danbooru_tags',
            {
              'tag': tag,
              'category': category,
              'post_count': count,
              'last_updated': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      imported++;

      // 每 10000 条提交一次
      if (imported % 10000 == 0) {
        await batch.commit(noResult: true);

        final progress = (imported / total * 100).toInt();
        if (progress > lastProgress) {
          stdout.write('\r  进度: $progress% ($imported / $total)');
          lastProgress = progress;
        }
      }
    }

    // 提交剩余数据
    await batch.commit(noResult: true);
  });

  print('\r  导入完成: $imported 条 Danbooru 标签记录');
}

/// 解析 CSV 行（简单处理引号）
List<String> _parseCsvLine(String line) {
  final result = <String>[];
  var current = '';
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];

    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      result.add(current.trim());
      current = '';
    } else {
      current += char;
    }
  }

  // 添加最后一个字段
  result.add(current.trim());

  return result;
}

/// 导入共现数据（流式处理，高性能版本）
Future<void> _importCooccurrences(Database db, File file) async {
  print('  导入共现数据（流式处理）...');

  // 导入前 200 万条高频共现数据（平衡文件大小和覆盖率）
  const maxCooccurrences = 2000000;
  const batchSize = 50000; // 增大每批数量

  var imported = 0;
  var lastProgress = -1;
  var lineCount = 0;

  // 先统计总行数（快速估算）
  print('  统计行数...');
  await for (final _ in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
    lineCount++;
  }
  print('  共约 $lineCount 行数据');

  // 流式读取并直接插入（跳过排序，CSV 已是按 count 降序）
  final stream = file.openRead().transform(utf8.decoder).transform(const LineSplitter());

  // 删除索引以加速插入
  await db.execute('DROP INDEX IF EXISTS idx_cooccurrences_tag1');
  await db.execute('DROP INDEX IF EXISTS idx_cooccurrences_count');
  await db.execute('PRAGMA journal_mode = MEMORY');
  await db.execute('PRAGMA synchronous = OFF');

  var batch = db.batch();
  var isFirstLine = true;

  await for (final line in stream) {
    // 跳过标题行
    if (isFirstLine) {
      isFirstLine = false;
      continue;
    }

    if (line.isEmpty) continue;

    final parts = line.split(',');
    if (parts.length >= 3) {
      final tag1 = parts[0].trim().toLowerCase();
      final tag2 = parts[1].trim().toLowerCase();
      final countDouble = double.tryParse(parts[2].trim()) ?? 0.0;
      final count = countDouble.toInt();

      if (tag1.isNotEmpty && tag2.isNotEmpty && count > 0) {
        batch.insert(
          'cooccurrences',
          {
            'tag1': tag1,
            'tag2': tag2,
            'count': count,
            'cooccurrence_score': 0.0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        imported++;

        // 每 batchSize 条提交一次
        if (imported % batchSize == 0) {
          await batch.commit(noResult: true);
          batch = db.batch();

          final progress = (imported / maxCooccurrences * 100).toInt();
          if (progress > lastProgress) {
            stdout.write('\r  进度: $progress% ($imported / $maxCooccurrences)');
            lastProgress = progress;
          }
        }

        // 达到上限时停止
        if (imported >= maxCooccurrences) break;
      }
    }
  }

  // 提交剩余数据
  if ((batch as dynamic).length > 0) {
    await batch.commit(noResult: true);
  }

  // 恢复设置并重建索引
  await db.execute('PRAGMA synchronous = NORMAL');
  await db.execute('PRAGMA journal_mode = WAL');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_cooccurrences_tag1
    ON cooccurrences(tag1)
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_cooccurrences_count
    ON cooccurrences(count DESC)
  ''');

  print('\r  导入完成: $imported 条共现记录');
}

/// 添加元数据
Future<void> _addMetadata(Database db) async {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  await db.insert(
    'metadata',
    {
      'source': 'unified',
      'last_update': now,
      'data_version': _databaseVersion.toString(),
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// 下载文件
Future<void> _downloadFile(
  Dio dio,
  String url,
  File outputFile,
  String description,
) async {
  print('  下载 $description...');

  final response = await dio.download(
    url,
    outputFile.path,
    onReceiveProgress: (received, total) {
      if (total > 0) {
        final progress = (received / total * 100).toInt();
        stdout.write('\r  进度: $progress%');
      }
    },
  );

  if (response.statusCode != 200) {
    throw Exception('下载失败: HTTP ${response.statusCode}');
  }

  final size = await outputFile.length();
  print('\r  下载完成: ${_formatBytes(size)}');
}

/// 压缩文件
Future<void> _compressFile(File input, File output) async {
  final inputBytes = await input.readAsBytes();

  // 使用 gzip 压缩
  final compressed = gzip.encode(inputBytes);
  await output.writeAsBytes(compressed);
}

/// 格式化字节数
String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  } else if (bytes >= 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  } else if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(2)} KB';
  } else {
    return '$bytes B';
  }
}

/// 格式化时间
String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes分$seconds秒';
}
