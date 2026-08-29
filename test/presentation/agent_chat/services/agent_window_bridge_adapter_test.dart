import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_turn_timeline.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_window_bridge_adapter.dart';

void main() {
  test(
    'loadEarlierHistory command delegates to the authoritative runtime',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var calls = 0;
      final adapter = AgentWindowBridgeAdapter.forTesting(
        container,
        loadEarlierHistory: () async => calls++,
      );

      final result = await adapter.handleCommand(
        'loadEarlierHistory',
        const {},
      );

      expect(result, const {'ok': true});
      expect(calls, 1);
    },
  );

  test('turn identity, cursor, and nullable duration cross IPC', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = AgentWindowBridgeAdapter.forTesting(container);
    const item = AgentChatTimelineItem(
      id: 'entry:user-1',
      entryId: 'user-1',
      seq: 7,
      parentEntryId: 'parent-1',
      kind: AgentChatTimelineItemKind.userMessage,
      timestamp: 100,
    );
    final payload = adapter.serializeAuthoritativeStateForTesting(
      const AgentChatState(
        turns: [
          AgentChatTurnTimeline(
            id: 'turn-1',
            status: AgentChatTurnStatus.interrupted,
            items: [item],
            firstSeq: 7,
            lastSeq: 7,
            startedAt: 90,
          ),
        ],
        hasEarlierTurns: true,
        historyCursor: AgentChatHistoryCursor(
          beforeSeq: 7,
          parentEntryId: 'parent-1',
        ),
      ),
    );
    final turn = (payload['timeline']! as List).single as Map;

    expect(turn['id'], 'turn-1');
    expect(turn, isNot(contains('durationMs')));
    expect(((turn['items'] as List).single as Map)['entryId'], 'user-1');
    expect((payload['history'] as Map)['cursor'], {
      'beforeSeq': 7,
      'parentEntryId': 'parent-1',
    });
  });

  test('approval arguments and Anlas estimate cross IPC together', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = AgentWindowBridgeAdapter.forTesting(container);

    final payload = adapter.serializeApprovalForTesting(
      const AgentToolApprovalRequest(
        toolCallId: 'submit-1',
        toolName: 'submit_generation',
        args: {
          'model': 'nai-diffusion-4',
          'params': {'width': 832, 'height': 1216},
          'api_token': 'do-not-cross-ipc',
          'headerValue': 'Bearer hidden-credential',
          'outputPath': r'C:\Users\alice\private.png',
          'endpoint':
              'https://example.test/run?token=query-secret&mode=safe#token=fragment-secret',
        },
        estimatedAnlas: 12,
      ),
    );

    expect(payload['toolCallId'], 'submit-1');
    expect(payload['estimatedAnlas'], 12);
    final args = payload['args']! as Map;
    expect(args['model'], 'nai-diffusion-4');
    expect(args['params'], {'width': 832, 'height': 1216});
    expect(args['api_token'], '[redacted]');
    expect(args['headerValue'], '[redacted]');
    expect(args['outputPath'], '[local path]');
    expect(args['endpoint'], isA<String>());
    expect(jsonEncode(payload), isNot(contains('do-not-cross-ipc')));
    expect(jsonEncode(payload), isNot(contains('hidden-credential')));
    expect(jsonEncode(payload), isNot(contains('query-secret')));
    expect(jsonEncode(payload), isNot(contains('fragment-secret')));
    expect(jsonEncode(payload), isNot(contains(r'C:\Users\alice')));
  });

  test('every assistant tool call crosses IPC in message order', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = AgentWindowBridgeAdapter.forTesting(container);
    final message = AssistantMessage(
      content: const [
        AssistantTextContent('Working'),
        ToolCallContent(
          id: 'call-1',
          name: 'read',
          arguments: {'path': r'C:\private\one.txt'},
        ),
        ToolCallContent(
          id: 'call-2',
          name: 'generate_image',
          arguments: {'prompt': 'sunset', 'token': 'secret'},
        ),
      ],
      stopReason: StopReason.toolUse,
      timestamp: 42,
    );

    final payload = await adapter.serializeMessageForTesting(message);
    final calls = payload['toolCalls']! as List;

    expect(calls, hasLength(2));
    expect(calls.map((value) => (value as Map)['id']), ['call-1', 'call-2']);
    expect((calls.first as Map)['args'], {'path': '[local path]'});
    expect((calls.last as Map)['args'], {
      'prompt': 'sunset',
      'token': '[redacted]',
    });
    expect(payload['timestamp'], 42);
  });

  test(
    'every tool result remains a distinct ordered transcript message',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = AgentWindowBridgeAdapter.forTesting(container);
      final messages = await adapter.serializeMessagesForTesting([
        ToolResultMessage(
          toolCallId: 'call-1',
          toolName: 'read',
          content: const [ToolResultTextContent('first')],
        ),
        ToolResultMessage(
          toolCallId: 'call-2',
          toolName: 'write',
          content: const [ToolResultTextContent('second')],
          isError: true,
        ),
      ]);

      expect(messages.map((message) => message['toolCallId']), [
        'call-1',
        'call-2',
      ]);
      expect(messages.map((message) => message['text']), ['first', 'second']);
      expect(messages.last['isError'], isTrue);
    },
  );

  test(
    'authoritative detached state preserves parity fields and stable resources',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = AgentWindowBridgeAdapter.forTesting(container);
      final resource = AgentChatResourceReference(
        kind: AgentChatResourceKind.generatedImage,
        source: 'generation',
        resourceId: 'image-42',
        display: const {'label': 'Result 42'},
      );
      final encoded = AgentChatResourceReferenceCodec.encodeJson(resource);
      final state = AgentChatState(
        initialized: true,
        status: AgentChatRunStatus.running,
        workPhase: AgentChatWorkPhase.awaitingApproval,
        routeLabel: 'Generation',
        routeReady: false,
        routeError: 'model unavailable',
        error: 'request failed',
        compacting: true,
        sessionTransitioning: true,
        sessionContentLoading: true,
        activeSessionId: 'session-2',
        composerText: 'draft survives',
        contextUsage: const Usage(input: 12, totalTokens: 34),
        contextWindow: 128000,
        queuedMessages: [
          AgentQueuedMessage(
            kind: AgentQueuedMessageKind.followUp,
            id: 7,
            message: UserMessage.text('later'),
          ),
        ],
        activities: const [
          AgentToolActivity(
            toolCallId: 'activity-1',
            toolName: 'read',
            args: {'path': r'C:\private\file.txt'},
            content: 'reading',
          ),
        ],
        pendingResources: [resource],
        unavailableResourceKeys: {encoded},
      );

      final payload = adapter.serializeAuthoritativeStateForTesting(state);

      expect(payload, containsPair('sessionTransitioning', true));
      expect(payload, containsPair('sessionContentLoading', true));
      expect(payload, containsPair('composerText', 'draft survives'));
      expect(payload, containsPair('workPhase', 'awaitingApproval'));
      expect(payload, containsPair('contextWindow', 128000));
      expect((payload['contextUsage'] as Map)['totalTokens'], 34);
      expect(payload, containsPair('error', 'request failed'));
      expect(payload, containsPair('routeError', 'model unavailable'));
      expect(payload['queue'], [
        {'kind': 'followUp', 'id': 7, 'text': 'later', 'editable': true},
      ]);
      expect(((payload['activities'] as List).single as Map)['args'], {
        'path': '[local path]',
      });
      final serializedResource = (payload['resources'] as List).single as Map;
      expect(serializedResource['resourceId'], 'image-42');
      expect(serializedResource['unavailable'], isTrue);
      expect(jsonEncode(serializedResource), isNot(contains(r'C:\')));
    },
  );

  test(
    'tool image crosses IPC once without exposing local file paths',
    () async {
      final directory = await Directory.systemTemp.createTemp('agent-window-');
      addTearDown(() => directory.delete(recursive: true));
      final image = File('${directory.path}/result.png');
      await image.writeAsBytes(base64Decode(_oneByOnePngBase64));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = AgentWindowBridgeAdapter.forTesting(container);
      final message = ToolResultMessage(
        toolCallId: 'generation-1',
        toolName: 'generate_image',
        content: const [ToolResultTextContent('Image ready')],
        details: {
          'files': [image.path],
          'preferFileImages': true,
          'nested': {
            'files': [image.path],
            'status': 'saved',
          },
        },
      );

      final first = await adapter.serializeToolResultForTesting(message);
      final firstJson = jsonEncode(first);
      final serializedMessage = first['message']! as Map<String, Object?>;
      final images = serializedMessage['images']! as List;
      final assetId = (images.single as Map)['assetId'];

      expect(assetId, isA<String>());
      expect(first['imageAssets'], contains(assetId));
      expect(firstJson, isNot(contains(image.path)));
      expect(firstJson, isNot(contains('"files"')));

      final next = await adapter.serializeToolResultForTesting(message);
      final nextMessage = next['message']! as Map<String, Object?>;
      expect((nextMessage['images']! as List).single, {'assetId': assetId});
      expect(next['imageAssets'], isEmpty);
      expect(next['referencedImageAssets'], [assetId]);
    },
  );

  test(
    'missing and damaged tool images are explicit and do not throw',
    () async {
      final directory = await Directory.systemTemp.createTemp('agent-window-');
      addTearDown(() => directory.delete(recursive: true));
      final damaged = File('${directory.path}/damaged.png');
      await damaged.writeAsString('not an image');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = AgentWindowBridgeAdapter.forTesting(container);

      for (final entry in {
        '${directory.path}/missing.png': 'image_unavailable',
        damaged.path: 'image_invalid',
      }.entries) {
        final payload = await adapter.serializeToolResultForTesting(
          ToolResultMessage(
            toolCallId: entry.value,
            toolName: 'read',
            content: const [],
            details: {
              'files': [entry.key],
            },
          ),
        );
        final message = payload['message']! as Map<String, Object?>;
        expect((message['images']! as List).single, {'error': entry.value});
        expect(jsonEncode(payload), isNot(contains(entry.key)));
      }
    },
  );

  test('non-image tool files use stable semantic DTOs without paths', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final adapter = AgentWindowBridgeAdapter.forTesting(container);
    final payload = await adapter.serializeToolResultForTesting(
      ToolResultMessage(
        toolCallId: 'write-1',
        toolName: 'write',
        content: const [ToolResultTextContent('saved')],
        details: const {
          'files': [r'C:\private\report.json'],
          'recordCount': 2,
        },
      ),
    );
    final message = payload['message']! as Map<String, Object?>;

    expect(message['artifacts'], [
      {'kind': 'file', 'name': 'report.json', 'availability': 'primary_only'},
    ]);
    expect(message['details'], {'recordCount': 2});
    expect(jsonEncode(payload), isNot(contains(r'C:\private')));
  });
}

const _oneByOnePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
