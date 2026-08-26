import '../../agent_types.dart';
import '../harness_messages.dart';
import '../harness_types.dart';
import '../session/session_context.dart';
import '../session/session_types.dart';
import 'compaction_utils.dart';

/// 上下文压缩：估算上下文 token、判定压缩阈值、选择保留切点，并以
/// 结构化摘要折叠旧历史（支持拆分 turn 的双段摘要与迭代更新）。

/// compaction 条目上存储的文件操作明细。
class CompactionDetails {
  const CompactionDetails({
    required this.readFiles,
    required this.modifiedFiles,
  });

  final List<String> readFiles;
  final List<String> modifiedFiles;
}

/// 生成完毕、待持久化为 compaction 条目的数据。
class CompactResult {
  const CompactResult({
    required this.summary,
    required this.tokensBefore,
    required this.retainedTail,
    this.usage,
    this.details,
  });

  /// 替代被压缩历史的摘要文本。
  final String summary;

  /// compaction 前的估算上下文 token。
  final int tokensBefore;

  /// 摘要生成调用的用量（可用时）。
  final Usage? usage;

  /// 直接存于 compaction 条目的保留近期消息。
  final List<AgentMessage> retainedTail;

  /// 实现特定的明细。
  final dynamic details;
}

Future<AssistantMessage> completeSimpleWithRetries(
  CompleteSimpleFn completeSimple,
  Model model,
  Context context,
  SimpleStreamOptions options, [
  RetryPolicy? retry,
  RetryCallbacks? callbacks,
]) {
  // 摘要是独立请求：隔离路由并避免不可复用的缓存写入。
  final requestOptions = SimpleStreamOptions(
    apiKey: options.apiKey,
    signal: options.signal,
    sessionId: uuidv7(),
    reasoning: options.reasoning,
    maxRetryDelayMs: options.maxRetryDelayMs,
  );
  return retryAssistantCall(
    () => completeSimple(model, context, requestOptions),
    retry,
    options.signal,
    callbacks,
  );
}

Usage _combineUsage(Usage first, Usage second) {
  return first + second;
}

/// compaction 阈值与保留设置。
class CompactionSettings {
  const CompactionSettings({
    required this.enabled,
    required this.reserveTokens,
    required this.keepRecentTokens,
  });

  /// 启用自动 compaction 决策。
  final bool enabled;

  /// 为摘要提示词与输出预留的 token。
  final int reserveTokens;

  /// compaction 后保留的近似近期上下文 token。
  final int keepRecentTokens;

  CompactionSettings copyWith({
    bool? enabled,
    int? reserveTokens,
    int? keepRecentTokens,
  }) {
    return CompactionSettings(
      enabled: enabled ?? this.enabled,
      reserveTokens: reserveTokens ?? this.reserveTokens,
      keepRecentTokens: keepRecentTokens ?? this.keepRecentTokens,
    );
  }
}

/// harness 使用的默认 compaction 设置。
const CompactionSettings defaultCompactionSettings = CompactionSettings(
  enabled: true,
  reserveTokens: 16384,
  keepRecentTokens: 20000,
);

/// 由 provider 用量计算总上下文 token。
int calculateContextTokens(Usage usage) {
  return usage.totalTokens != 0
      ? usage.totalTokens
      : usage.input + usage.output + usage.cacheRead + usage.cacheWrite;
}

Usage? _getAssistantUsage(AgentMessage message) {
  if (message is AssistantMessage &&
      message.stopReason != StopReason.aborted &&
      message.stopReason != StopReason.error &&
      message.usage != null &&
      calculateContextTokens(message.usage!) > 0) {
    return message.usage;
  }
  return null;
}

/// 返回会话条目中最后一条有效助手消息的用量。
Usage? getLastAssistantUsage(List<SessionEntry> entries) {
  for (var i = entries.length - 1; i >= 0; i--) {
    final entry = entries[i];
    if (entry is MessageEntry) {
      final usage = _getAssistantUsage(entry.message);
      if (usage != null) {
        return usage;
      }
    }
  }
  return null;
}

/// 消息列表的估算上下文用量。
class ContextUsageEstimate {
  const ContextUsageEstimate({
    required this.tokens,
    required this.usageTokens,
    required this.trailingTokens,
    required this.lastUsageIndex,
  });

  final int tokens;
  final int usageTokens;
  final int trailingTokens;

  /// 提供用量的消息下标；不存在时为 null。
  final int? lastUsageIndex;
}

({Usage usage, int index})? _getLastAssistantUsageInfo(
  List<AgentMessage> messages,
) {
  for (var i = messages.length - 1; i >= 0; i--) {
    final usage = _getAssistantUsage(messages[i]);
    if (usage != null) {
      return (usage: usage, index: i);
    }
  }
  return null;
}

/// 可用时基于 provider 用量估算上下文 token。
ContextUsageEstimate estimateContextTokens(List<AgentMessage> messages) {
  final usageInfo = _getLastAssistantUsageInfo(messages);

  if (usageInfo == null) {
    var estimated = 0;
    for (final message in messages) {
      estimated += estimateTokens(message);
    }
    return ContextUsageEstimate(
      tokens: estimated,
      usageTokens: 0,
      trailingTokens: estimated,
      lastUsageIndex: null,
    );
  }

  final usageTokens = calculateContextTokens(usageInfo.usage);
  var trailingTokens = 0;
  for (var i = usageInfo.index + 1; i < messages.length; i++) {
    trailingTokens += estimateTokens(messages[i]);
  }

  return ContextUsageEstimate(
    tokens: usageTokens + trailingTokens,
    usageTokens: usageTokens,
    trailingTokens: trailingTokens,
    lastUsageIndex: usageInfo.index,
  );
}

/// 上下文用量是否超过配置的 compaction 阈值。
bool shouldCompact(
  int contextTokens,
  int contextWindow,
  CompactionSettings settings,
) {
  if (!settings.enabled) {
    return false;
  }
  return contextTokens > contextWindow - settings.reserveTokens;
}

const int _estimatedImageChars = 4800;

int _estimateTextAndImageContentChars(Object content) {
  if (content is String) {
    return content.length;
  }
  var chars = 0;
  if (content is List<UserContent>) {
    for (final block in content) {
      if (block is UserTextContent) {
        chars += block.text.length;
      } else if (block is UserImageContent) {
        chars += _estimatedImageChars;
      }
    }
  } else if (content is List<ToolResultContent>) {
    for (final block in content) {
      if (block is ToolResultTextContent) {
        chars += block.text.length;
      } else if (block is ToolResultImageContent) {
        chars += _estimatedImageChars;
      }
    }
  }
  return chars;
}

/// 用保守的字符启发式估算单条消息的 token 数。
int estimateTokens(AgentMessage message) {
  var chars = 0;

  if (message is UserMessage) {
    chars = _estimateTextAndImageContentChars(message.content);
    return (chars / 4).ceil();
  }
  if (message is AssistantMessage) {
    for (final block in message.content) {
      if (block is AssistantTextContent) {
        chars += block.text.length;
      } else if (block is AssistantThinkingContent) {
        chars += block.thinking.length;
      } else if (block is ToolCallContent) {
        chars += block.name.length +
            compactionSafeJsonStringify(block.arguments).length;
      }
    }
    return (chars / 4).ceil();
  }
  if (message is ToolResultMessage) {
    chars = _estimateTextAndImageContentChars(message.content);
    return (chars / 4).ceil();
  }
  if (message is BashExecutionMessage) {
    chars = message.command.length + message.output.length;
    return (chars / 4).ceil();
  }
  if (message is BranchSummaryMessage) {
    chars = message.summary.length;
    return (chars / 4).ceil();
  }
  if (message is CompactionSummaryMessage) {
    chars = message.summary.length;
    return (chars / 4).ceil();
  }
  return 0;
}

List<int> _findValidCutPoints(
  List<SessionEntry> entries,
  int startIndex,
  int endIndex,
) {
  final cutPoints = <int>[];
  for (var i = startIndex; i < endIndex; i++) {
    final entry = entries[i];
    if (entry is MessageEntry) {
      final role = entry.message.role;
      const eligible = {
        'bashExecution',
        'custom',
        'branchSummary',
        'compactionSummary',
        'user',
        'assistant',
      };
      if (eligible.contains(role)) {
        cutPoints.add(i);
      }
    } else if (entry is BranchSummaryEntry) {
      cutPoints.add(i);
    }
  }
  return cutPoints;
}

/// 找到包含某条目的 turn 的用户可见起始消息。
int findTurnStartIndex(
  List<SessionEntry> entries,
  int entryIndex,
  int startIndex,
) {
  for (var i = entryIndex; i >= startIndex; i--) {
    final entry = entries[i];
    if (entry is BranchSummaryEntry) {
      return i;
    }
    if (entry is MessageEntry) {
      final role = entry.message.role;
      if (role == 'user' || role == 'bashExecution') {
        return i;
      }
    }
  }
  return -1;
}

/// compaction 选定的切点。
class CutPointResult {
  const CutPointResult({
    required this.firstKeptEntryIndex,
    required this.turnStartIndex,
    required this.isSplitTurn,
  });

  /// compaction 后保留的首条条目下标。
  final int firstKeptEntryIndex;

  /// 切点拆分 turn 时的 turn 起始条目下标；否则 -1。
  final int turnStartIndex;

  /// 选定切点是否拆分进行中的 turn。
  final bool isSplitTurn;
}

/// 找到保留约请求近期 token 预算的 compaction 切点。
CutPointResult findCutPoint(
  List<SessionEntry> entries,
  int startIndex,
  int endIndex,
  int keepRecentTokens,
) {
  final cutPoints = _findValidCutPoints(entries, startIndex, endIndex);

  if (cutPoints.isEmpty) {
    return CutPointResult(
      firstKeptEntryIndex: startIndex,
      turnStartIndex: -1,
      isSplitTurn: false,
    );
  }
  var accumulatedTokens = 0;
  var cutIndex = cutPoints[0];

  for (var i = endIndex - 1; i >= startIndex; i--) {
    final entry = entries[i];
    if (entry is! MessageEntry) {
      continue;
    }
    accumulatedTokens += estimateTokens(entry.message);
    if (accumulatedTokens >= keepRecentTokens) {
      for (var c = 0; c < cutPoints.length; c++) {
        if (cutPoints[c] >= i) {
          cutIndex = cutPoints[c];
          break;
        }
      }
      break;
    }
  }
  while (cutIndex > startIndex) {
    final prevEntry = entries[cutIndex - 1];
    if (prevEntry is CompactionEntry || prevEntry is MessageEntry) {
      break;
    }
    cutIndex--;
  }
  final cutEntry = entries[cutIndex];
  final isUserMessage =
      cutEntry is MessageEntry && cutEntry.message.role == 'user';
  final turnStartIndex =
      isUserMessage ? -1 : findTurnStartIndex(entries, cutIndex, startIndex);

  return CutPointResult(
    firstKeptEntryIndex: cutIndex,
    turnStartIndex: turnStartIndex,
    isSplitTurn: !isUserMessage && turnStartIndex != -1,
  );
}

const String summarizationSystemPrompt =
    'You are a context summarization assistant. Your task is to read a '
    'conversation between a user and an AI assistant, then produce a '
    'structured summary following the exact format specified.\n\n'
    'Do NOT continue the conversation. Do NOT respond to any questions in '
    'the conversation. ONLY output the structured summary.';

const String _summarizationPrompt =
    'The messages above are a conversation to summarize. Create a structured '
    'context checkpoint summary that another LLM will use to continue the '
    'work.\n\n'
    'Use this EXACT format:\n\n'
    '## Goal\n'
    '[What is the user trying to accomplish? Can be multiple items if the '
    'session covers different tasks.]\n\n'
    '## Constraints & Preferences\n'
    '- [Any constraints, preferences, or requirements mentioned by user]\n'
    '- [Or "(none)" if none were mentioned]\n\n'
    '## Progress\n'
    '### Done\n'
    '- [x] [Completed tasks/changes]\n\n'
    '### In Progress\n'
    '- [ ] [Current work]\n\n'
    '### Blocked\n'
    '- [Issues preventing progress, if any]\n\n'
    '## Key Decisions\n'
    '- **[Decision]**: [Brief rationale]\n\n'
    '## Next Steps\n'
    '1. [Ordered list of what should happen next]\n\n'
    '## Critical Context\n'
    '- [Any data, examples, or references needed to continue]\n'
    '- [Or "(none)" if not applicable]\n\n'
    'Keep each section concise. Preserve exact file paths, function names, '
    'and error messages.';

const String _updateSummarizationPrompt =
    'The messages above are NEW conversation messages to incorporate into '
    'the existing summary provided in <previous-summary> tags.\n\n'
    'Update the existing structured summary with new information. RULES:\n'
    '- PRESERVE all existing information from the previous summary\n'
    '- ADD new progress, decisions, and context from the new messages\n'
    '- UPDATE the Progress section: move items from "In Progress" to "Done" '
    'when completed\n'
    '- UPDATE "Next Steps" based on what was accomplished\n'
    '- PRESERVE exact file paths, function names, and error messages\n'
    '- If something is no longer relevant, you may remove it\n\n'
    'Use this EXACT format:\n\n'
    '## Goal\n'
    '[Preserve existing goals, add new ones if the task expanded]\n\n'
    '## Constraints & Preferences\n'
    '- [Preserve existing, add new ones discovered]\n\n'
    '## Progress\n'
    '### Done\n'
    '- [x] [Include previously done items AND newly completed items]\n\n'
    '### In Progress\n'
    '- [ ] [Current work - update based on progress]\n\n'
    '### Blocked\n'
    '- [Current blockers - remove if resolved]\n\n'
    '## Key Decisions\n'
    '- **[Decision]**: [Brief rationale] (preserve all previous, add new)\n\n'
    '## Next Steps\n'
    '1. [Update based on current state]\n\n'
    '## Critical Context\n'
    '- [Preserve important context, add new if needed]\n\n'
    'Keep each section concise. Preserve exact file paths, function names, '
    'and error messages.';

/// 生成或更新 compaction 用会话摘要。
Future<HarnessResult<String, CompactionError>> generateSummary(
  List<AgentMessage> currentMessages,
  CompleteSimpleFn completeSimple,
  Model model,
  int reserveTokens, {
  AbortSignal? signal,
  String? customInstructions,
  String? previousSummary,
  String? thinkingLevel,
  RetryPolicy? retry,
  RetryCallbacks? callbacks,
}) async {
  final result = await generateSummaryWithUsage(
    currentMessages,
    completeSimple,
    model,
    reserveTokens,
    signal: signal,
    customInstructions: customInstructions,
    previousSummary: previousSummary,
    thinkingLevel: thinkingLevel,
    retry: retry,
    callbacks: callbacks,
  );
  final value = result.valueOrNull;
  if (value != null) {
    return ok(value.text);
  }
  return err(result.errorOrNull!);
}

/// 生成或更新会话摘要并返回其 provider 用量。
Future<
    HarnessResult<({String text, Usage usage}), CompactionError>
>
generateSummaryWithUsage(
  List<AgentMessage> currentMessages,
  CompleteSimpleFn completeSimple,
  Model model,
  int reserveTokens, {
  AbortSignal? signal,
  String? customInstructions,
  String? previousSummary,
  String? thinkingLevel,
  RetryPolicy? retry,
  RetryCallbacks? callbacks,
}) async {
  final maxTokens = model.maxTokens > 0
      ? (0.8 * reserveTokens).floor().clamp(0, model.maxTokens)
      : (0.8 * reserveTokens).floor();
  var basePrompt = previousSummary != null
      ? _updateSummarizationPrompt
      : _summarizationPrompt;
  if (customInstructions != null && customInstructions.isNotEmpty) {
    basePrompt = '$basePrompt\n\nAdditional focus: $customInstructions';
  }
  final llmMessages = harnessConvertToLlm(currentMessages);
  final conversationText = serializeConversation(llmMessages);
  var promptText = '<conversation>\n$conversationText\n</conversation>\n\n';
  if (previousSummary != null) {
    promptText += '<previous-summary>\n$previousSummary\n</previous-summary>\n\n';
  }
  promptText += basePrompt;

  final summarizationMessages = <Message>[
    UserMessage(
      content: [UserTextContent(promptText)],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ),
  ];

  final response = await completeSimpleWithRetries(
    completeSimple,
    model,
    Context(
      systemPrompt: summarizationSystemPrompt,
      messages: summarizationMessages,
    ),
    SimpleStreamOptions(
      signal: signal,
      reasoning: model.reasoning &&
              thinkingLevel != null &&
              thinkingLevel != 'off'
          ? thinkingLevel
          : null,
      maxTokens: maxTokens,
    ),
    retry,
    callbacks,
  );
  if (response.stopReason == StopReason.aborted) {
    return err(
      CompactionError(
        CompactionErrorCode.aborted,
        response.errorMessage ?? 'Summarization aborted',
      ),
    );
  }
  if (response.stopReason == StopReason.error) {
    return err(
      CompactionError(
        CompactionErrorCode.summarizationFailed,
        'Summarization failed: ${response.errorMessage ?? "Unknown error"}',
      ),
    );
  }

  final textContent = assistantContentText(response);

  return ok((text: textContent, usage: response.usage ?? const Usage()));
}

String assistantContentText(AssistantMessage message) {
  return message.content
      .whereType<AssistantTextContent>()
      .map((c) => c.text)
      .join();
}

/// 一次 compaction 运行的准备输入。
class CompactionPreparation {
  const CompactionPreparation({
    required this.messagesToSummarize,
    required this.turnPrefixMessages,
    required this.retainedTail,
    required this.isSplitTurn,
    required this.tokensBefore,
    required this.fileOps,
    required this.settings,
    this.previousSummary,
  });

  /// 被摘要进历史摘要的消息。
  final List<AgentMessage> messagesToSummarize;

  /// compaction 拆分 turn 时单独摘要的前缀消息。
  final List<AgentMessage> turnPrefixMessages;

  /// compaction 后保留、存于 compaction 条目的近期消息。
  final List<AgentMessage> retainedTail;

  /// 是否拆分 turn。
  final bool isSplitTurn;

  /// compaction 前的估算上下文 token。
  final int tokensBefore;

  /// 迭代更新用的上一次 compaction 摘要。
  final String? previousSummary;

  /// 从被摘要历史提取的文件操作。
  final FileOperations fileOps;

  /// 准备 compaction 所用设置。
  final CompactionSettings settings;
}

AgentMessage? _getMessageFromEntry(SessionEntry entry) {
  if (entry is MessageEntry) {
    return entry.message;
  }
  if (entry is BranchSummaryEntry) {
    return createBranchSummaryMessage(entry.summary, entry.fromId, entry.timestamp);
  }
  if (entry is CompactionEntry) {
    return createCompactionSummaryMessage(
      entry.summary,
      entry.tokensBefore,
      entry.timestamp,
    );
  }
  return null;
}

AgentMessage? _getMessageFromEntryForCompaction(SessionEntry entry) {
  if (entry is CompactionEntry) {
    return null;
  }
  return _getMessageFromEntry(entry);
}

/// 准备会话条目的 compaction；不适用时返回 ok(null)。
HarnessResult<CompactionPreparation?, CompactionError> prepareCompaction(
  List<SessionEntry> pathEntries,
  CompactionSettings settings,
) {
  if (pathEntries.isEmpty || pathEntries.last is CompactionEntry) {
    return ok(null);
  }

  var prevCompactionIndex = -1;
  for (var i = pathEntries.length - 1; i >= 0; i--) {
    if (pathEntries[i] is CompactionEntry) {
      prevCompactionIndex = i;
      break;
    }
  }

  String? previousSummary;
  var compactableEntries = pathEntries;
  if (prevCompactionIndex >= 0) {
    final prevCompaction = pathEntries[prevCompactionIndex] as CompactionEntry;
    previousSummary = prevCompaction.summary;
    final virtualRetainedEntries = <SessionEntry>[
      for (var index = 0; index < prevCompaction.retainedTail.length; index++)
        MessageEntry(
          id: '${prevCompaction.id}:retained:$index',
          message: prevCompaction.retainedTail[index],
          parentId: index == 0
              ? prevCompaction.id
              : '${prevCompaction.id}:retained:${index - 1}',
          seq: prevCompaction.seq,
          timestamp: prevCompaction.retainedTail[index].timestamp,
        ),
    ];
    compactableEntries = [
      ...virtualRetainedEntries,
      ...pathEntries.sublist(prevCompactionIndex + 1),
    ];
  }
  final boundaryEnd = compactableEntries.length;

  final tokensBefore = estimateContextTokens(
    buildSessionContext(pathEntries).messages,
  ).tokens;

  final cutPoint = findCutPoint(
    compactableEntries,
    0,
    boundaryEnd,
    settings.keepRecentTokens,
  );
  final historyEnd = cutPoint.isSplitTurn
      ? cutPoint.turnStartIndex
      : cutPoint.firstKeptEntryIndex;
  final messagesToSummarize = <AgentMessage>[];
  for (var i = 0; i < historyEnd; i++) {
    final msg = _getMessageFromEntryForCompaction(compactableEntries[i]);
    if (msg != null) {
      messagesToSummarize.add(msg);
    }
  }
  final turnPrefixMessages = <AgentMessage>[];
  if (cutPoint.isSplitTurn) {
    for (var i = cutPoint.turnStartIndex; i < cutPoint.firstKeptEntryIndex; i++) {
      final msg = _getMessageFromEntryForCompaction(compactableEntries[i]);
      if (msg != null) {
        turnPrefixMessages.add(msg);
      }
    }
  }
  final retainedTail = <AgentMessage>[];
  for (var i = cutPoint.firstKeptEntryIndex; i < boundaryEnd; i++) {
    final msg = _getMessageFromEntryForCompaction(compactableEntries[i]);
    if (msg != null) {
      retainedTail.add(msg);
    }
  }
  final fileOps = createFileOps();
  if (prevCompactionIndex >= 0) {
    final prevCompaction = pathEntries[prevCompactionIndex] as CompactionEntry;
    final details = prevCompaction.details;
    if (details is CompactionDetails) {
      fileOps.read.addAll(details.readFiles);
      fileOps.edited.addAll(details.modifiedFiles);
    }
  }
  for (final msg in messagesToSummarize) {
    extractFileOpsFromMessage(msg, fileOps);
  }
  if (cutPoint.isSplitTurn) {
    for (final msg in turnPrefixMessages) {
      extractFileOpsFromMessage(msg, fileOps);
    }
  }

  return ok(
    CompactionPreparation(
      messagesToSummarize: messagesToSummarize,
      turnPrefixMessages: turnPrefixMessages,
      retainedTail: retainedTail,
      isSplitTurn: cutPoint.isSplitTurn,
      tokensBefore: tokensBefore,
      previousSummary: previousSummary,
      fileOps: fileOps,
      settings: settings,
    ),
  );
}

const String _turnPrefixSummarizationPrompt =
    'This is the PREFIX of a turn that was too large to keep. The SUFFIX '
    '(recent work) is retained.\n\n'
    'Summarize the prefix to provide context for the retained suffix:\n\n'
    '## Original Request\n'
    '[What did the user ask for in this turn?]\n\n'
    '## Early Progress\n'
    '- [Key decisions and work done in the prefix]\n\n'
    '## Context for Suffix\n'
    '- [Information needed to understand the retained recent work]\n\n'
    'Be concise. Focus on what\'s needed to understand the kept suffix.';

/// 从准备好的会话历史生成 compaction 摘要数据。
Future<HarnessResult<CompactResult, CompactionError>> compact(
  CompactionPreparation preparation,
  CompleteSimpleFn completeSimple,
  Model model, {
  String? customInstructions,
  AbortSignal? signal,
  String? thinkingLevel,
  RetryPolicy? retry,
  RetryCallbacks? callbacks,
}) async {
  final messagesToSummarize = preparation.messagesToSummarize;
  final turnPrefixMessages = preparation.turnPrefixMessages;
  final retainedTail = preparation.retainedTail;
  final isSplitTurn = preparation.isSplitTurn;
  final tokensBefore = preparation.tokensBefore;
  final previousSummary = preparation.previousSummary;
  final fileOps = preparation.fileOps;
  final settings = preparation.settings;

  String summary;
  Usage summaryUsage;

  if (isSplitTurn && turnPrefixMessages.isNotEmpty) {
    var historyText = 'No prior history.';
    Usage? historyUsage;
    if (messagesToSummarize.isNotEmpty) {
      final historyResult = await generateSummaryWithUsage(
        messagesToSummarize,
        completeSimple,
        model,
        settings.reserveTokens,
        signal: signal,
        customInstructions: customInstructions,
        previousSummary: previousSummary,
        thinkingLevel: thinkingLevel,
        retry: retry,
        callbacks: callbacks,
      );
      final historyError = historyResult.errorOrNull;
      if (historyError != null) {
        return err(historyError);
      }
      final historyValue = historyResult.valueOrNull!;
      historyText = historyValue.text;
      historyUsage = historyValue.usage;
    }
    final turnPrefixResult = await _generateTurnPrefixSummary(
      turnPrefixMessages,
      completeSimple,
      model,
      settings.reserveTokens,
      signal: signal,
      thinkingLevel: thinkingLevel,
      retry: retry,
      callbacks: callbacks,
    );
    final turnPrefixError = turnPrefixResult.errorOrNull;
    if (turnPrefixError != null) {
      return err(turnPrefixError);
    }
    final turnPrefixValue = turnPrefixResult.valueOrNull!;
    summary =
        '$historyText\n\n---\n\n**Turn Context (split turn):**\n\n'
        '${turnPrefixValue.text}';
    summaryUsage = historyUsage != null
        ? _combineUsage(historyUsage, turnPrefixValue.usage)
        : turnPrefixValue.usage;
  } else {
    final summaryResult = await generateSummaryWithUsage(
      messagesToSummarize,
      completeSimple,
      model,
      settings.reserveTokens,
      signal: signal,
      customInstructions: customInstructions,
      previousSummary: previousSummary,
      thinkingLevel: thinkingLevel,
      retry: retry,
      callbacks: callbacks,
    );
    final summaryError = summaryResult.errorOrNull;
    if (summaryError != null) {
      return err(summaryError);
    }
    final summaryValue = summaryResult.valueOrNull!;
    summary = summaryValue.text;
    summaryUsage = summaryValue.usage;
  }

  final (:readFiles, :modifiedFiles) = computeFileLists(fileOps);
  summary += formatFileOperations(readFiles, modifiedFiles);

  return ok(
    CompactResult(
      summary: summary,
      tokensBefore: tokensBefore,
      usage: summaryUsage,
      retainedTail: retainedTail,
      details: CompactionDetails(
        readFiles: readFiles,
        modifiedFiles: modifiedFiles,
      ),
    ),
  );
}

Future<
    HarnessResult<({String text, Usage usage}), CompactionError>
>
_generateTurnPrefixSummary(
  List<AgentMessage> messages,
  CompleteSimpleFn completeSimple,
  Model model,
  int reserveTokens, {
  AbortSignal? signal,
  String? thinkingLevel,
  RetryPolicy? retry,
  RetryCallbacks? callbacks,
}) async {
  final maxTokens = model.maxTokens > 0
      ? (0.5 * reserveTokens).floor().clamp(0, model.maxTokens)
      : (0.5 * reserveTokens).floor();
  final llmMessages = harnessConvertToLlm(messages);
  final conversationText = serializeConversation(llmMessages);
  final promptText =
      '<conversation>\n$conversationText\n</conversation>\n\n'
      '$_turnPrefixSummarizationPrompt';
  final summarizationMessages = <Message>[
    UserMessage(
      content: [UserTextContent(promptText)],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ),
  ];

  final response = await completeSimpleWithRetries(
    completeSimple,
    model,
    Context(
      systemPrompt: summarizationSystemPrompt,
      messages: summarizationMessages,
    ),
    SimpleStreamOptions(
      signal: signal,
      reasoning: model.reasoning &&
              thinkingLevel != null &&
              thinkingLevel != 'off'
          ? thinkingLevel
          : null,
      maxTokens: maxTokens,
    ),
    retry,
    callbacks,
  );
  if (response.stopReason == StopReason.aborted) {
    return err(
      CompactionError(
        CompactionErrorCode.aborted,
        response.errorMessage ?? 'Turn prefix summarization aborted',
      ),
    );
  }
  if (response.stopReason == StopReason.error) {
    return err(
      CompactionError(
        CompactionErrorCode.summarizationFailed,
        'Turn prefix summarization failed: '
            '${response.errorMessage ?? "Unknown error"}',
      ),
    );
  }

  return ok((
    text: assistantContentText(response),
    usage: response.usage ?? const Usage(),
  ));
}
