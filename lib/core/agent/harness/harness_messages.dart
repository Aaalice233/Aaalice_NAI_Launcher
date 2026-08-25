import '../agent_types.dart';


export 'llm_helpers.dart';

const String compactionSummaryPrefix =
    'The conversation history before this point was compacted into the '
    'following summary:\n\n<summary>\n';

const String compactionSummarySuffix = '\n</summary>';

const String branchSummaryPrefix =
    'The following is a summary of a branch that this conversation came '
    'back from:\n\n<summary>\n';

const String branchSummarySuffix = '\n</summary>';

/// bash 执行记录（RPC bash 命令产物，非 LLM 工具调用）。
class BashExecutionMessage extends CustomMessage {
  const BashExecutionMessage({
    required this.command,
    required this.output,
    required this.exitCode,
    required this.cancelled,
    required this.truncated,
    this.fullOutputPath,
    this.excludeFromContext,
    required super.timestamp,
  });

  final String command;
  final String output;
  final int? exitCode;
  final bool cancelled;
  final bool truncated;
  final String? fullOutputPath;
  final bool? excludeFromContext;

  @override
  String get role => 'bashExecution';
}

/// 应用自定义展示消息。
class HarnessCustomMessage extends CustomMessage {
  const HarnessCustomMessage({
    required this.customType,
    required this.display,
    required super.timestamp,
    this.textContent,
    this.blockContent,
    this.details,
  });

  final String customType;

  /// 字符串内容或内容块列表（二选一）。
  final String? textContent;
  final List<UserContent>? blockContent;
  final bool display;
  final dynamic details;

  @override
  String get role => 'custom';

  List<UserContent> get content {
    final text = textContent;
    if (text != null) {
      return [UserTextContent(text)];
    }
    return blockContent ?? const [];
  }
}

/// 分支返回摘要。
class BranchSummaryMessage extends CustomMessage {
  const BranchSummaryMessage({
    required this.summary,
    required this.fromId,
    required super.timestamp,
  });

  final String summary;
  final String fromId;

  @override
  String get role => 'branchSummary';
}

/// compaction 摘要。
class CompactionSummaryMessage extends CustomMessage {
  const CompactionSummaryMessage({
    required this.summary,
    required this.tokensBefore,
    required super.timestamp,
  });

  final String summary;
  final int tokensBefore;

  @override
  String get role => 'compactionSummary';
}

BranchSummaryMessage createBranchSummaryMessage(
  String summary,
  String fromId,
  int timestamp,
) {
  return BranchSummaryMessage(
    summary: summary,
    fromId: fromId,
    timestamp: timestamp,
  );
}

CompactionSummaryMessage createCompactionSummaryMessage(
  String summary,
  int tokensBefore,
  int timestamp,
) {
  return CompactionSummaryMessage(
    summary: summary,
    tokensBefore: tokensBefore,
    timestamp: timestamp,
  );
}

HarnessCustomMessage createCustomMessage(
  String customType,
  Object content,
  bool display,
  dynamic details,
  int timestamp,
) {
  return HarnessCustomMessage(
    customType: customType,
    display: display,
    details: details,
    timestamp: timestamp,
    textContent: content is String ? content : null,
    blockContent: content is List<UserContent> ? content : null,
  );
}

String bashExecutionToText(BashExecutionMessage msg) {
  var text = 'Ran `${msg.command}`\n';
  if (msg.output.isNotEmpty) {
    text += '```\n${msg.output}\n```';
  } else {
    text += '(no output)';
  }
  if (msg.cancelled) {
    text += '\n\n(command cancelled)';
  } else if (msg.exitCode != null && msg.exitCode != 0) {
    text += '\n\nCommand exited with code ${msg.exitCode}';
  }
  if (msg.truncated && msg.fullOutputPath != null) {
    text += '\n\n[Output truncated. Full output: ${msg.fullOutputPath}]';
  }
  return text;
}

/// AgentMessage[] → LLM Message[]（循环边界的唯一转换点）。
List<Message> harnessConvertToLlm(List<AgentMessage> messages) {
  final result = <Message>[];
  for (final message in messages) {
    if (message is BashExecutionMessage) {
      if (message.excludeFromContext == true) {
        continue;
      }
      result.add(
        UserMessage(
          content: [UserTextContent(bashExecutionToText(message))],
          timestamp: message.timestamp,
        ),
      );
    } else if (message is HarnessCustomMessage) {
      result.add(
        UserMessage(content: message.content, timestamp: message.timestamp),
      );
    } else if (message is BranchSummaryMessage) {
      result.add(
        UserMessage(
          content: [
            UserTextContent(
              branchSummaryPrefix + message.summary + branchSummarySuffix,
            ),
          ],
          timestamp: message.timestamp,
        ),
      );
    } else if (message is CompactionSummaryMessage) {
      result.add(
        UserMessage(
          content: [
            UserTextContent(
              compactionSummaryPrefix + message.summary + compactionSummarySuffix,
            ),
          ],
          timestamp: message.timestamp,
        ),
      );
    } else if (message is UserMessage ||
        message is AssistantMessage ||
        message is ToolResultMessage) {
      result.add(message);
    }
  }
  return result;
}
