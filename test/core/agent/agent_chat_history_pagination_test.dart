import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent.dart';
import 'package:nai_launcher/core/agent/harness/session/session.dart';
import 'package:nai_launcher/core/agent/harness/session/session_memory.dart';

void main() {
  test('entry and record newest-first cursors page without overlap', () async {
    final session = Session(
      InMemorySessionStorage(
        const SessionMetadata(id: 'bounded', createdAt: 1),
      ),
      idGenerator: _ids(),
    );
    for (var index = 0; index < 40; index++) {
      await session.appendMessage(UserMessage.text('message-$index'));
      await session.appendRecord(
        UsageRecord(
          id: 'usage-$index',
          lane: 'main',
          usage: const Usage(totalTokens: 1),
          cause: UsageCause.assistant,
        ),
      );
    }

    final first = await session.findEntriesOnBranch(
      const EntryQuery(order: EntryOrder.newestFirst, limit: 10),
    );
    final second = await session.findEntriesOnBranch(
      EntryQuery(
        order: EntryOrder.newestFirst,
        limit: 10,
        cursor: EntryCursor(afterSeq: first.last.seq),
      ),
    );
    final firstRecords = await session.findRecords(
      const RecordQuery(order: EntryOrder.newestFirst, limit: 10),
    );
    final secondRecords = await session.findRecords(
      RecordQuery(
        order: EntryOrder.newestFirst,
        limit: 10,
        cursor: EntryCursor(afterSeq: firstRecords.last.seq),
      ),
    );

    expect(first, hasLength(10));
    expect(second, hasLength(10));
    expect(
      first
          .map((entry) => entry.id)
          .toSet()
          .intersection(second.map((entry) => entry.id).toSet()),
      isEmpty,
    );
    expect(second.first.seq, lessThan(first.last.seq));
    expect(secondRecords.first.seq, lessThan(firstRecords.last.seq));
  });
}

String Function() _ids() {
  var next = 0;
  return () => 'entry-${next++}';
}
