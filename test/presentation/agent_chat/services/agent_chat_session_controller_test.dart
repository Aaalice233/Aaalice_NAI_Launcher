import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent.dart';
import 'package:nai_launcher/core/agent/audit/audit_sink.dart';
import 'package:nai_launcher/core/agent/harness/session/session.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';
import 'package:nai_launcher/core/agent/harness/session/session_memory.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_draft_store.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_draft_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_event_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_session_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_tool_permission_controller.dart';

void main() {
  test(
    'finish is idempotent and a stale end cannot finish the new turn',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'agent-chat-turn-lifecycle-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final session = Session(
        InMemorySessionStorage(
          const SessionMetadata(id: 'session', createdAt: 1),
        ),
        idGenerator: _ids(),
      );
      var state = const AgentChatState();
      final localStorage = LocalStorageService();
      final draftController = AgentChatDraftController(
        resourceStore: AgentChatResourceDraftStore(
          File('${directory.path}/drafts.json'),
        ),
        localStorage: localStorage,
        readState: () => state,
        writeState: (next) => state = next,
        createResourceResolver: () => throw UnimplementedError(),
        isMounted: () => true,
      );
      final controller = AgentChatSessionController(
        repository: JsonlSessionRepo(directory),
        localStorage: localStorage,
        draftController: draftController,
        workspaceDir: directory.path,
        buildAgent: () => throw UnimplementedError(),
        buildSystemPrompt: () async => '',
        readState: () => state,
        writeState: (next) => state = next,
        isMounted: () => true,
      )..session = session;

      final oldTurnId = (await controller.startTurn())!;
      await controller.finishTurn(
        turnId: oldTurnId,
        outcome: OperationOutcomeKind.completed,
      );
      final newTurnId = (await controller.startTurn())!;

      await controller.finishTurn(
        turnId: oldTurnId,
        outcome: OperationOutcomeKind.failed,
        error: 'late duplicate',
      );

      final records = await session.findRecords();
      final oldFinishes = records
          .whereType<OperationFinishedRecord>()
          .where((record) => record.runId == oldTurnId)
          .toList();
      expect(oldFinishes, hasLength(1));
      expect(oldFinishes.single.outcome, OperationOutcomeKind.completed);
      expect(controller.activeTurnId, newTurnId);

      await controller.finishTurn(
        turnId: newTurnId,
        outcome: OperationOutcomeKind.completed,
      );
      expect(controller.activeTurnId, isNull);

      final reloadedController = AgentChatSessionController(
        repository: JsonlSessionRepo(directory),
        localStorage: localStorage,
        draftController: draftController,
        workspaceDir: directory.path,
        buildAgent: () => throw UnimplementedError(),
        buildSystemPrompt: () async => '',
        readState: () => state,
        writeState: (next) => state = next,
        isMounted: () => true,
      )..session = session;
      await reloadedController.finishTurn(
        turnId: oldTurnId,
        outcome: OperationOutcomeKind.failed,
        error: 'duplicate after controller reload',
      );

      expect(
        (await session.findRecords()).whereType<OperationFinishedRecord>(),
        hasLength(2),
      );
    },
  );

  test(
    'rewind activation failure restores the branch and returns no checkpoint',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'agent-chat-rewind-rollback-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = JsonlSessionRepo(directory);
      final session = await repository.create(
        const SessionCreateOptions(id: 'session'),
      );
      await session.appendMessage(UserMessage.text('first request'));
      await session.appendMessage(UserMessage.text('edit this request'));
      var state = const AgentChatState(activeSessionId: 'session');
      final localStorage = LocalStorageService();
      final draftController = AgentChatDraftController(
        resourceStore: AgentChatResourceDraftStore(
          File('${directory.path}/drafts.json'),
        ),
        localStorage: localStorage,
        readState: () => state,
        writeState: (next) => state = next,
        createResourceResolver: () => throw UnimplementedError(),
        isMounted: () => true,
      );
      final controller = AgentChatSessionController(
        repository: repository,
        localStorage: localStorage,
        draftController: draftController,
        workspaceDir: directory.path,
        buildAgent: () => throw StateError('activation failed'),
        buildSystemPrompt: () async => '',
        readState: () => state,
        writeState: (next) => state = next,
        isMounted: () => true,
      )..session = session;

      final checkpoint = await controller.beginRewindLastUserMessage();

      expect(checkpoint, isNull);
      expect(
        (await session.findEntriesOnBranch(
          const EntryQuery(order: EntryOrder.oldestFirst),
        )).whereType<MessageEntry>().map(
          (entry) => (entry.message as UserMessage).text,
        ),
        ['first request', 'edit this request'],
      );
      expect(state.sessionTransitioning, isFalse);
    },
  );

  test('TurnEnd and AgentEnd persist only one finish record', () async {
    final directory = await Directory.systemTemp.createTemp(
      'agent-chat-event-lifecycle-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final session = Session(
      InMemorySessionStorage(
        const SessionMetadata(id: 'session', createdAt: 1),
      ),
      idGenerator: _ids(),
    );
    var state = const AgentChatState();
    final localStorage = LocalStorageService();
    final draftController = AgentChatDraftController(
      resourceStore: AgentChatResourceDraftStore(
        File('${directory.path}/drafts.json'),
      ),
      localStorage: localStorage,
      readState: () => state,
      writeState: (next) => state = next,
      createResourceResolver: () => throw UnimplementedError(),
      isMounted: () => true,
    );
    final sessionController = AgentChatSessionController(
      repository: JsonlSessionRepo(directory),
      localStorage: localStorage,
      draftController: draftController,
      workspaceDir: directory.path,
      buildAgent: () => throw UnimplementedError(),
      buildSystemPrompt: () async => '',
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => true,
    )..session = session;
    final eventController = AgentChatEventController(
      sessionController: sessionController,
      permissionController: AgentToolPermissionController(
        auditSink: MemoryAgentAuditSink(),
        estimateAnlas: (_, _) async => null,
        onApprovalChanged: (_) {},
        isMounted: () => true,
      ),
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => true,
    );
    final signal = AbortController().signal;
    final assistant = AssistantMessage(
      content: const [AssistantTextContent('done')],
      stopReason: StopReason.stop,
    );

    await eventController.handle(const AgentEventAgentStart(), signal);
    await eventController.handle(
      AgentEventTurnEnd(message: assistant, toolResults: const []),
      signal,
    );
    await eventController.handle(
      AgentEventAgentEnd(messages: [assistant]),
      signal,
    );

    expect(
      (await session.findRecords()).whereType<OperationFinishedRecord>(),
      hasLength(1),
    );
  });
}

String Function() _ids() {
  var next = 0;
  return () => 'id-${next++}';
}
