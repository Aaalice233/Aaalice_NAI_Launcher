import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/compaction/compaction.dart';
import 'package:nai_launcher/core/agent/harness/harness_messages.dart';
import 'package:nai_launcher/core/agent/harness/harness_result.dart';
import 'package:nai_launcher/core/agent/harness/session/session.dart';
import 'package:nai_launcher/core/agent/harness/session/session_context.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';

const _model = Model(
  id: 'm',
  name: 'M',
  api: 'test',
  provider: 'p',
  contextWindow: 1000,
  maxTokens: 512,
);

AssistantMessage _assistant(String text, {Usage? usage}) {
  return AssistantMessage(
    content: [AssistantTextContent(text)],
    stopReason: StopReason.stop,
    usage: usage,
    provider: 'p',
    model: 'm',
  );
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('harness_test');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  group('harnessConvertToLlm', () {
    test('maps compaction summary to prefixed user message', () {
      final messages = <AgentMessage>[
        UserMessage.text('hi'),
        const CompactionSummaryMessage(
          summary: 'earlier stuff',
          tokensBefore: 99,
          timestamp: 1,
        ),
      ];
      final llm = harnessConvertToLlm(messages);
      expect(llm.length, 2);
      final last = llm.last as UserMessage;
      expect(last.text, contains('<summary>'));
      expect(last.text, contains('earlier stuff'));
    });

    test('excludes bashExecution with excludeFromContext', () {
      final messages = <AgentMessage>[
        const BashExecutionMessage(
          command: 'ls',
          output: '',
          exitCode: 0,
          cancelled: false,
          truncated: false,
          timestamp: 1,
          excludeFromContext: true,
        ),
      ];
      expect(harnessConvertToLlm(messages), isEmpty);
    });

    test('drops empty failed messages but keeps partial text', () {
      final emptyAborted = AssistantMessage(
        content: const [],
        stopReason: StopReason.aborted,
      );
      final emptyError = AssistantMessage(
        content: const [],
        stopReason: StopReason.error,
      );
      final partialAborted = AssistantMessage(
        content: const [AssistantTextContent('partial answer')],
        stopReason: StopReason.aborted,
      );

      final llm = harnessConvertToLlm([
        UserMessage.text('first'),
        emptyAborted,
        emptyError,
        UserMessage.text('continue'),
        partialAborted,
      ]);

      expect(llm, hasLength(3));
      expect(llm.whereType<AssistantMessage>().single.text, 'partial answer');
    });

    test('keeps complete tool calls and removes broken tool history', () {
      final completeCall = AssistantMessage(
        content: const [
          ToolCallContent(id: 'complete', name: 'read', arguments: {}),
        ],
        stopReason: StopReason.toolUse,
      );
      final incompleteCall = AssistantMessage(
        content: const [
          AssistantTextContent('I will check.'),
          ToolCallContent(id: 'first', name: 'read', arguments: {}),
          ToolCallContent(id: 'missing', name: 'read', arguments: {}),
        ],
        stopReason: StopReason.aborted,
      );
      final llm = harnessConvertToLlm([
        UserMessage.text('complete request'),
        completeCall,
        ToolResultMessage(
          toolCallId: 'complete',
          toolName: 'read',
          content: const [ToolResultTextContent('done')],
        ),
        UserMessage.text('broken request'),
        incompleteCall,
        ToolResultMessage(
          toolCallId: 'first',
          toolName: 'read',
          content: const [ToolResultTextContent('partial')],
        ),
        ToolResultMessage(
          toolCallId: 'orphan',
          toolName: 'read',
          content: const [ToolResultTextContent('orphan')],
        ),
        UserMessage.text('continue'),
      ]);

      expect(llm.whereType<ToolResultMessage>(), hasLength(1));
      expect(llm.whereType<ToolResultMessage>().single.toolCallId, 'complete');
      final assistants = llm.whereType<AssistantMessage>().toList();
      expect(assistants, hasLength(2));
      expect(assistants.last.text, 'I will check.');
      expect(assistants.last.toolCalls, isEmpty);
    });

    test('session restore ignores empty failed assistant messages', () {
      final context = buildSessionContext([
        MessageEntry(id: 'user', message: UserMessage.text('hello')),
        MessageEntry(
          id: 'aborted',
          message: AssistantMessage(
            content: const [],
            stopReason: StopReason.aborted,
          ),
        ),
        MessageEntry(
          id: 'error',
          message: AssistantMessage(
            content: const [],
            stopReason: StopReason.error,
          ),
        ),
      ]);

      expect(context.messages, hasLength(1));
      expect(context.messages.single, isA<UserMessage>());
    });
  });

  group('compaction', () {
    test('estimateTokens uses chars/4 for user text', () {
      expect(estimateTokens(UserMessage.text('a' * 40)), 10);
    });

    test('shouldCompact respects threshold', () {
      const settings = CompactionSettings(
        enabled: true,
        reserveTokens: 200,
        keepRecentTokens: 100,
      );
      expect(shouldCompact(900, 1000, settings), isTrue);
      expect(shouldCompact(700, 1000, settings), isFalse);
      expect(
        shouldCompact(900, 1000, settings.copyWith(enabled: false)),
        isFalse,
      );
    });

    test('prepareCompaction + compact summarize and retain tail', () async {
      // 构造：大量旧消息 + 少量近期消息。
      final entries = <SessionEntry>[];
      var id = 0;
      for (var i = 0; i < 12; i++) {
        entries.add(
          MessageEntry(
            id: 'u${id++}',
            message: UserMessage.text('question ${'x' * 200} $i'),
          ),
        );
        entries.add(
          MessageEntry(id: 'a${id++}', message: _assistant('answer $i')),
        );
      }

      final prepResult = prepareCompaction(
        entries,
        const CompactionSettings(
          enabled: true,
          reserveTokens: 100,
          keepRecentTokens: 300,
        ),
      );
      final prep = prepResult.valueOrNull;
      expect(prep, isNotNull);
      expect(prep!.messagesToSummarize, isNotEmpty);
      expect(prep.retainedTail.length, lessThan(entries.length));

      // completeSimple 桩：返回固定摘要。
      Future<AssistantMessage> completeSimple(
        Model model,
        Context context, [
        SimpleStreamOptions? options,
      ]) async {
        return _assistant('SUMMARY');
      }

      final result = await compact(prep, completeSimple, _model);
      final value = result.valueOrNull!;
      expect(value.summary, contains('SUMMARY'));
      expect(value.tokensBefore, greaterThan(0));
      expect(value.retainedTail.length, prep.retainedTail.length);

      // 生成的条目可被 buildSessionContext 折叠为摘要消息 + 尾部。
      final compactionEntry = CompactionEntry(
        id: 'c1',
        summary: value.summary,
        retainedTail: value.retainedTail,
        tokensBefore: value.tokensBefore,
      );
      final rebuilt = buildSessionContext([compactionEntry]);
      expect(rebuilt.messages.first, isA<CompactionSummaryMessage>());
      expect(rebuilt.messages.length, 1 + value.retainedTail.length);
    });
  });

  group('JsonlSessionStorage', () {
    test('append/reopen round-trips entries', () async {
      final file = File('${tmp.path}${Platform.pathSeparator}s1.jsonl');
      const metadata = SessionMetadata(id: 's1', createdAt: 42);
      final storage = await JsonlSessionStorage.create(file.path, metadata);
      final session = Session(storage);

      await session.appendMessage(UserMessage.text('hello'));
      final assistantMessage = _assistant('world');
      await session.appendMessage(assistantMessage);

      final reopened = await JsonlSessionStorage.create(file.path, metadata);
      final reopenedSession = Session(reopened);
      // 默认 newestFirst：从叶子（最新）向根，条目均为 MessageEntry。
      final entries = await reopenedSession.findEntriesOnBranch();
      expect(entries.length, 2);
      final newest = (entries[0] as MessageEntry).message as AssistantMessage;
      final oldest = (entries[1] as MessageEntry).message as UserMessage;
      expect(newest.text, 'world');
      expect(oldest.text, 'hello');
      expect(await reopenedSession.getLeafId(), isNotNull);
    });

    test('append/reopen round-trips every lane record type', () async {
      final file = File('${tmp.path}${Platform.pathSeparator}records.jsonl');
      const metadata = SessionMetadata(id: 'records', createdAt: 42);
      final storage = await JsonlSessionStorage.create(file.path, metadata);
      final session = Session(storage);
      final queuedEntry = MessageEntry(
        id: 'queued-entry',
        message: UserMessage.text('queued'),
      );
      final deferredEntry = CustomEntry(
        id: 'deferred-entry',
        customType: 'deferred',
        data: const {'ok': true},
      );

      await session.appendRecord(
        OperationStartedRecord(
          id: 'run-1',
          lane: 'main',
          sourceLeafId: null,
          intent: RunIntent(
            kind: RunIntentKind.run,
            originalPrompt: [UserMessage.text('start')],
            initialMessages: [
              MessageEntry(
                id: 'initial-entry',
                message: UserMessage.text('initial'),
              ),
            ],
            systemPromptOverride: 'system',
            resumeData: const {'cursor': 3},
          ),
        ),
      );
      await session.appendRecord(
        AbortRequestedRecord(id: 'abort-1', lane: 'main', runId: 'run-1'),
      );
      await session.appendRecord(
        StepAttemptRecord(
          id: 'step-1',
          lane: 'main',
          runId: 'run-1',
          step: 'compaction',
          attempt: 2,
          resultEntryId: 'result-1',
          compactionReason: CompactionReason.threshold,
        ),
      );
      await session.appendRecord(
        ToolStartedRecord(
          id: 'tool-1',
          lane: 'main',
          runId: 'run-1',
          assistantEntryId: 'assistant-1',
          toolIndex: 4,
          toolCallId: 'call-1',
          toolName: 'read',
          effectiveArgs: const {'path': 'image.png'},
          resultEntryId: 'tool-result-1',
          replay: ReplayMode.safe,
        ),
      );
      await session.appendRecord(
        QueueEnqueuedRecord(
          id: 'queue-1',
          lane: 'main',
          queue: QueueKind.steer,
          target: queuedEntry,
          runId: 'run-1',
        ),
      );
      await session.appendRecord(
        QueueCancelledRecord(
          id: 'cancel-1',
          lane: 'main',
          entryId: 'queued-entry',
          runId: 'run-1',
        ),
      );
      await session.appendRecord(
        WriteDeferredRecord(
          id: 'deferred-1',
          lane: 'main',
          runId: 'run-1',
          target: deferredEntry,
        ),
      );
      await session.appendRecord(
        UsageRecord(
          id: 'usage-1',
          lane: 'main',
          usage: const Usage(
            input: 10,
            output: 4,
            totalTokens: 14,
            cost: Cost(total: 0.25),
          ),
          cause: UsageCause.tool,
          runId: 'run-1',
          toolCallId: 'call-1',
          details: const {'provider': 'test'},
        ),
      );
      await session.appendRecord(
        OperationFinishedRecord(
          id: 'finish-1',
          lane: 'main',
          runId: 'run-1',
          outcome: OperationOutcomeKind.failed,
          error: (code: 'failed', message: 'expected failure'),
        ),
      );

      final reopened = JsonlSessionStorage(file, metadata);
      final records = await reopened.findRecords(
        const RecordQuery(order: EntryOrder.oldestFirst),
      );
      expect(records.length, 9);
      expect(records.map((record) => record.runtimeType), [
        OperationStartedRecord,
        AbortRequestedRecord,
        StepAttemptRecord,
        ToolStartedRecord,
        QueueEnqueuedRecord,
        QueueCancelledRecord,
        WriteDeferredRecord,
        UsageRecord,
        OperationFinishedRecord,
      ]);
      final started = records.first as OperationStartedRecord;
      expect(started.intent.originalPrompt.single, isA<UserMessage>());
      expect(started.intent.initialMessages.single, isA<MessageEntry>());
      expect(started.intent.resumeData, {'cursor': 3});
      final tool = records[3] as ToolStartedRecord;
      expect(tool.effectiveArgs, {'path': 'image.png'});
      expect(tool.replay, ReplayMode.safe);
      final usage = records[7] as UsageRecord;
      expect(usage.usage.totalTokens, 14);
      expect(usage.usage.cost.total, 0.25);
      final finished = records.last as OperationFinishedRecord;
      expect(finished.outcome, OperationOutcomeKind.failed);
      expect(finished.error?.message, 'expected failure');
      expect(await reopened.findOpenOperations('main'), isEmpty);
    });

    test('buildSessionContext collapses after compaction entry', () async {
      final file = File('${tmp.path}${Platform.pathSeparator}s2.jsonl');
      const metadata = SessionMetadata(id: 's2', createdAt: 1);
      final storage = await JsonlSessionStorage.create(file.path, metadata);
      final session = Session(storage);

      await session.appendMessage(UserMessage.text('old question'));
      await session.appendMessage(_assistant('old answer'));

      await session.appendEntry(
        CompactionEntry(
          id: 'c',
          summary: 'the old talk',
          retainedTail: [UserMessage.text('recent')],
          tokensBefore: 5000,
          details: const CompactionDetails(
            readFiles: ['old.txt'],
            modifiedFiles: ['new.txt'],
          ),
          usage: const Usage(totalTokens: 12),
        ),
        'main',
      );

      final entries = await session.findEntriesOnBranch(
        const EntryQuery(order: EntryOrder.oldestFirst),
      );
      final context = buildSessionContext(entries);
      // compaction 条目折叠其上方历史 → 摘要消息 + 保留尾部。
      expect(context.messages.length, 2);
      expect(context.messages.first, isA<CompactionSummaryMessage>());
      expect((context.messages.last as UserMessage).text, 'recent');

      // 重放后语义一致。
      final reopened = JsonlSessionStorage(file, metadata);
      final entries2 = await reopened.findEntriesOnBranch(
        const EntryQuery(order: EntryOrder.oldestFirst),
        const BranchBounds(),
        start: (await reopened.getLanes()).first.leafId!,
      );
      final context2 = buildSessionContext(entries2);
      expect(context2.messages.length, 2);
      final reopenedCompaction = entries2.whereType<CompactionEntry>().single;
      expect(reopenedCompaction.usage?.totalTokens, 12);
      final details = reopenedCompaction.details as CompactionDetails;
      expect(details.readFiles, ['old.txt']);
      expect(details.modifiedFiles, ['new.txt']);
    });

    test(
      'listWithNames prefers persisted name over first user message',
      () async {
        final repo = JsonlSessionRepo(Directory(tmp.path));

        // 会话 A：setName 持久化名优先。
        final a = await repo.create();
        await a.appendMessage(UserMessage.text('first message text'));
        await a.setName('custom name');

        // 会话 B：未命名 → 回退首条用户消息。
        final b = await repo.create();
        await b.appendMessage(UserMessage.text('derive my name please'));

        final aId = (await a.getMetadata()).id;
        final bId = (await b.getMetadata()).id;
        final expectedUpdatedAt = DateTime(2026, 1, 2, 3, 4, 5);
        final aFile = File(
          '${tmp.path}${Platform.pathSeparator}agent_chat'
          '${Platform.pathSeparator}sessions${Platform.pathSeparator}$aId.jsonl',
        );
        await aFile.setLastModified(expectedUpdatedAt);
        final named = await repo.listWithNames();
        final names = {for (final (m, n, _) in named) m.id: n};
        final updatedAt = {
          for (final (metadata, _, modified) in named) metadata.id: modified,
        };
        expect(names[aId], 'custom name');
        expect(names[bId], 'derive my name please');
        expect(
          updatedAt[aId]?.millisecondsSinceEpoch,
          expectedUpdatedAt.millisecondsSinceEpoch,
        );
      },
    );
  });
}
