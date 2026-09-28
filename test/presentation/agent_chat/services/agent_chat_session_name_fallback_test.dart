import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/harness_messages.dart';
import 'package:nai_launcher/core/agent/harness/session/session.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_draft_store.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_prompt_envelope.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_draft_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_session_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_session_naming.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_session_summary_cache.dart';

AssistantMessage _assistant(String text) => AssistantMessage(
  content: [AssistantTextContent(text)],
  stopReason: StopReason.stop,
);

HarnessCustomMessage _envelope(String visible) => HarnessCustomMessage(
  customType: agentPromptEnvelopeType,
  display: true,
  blockContent: [
    const UserTextContent('<resources/>'),
    UserTextContent(visible),
  ],
  details: const {'visibleContentOffset': 1},
  timestamp: 1,
);

void main() {
  late Directory tmp;
  late JsonlSessionRepo repo;
  late AgentChatSessionSummaryCache cache;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('session_name_fallback');
    repo = JsonlSessionRepo(Directory(tmp.path));
    cache = AgentChatSessionSummaryCache(repository: repo);
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  Future<Session> createSession(List<AgentMessage> messages) async {
    final session = await repo.create();
    for (final message in messages) {
      await session.appendMessage(message);
    }
    return session;
  }

  Future<String> listedName(Session session) async {
    final id = (await session.getMetadata()).id;
    final summaries = await cache.list();
    return summaries.firstWhere((summary) => summary.id == id).name;
  }

  group('unnamed session names', () {
    test('come from the first user message, not the latest', () async {
      final session = await createSession([
        UserMessage.text('first ask'),
        _assistant('an answer'),
        UserMessage.text('second ask'),
      ]);

      expect(await listedName(session), 'first ask');
    });

    test('skip a leading assistant message', () async {
      final session = await createSession([
        _assistant('a greeting before any prompt'),
        UserMessage.text('the actual ask'),
      ]);

      expect(await listedName(session), 'the actual ask');
    });

    test('skip a leading custom message', () async {
      final session = await createSession([
        const HarnessCustomMessage(
          customType: 'systemNote',
          display: true,
          textContent: 'restored context',
          timestamp: 1,
        ),
        UserMessage.text('the actual ask'),
      ]);

      expect(await listedName(session), 'the actual ask');
    });

    test('read the visible half of a prompt envelope', () async {
      final session = await createSession([
        _envelope('draw a cat'),
        _assistant('done'),
      ]);

      expect(await listedName(session), 'draw a cat');
    });

    test('skip a first user message without visible text', () async {
      final session = await createSession([
        UserMessage.text('   '),
        UserMessage.text('the actual ask'),
      ]);

      expect(await listedName(session), 'the actual ask');
    });

    test('collapse whitespace across lines', () async {
      final session = await createSession([
        UserMessage.text('  draw\n  a cat  '),
      ]);

      expect(await listedName(session), 'draw a cat');
    });

    test('lose to a persisted name', () async {
      final session = await createSession([UserMessage.text('first ask')]);
      await session.setName('custom name');

      expect(await listedName(session), 'custom name');
    });

    test('are truncated past the limit', () async {
      final text = List.filled(20, 'lorem').join(' ');
      final session = await createSession([UserMessage.text(text)]);

      expect(await listedName(session), '${text.substring(0, 40)}…');
    });
  });

  test('auto naming and the list fallback agree', () async {
    final text = List.filled(20, 'lorem').join(' ');
    final session = await createSession([
      UserMessage.text(text),
      _assistant('an answer'),
      UserMessage.text('a much shorter follow-up'),
    ]);
    final localStorage = LocalStorageService();
    var state = const AgentChatState();
    final controller = AgentChatSessionController(
      repository: repo,
      localStorage: localStorage,
      draftController: AgentChatDraftController(
        resourceStore: AgentChatResourceDraftStore(
          File('${tmp.path}${Platform.pathSeparator}drafts.json'),
        ),
        localStorage: localStorage,
        readState: () => state,
        writeState: (next) => state = next,
        createResourceResolver: () => throw UnimplementedError(),
        isMounted: () => true,
      ),
      workspaceDir: tmp.path,
      buildAgent: () => throw UnimplementedError(),
      buildSystemPrompt: () async => '',
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => true,
    )..session = session;

    await controller.autoNameSession();

    expect(await session.getName(), AgentChatSessionNaming.fromText(text));
    expect(await listedName(session), AgentChatSessionNaming.fromText(text));
  });
}
