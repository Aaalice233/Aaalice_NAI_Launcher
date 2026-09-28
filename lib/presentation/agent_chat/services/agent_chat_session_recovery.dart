import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/session/session.dart';
import 'package:nai_launcher/core/agent/harness/session/session_types.dart'
    as session_types;

class AgentChatRecoveredQueueMessage {
  const AgentChatRecoveredQueueMessage({
    required this.message,
    required this.entryId,
  });

  final AgentMessage message;
  final String entryId;
}

class AgentChatSuspendedRecovery {
  const AgentChatSuspendedRecovery({
    this.transcriptEntries = const [],
    this.steeringMessages = const [],
    this.followUpMessages = const [],
  });

  final List<session_types.MessageEntry> transcriptEntries;
  final List<AgentChatRecoveredQueueMessage> steeringMessages;
  final List<AgentChatRecoveredQueueMessage> followUpMessages;
}

/// Applies persisted Pi suspended-run intents at the presentation boundary.
///
/// The durable Harness protocol stays in core; this adapter prepares its
/// provisioned entries and queues for the legacy Agent loop to resume.
abstract final class AgentChatSessionRecovery {
  static Future<AgentChatSuspendedRecovery> restore({
    required Session session,
    required session_types.OperationStartedRecord operation,
  }) async {
    final transcriptEntries = <session_types.MessageEntry>[];

    Future<void> appendProvisionedMessage(
      session_types.MessageEntry provisioned,
    ) async {
      if (await session.getEntry(provisioned.id) != null) return;
      final entry =
          await session.appendEntry(
                session_types.MessageEntry(
                  id: provisioned.id,
                  message: provisioned.message,
                ),
                'main',
              )
              as session_types.MessageEntry;
      transcriptEntries.add(entry);
    }

    for (final provisioned
        in operation.intent.initialMessages
            .whereType<session_types.MessageEntry>()) {
      await appendProvisionedMessage(provisioned);
    }

    await _restoreInterruptedToolResults(
      session: session,
      operation: operation,
      appendProvisionedMessage: appendProvisionedMessage,
    );
    final queues = await _findPendingQueueMessages(
      session: session,
      operation: operation,
    );
    return AgentChatSuspendedRecovery(
      transcriptEntries: transcriptEntries,
      steeringMessages: queues.steering,
      followUpMessages: queues.followUp,
    );
  }

  static Future<session_types.QueueEnqueuedRecord> acceptPrompt({
    required Session session,
    required session_types.OperationStartedRecord operation,
    required AgentMessage prompt,
    required session_types.QueueKind queue,
  }) async {
    final target = session_types.MessageEntry(
      id: session.idGenerator(),
      message: prompt,
    );
    return await session.appendRecord(
          session_types.QueueEnqueuedRecord(
            id: session.idGenerator(),
            lane: 'main',
            queue: queue,
            target: target,
            runId: operation.id,
          ),
        )
        as session_types.QueueEnqueuedRecord;
  }

  static Future<void> _restoreInterruptedToolResults({
    required Session session,
    required session_types.OperationStartedRecord operation,
    required Future<void> Function(session_types.MessageEntry)
    appendProvisionedMessage,
  }) async {
    final toolStarts = (await session.findRecords(
      session_types.RecordQuery(
        lane: 'main',
        type: 'tool_started',
        runId: operation.id,
        order: session_types.EntryOrder.oldestFirst,
      ),
    )).whereType<session_types.ToolStartedRecord>();
    for (final started in toolStarts) {
      if (await session.getEntry(started.resultEntryId) != null) continue;
      // The legacy Tool declaration has no current replay-safety marker, so it
      // cannot satisfy Pi's persisted-and-current "safe" gate. Never replay an
      // external effect unless both declarations prove that it is safe.
      final result = ToolResultMessage(
        toolCallId: started.toolCallId,
        toolName: started.toolName,
        content: const [
          ToolResultTextContent(
            'Tool execution was interrupted before its result was persisted.',
          ),
        ],
        details: const {'reason': 'interrupted'},
        isError: true,
      );
      await appendProvisionedMessage(
        session_types.MessageEntry(id: started.resultEntryId, message: result),
      );
    }
  }

  static Future<
    ({
      List<AgentChatRecoveredQueueMessage> steering,
      List<AgentChatRecoveredQueueMessage> followUp,
    })
  >
  _findPendingQueueMessages({
    required Session session,
    required session_types.OperationStartedRecord operation,
  }) async {
    final cancelled =
        (await session.findRecords(
              session_types.RecordQuery(
                lane: 'main',
                type: 'queue_cancelled',
                runId: operation.id,
              ),
            ))
            .whereType<session_types.QueueCancelledRecord>()
            .map((record) => record.entryId)
            .toSet();
    final queueRecords = (await session.findRecords(
      session_types.RecordQuery(
        lane: 'main',
        type: 'queue_enqueued',
        runId: operation.id,
        order: session_types.EntryOrder.oldestFirst,
      ),
    )).whereType<session_types.QueueEnqueuedRecord>();
    final steering = <AgentChatRecoveredQueueMessage>[];
    final followUp = <AgentChatRecoveredQueueMessage>[];
    for (final record in queueRecords) {
      final target = record.target;
      if (cancelled.contains(target.id) ||
          target is! session_types.MessageEntry ||
          await session.getEntry(target.id) != null) {
        continue;
      }
      final recovered = AgentChatRecoveredQueueMessage(
        message: target.message,
        entryId: target.id,
      );
      switch (record.queue) {
        case session_types.QueueKind.steer:
          steering.add(recovered);
        case session_types.QueueKind.followUp:
          followUp.add(recovered);
        case session_types.QueueKind.nextRun:
          break;
      }
    }
    return (steering: steering, followUp: followUp);
  }
}
