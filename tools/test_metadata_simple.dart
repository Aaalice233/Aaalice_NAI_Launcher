#!/usr/bin/env dart
// 纯Dart脚本，测试PNG元数据提取
// 不依赖Flutter，可以直接用 dart run 运行

import 'dart:convert';
import 'dart:io';

// 简化版的PNG元数据提取器
// 只检查 tEXt 和 zTXt chunk 中的常见元数据字段

class SimpleMetadataResult {
  final bool hasMetadata;
  final String? source;
  final Map<String, String>? textData;
  final String? prompt;
  final String fileName;

  SimpleMetadataResult({
    required this.hasMetadata,
    this.source,
    this.textData,
    this.prompt,
    required this.fileName,
  });
}

/// 检查PNG文件中的文本块
SimpleMetadataResult extractMetadata(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return SimpleMetadataResult(hasMetadata: false, fileName: filePath);
  }

  try {
    final bytes = file.readAsBytesSync();
    
    // 检查PNG签名
    if (bytes.length < 8 || 
        bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47) {
      return SimpleMetadataResult(hasMetadata: false, fileName: filePath);
    }

    final textData = <String, String>{};
    var offset = 8; // 跳过PNG签名

    while (offset < bytes.length) {
      if (offset + 12 > bytes.length) break;

      // 读取chunk长度（4字节，大端序）
      final length = (bytes[offset] << 24) | 
                     (bytes[offset + 1] << 16) | 
                     (bytes[offset + 2] << 8) | 
                     bytes[offset + 3];

      // 读取chunk类型（4字节）
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));

      // 检查边界
      if (offset + 12 + length > bytes.length) break;

      // 读取chunk数据
      final data = bytes.sublist(offset + 8, offset + 8 + length);

      // 解析tEXt chunk
      if (type == 'tEXt' && length > 0) {
        final nullIndex = data.indexOf(0);
        if (nullIndex > 0) {
          final keyword = utf8.decode(data.sublist(0, nullIndex));
          final text = utf8.decode(data.sublist(nullIndex + 1));
          textData[keyword] = text;
        }
      }

      // 解析zTXt chunk（压缩文本）
      if (type == 'zTXt' && length > 0) {
        final nullIndex = data.indexOf(0);
        if (nullIndex > 0) {
          final keyword = utf8.decode(data.sublist(0, nullIndex));
          // zTXt的文本是压缩的，这里只标记存在
          textData[keyword] = '[zTXt compressed]';
        }
      }

      // 移动到下一个chunk
      offset += 12 + length;

      // IEND chunk表示文件结束
      if (type == 'IEND') break;
    }

    // 检查是否有常见的元数据字段
    final hasComment = textData.containsKey('Comment') && textData['Comment']!.isNotEmpty;
    final hasParameters = textData.containsKey('parameters') && textData['parameters']!.isNotEmpty;
    final hasNai = textData.containsKey('nai') || textData.containsKey('novelai');

    String? source;
    if (hasComment) {
      source = 'Comment';
    } else if (hasParameters) source = 'parameters';
    else if (hasNai) source = 'nai/novelai';

    // 尝试提取prompt
    String? prompt;
    if (hasComment) {
      try {
        final json = jsonDecode(textData['Comment']!) as Map<String, dynamic>;
        prompt = json['prompt'] as String?;
      } catch (_) {
        prompt = textData['Comment']!.length > 50 
            ? '${textData['Comment']!.substring(0, 50)}...'
            : textData['Comment'];
      }
    } else if (hasParameters) {
      final params = textData['parameters']!;
      final lines = params.split('\n');
      if (lines.isNotEmpty) {
        prompt = lines[0].length > 50 
            ? '${lines[0].substring(0, 50)}...'
            : lines[0];
      }
    }

    final hasMetadata = hasComment || hasParameters || hasNai;

    return SimpleMetadataResult(
      hasMetadata: hasMetadata,
      source: source,
      textData: textData.keys.toList().join(', ').isEmpty ? null : 
                Map.fromEntries(textData.entries.map((e) => MapEntry(e.key, 
                    e.value.length > 30 ? '${e.value.substring(0, 30)}...' : e.value,),),),
      prompt: prompt,
      fileName: file.path.split(Platform.pathSeparator).last,
    );

  } catch (e) {
    return SimpleMetadataResult(
      hasMetadata: false, 
      fileName: filePath,
      source: 'Error: $e',
    );
  }
}

void main(List<String> args) async {
  const testDir = r'C:\Users\Administrator\Documents\nai_launcher\images\test_batch';
  
  print('========================================');
  print('PNG 元数据检测脚本');
  print('目录: $testDir');
  print('========================================\n');

  final dir = Directory(testDir);
  if (!dir.existsSync()) {
    print('❌ 目录不存在: $testDir');
    exit(1);
  }

  final files = dir.listSync()
      .where((f) => f is File && f.path.toLowerCase().endsWith('.png'))
      .cast<File>()
      .toList();

  print('找到 ${files.length} 个 PNG 文件\n');

  int hasMetadata = 0;
  int noMetadata = 0;
  final noMetadataFiles = <String>[];
  final metadataSources = <String, int>{};

  // 检测所有文件
  final testFiles = files;
  
  print('正在检测全部 ${testFiles.length} 个文件...\n');

  for (var i = 0; i < testFiles.length; i++) {
    final file = testFiles[i];
    final result = extractMetadata(file.path);

    if (result.hasMetadata) {
      hasMetadata++;
      final source = result.source ?? 'Unknown';
      metadataSources[source] = (metadataSources[source] ?? 0) + 1;
      
      // 只打印前5个有元数据的文件详情
      if (hasMetadata <= 5) {
        print('✅ ${result.fileName}');
        print('   来源: ${result.source}');
        print('   Prompt: ${result.prompt ?? "N/A"}');
        print('   所有字段: ${result.textData?.keys.join(", ")}');
        print('');
      }
    } else {
      noMetadata++;
      noMetadataFiles.add(result.fileName);
    }

    // 每10个文件显示一次进度
    if ((i + 1) % 10 == 0) {
      stdout.write('\r进度: ${i + 1}/${testFiles.length} (${((i+1)/testFiles.length*100).toStringAsFixed(1)}%)');
    }
  }

  print('\n\n========================================');
  print('检测结果统计 (前 ${testFiles.length} 个文件)');
  print('========================================');
  print('有元数据: $hasMetadata (${(hasMetadata/testFiles.length*100).toStringAsFixed(1)}%)');
  print('无元数据: $noMetadata (${(noMetadata/testFiles.length*100).toStringAsFixed(1)}%)');
  print('\n元数据来源分布:');
  metadataSources.forEach((source, count) {
    print('  - $source: $count');
  });

  if (noMetadataFiles.isNotEmpty && noMetadataFiles.length <= 20) {
    print('\n无元数据的文件列表:');
    for (final name in noMetadataFiles) {
      print('  - $name');
    }
  } else if (noMetadataFiles.length > 20) {
    print('\n无元数据的前20个文件:');
    for (final name in noMetadataFiles.take(20)) {
      print('  - $name');
    }
    print('  ... 还有 ${noMetadataFiles.length - 20} 个文件');
  }

  // 如果要检测所有文件，需要更多时间
  if (files.length > 100) {
    print('\n\n提示: 只检测了前100个文件');
    print('要检测所有 ${files.length} 个文件，请修改脚本中的 testFiles 逻辑');
  }
}
