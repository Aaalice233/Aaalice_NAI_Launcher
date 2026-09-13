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

    test('promotes JSON-encodable map details to structuredContent', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [const ToolResultTextContent('ok')],
            details: <String, dynamic>{
              'count': 2,
              'items': ['a', 'b'],
            },
          ),
        ),
      );

      expect(encoded['structuredContent'], {
        'count': 2,
        'items': ['a', 'b'],
      });
    });

    test('omits structuredContent for non-map details', () {
      for (final details in <dynamic>[
        null,
        'text',
        42,
        <int>[1, 2],
      ]) {
        final encoded = wire(
          McpToolAdapter.toCallToolResult(
            AgentToolResult(
              content: [const ToolResultTextContent('ok')],
              details: details,
            ),
          ),
        );

        expect(encoded.containsKey('structuredContent'), isFalse);
      }
    });

    test('omits structuredContent when the map cannot be encoded', () {
      final encoded = wire(
        McpToolAdapter.toCallToolResult(
          AgentToolResult(
            content: [const ToolResultTextContent('ok')],
            details: <String, dynamic>{'handle': Object()},
          ),
        ),
      );

      expect(encoded.containsKey('structuredContent'), isFalse);
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
