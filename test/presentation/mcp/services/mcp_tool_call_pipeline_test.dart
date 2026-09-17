import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_mcp/server.dart' show CallToolResult, TextContent;
import 'package:dart_mcp/server.dart' as mcp;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/audit/audit_sink.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/defined_agent_tool.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_approval_coordinator.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_external_tool_registry_factory.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_tool_call_pipeline.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_image_response_service.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_executor.dart';
import 'package:nai_launcher/core/mcp/mcp_image_http_endpoint.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

import '../mcp_test_tools.dart';

void main() {
  late _Harness harness;

  setUp(() => harness = _Harness());
  tearDown(() => harness.dispose());

  test('unknown tool fails without touching the permission gate', () async {
    final result = await harness.call('u1', 'no_such_tool');

    expect(result.isError, isTrue);
    expect(harness.auditIds, contains('u1.lookup'));
    expect(harness.coordinator.current, isNull);
  });

  test('invalid arguments fail before the permission gate', () async {
    final result = await harness.call(
      'x1',
      'set_positive_prompt',
      arguments: const {'unknown': 'field'},
    );

    expect(result.isError, isTrue);
    expect(harness.auditIds, contains('x1.validation'));
    expect(harness.executed, isEmpty);
    expect(harness.coordinator.current, isNull);
  });

  test('read tools run without approval while a write waits', () async {
    final write = harness.call('w1', 'set_positive_prompt');
    await pumpEventQueue();
    expect(harness.coordinator.current?.toolCallId, 'w1');
    expect(harness.executed, isEmpty);

    final read = await harness.call('r1', 'get_generation_settings');

    expect(read.isError, isNot(isTrue));
    expect(harness.executed, ['get_generation_settings']);
    expect(harness.coordinator.current?.toolCallId, 'w1');
    expect(harness.auditIds, containsAll(['r1.decision', 'r1.result']));

    harness.coordinator.resolve('w1', true);
    expect((await write).isError, isNot(isTrue));
    expect(harness.executed, [
      'get_generation_settings',
      'set_positive_prompt',
    ]);
  });

  test('approved write executes and is audited', () async {
    final pending = harness.call('w1', 'set_positive_prompt');
    await pumpEventQueue();

    expect(harness.coordinator.current?.clientLabel, 'codex 1.0.0');
    harness.coordinator.resolve('w1', true);

    final result = await pending;
    expect(result.isError, isNot(isTrue));
    expect(_textOf(result), 'ok:set_positive_prompt');
    expect(
      harness.auditIds,
      containsAll(['w1.decision', 'w1.approval', 'w1.result']),
    );
  });

  test('declined write never executes', () async {
    final pending = harness.call('w1', 'set_positive_prompt');
    await pumpEventQueue();

    harness.coordinator.resolve('w1', false);

    final result = await pending;
    expect(result.isError, isTrue);
    expect(harness.executed, isEmpty);
  });

  test('expired approval declines instead of hanging', () async {
    final expiring = _Harness(timeout: const Duration(milliseconds: 40));
    addTearDown(expiring.dispose);

    final result = await expiring.call('w1', 'set_positive_prompt');

    expect(result.isError, isTrue);
    expect(expiring.executed, isEmpty);
    expect(expiring.coordinator.current, isNull);
  });

  test('client abort resolves the pending approval as declined', () async {
    final controller = AbortController();
    final pending = harness.call(
      'w1',
      'set_positive_prompt',
      signal: controller.signal,
    );
    await pumpEventQueue();
    expect(harness.coordinator.current?.toolCallId, 'w1');

    controller.abort();

    final result = await pending;
    expect(result.isError, isTrue);
    expect(harness.executed, isEmpty);
    expect(harness.coordinator.current, isNull);
  });

  test('a second write queues instead of cancelling the first', () async {
    final first = harness.call('w1', 'set_positive_prompt');
    await pumpEventQueue();
    final second = harness.call('w2', 'delete_fixed_tag');
    await pumpEventQueue();

    expect(harness.coordinator.current?.toolCallId, 'w1');

    harness.coordinator.resolve('w1', true);
    expect((await first).isError, isNot(isTrue));
    await pumpEventQueue();

    expect(harness.coordinator.current?.toolCallId, 'w2');
    harness.coordinator.resolve('w2', true);
    expect((await second).isError, isNot(isTrue));
    expect(harness.executed, ['set_positive_prompt', 'delete_fixed_tag']);
  });

  test('full access only confirms charged calls', () async {
    final full = _Harness(mode: AgentPermissionMode.fullAccess);
    addTearDown(full.dispose);

    final plain = await full.call('w1', 'set_positive_prompt');
    expect(plain.isError, isNot(isTrue));
    expect(full.coordinator.current, isNull);

    final destructive = await full.call('w2', 'delete_fixed_tag');
    expect(destructive.isError, isNot(isTrue));
    expect(full.coordinator.current, isNull);
    expect(full.executed, ['set_positive_prompt', 'delete_fixed_tag']);

    final charged = full.call(
      'w3',
      'generate_image',
      arguments: const {'preparation_id': 'prep-1'},
    );
    await pumpEventQueue();
    expect(full.coordinator.current?.toolCallId, 'w3');
    expect(full.coordinator.current?.request.estimatedAnlas, 24);
    full.coordinator.resolve('w3', false);
    expect((await charged).isError, isTrue);
  });

  test('tools reflect the currently built registry', () {
    expect(
      harness.executor.tools.map((tool) => tool.name),
      containsAll(['get_generation_settings', 'set_positive_prompt']),
    );
  });

  for (final cost in [0, 24]) {
    test('two calls return a displayable image at cost $cost', () async {
      var generations = 0;
      var reads = 0;
      var writes = 0;
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 64, height: 64)),
      );
      final reference = {
        'version': 1,
        'kind': 'generatedImage',
        'source': 'generation_history',
        'resourceId': 'new-image',
      };
      final tools = McpExternalToolSurface.filter(
        fakeToolRegistry([
          FakeAgentTool(
            name: 'prepare_generation',
            runner: (args, signal) async => agentToolJsonResult({
              'ok': true,
              'status': 'prepared',
              'operation': 'generate',
              'preparation_id': 'prep-1',
              'estimated_anlas': cost,
              'confirmation_required': cost != 0,
              'auto_start': true,
              'parameters': {
                'prompt': 'long prompt,' * 1000,
                'width': 64,
                'height': 64,
              },
            }),
          ),
          FakeAgentTool(
            name: 'submit_generation',
            parameters: const {
              'type': 'object',
              'properties': {
                'preparation_id': {'type': 'string'},
                'confirmed': {'type': 'boolean', 'const': true},
              },
              'required': ['preparation_id'],
              'additionalProperties': false,
            },
            runner: (args, signal) async {
              expect(args, {
                'preparation_id': 'prep-1',
                if (cost > 0) 'confirmed': true,
              });
              generations++;
              return agentToolJsonResult({
                'ok': true,
                'images': [
                  {'resource_ref': reference},
                ],
              });
            },
          ),
        ], mode: AgentPermissionMode.fullAccess),
      ).tools;
      final pipeline = _Harness(
        mode: AgentPermissionMode.fullAccess,
        toolOverrides: tools,
        estimatedAnlas: cost,
        imageResponses: McpImageResponseService(
          resolve: (ref) async {
            reads++;
            return ResolvedAgentResource(
              reference: ref,
              label: 'new image',
              bytes: bytes,
            );
          },
          shouldStripMetadata: () => true,
          writeDisplayFile: (image) async {
            writes++;
            return File(p.join(Directory.systemTemp.path, 'new-display.png'));
          },
          publishDisplayImage:
              (bytes, {required mimeType, required metadataStripped}) =>
                  McpImageDisplayLink(
                    Uri.parse('http://127.0.0.1:20624/mcp/images/new.png'),
                    DateTime.utc(2026, 9, 16),
                  ),
        ),
      );
      addTearDown(pipeline.dispose);
      final preparation = await pipeline.call('prepare', 'prepare_generation');
      expect(generations, 0);
      expect(jsonEncode(preparation.structuredContent).length, lessThan(500));
      final next = preparation.structuredContent!['next_action'] as Map;
      final pending = pipeline.call(
        'submit',
        next['tool'] as String,
        arguments: Map<String, dynamic>.from(next['arguments'] as Map),
      );
      if (cost > 0) {
        await pumpEventQueue();
        expect(generations, 0);
        expect(pipeline.coordinator.current?.request.estimatedAnlas, cost);
        pipeline.coordinator.resolve('submit', true);
      }
      final result = await pending;
      expect(result.isError, isFalse);
      expect(generations, 1);
      expect(reads, 1);
      expect(writes, 1);
      expect(result.content.where((c) => c.isImage), hasLength(1));
      final descriptor =
          (result.structuredContent!['images'] as List).single as Map;
      expect(
        descriptor['display_markdown'],
        descriptor['display_file_markdown'],
      );
      expect(descriptor['display_markdown'], contains('new-display.png'));
      expect(
        result.structuredContent!['display_markdown'],
        descriptor['display_markdown'],
      );
      expect(
        (result.content.lastWhere((c) => c.isText) as TextContent).text,
        descriptor['display_markdown'],
      );
      expect(
        descriptor['display_url_markdown'],
        contains('/mcp/images/new.png'),
      );
      expect(
        result.structuredContent!['display_instructions'].toString().length,
        lessThan(600),
      );
      expect(
        pipeline.auditIds.where((id) => id.endsWith('.result')),
        hasLength(2),
      );
    });
  }

  test(
    'tools/call sends sanitized full-resolution ImageContent on the wire',
    () async {
      final source = img.Image(width: 320, height: 448, numChannels: 4)
        ..textData = {'Comment': 'private prompt'};
      source.clear(img.ColorRgba8(20, 40, 60, 255));
      final bytes = Uint8List.fromList(img.encodePng(source));
      final raw = agentToolJsonResult({
        'ok': true,
        'files': ['C:/private/original.png'],
        'images': [
          {
            'path': 'private-12345.png',
            'resource_ref': {
              'version': 1,
              'kind': 'generatedImage',
              'source': 'generation_history',
              'resourceId': 'test-1',
            },
          },
        ],
      });
      Uint8List? displayBytes;
      final displayPath = p.join(
        Directory.systemTemp.path,
        'display-cache',
        'image.png',
      );
      final markdownPath = p.absolute(displayPath).replaceAll('\\', '/');
      final displayUrl = Uri.parse(
        'http://127.0.0.1:20624/mcp/images/test.png',
      );
      var publishes = 0;
      final pipeline = _Harness(
        sourceResult: raw,
        imageResponses: McpImageResponseService(
          resolve: (AgentChatResourceReference ref) async =>
              ResolvedAgentResource(
                reference: ref,
                label: 'private',
                bytes: bytes,
              ),
          shouldStripMetadata: () => true,
          publishDisplayImage:
              (bytes, {required mimeType, required metadataStripped}) {
                publishes++;
                expect(metadataStripped, isTrue);
                return McpImageDisplayLink(
                  displayUrl,
                  DateTime.utc(2026, 9, 14),
                );
              },
          writeDisplayFile: (image) async {
            displayBytes = image.bytes;
            return File(displayPath);
          },
        ),
      );
      addTearDown(pipeline.dispose);
      final result = await pipeline.call(
        'image-1',
        'display_images',
        arguments: {'include_display_file': true},
      );
      expect(result.isError, isFalse);
      final content =
          result.content.singleWhere((c) => c.isImage) as mcp.ImageContent;
      final decoded = img.decodePng(base64Decode(content.data))!;
      expect([decoded.width, decoded.height], [320, 448]);
      expect(decoded.textData ?? {}, isEmpty);
      expect(result.structuredContent?['metadata_stripped'], isTrue);
      expect(_textOf(result), isNot(contains('private')));
      expect(result.structuredContent?.containsKey('files'), isFalse);
      expect(displayBytes, orderedEquals(base64Decode(content.data)));
      expect(
        result.structuredContent?['display_status'],
        'requires_client_rendering',
      );
      expect(result.structuredContent?.containsKey('displayed_count'), isFalse);
      final descriptor =
          (result.structuredContent!['images'] as List).single as Map;
      expect(
        descriptor['display_markdown'],
        '![Generated image](<$markdownPath>)',
      );
      expect(pipeline.coordinator.current, isNull);
      expect(pipeline.auditIds, contains('image-1.result'));
      expect(descriptor['display_url'], displayUrl.toString());
      final cherry = await pipeline.call(
        'image-2',
        'display_images',
        arguments: {'include_display_file': true},
        clientLabel: 'CherryStudio 2.0.14',
      );
      final cherryImage =
          (cherry.structuredContent!['images'] as List).single as Map;
      expect(
        cherryImage['display_markdown'],
        '![Generated image]($displayUrl)',
      );
      expect(
        cherryImage['display_file_markdown'],
        '![Generated image](<$markdownPath>)',
      );
      final desktop = await pipeline.call(
        'image-4',
        'display_images',
        clientLabel: 'claude-ai 0.1.0',
      );
      final desktopImage =
          (desktop.structuredContent!['images'] as List).single as Map;
      expect(
        desktopImage['display_markdown'],
        '![Generated image]($displayUrl)',
      );
      expect(
        desktopImage['display_link_markdown'],
        '[Generated image 320x448](<$displayUrl>)',
      );
      expect(
        desktop.structuredContent?['display_instructions'],
        contains('one-click reveal'),
      );
      expect(
        desktop.structuredContent?['display_instructions'],
        contains('clickable link'),
      );

      final cli = await pipeline.call(
        'image-5',
        'display_images',
        clientLabel: 'claude-code 2.0.0',
      );
      final cliImage = (cli.structuredContent!['images'] as List).single as Map;
      expect(
        cliImage['display_markdown'],
        '[Generated image 320x448](<$displayUrl>)',
      );
      expect(cliImage['display_markdown'], cliImage['display_link_markdown']);
      expect(cliImage['display_path'], markdownPath);
      expect(
        cli.structuredContent?['display_instructions'],
        contains('clickable link'),
      );

      final disabled = await pipeline.call(
        'image-3',
        'display_images',
        arguments: {'include_display_url': false},
      );
      expect(
        ((disabled.structuredContent!['images'] as List).single as Map)
            .containsKey('display_url'),
        isFalse,
      );
      expect(publishes, 4);
    },
  );

  test(
    'the observation hook sees the prepared result, not the raw one',
    () async {
      final observed = <AgentToolResult>[];
      final pipeline = _Harness(
        sourceResult: agentToolJsonResult({'ok': true, 'stage': 'raw'}),
        imageResponses: _PreparedStageImageResponses(),
        observeResult: observed.add,
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.call('observe-1', 'display_images');

      expect(result.isError, isFalse);
      expect(observed, hasLength(1));
      expect(observed.single.details['stage'], 'prepared');
    },
  );
}

/// Marks every prepared result so the hook cannot be satisfied by the raw one.
class _PreparedStageImageResponses extends McpImageResponseService {
  _PreparedStageImageResponses()
    : super(resolve: (_) async => null, shouldStripMetadata: () => false);

  @override
  Future<AgentToolResult> prepare(
    String toolName,
    AgentToolResult result, {
    AbortSignal? signal,
    bool? includeDisplayFile,
    bool includeDisplayUrl = true,
    McpImageDisplayStyle style = McpImageDisplayStyle.inlineUrl,
  }) async => agentToolJsonResult({'ok': true, 'stage': 'prepared'});
}

String? _textOf(CallToolResult result) {
  final content = result.content;
  if (content.isEmpty || !content.first.isText) return null;
  return (content.first as TextContent).text;
}

class _Harness {
  _Harness({
    Duration timeout = const Duration(minutes: 5),
    AgentPermissionMode mode = AgentPermissionMode.askBeforeSensitiveActions,
    McpImageResponseService? imageResponses,
    this.sourceResult,
    List<AgentTool>? toolOverrides,
    int estimatedAnlas = 24,
    void Function(AgentToolResult result)? observeResult,
  }) {
    tools =
        toolOverrides ??
        [
          FakeAgentTool(
            name: 'get_generation_settings',
            runner: _runner('get_generation_settings'),
          ),
          FakeAgentTool(
            name: 'display_images',
            parameters: const {
              'type': 'object',
              'properties': {
                'include_display_file': {'type': 'boolean'},
                'include_display_url': {'type': 'boolean'},
              },
            },
            runner: _runner('display_images'),
          ),
          FakeAgentTool(
            name: 'set_positive_prompt',
            runner: _runner('set_positive_prompt'),
          ),
          FakeAgentTool(
            name: 'delete_fixed_tag',
            runner: _runner('delete_fixed_tag'),
          ),
          FakeAgentTool(
            name: 'generate_image',
            parameters: const {
              'type': 'object',
              'properties': {
                'preparation_id': {'type': 'string'},
              },
              'additionalProperties': false,
            },
            runner: _runner('generate_image'),
          ),
        ];
    coordinator = McpApprovalCoordinator(
      auditSink: audit,
      estimateAnlas: (_, args) async =>
          args['preparation_id'] is String ? estimatedAnlas : null,
      isMounted: () => true,
      timeout: timeout,
    );
    coordinator.configure(fakeToolRegistry(tools, mode: mode));
    executor = LauncherMcpToolExecutor(
      registry: () => fakeToolRegistry(tools, mode: mode),
      approvals: coordinator,
      auditSink: audit,
      imageResponses:
          imageResponses ??
          McpImageResponseService(
            resolve: (_) async => null,
            shouldStripMetadata: () => false,
          ),
      observeResult: observeResult,
    );
  }

  final MemoryAgentAuditSink audit = MemoryAgentAuditSink();
  final AgentToolResult? sourceResult;
  final List<String> executed = [];
  late final List<AgentTool> tools;
  late final McpApprovalCoordinator coordinator;
  late final LauncherMcpToolExecutor executor;

  Iterable<String> get auditIds => audit.events.map((event) => event.id);

  FakeToolRunner _runner(String name) => (args, signal) async {
    executed.add(name);
    return sourceResult ??
        AgentToolResult(
          content: [ToolResultTextContent('ok:$name')],
          details: null,
        );
  };

  Future<CallToolResult> call(
    String callId,
    String toolName, {
    Map<String, dynamic> arguments = const {},
    AbortSignal? signal,
    String clientLabel = 'codex 1.0.0',
  }) {
    return executor.call(
      McpToolCallRequest(
        sessionId: 'session-1',
        callId: callId,
        toolName: toolName,
        arguments: arguments,
        signal: signal ?? AbortController().signal,
        clientLabel: clientLabel,
      ),
    );
  }

  void dispose() => coordinator.dispose();
}
