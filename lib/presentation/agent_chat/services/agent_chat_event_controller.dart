import '../../../core/agent/agent.dart';
import '../../../core/agent/harness/harness_messages.dart';
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

  Future<void> handle(AgentEvent event, AbortSignal signal) async {
    if (!_isMounted()) return;
    switch (event) {
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
                AssistantTextContent() => content.text.trim().isNotEmpty,
                AssistantThinkingContent() =>
                  content.thinking.trim().isNotEmpty,
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
          _writeState(
            _readState().copyWith(
              totalUsage: _sessionController.totalUsage,
              contextUsage: message.usage,
            ),
          );
        }
      case AgentEventToolExecutionStart():
        final args = event.args;
        _writeState(
          _readState().copyWith(
            activities: [
              ..._readState().activities,
              AgentToolActivity(
                toolCallId: event.toolCallId,
                toolName: event.toolName,
                args: args is Map<String, dynamic> ? args : const {},
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
                      )
                    : activity,
            ],
          ),
        );
      case AgentEventAgentEnd():
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
        if (message is AssistantMessage &&
            message.errorMessage != null &&
            message.stopReason == StopReason.error) {
          _writeState(_readState().copyWith(error: message.errorMessage));
          _writeState(
            _readState().copyWith(workPhase: AgentChatWorkPhase.failed),
          );
        }
      case AgentEventTurnStart():
        final agent = _sessionController.agent;
        if (agent != null) {
          _writeState(
            _readState().copyWith(queuedMessages: _queuedMessages(agent)),
          );
        }
      default:
        break;
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
