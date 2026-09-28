import '../../../core/agent/agent.dart';
import '../../../core/agent/context_usage.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/harness/session/session_types.dart'
    as session_types;
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../models/agent_chat_turn_timeline.dart';
import 'agent_chat_session_view.dart';
import '../models/agent_user_question_request.dart';

/// Agent 会话 UI 状态。
class AgentChatState {
  const AgentChatState({
    this.initialized = false,
    this.status = AgentChatRunStatus.idle,
    this.messages = const [],
    this.streamingMessage,
    this.activities = const [],
    this.queuedMessages = const [],
    this.workPhase = AgentChatWorkPhase.idle,
    this.sessions = const [],
    this.activeSessionId = '',
    this.skills = const [],
    this.routeLabel = '',
    this.routeReady = false,
    this.routeError = '',
    this.error = '',
    this.compacting = false,
    this.sessionTransitioning = false,
    this.sessionContentLoading = false,
    this.approvalRequest,
    this.questionRequest,
    this.totalUsage,
    this.lastRequestUsage,
    this.contextUsage = const AgentContextUsage.unknown(),
    this.thinkingLevel = ThinkingLevel.off,
    this.availableThinkingLevels = const [],
    this.pendingResources = const [],
    this.unavailableResourceKeys = const {},
    this.composerText = '',
    this.turns = const [],
    this.hasEarlierTurns = false,
    this.historyLoading = false,
    this.historyCursor,
    this.prependAnchorEntryId,
  });

  final bool initialized;
  final AgentChatRunStatus status;

  /// 当前会话转录（user/assistant/toolResult）。
  final List<Message> messages;
  final AssistantMessage? streamingMessage;
  final List<AgentToolActivity> activities;
  final List<AgentQueuedMessage> queuedMessages;
  final AgentChatWorkPhase workPhase;
  final List<AgentChatSessionSummary> sessions;
  final String activeSessionId;
  final List<HarnessSkill> skills;
  final String routeLabel;
  final bool routeReady;
  final String routeError;
  final String error;
  final bool compacting;
  final bool sessionTransitioning;
  final bool sessionContentLoading;
  final AgentToolApprovalRequest? approvalRequest;
  final AgentUserQuestionRequest? questionRequest;
  final Usage? totalUsage;

  /// Provider usage from the most recent model request.
  final Usage? lastRequestUsage;

  /// Current context occupancy, anchored to the last valid assistant usage.
  final AgentContextUsage contextUsage;
  final ThinkingLevel thinkingLevel;
  final List<ThinkingLevel> availableThinkingLevels;
  final List<AgentChatResourceReference> pendingResources;
  final Set<String> unavailableResourceKeys;
  final String composerText;
  final List<AgentChatTurnTimeline> turns;
  final bool hasEarlierTurns;
  final bool historyLoading;
  final AgentChatHistoryCursor? historyCursor;
  final String? prependAnchorEntryId;

  AgentChatState copyWith({
    bool? initialized,
    AgentChatRunStatus? status,
    List<Message>? messages,
    AssistantMessage? streamingMessage,
    bool clearStreamingMessage = false,
    List<AgentToolActivity>? activities,
    List<AgentQueuedMessage>? queuedMessages,
    AgentChatWorkPhase? workPhase,
    List<AgentChatSessionSummary>? sessions,
    String? activeSessionId,
    List<HarnessSkill>? skills,
    String? routeLabel,
    bool? routeReady,
    String? routeError,
    String? error,
    bool? compacting,
    bool? sessionTransitioning,
    bool? sessionContentLoading,
    AgentToolApprovalRequest? approvalRequest,
    bool clearApprovalRequest = false,
    AgentUserQuestionRequest? questionRequest,
    bool clearQuestionRequest = false,
    Usage? totalUsage,
    Usage? lastRequestUsage,
    bool clearLastRequestUsage = false,
    AgentContextUsage? contextUsage,
    ThinkingLevel? thinkingLevel,
    List<ThinkingLevel>? availableThinkingLevels,
    List<AgentChatResourceReference>? pendingResources,
    Set<String>? unavailableResourceKeys,
    String? composerText,
    List<AgentChatTurnTimeline>? turns,
    bool? hasEarlierTurns,
    bool? historyLoading,
    AgentChatHistoryCursor? historyCursor,
    bool clearHistoryCursor = false,
    String? prependAnchorEntryId,
    bool clearPrependAnchorEntryId = false,
  }) {
    return AgentChatState(
      initialized: initialized ?? this.initialized,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      streamingMessage: clearStreamingMessage
          ? null
          : streamingMessage ?? this.streamingMessage,
      activities: activities ?? this.activities,
      queuedMessages: queuedMessages ?? this.queuedMessages,
      workPhase: workPhase ?? this.workPhase,
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      skills: skills ?? this.skills,
      routeLabel: routeLabel ?? this.routeLabel,
      routeReady: routeReady ?? this.routeReady,
      routeError: routeError ?? this.routeError,
      error: error ?? this.error,
      compacting: compacting ?? this.compacting,
      sessionTransitioning: sessionTransitioning ?? this.sessionTransitioning,
      sessionContentLoading:
          sessionContentLoading ?? this.sessionContentLoading,
      approvalRequest: clearApprovalRequest
          ? null
          : approvalRequest ?? this.approvalRequest,
      questionRequest: clearQuestionRequest
          ? null
          : questionRequest ?? this.questionRequest,
      totalUsage: totalUsage ?? this.totalUsage,
      lastRequestUsage: clearLastRequestUsage
          ? null
          : lastRequestUsage ?? this.lastRequestUsage,
      contextUsage: contextUsage ?? this.contextUsage,
      thinkingLevel: thinkingLevel ?? this.thinkingLevel,
      availableThinkingLevels:
          availableThinkingLevels ?? this.availableThinkingLevels,
      pendingResources: pendingResources ?? this.pendingResources,
      unavailableResourceKeys:
          unavailableResourceKeys ?? this.unavailableResourceKeys,
      composerText: composerText ?? this.composerText,
      turns: turns ?? this.turns,
      hasEarlierTurns: hasEarlierTurns ?? this.hasEarlierTurns,
      historyLoading: historyLoading ?? this.historyLoading,
      historyCursor: clearHistoryCursor
          ? null
          : historyCursor ?? this.historyCursor,
      prependAnchorEntryId: clearPrependAnchorEntryId
          ? null
          : prependAnchorEntryId ?? this.prependAnchorEntryId,
    );
  }
}

enum AgentChatRunStatus { idle, running }

enum AgentChatWorkPhase {
  idle,
  preparing,
  thinking,
  responding,
  usingTools,
  awaitingApproval,
  compacting,
  stopping,
  failed,
}

enum AgentQueuedMessageKind { steering, followUp }

class AgentQueuedMessage {
  const AgentQueuedMessage({
    required this.kind,
    required this.id,
    required this.message,
  });

  final AgentQueuedMessageKind kind;
  final int id;
  final AgentMessage message;

  String get text => switch (message) {
    UserMessage() => (message as UserMessage).text,
    HarnessCustomMessage() =>
      (message as HarnessCustomMessage).content
          .whereType<UserTextContent>()
          .map((content) => content.text)
          .join(),
    _ => '',
  };
}

bool canManageAgentChatSessions(AgentChatState state) =>
    state.status == AgentChatRunStatus.idle && !state.sessionTransitioning;

Usage calculateAgentChatSessionUsage(
  Iterable<session_types.SessionEntry> entries,
) {
  var total = Usage.empty;
  for (final entry in entries) {
    Usage? usage;
    if (entry is session_types.MessageEntry &&
        entry.message is AssistantMessage) {
      usage = (entry.message as AssistantMessage).usage;
    } else if (entry is session_types.CompactionEntry) {
      usage = entry.usage;
    } else if (entry is session_types.BranchSummaryEntry) {
      usage = entry.usage;
    }
    if (usage != null) {
      total = total + usage;
    }
  }
  return total;
}

/// 工具执行卡片状态。
class AgentToolActivity {
  const AgentToolActivity({
    required this.toolCallId,
    required this.toolName,
    required this.args,
    this.status = AgentToolActivityStatus.running,
    this.content = '',
    this.turnId,
    this.itemId,
    this.startedAt,
    this.completedAt,
  });

  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> args;
  final AgentToolActivityStatus status;
  final String content;
  final String? turnId;
  final String? itemId;
  final int? startedAt;
  final int? completedAt;

  AgentToolActivity copyWith({
    AgentToolActivityStatus? status,
    String? content,
    String? turnId,
    String? itemId,
    int? startedAt,
    int? completedAt,
  }) {
    return AgentToolActivity(
      toolCallId: toolCallId,
      toolName: toolName,
      args: args,
      status: status ?? this.status,
      content: content ?? this.content,
      turnId: turnId ?? this.turnId,
      itemId: itemId ?? this.itemId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

enum AgentToolActivityStatus { running, succeeded, failed }

class AgentToolApprovalRequest {
  const AgentToolApprovalRequest({
    required this.toolCallId,
    required this.toolName,
    required this.args,
    this.estimatedAnlas,
    this.turnId,
    this.itemId,
  });

  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> args;
  final int? estimatedAnlas;
  final String? turnId;
  final String? itemId;

  AgentToolApprovalRequest bind({String? turnId, String? itemId}) =>
      AgentToolApprovalRequest(
        toolCallId: toolCallId,
        toolName: toolName,
        args: args,
        estimatedAnlas: estimatedAnlas,
        turnId: turnId ?? this.turnId,
        itemId: itemId ?? this.itemId,
      );
}
