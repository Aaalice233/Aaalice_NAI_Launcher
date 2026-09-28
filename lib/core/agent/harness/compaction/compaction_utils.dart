import 'dart:convert';

import '../../agent_types.dart';
import '../llm_helpers.dart';

/// 会话分支或 compaction 范围触碰的文件路径。
class FileOperations {
  final Set<String> read = {};
  final Set<String> written = {};
  final Set<String> edited = {};
}

/// 创建空的文件操作累积器。
FileOperations createFileOps() {
  return FileOperations();
}

/// 从助手工具调用中提取文件操作加入累积器。
void extractFileOpsFromMessage(AgentMessage message, FileOperations fileOps) {
  if (message is! AssistantMessage) {
    return;
  }
  for (final block in message.content) {
    if (block is! ToolCallContent) {
      continue;
    }
    final path = block.arguments['path'];
    if (path is! String || path.isEmpty) {
      continue;
    }
    switch (block.name) {
      case 'read':
        fileOps.read.add(path);
      case 'write':
        fileOps.written.add(path);
      case 'edit':
        fileOps.edited.add(path);
    }
  }
}

/// 从累积操作计算排序后的只读/已修改文件列表。
({List<String> readFiles, List<String> modifiedFiles}) computeFileLists(
  FileOperations fileOps,
) {
  final modified = {...fileOps.edited, ...fileOps.written};
  final readOnly = fileOps.read.where((f) => !modified.contains(f)).toList()
    ..sort();
  final modifiedFiles = modified.toList()..sort();
  return (readFiles: readOnly, modifiedFiles: modifiedFiles);
}

/// 把文件列表格式化为摘要元数据标签。
String formatFileOperations(
  List<String> readFiles,
  List<String> modifiedFiles,
) {
  final sections = <String>[];
  if (readFiles.isNotEmpty) {
    sections.add('<read-files>\n${readFiles.join('\n')}\n</read-files>');
  }
  if (modifiedFiles.isNotEmpty) {
    sections.add('<modified-files>\n${modifiedFiles.join('\n')}\n</modified-files>');
  }
  if (sections.isEmpty) {
    return '';
  }
  return '\n\n${sections.join('\n\n')}';
}

const int toolResultMaxChars = 2000;

String _safeJsonStringify(Object? value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return '[unserializable]';
  }
}

/// 公开形态（compaction.dart 的 estimateTokens 使用）。
String compactionSafeJsonStringify(Object? value) =>
    _safeJsonStringify(value);

/// 把 LLM 消息序列化为摘要提示词用的纯文本
/// 。
String serializeConversation(List<Message> messages) {
  final parts = <String>[];

  for (final msg in messages) {
    if (msg is UserMessage) {
      final content = userContentText(msg.content);
      if (content.isNotEmpty) {
        parts.add('[User]: $content');
      }
    } else if (msg is AssistantMessage) {
      final thinkingParts = <String>[];
      final toolCalls = <String>[];

      for (final block in msg.content) {
        if (block is AssistantThinkingContent) {
          thinkingParts.add(block.thinking);
        } else if (block is ToolCallContent) {
          final argsStr = block.arguments.entries
              .map((e) => '${e.key}=${_safeJsonStringify(e.value)}')
              .join(', ');
          toolCalls.add('${block.name}($argsStr)');
        }
      }

      if (thinkingParts.isNotEmpty) {
        parts.add('[Assistant thinking]: ${thinkingParts.join('\n')}');
      }
      if (msg.content.any((block) => block is AssistantTextContent)) {
        parts.add('[Assistant]: ${_assistantText(msg)}');
      }
      if (toolCalls.isNotEmpty) {
        parts.add('[Assistant tool calls]: ${toolCalls.join('; ')}');
      }
    } else if (msg is ToolResultMessage) {
      final content = msg.text;
      if (content.isNotEmpty) {
        parts.add('[Tool result]: ${_truncate(content, toolResultMaxChars)}');
      }
    }
  }

  return parts.join('\n\n');
}

String _assistantText(AssistantMessage message) {
  return message.content
      .whereType<AssistantTextContent>()
      .map((c) => c.text)
      .join();
}

String _truncate(String text, int maxChars) {
  if (text.length <= maxChars) {
    return text;
  }
  final truncatedChars = text.length - maxChars;
  return '${text.substring(0, maxChars)}\n\n[... $truncatedChars more characters truncated]';
}
