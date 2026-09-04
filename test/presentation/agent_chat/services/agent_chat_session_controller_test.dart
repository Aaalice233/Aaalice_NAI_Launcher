import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/agent/agent.dart';
import 'package:nai_launcher/core/agent/audit/audit_sink.dart';
import 'package:nai_launcher/core/agent/harness/session/session.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';
import 'package:nai_launcher/core/agent/harness/session/session_memory.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_draft_store.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_draft_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_event_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_session_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_tool_permission_controller.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'agent-chat-session-controller-hive-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDirectory.existsSync()) {
      hiveDirectory.deleteSync(recursive: true);
    }
  });

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

      final acceptedPrompt = UserMessage.text('persist before execution');
      controller.prepareRunPrompt(acceptedPrompt);
      final oldTurnId = (await controller.startTurn())!;
      final started = (await session.findRecords())
          .whereType<OperationStartedRecord>()
          .single;
      expect(started.intent.originalPrompt, [acceptedPrompt]);
      expect(started.intent.initialMessages, hasLength(1));
      final persistedPrompt = await controller.persistMessage(acceptedPrompt);
      expect(persistedPrompt?.id, started.intent.initialMessages.single.id);

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

      var queuedInMemory = false;
      final queuedPrompt = UserMessage.text('queued at run completion');
      final accepting = controller.acceptQueuedPrompt(
        queuedPrompt,
        QueueKind.steer,
        enqueue: () => queuedInMemory = true,
      );
      final finishing = controller.finishTurn(
        turnId: newTurnId,
        outcome: OperationOutcomeKind.completed,
      );
      await expectLater(accepting, throwsStateError);
      await finishing;
      expect(queuedInMemory, isFalse);
      expect(controller.activeTurnId, isNull);
      final serializedRecords = await session.findRecords(
        const RecordQuery(order: EntryOrder.oldestFirst),
      );
      expect(serializedRecords.whereType<QueueEnqueuedRecord>(), isEmpty);
      expect(
        serializedRecords.whereType<OperationFinishedRecord>().where(
          (record) => record.runId == newTurnId,
        ),
        hasLength(1),
      );

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

  test('reopening preserves and resumes the suspended operation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'agent-chat-suspended-operation-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = JsonlSessionRepo(directory);
    final session = await repository.create(
      const SessionCreateOptions(id: 'session'),
    );
    const suspendedTurnId = 'suspended-turn';
    await session.appendRecord(
      OperationStartedRecord(
        id: suspendedTurnId,
        lane: 'main',
        sourceLeafId: null,
        intent: const RunIntent(kind: RunIntentKind.run),
      ),
    );
    await session.appendMessage(UserMessage.text('keep this request'));
    final partialAssistant = await session.appendMessage(
      AssistantMessage(
        content: const [
          AssistantTextContent('keep this partial response'),
          ToolCallContent(
            id: 'tool-call',
            name: 'read',
            arguments: {'path': 'unfinished.txt'},
          ),
        ],
        stopReason: StopReason.toolUse,
      ),
    );
    const interruptedResultId = 'interrupted-result';
    await session.appendRecord(
      ToolStartedRecord(
        id: 'tool-started',
        lane: 'main',
        runId: suspendedTurnId,
        assistantEntryId: partialAssistant,
        toolIndex: 0,
        toolCallId: 'tool-call',
        toolName: 'read',
        effectiveArgs: const {'path': 'unfinished.txt'},
        resultEntryId: interruptedResultId,
        replay: ReplayMode.never,
      ),
    );
    final pendingSteer = MessageEntry(
      id: 'pending-steer',
      message: UserMessage.text('persisted steering'),
    );
    final pendingFollowUp = MessageEntry(
      id: 'pending-follow-up',
      message: UserMessage.text('persisted follow-up'),
    );
    final cancelledSteer = MessageEntry(
      id: 'cancelled-steer',
      message: UserMessage.text('cancelled steering'),
    );
    await session.appendRecord(
      QueueEnqueuedRecord(
        id: 'steer-queued',
        lane: 'main',
        queue: QueueKind.steer,
        target: pendingSteer,
        runId: suspendedTurnId,
      ),
    );
    await session.appendRecord(
      QueueEnqueuedRecord(
        id: 'follow-up-queued',
        lane: 'main',
        queue: QueueKind.followUp,
        target: pendingFollowUp,
        runId: suspendedTurnId,
      ),
    );
    await session.appendRecord(
      QueueEnqueuedRecord(
        id: 'cancelled-queued',
        lane: 'main',
        queue: QueueKind.steer,
        target: cancelledSteer,
        runId: suspendedTurnId,
      ),
    );
    await session.appendRecord(
      QueueCancelledRecord(
        id: 'queue-cancelled',
        lane: 'main',
        entryId: cancelledSteer.id,
        runId: suspendedTurnId,
      ),
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
      repository: repository,
      localStorage: localStorage,
      draftController: draftController,
      workspaceDir: directory.path,
      buildAgent: () async => Agent(
        AgentOptions(
          streamFn: (model, context, [options]) => throw UnimplementedError(),
        ),
      ),
      buildSystemPrompt: () async => '',
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => true,
    );

    await controller.activateSession('session');
    final restoredSession = controller.session!;

    expect(
      (await restoredSession.findOpenOperations('main')).single.id,
      suspendedTurnId,
    );
    expect(state.turns.single.status.name, 'interrupted');
    expect(state.messages, hasLength(2));
    expect((state.messages[0] as UserMessage).text, 'keep this request');
    expect(
      (state.messages[1] as AssistantMessage).text,
      'keep this partial response',
    );

    final resumedPrompt = UserMessage.text('continue this task');
    await controller.acceptQueuedPrompt(
      resumedPrompt,
      QueueKind.steer,
      enqueue: () {},
    );
    final queueRecord = (await restoredSession.findRecords())
        .whereType<QueueEnqueuedRecord>()
        .where(
          (record) =>
              record.target is MessageEntry &&
              (record.target as MessageEntry).message == resumedPrompt,
        )
        .single;

    final recovery = await controller.restoreSuspendedRun();
    final resumedTurnId = await controller.startTurn();

    expect(recovery.transcriptEntries, hasLength(1));
    final interruptedResult = recovery.transcriptEntries.single.message;
    expect(interruptedResult, isA<ToolResultMessage>());
    expect((interruptedResult as ToolResultMessage).toolCallId, 'tool-call');
    expect(interruptedResult.isError, isTrue);
    expect(
      recovery.steeringMessages.map(
        (queued) => (queued.message as UserMessage).text,
      ),
      ['persisted steering', 'continue this task'],
    );
    expect(
      recovery.followUpMessages.map(
        (queued) => (queued.message as UserMessage).text,
      ),
      ['persisted follow-up'],
    );
    expect(
      (await restoredSession.getEntry(interruptedResultId))?.id,
      interruptedResultId,
    );
    expect(await restoredSession.getEntry(queueRecord.target.id), isNull);
    for (final queued in [
      ...recovery.steeringMessages,
      ...recovery.followUpMessages,
    ]) {
      await controller.persistMessage(queued.message);
    }
    expect(
      (await restoredSession.getEntry(queueRecord.target.id))?.id,
      queueRecord.target.id,
    );
    expect(await restoredSession.getEntry(pendingSteer.id), isNotNull);
    expect(await restoredSession.getEntry(pendingFollowUp.id), isNotNull);
    expect(await restoredSession.getEntry(cancelledSteer.id), isNull);
    expect(resumedTurnId, suspendedTurnId);
    expect(controller.activeTurnId, suspendedTurnId);
    expect(state.turns.single.status.name, 'running');
    expect(
      (await restoredSession.findRecords()).whereType<OperationStartedRecord>(),
      hasLength(1),
    );
    expect(await restoredSession.findOpenOperations('main'), hasLength(1));

    await controller.finishTurn(
      turnId: resumedTurnId!,
      outcome: OperationOutcomeKind.completed,
    );
    expect(await restoredSession.findOpenOperations('main'), isEmpty);
  });

  test(
    'large sessions restore a bounded UI window without truncating context',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'agent-chat-history-window-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = JsonlSessionRepo(directory);
      final session = await repository.create(
        const SessionCreateOptions(id: 'session'),
      );
      const total = AgentChatSessionController.recentHistoryEntryLimit + 12;
      for (var index = 0; index < total; index++) {
        await session.appendMessage(UserMessage.text('message $index'));
      }

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
        repository: repository,
        localStorage: localStorage,
        draftController: draftController,
        workspaceDir: directory.path,
        buildAgent: () async => Agent(
          AgentOptions(
            streamFn: (model, context, [options]) => throw UnimplementedError(),
          ),
        ),
        buildSystemPrompt: () async => '',
        readState: () => state,
        writeState: (next) => state = next,
        isMounted: () => true,
      );

      await controller.activateSession('session');

      expect(
        state.messages,
        hasLength(AgentChatSessionController.recentHistoryEntryLimit),
      );
      expect(state.hasEarlierTurns, isTrue);
      expect(controller.agent!.state.messages, hasLength(total));

      await controller.loadEarlierHistory();

      expect(state.messages, hasLength(total));
      expect(state.hasEarlierTurns, isFalse);
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
    final agent = Agent(const AgentOptions(streamFn: _unusedStream));
    sessionController.agent = agent;
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
    final unconsumedPrompt = UserMessage.text('too late for the final poll');
    await sessionController.acceptQueuedPrompt(
      unconsumedPrompt,
      QueueKind.steer,
      enqueue: () => agent.steer(unconsumedPrompt),
    );
    expect(agent.steeringQueue, hasLength(1));

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
    expect(agent.steeringQueue, isEmpty);
    expect(agent.followUpQueue, isEmpty);
  });
}

AssistantMessageEventStream _unusedStream(
  Model model,
  Context context, [
  SimpleStreamOptions? options,
]) => AssistantMessageEventStream();

String Function() _ids() {
  var next = 0;
  return () => 'id-${next++}';
}
