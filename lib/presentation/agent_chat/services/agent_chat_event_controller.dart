import 'dart:collection';

import '../../../core/agent/agent.dart';
import '../../../core/agent/context_usage.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/harness/session/session_types.dart'
    as session_types;
import '../providers/agent_chat_state.dart';
import 'agent_chat_session_controller.dart';
import 'agent_tool_permission_controller.dart';

class AgentChatEventController {
  AgentChatEventController({
    required AgentChatSessionController sessionController,
    required AgentToolPermissionController permissionController,
    required AgentChatState Function() readState,
    required void Function(AgentChatState state) writeState,
    required bool Function() isMounted,
  }) : _sessionController = sessionController,
       _permissionController = permissionController,
       _readState = readState,
       _writeState = writeState,
       _isMounted = isMounted;

  final AgentChatSessionController _sessionController;
  final AgentToolPermissionController _permissionController;
  final AgentChatState Function() _readState;
  final void Function(AgentChatState) _writeState;
  final bool Function() _isMounted;
  final Queue<_AgentRunTurnContext> _runContexts = Queue();

  _AgentRunTurnContext? get _currentRunContext =>
      _runContexts.isEmpty ? null : _runContexts.last;

  _AgentRunTurnContext? get _contextWithActiveTurn {
    for (final context in _runContexts.toList().reversed) {
      if (context.currentTurnId != null) return context;
    }
    return null;
  }

  Future<void> handle(AgentEvent event, AbortSignal signal) async {
    if (!_isMounted()) return;
    switch (event) {
      case AgentEventAgentStart():
        final turnId = await _sessionController.startTurn();
        if (turnId != null) {
          _runContexts.add(_AgentRunTurnContext(turnId));
        }
      case AgentEventMessageStart():
        if (event.message is AssistantMessage) {
          _writeState(
            _readState().copyWith(
              streamingMessage: event.message as AssistantMessage,
              workPhase: AgentChatWorkPhase.thinking,
            ),
          );
        }
      case AgentEventMessageUpdate():
        final update = event.assistantMessageEvent;
        if (update is AmTextDelta || update is AmThinkingDelta) {
          final partial = update.partial;
          _writeState(
            _readState().copyWith(
              streamingMessage: partial,
              workPhase: update is AmThinkingDelta
                  ? AgentChatWorkPhase.thinking
                  : AgentChatWorkPhase.responding,
            ),
          );
        }
      case AgentEventMessageEnd():
        final message = event.message;
        final shouldPersist =
            message is! AssistantMessage ||
            message.content.any(
              (content) => switch (content) {
                AssistantTextContent() =>
                  content.text.trim().isNotEmpty ||
                      content.signature?.isNotEmpty == true,
                AssistantThinkingContent() =>
                  content.thinking.trim().isNotEmpty ||
                      content.signature?.isNotEmpty == true,
                ToolCallContent() =>
                  content.id.trim().isNotEmpty &&
                      content.name.trim().isNotEmpty,
              },
            );
        if (!shouldPersist) {
          _writeState(_readState().copyWith(clearStreamingMessage: true));
        } else {
          _writeState(
            _readState().copyWith(
              messages: [..._readState().messages, message],
              clearStreamingMessage: true,
            ),
          );
          await _sessionController.persistMessage(message);
          if (message is UserMessage ||
              (message is HarnessCustomMessage &&
                  message.customType == 'agentResourcePrompt')) {
            await _sessionController.autoNameSession(message);
          }
        }
        if (message is AssistantMessage && message.usage != null) {
          _sessionController.totalUsage =
              _sessionController.totalUsage + message.usage!;
        }
        final current = _readState();
        final contextUsage = resolveAgentContextUsage(
          _sessionController.agent?.state.messages ?? current.messages,
          contextWindow: current.contextUsage.contextWindow,
        );
        _writeState(
          current.copyWith(
            totalUsage: _sessionController.totalUsage,
            lastRequestUsage: message is AssistantMessage
                ? message.usage
                : null,
            clearLastRequestUsage:
                message is AssistantMessage && message.usage == null,
            contextUsage: contextUsage,
          ),
        );
      case AgentEventToolExecutionStart():
        final args = event.args;
        final normalizedArgs = args is Map<String, dynamic>
            ? args
            : const <String, dynamic>{};
        final turnId =
            _contextWithActiveTurn?.currentTurnId ??
            _sessionController.activeTurnId;
        await _sessionController.recordToolStarted(
          toolCallId: event.toolCallId,
          toolName: event.toolName,
          args: normalizedArgs,
        );
        final startedAt = DateTime.now().millisecondsSinceEpoch;
        _writeState(
          _readState().copyWith(
            activities: [
              ..._readState().activities,
              AgentToolActivity(
                toolCallId: event.toolCallId,
                toolName: event.toolName,
                args: normalizedArgs,
                turnId: turnId,
                itemId: 'call:${event.toolCallId}',
                startedAt: startedAt,
              ),
            ],
            workPhase: AgentChatWorkPhase.usingTools,
          ),
        );
      case AgentEventToolExecutionUpdate():
        final preview = event.partialResult.content
            .whereType<ToolResultTextContent>()
            .map((content) => content.text)
            .join();
        _writeState(
          _readState().copyWith(
            activities: [
              for (final activity in _readState().activities)
                activity.toolCallId == event.toolCallId
                    ? activity.copyWith(content: preview)
                    : activity,
            ],
          ),
        );
      case AgentEventToolExecutionEnd():
        await _permissionController.writeAudit(
          id: '${event.toolCallId}.result',
          summary: '${event.toolName} completed',
          result: _permissionController.takeDecision(event.toolCallId),
          error: event.isError ? _resultPreview(event.result) : null,
        );
        _writeState(
          _readState().copyWith(
            activities: [
              for (final activity in _readState().activities)
                activity.toolCallId == event.toolCallId
                    ? activity.copyWith(
                        status: event.isError
                            ? AgentToolActivityStatus.failed
                            : AgentToolActivityStatus.succeeded,
                        content: _resultPreview(event.result),
                        completedAt: DateTime.now().millisecondsSinceEpoch,
                      )
                    : activity,
            ],
          ),
        );
      case AgentEventAgentEnd():
        final runContext = _runContexts.isEmpty ? null : _runContexts.first;
        final turnId = runContext?.currentTurnId ?? runContext?.lastTurnId;
        AssistantMessage? lastAssistant;
        for (final message in event.messages.reversed) {
          if (message is AssistantMessage) {
            lastAssistant = message;
            break;
          }
        }
        final failed = lastAssistant?.stopReason == StopReason.error;
        final aborted = lastAssistant?.stopReason == StopReason.aborted;
        if (turnId != null) {
          await _sessionController.finishTurn(
            turnId: turnId,
            outcome: failed
                ? session_types.OperationOutcomeKind.failed
                : aborted
                ? session_types.OperationOutcomeKind.aborted
                : session_types.OperationOutcomeKind.completed,
            error: failed ? lastAssistant?.errorMessage : null,
          );
        }
        if (runContext != null) {
          _runContexts.remove(runContext);
        }
        final agent = _sessionController.agent;
        _writeState(
          _readState().copyWith(
            activities: const [],
            sessions: await _sessionController.listSessions(),
            queuedMessages: agent == null ? const [] : _queuedMessages(agent),
            workPhase: AgentChatWorkPhase.idle,
          ),
        );
      case AgentEventTurnEnd():
        final message = event.message;
        final failure =
            message is AssistantMessage &&
            message.stopReason == StopReason.error;
        final aborted =
            message is AssistantMessage &&
            message.stopReason == StopReason.aborted;
        final completesUserTurn =
            message is AssistantMessage &&
            (failure ||
                aborted ||
                (message.toolCalls.isEmpty &&
                    message.stopReason != StopReason.toolUse));
        final runContext = _contextWithActiveTurn;
        final turnId = runContext?.currentTurnId;
        if (completesUserTurn && turnId != null) {
          await _sessionController.finishTurn(
            turnId: turnId,
            outcome: failure
                ? session_types.OperationOutcomeKind.failed
                : aborted
                ? session_types.OperationOutcomeKind.aborted
                : session_types.OperationOutcomeKind.completed,
            error: failure ? message.errorMessage : null,
          );
          if (runContext != null && runContext.currentTurnId == turnId) {
            runContext
              ..lastTurnId = turnId
              ..currentTurnId = null;
          }
        }
        if (message is AssistantMessage &&
            message.errorMessage != null &&
            message.stopReason == StopReason.error) {
          _writeState(_readState().copyWith(error: message.errorMessage));
          _writeState(
            _readState().copyWith(workPhase: AgentChatWorkPhase.failed),
          );
        }
      case AgentEventTurnStart():
        final runContext = _currentRunContext;
        if (runContext == null) {
          final turnId = await _sessionController.startTurn();
          if (turnId != null) {
            _runContexts.add(_AgentRunTurnContext(turnId));
          }
        } else if (runContext.currentTurnId == null) {
          final turnId = await _sessionController.startTurn();
          if (turnId != null) {
            runContext
              ..currentTurnId = turnId
              ..lastTurnId = turnId;
          }
        }
        final agent = _sessionController.agent;
        if (agent != null) {
          _writeState(
            _readState().copyWith(queuedMessages: _queuedMessages(agent)),
          );
        }
    }
  }

  String _resultPreview(AgentToolResult result) => result.content
      .whereType<ToolResultTextContent>()
      .map((content) => content.text)
      .join();

  List<AgentQueuedMessage> _queuedMessages(Agent agent) => [
    for (final entry in agent.steeringQueue)
      AgentQueuedMessage(
        kind: AgentQueuedMessageKind.steering,
        id: entry.id,
        message: entry.message,
      ),
    for (final entry in agent.followUpQueue)
      AgentQueuedMessage(
        kind: AgentQueuedMessageKind.followUp,
        id: entry.id,
        message: entry.message,
      ),
  ];
}

final class _AgentRunTurnContext {
  _AgentRunTurnContext(String turnId)
    : currentTurnId = turnId,
      lastTurnId = turnId;

  String? currentTurnId;
  String lastTurnId;
}
