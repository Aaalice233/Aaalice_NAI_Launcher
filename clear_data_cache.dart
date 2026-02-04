#!/usr/bin/env dart
// 清空数据源缓存脚本
// 运行: dart clear_data_cache.dart

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() async {
  print('========================================');
  print('  清空 NAI Launcher 数据源缓存');
  print('========================================\n');

  try {
    // 获取应用支持目录
    final appDir = await getApplicationSupportDirectory();
    print('应用数据目录: ${appDir.path}\n');

    // 需要删除的文件列表
    final filesToDelete = [
      // SQLite 数据库
      path.join(appDir.path, 'databases', 'cooccurrence.db'),
      path.join(appDir.path, 'databases', 'translation.db'),
      path.join(appDir.path, 'databases', 'danbooru_tags.db'),

      // 元数据文件
      path.join(appDir.path, 'cooccurrence_meta.json'),
      path.join(appDir.path, 'danbooru_tags_meta.json'),
      path.join(appDir.path, 'danbooru_artists_meta.json'),
      path.join(appDir.path, 'translation_meta.json'),
      path.join(appDir.path, 'tags_meta.json'),

      // CSV 缓存文件
      path.join(appDir.path, 'danbooru_artists.csv'),
      path.join(appDir.path, 'tags.csv'),
      path.join(appDir.path, 'translation.csv'),
      path.join(appDir.path, 'translation_zh.csv'),

      // 旧版二进制缓存
      path.join(appDir.path, 'cooccurrence_data.bin'),
      path.join(appDir.path, 'cooccurrence_cache.json'),
    ];

    // 删除文件
    int deletedCount = 0;
    int notFoundCount = 0;
    int errorCount = 0;

    for (final filePath in filesToDelete) {
      final file = File(filePath);
      final fileName = path.basename(filePath);

      if (await file.exists()) {
        try {
          await file.delete();
          print('✓ 已删除: $fileName');
          deletedCount++;
        } catch (e) {
          print('✗ 删除失败: $fileName - $e');
          errorCount++;
        }
      } else {
        print('○ 不存在: $fileName');
        notFoundCount++;
      }
    }

    // 删除数据库目录中的其他文件
    final dbDir = Directory(path.join(appDir.path, 'databases'));
    if (await dbDir.exists()) {
      print('\n--- 清理数据库目录 ---');
      final dbFiles = await dbDir.list().toList();
      for (final entity in dbFiles) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          // 跳过已处理的文件
          if (!filesToDelete.contains(entity.path)) {
            try {
              await entity.delete();
              print('✓ 已删除: $fileName');
              deletedCount++;
            } catch (e) {
              print('✗ 删除失败: $fileName - $e');
              errorCount++;
            }
          }
        }
      }
    }

    print('\n========================================');
    print('  清理完成');
    print('========================================');
    print('已删除: $deletedCount 个文件');
    print('不存在: $notFoundCount 个文件');
    print('失败: $errorCount 个文件');
    print('\n下次启动时将重新从网络下载数据。');
    print('========================================');

  } catch (e, stack) {
    print('\n✗ 错误: $e');
    print('堆栈: $stack');
    exit(1);
  }
}
