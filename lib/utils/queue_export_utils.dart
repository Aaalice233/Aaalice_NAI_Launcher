import 'dart:convert';

import '../../../data/models/queue/replication_task.dart';

/// 队列导出/导入工具类
class QueueExportUtils {
  QueueExportUtils._();

  /// 导出为 JSON 字符串
  static String exportToJson(List<ReplicationTask> tasks) {
    final taskList = ReplicationTaskList(tasks: tasks);
    final encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(taskList.toJson());
  }

  /// 导出为 CSV 字符串（仅提示词）
  static String exportToCsv(List<ReplicationTask> tasks) {
    final buffer = StringBuffer();

    // CSV 头
    buffer.writeln('prompt,negative_prompt,source,created_at');

    for (final task in tasks) {
      final prompt = _escapeCsvField(task.prompt);
      final negativePrompt = _escapeCsvField(task.negativePrompt);
      final source = task.source.name;
      final createdAt = task.createdAt.toIso8601String();

      buffer.writeln('$prompt,$negativePrompt,$source,$createdAt');
    }

    return buffer.toString();
  }

  /// 导出为纯文本（每行一个提示词）
  static String exportToText(List<ReplicationTask> tasks) {
    return tasks.map((t) => t.prompt).join('\n');
  }

  /// 从 JSON 字符串导入
  static List<ReplicationTask> importFromJson(String json) {
    try {
      final decoded = jsonDecode(json);

      // 尝试解析为 ReplicationTaskList 格式
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('tasks')) {
          final taskList = ReplicationTaskList.fromJson(decoded);
          return taskList.tasks;
        }

        // 单个任务
        return [ReplicationTask.fromJson(decoded)];
      }

      // 任务数组
      if (decoded is List) {
        return decoded
            .map((item) =>
                ReplicationTask.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      throw FormatException('无效的 JSON 格式: $e');
    }
  }

  /// 从纯文本导入（每行一个提示词）
  static List<ReplicationTask> importFromText(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return lines
        .map((prompt) => ReplicationTask.create(prompt: prompt))
        .toList();
  }

  /// 从 CSV 导入
  static List<ReplicationTask> importFromCsv(String csv) {
    final lines = csv.split('\n');
    if (lines.isEmpty) return [];

    // 跳过头行
    final dataLines = lines.skip(1).where((line) => line.trim().isNotEmpty);

    final tasks = <ReplicationTask>[];

    for (final line in dataLines) {
      final fields = _parseCsvLine(line);
      if (fields.isEmpty) continue;

      final prompt = fields.isNotEmpty ? fields[0] : '';
      final negativePrompt = fields.length > 1 ? fields[1] : '';

      if (prompt.isNotEmpty) {
        tasks.add(ReplicationTask.create(
          prompt: prompt,
          negativePrompt: negativePrompt,
        ));
      }
    }

    return tasks;
  }

  /// 转义 CSV 字段
  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// 解析 CSV 行
  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            current.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          current.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          fields.add(current.toString());
          current = StringBuffer();
        } else {
          current.write(char);
        }
      }
    }

    fields.add(current.toString());
    return fields;
  }
}

/// 导出格式
enum ExportFormat {
  json('JSON', 'json'),
  csv('CSV', 'csv'),
  text('纯文本', 'txt');

  final String displayName;
  final String extension;

  const ExportFormat(this.displayName, this.extension);
}

/// 导入策略
enum ImportStrategy {
  merge('合并', '将导入的任务添加到现有队列末尾'),
  replace('覆盖', '清空现有队列，使用导入的任务替换');

  final String displayName;
  final String description;

  const ImportStrategy(this.displayName, this.description);
}
