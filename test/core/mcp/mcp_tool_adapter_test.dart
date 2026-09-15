import 'dart:convert';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_adapter.dart';

import 'fake_mcp_tool_executor.dart';

void main() {
  Map<String, Object?> wire(Object? value) =>
      jsonDecode(jsonEncode(value)) as Map<String, Object?>;

  Map<String, Object?>? annotationsOf(mcp.Tool tool) =>
      wire(tool)['annotations'] as Map<String, Object?>?;

  group('toMcpTool', () {
    test('carries name, label, description and input schema verbatim', () {
      final tool = FakeAgentTool(
        name: 'get_application_context',
        label: '读取应用状态',
        description: 'Reports the current launcher state.',
        parameters: const {
          'type': 'object',
          'properties': {
            'verbose': {'type': 'boolean'},
          },
          'required': ['verbose'],
        },
      );

      final encoded = wire(McpToolAdapter.toMcpTool(tool));

      expect(encoded['name'], 'get_application_context');
      expect(encoded['title'], '读取应用状态');
      expect(encoded['description'], 'Reports the current launcher state.');
      expect(encoded['inputSchema'], {
        'type': 'object',
        'properties': {
          'verbose': {'type': 'boolean'},
        },
        'required': ['verbose'],
      });
    });

    test('marks a read tool read-only and idempotent', () {
      final annotations = annotationsOf(
        McpToolAdapter.toMcpTool(
          FakeAgentTool(name: 'get_generation_settings', label: 'Settings'),
        ),
      );

      expect(annotations, {
        'title': 'Settings',
        'readOnlyHint': true,
        'destructiveHint': false,
        'idempotentHint': true,
        'openWorldHint': false,
      });
    });

    test('marks a writing tool neither read-only nor destructive', () {
      final annotations = annotationsOf(
        McpToolAdapter.toMcpTool(
          FakeAgentTool(name: 'save_generated_image', label: 'Save'),
        ),
      );

      expect(annotations!['readOnlyHint'], isFalse);
      expect(annotations['destructiveHint'], isFalse);
      expect(annotations['idempotentHint'], isFalse);
      expect(annotations['openWorldHint'], isFalse);
    });

    test('marks a deleting tool destructive', () {
      final annotations = annotationsOf(
        McpToolAdapter.toMcpTool(
          FakeAgentTool(name: 'delete_fixed_tag', label: 'Delete'),
        ),
      );

      expect(annotations!['readOnlyHint'], isFalse);
      expect(annotations['destructiveHint'], isTrue);
    });

    test('omits behaviour hints for a tool outside the permission catalog', () {
      final annotations = annotationsOf(
        McpToolAdapter.toMcpTool(
          FakeAgentTool(name: 'totally_unknown_tool', label: 'Unknown'),
        ),
      );

      expect(annotations, {'title': 'Unknown', 'openWorldHint': false});
    });
  });

  group('toCallToolResult', () {
    test('maps text content', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [
              const ToolResultTextContent('first'),
              const ToolResultTextContent('second'),
            ],
            details: null,
          ),
        ),
      );

      expect(encoded['content'], [
        {'type': 'text', 'text': 'first'},
        {'type': 'text', 'text': 'second'},
      ]);
      expect(encoded.containsKey('structuredContent'), isFalse);
      expect(encoded['isError'], isFalse);
    });

    test('maps base64 image content with its mime type', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [
              const ToolResultImageContent(
                ImageContent(
                  source: ImageSource.base64(
                    mimeType: 'image/webp',
                    base64Data: 'AAAB',
                  ),
                ),
              ),
            ],
            details: null,
          ),
        ),
      );

      expect(encoded['content'], [
        {'data': 'AAAB', 'mimeType': 'image/webp', 'type': 'image'},
      ]);
    });

    test('degrades a url-only image to its link', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [
              const ToolResultImageContent(
                ImageContent(
                  source: ImageSource.url(url: 'https://example.invalid/a.png'),
                ),
              ),
            ],
            details: null,
          ),
        ),
      );

      expect(encoded['content'], [
        {'type': 'text', 'text': 'https://example.invalid/a.png'},
      ]);
    });

    test('derives structuredContent from the JSON object text block', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [
              ToolResultTextContent(
                jsonEncode({
                  'count': 2,
                  'items': ['a', 'b'],
                }),
              ),
            ],
            details: null,
          ),
        ),
      );

      expect(encoded['structuredContent'], {
        'count': 2,
        'items': ['a', 'b'],
      });
      expect(encoded['content'], [
        {'type': 'text', 'text': '{"count":2,"items":["a","b"]}'},
      ]);
    });

    test('keeps details out of the wire result', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [const ToolResultTextContent('{"ok":true}')],
            details: <String, dynamic>{
              'files': ['C:/Users/alice/secret.png'],
              'preferFileImages': true,
            },
          ),
        ),
      );

      expect(encoded['structuredContent'], {'ok': true});
      expect(jsonEncode(encoded), isNot(contains('secret.png')));
    });

    test('omits structuredContent when no text block is a JSON object', () {
      for (final details in <dynamic>[
        null,
        <String, dynamic>{},
        <String, dynamic>{'count': 1},
        'text',
        42,
      ]) {
        for (final text in const ['ok', '[1, 2]', '{not json', '']) {
          final encoded = wire(
            McpToolAdapter.toCallToolResult(
              AgentToolResult(
                content: [ToolResultTextContent(text)],
                details: details,
              ),
            ),
          );

          expect(
            encoded.containsKey('structuredContent'),
            isFalse,
            reason: 'text=$text details=$details',
          );
        }
      }
    });

    test('uses the first JSON object text block', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [
              const ToolResultTextContent('plain prefix'),
              const ToolResultTextContent(' {"first": 1} '),
              const ToolResultTextContent('{"second": 2}'),
            ],
            details: null,
          ),
        ),
      );

      expect(encoded['structuredContent'], {'first': 1});
    });

    test('derives structuredContent for coded error results', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [
              const ToolResultTextContent(
                '{"ok":false,"code":"missing_query","message":"required"}',
              ),
            ],
            details: null,
            isError: true,
          ),
        ),
      );

      expect(encoded['isError'], isTrue);
      expect(encoded['structuredContent'], {
        'ok': false,
        'code': 'missing_query',
        'message': 'required',
      });
    });

    test('passes isError through', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [const ToolResultTextContent('boom')],
            details: null,
            isError: true,
          ),
        ),
      );

      expect(encoded['isError'], isTrue);
    });
  });

  test('errorResult wraps a message as a failed tool call', () {
    final encoded = wire(McpToolAdapter.errorResult('nope'));

    expect(encoded['isError'], isTrue);
    expect(encoded['content'], [
      {'type': 'text', 'text': 'nope'},
    ]);
  });
}
