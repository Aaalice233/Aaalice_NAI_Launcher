import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/mcp/mcp_image_http_endpoint.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_adapter.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/defined_agent_tool.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_image_response_service.dart';
import 'package:path/path.dart' as p;

void main() {
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 64, height: 64)),
  );
  final filePath = p
      .absolute(p.join(Directory.systemTemp.path, 'display cache', 'safe.png'))
      .replaceAll('\\', '/');
  final url = Uri.parse('http://127.0.0.1:20624/mcp/images/safe.png');
  late int writes;
  late int publishes;
  late McpImageResponseService service;

  setUp(() {
    writes = 0;
    publishes = 0;
    service = McpImageResponseService(
      resolve: (reference) async => ResolvedAgentResource(
        reference: reference,
        label: 'image',
        bytes: bytes,
      ),
      shouldStripMetadata: () => false,
      writeDisplayFile: (_) async {
        writes++;
        return File(filePath);
      },
      publishDisplayImage: (_, {required mimeType, required metadataStripped}) {
        publishes++;
        return McpImageDisplayLink(url, DateTime.utc(2026, 9, 17));
      },
    );
  });

  for (final client in ['codex-mcp-client 0.154.0', 'Cherry Studio 2.0.14']) {
    for (final tool in [
      'generate_image',
      'submit_generation',
      'display_images',
    ]) {
      test(
        '$client $tool survives top-level-only and text-only forwarding',
        () async {
          final codex = client.startsWith('codex');
          final expected = codex
              ? '![Generated image](<$filePath>)'
              : '![Generated image]($url)';
          final result = await service.prepare(
            tool,
            _result(['one']),
            style: McpImageResponseService.styleForClient(client),
          );
          final wire = McpToolAdapter.toCallToolResult(result);
          expect(result.isError, isFalse);
          expect(wire.content.where((c) => c.isImage), hasLength(1));
          expect(writes, codex ? 1 : 0);
          expect(publishes, 1);
          // Reproduce the failed client projection: it never visits images[].
          expect(wire.structuredContent!['display_markdown'], expected);
          final texts = wire.content
              .where((c) => c.isText)
              .map((c) => c as mcp.TextContent)
              .toList();
          final jsonText = jsonDecode(texts.first.text) as Map;
          expect(jsonText['display_markdown'], expected);
          expect(texts.last.text, expected);
          expect(jsonText, wire.structuredContent);
          expect(
            wire.structuredContent!['display_instructions'],
            contains(codex ? 'Codex desktop' : 'Cherry Studio'),
          );
        },
      );
    }
  }

  test('aggregate keeps image order and gated client links', () async {
    var index = 0;
    final ordered = McpImageResponseService(
      resolve: (reference) async => ResolvedAgentResource(
        reference: reference,
        label: 'image',
        bytes: bytes,
      ),
      shouldStripMetadata: () => false,
      publishDisplayImage:
          (_, {required mimeType, required metadataStripped}) =>
              McpImageDisplayLink(
                url.replace(path: '/mcp/images/${++index}.png'),
                DateTime.utc(2026, 9, 17),
              ),
    );
    final result = await ordered.prepare(
      'submit_generation',
      _result(['first', 'second']),
      style: McpImageDisplayStyle.inlineWithLink,
    );
    final images = result.details['images'] as List;
    final expected = images
        .expand(
          (dynamic image) => [
            image['display_markdown'],
            image['display_link_markdown'],
          ],
        )
        .join('\n\n');
    expect(result.details['display_markdown'], expected);
    expect(
      result.content.whereType<ToolResultTextContent>().last.text,
      expected,
    );
    expect(images.map((dynamic image) => image['resource_ref']['resourceId']), [
      'first',
      'second',
    ]);
    expect(result.content.whereType<ToolResultImageContent>(), hasLength(2));
  });

  test(
    'link clients keep links in the aggregate, never image embeds',
    () async {
      final result = await service.prepare(
        'submit_generation',
        _result(['one']),
        style: McpImageDisplayStyle.link,
      );
      final markdown = result.details['display_markdown'] as String;
      expect(markdown, '[Generated image 64x64](<$url>)');
      expect(markdown, isNot(contains('![')));
    },
  );

  for (final style in [
    McpImageDisplayStyle.inlineFile,
    McpImageDisplayStyle.inlineUrl,
  ]) {
    test(
      '$style never presents an incompatible fallback as displayable',
      () async {
        final result = await service.prepare(
          'submit_generation',
          _result(['one']),
          style: style,
          includeDisplayFile: style != McpImageDisplayStyle.inlineFile,
          includeDisplayUrl: style != McpImageDisplayStyle.inlineUrl,
        );
        expect(result.isError, isFalse);
        expect(result.details.containsKey('display_markdown'), isFalse);
        expect(
          (result.details['images'] as List).single['display_markdown'],
          isNull,
        );
        expect(
          result.content.whereType<ToolResultImageContent>(),
          hasLength(1),
        );
        expect(result.content.whereType<ToolResultTextContent>(), hasLength(1));
        expect(result.details['display_instructions'], contains('missing'));
        expect(
          result.details['display_instructions'],
          contains('Never regenerate'),
        );
      },
    );
  }

  test(
    'analysis and metadata tools do not add display work or Markdown',
    () async {
      for (final tool in ['inspect_images', 'get_recent_images']) {
        final result = await service.prepare(
          tool,
          _result(['one']),
          style: McpImageDisplayStyle.inlineFile,
        );
        expect(result.details.containsKey('display_markdown'), isFalse);
        expect(result.content.whereType<ToolResultTextContent>(), hasLength(1));
      }
      expect(writes, 0);
      expect(publishes, 0);
    },
  );
}

AgentToolResult _result(List<String> ids) => agentToolJsonResult({
  'ok': true,
  'images': [
    for (final id in ids)
      {
        'resource_ref': {
          'version': 1,
          'kind': 'generatedImage',
          'source': 'generation_history',
          'resourceId': id,
        },
      },
  ],
});
