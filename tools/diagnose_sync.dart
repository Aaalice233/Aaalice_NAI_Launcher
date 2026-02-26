#!/usr/bin/env dart
// 诊断工具：检查固定词和词库的同步状态
// 用法: dart tools/diagnose_sync.dart

import 'dart:convert';
import 'dart:io';

void main() {
  print('========================================');
  print('双向同步诊断工具');
  print('========================================\n');

  // 检查固定词存储文件
  final fixedTagsPath = _getFixedTagsPath();
  print('1. 检查固定词存储文件');
  print('   路径: $fixedTagsPath');
  
  if (!File(fixedTagsPath).existsSync()) {
    print('   状态: ❌ 文件不存在\n');
    return;
  }
  
  final fixedTagsContent = File(fixedTagsPath).readAsStringSync();
  if (fixedTagsContent.isEmpty) {
    print('   状态: ⚠️ 文件为空\n');
    return;
  }

  List<dynamic> fixedTags;
  try {
    fixedTags = jsonDecode(fixedTagsContent) as List<dynamic>;
    print('   状态: ✅ 找到 ${fixedTags.length} 个固定词\n');
  } catch (e) {
    print('   状态: ❌ JSON 解析失败: $e\n');
    return;
  }

  // 分析固定词
  print('2. 分析固定词');
  int withSourceId = 0;
  int withoutSourceId = 0;
  
  for (final tag in fixedTags) {
    final sourceId = tag['sourceEntryId'];
    final name = tag['name'] ?? '未命名';
    
    if (sourceId != null && sourceId.isNotEmpty) {
      withSourceId++;
      print('   ✅ $name (关联ID: $sourceId)');
    } else {
      withoutSourceId++;
      print('   ⚠️ $name (无关联)');
    }
  }
  
  print('');
  print('   统计: $withSourceId 个已关联, $withoutSourceId 个未关联\n');

  // 检查词库存储文件
  final tagLibraryPath = _getTagLibraryPath();
  print('3. 检查词库存储文件');
  print('   路径: $tagLibraryPath');
  
  if (!File(tagLibraryPath).existsSync()) {
    print('   状态: ❌ 文件不存在\n');
    return;
  }
  
  final tagLibraryContent = File(tagLibraryPath).readAsStringSync();
  if (tagLibraryContent.isEmpty) {
    print('   状态: ⚠️ 文件为空\n');
    return;
  }

  Map<String, dynamic> tagLibrary;
  try {
    tagLibrary = jsonDecode(tagLibraryContent) as Map<String, dynamic>;
    final entries = tagLibrary['entries'] as List<dynamic>? ?? [];
    print('   状态: ✅ 找到 ${entries.length} 个词库条目\n');
  } catch (e) {
    print('   状态: ❌ JSON 解析失败: $e\n');
    return;
  }

  // 验证关联
  print('4. 验证关联');
  final entries = (tagLibrary['entries'] as List<dynamic>? ?? []);
  final entryIds = entries.map((e) => e['id'] as String?).toSet();
  
  int validLinks = 0;
  int brokenLinks = 0;
  
  for (final tag in fixedTags) {
    final sourceId = tag['sourceEntryId'] as String?;
    final name = tag['name'] ?? '未命名';
    
    if (sourceId != null && sourceId.isNotEmpty) {
      if (entryIds.contains(sourceId)) {
        validLinks++;
      } else {
        brokenLinks++;
        print('   ⚠️ $name 关联的词库条目不存在 (ID: $sourceId)');
      }
    }
  }
  
  if (validLinks > 0 && brokenLinks == 0) {
    print('   ✅ 所有关联都有效 ($validLinks 个)');
  } else if (brokenLinks > 0) {
    print('   ⚠️ 发现 $brokenLinks 个无效关联');
  }
  
  print('');

  // 总结
  print('========================================');
  print('诊断总结');
  print('========================================');
  
  if (withoutSourceId > 0) {
    print('⚠️  有 $withoutSourceId 个固定词没有关联词库条目');
    print('   这些固定词是在修复前添加的，需要删除后重新添加才能启用同步。');
    print('');
  }
  
  if (brokenLinks > 0) {
    print('⚠️  有 $brokenLinks 个固定词关联了不存在的词库条目');
    print('   词库条目可能已被删除。');
    print('');
  }
  
  if (withSourceId == 0) {
    print('ℹ️  没有关联的固定词');
    print('   请从词库添加固定词来建立关联。');
    print('');
  } else if (validLinks > 0 && brokenLinks == 0 && withoutSourceId == 0) {
    print('✅ 所有固定词都正确关联到词库条目');
    print('   双向同步应该正常工作。');
    print('');
  }
  
  print('修复建议:');
  print('1. 删除没有关联的固定词，重新从词库添加');
  print('2. 删除关联失效的固定词');
  print('3. 确保代码已更新到最新版本');
}

String _getFixedTagsPath() {
  final home = Platform.environment['USERPROFILE'] ?? 
               Platform.environment['HOME'] ?? 
               '';
  return '$home\\AppData\\Roaming\\com.example\\nai_launcher\\fixed_tags.json';
}

String _getTagLibraryPath() {
  final home = Platform.environment['USERPROFILE'] ?? 
               Platform.environment['HOME'] ?? 
               '';
  return '$home\\AppData\\Roaming\\com.example\\nai_launcher\\tag_library.json';
}
