import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_adapter.dart';
import 'package:nai_launcher/core/mcp/mcp_image_http_endpoint.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/defined_agent_tool.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_image_response_service.dart';
import 'package:nai_launcher/presentation/providers/share_image_settings_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  late Uint8List original;
  late ShareImageSettings settings;
  late McpImageResponseService service;
  late int resolves;
  late int validations;
  setUp(() {
    original = _png();
    settings = const ShareImageSettings();
    resolves = 0;
    validations = 0;
    service = McpImageResponseService(
      resolve: (reference) async {
        resolves++;
        return ResolvedAgentResource(
          reference: reference,
          label: 'private-file-12345.png',
          bytes: original,
          filePath: 'C:/private/original.png',
        );
      },
      validate: (_) async {
        validations++;
      },
      shouldStripMetadata: () => settings.effectiveStripMetadataForCopyAndDrag,
    );
  });

  for (final name in McpImageResponseService.imageTools) {
    test(
      '$name returns original PNG bytes instead of a 256px preview',
      () async {
        final result = await service.prepare(name, _internalResult());
        final wire = McpToolAdapter.toCallToolResult(result);
        final image =
            wire.content.singleWhere((c) => c.isImage) as mcp.ImageContent;
        final bytes = base64Decode(image.data);
        final decoded = img.decodePng(bytes)!;
        expect(result.isError, isFalse);
        expect(image.mimeType, 'image/png');
        expect(bytes, orderedEquals(original));
        expect([decoded.width, decoded.height], [832, 1216]);
        expect(wire.structuredContent?['metadata_stripped'], isFalse);
        expect(
          wire.structuredContent?['display_status'],
          'requires_client_rendering',
        );
        expect(wire.structuredContent?['image_content_count'], 1);
        expect(wire.structuredContent?.containsKey('displayed_count'), isFalse);
        expect(resolves, 1);
        expect(validations, 1);
        _expectNoFileShortcuts(wire);
      },
    );
  }

  test(
    'privacy strips text, EXIF and alpha LSB without resizing or overwriting',
    () async {
      settings = const ShareImageSettings(protectionMode: true);
      final originalSnapshot = Uint8List.fromList(original);
      final result = await service.prepare(
        'submit_generation',
        _internalResult(),
      );
      final wire = McpToolAdapter.toCallToolResult(result);
      final media =
          wire.content.singleWhere((c) => c.isImage) as mcp.ImageContent;
      final bytes = base64Decode(media.data);
      final decoded = img.decodePng(bytes)!;
      expect([decoded.width, decoded.height], [832, 1216]);
      expect(decoded.textData ?? {}, isEmpty);
      expect(decoded.exif.isEmpty, isTrue);
      expect(decoded.iccProfile, isNull);
      expect(UnifiedMetadataParser.extractPngTextData(bytes), isEmpty);
      final alphaBits = decoded.map((p) => p.a.toInt() & 1).toSet();
      expect(alphaBits, {0});
      expect(decoded.getPixel(0, 0).r, 40);
      expect(decoded.getPixel(0, 0).g, 80);
      expect(decoded.getPixel(0, 0).b, 120);
      expect(original, orderedEquals(originalSnapshot));
      expect(
        img.decodePng(original)!.textData?['Comment'],
        contains('private'),
      );
      expect(wire.structuredContent?['metadata_stripped'], isTrue);
      final report = jsonEncode(wire.structuredContent);
      expect(report, isNot(contains('12345')));
      expect(report, isNot(contains('private')));
      final entry = (wire.structuredContent!['images'] as List).single as Map;
      expect(entry['resource_ref'], {
        'version': 1,
        'kind': 'generatedImage',
        'source': 'generation_history',
        'resourceId': 'image-1',
      });
      _expectNoFileShortcuts(wire);
    },
  );

  test(
    'effective setting is re-read on every retrieval, without raw-cache reuse',
    () async {
      for (final (protection, strip, expectedStrip) in [
        (false, true, false),
        (true, true, true),
        (true, false, false),
        (true, true, true),
      ]) {
        settings = ShareImageSettings(
          protectionMode: protection,
          stripMetadataForCopyAndDrag: strip,
        );
        final result = await service.prepare(
          'display_images',
          _internalResult(),
        );
        final bytes = _bytes(result);
        expect(result.details['metadata_stripped'], expectedStrip);
        expect(
          UnifiedMetadataParser.extractPngTextData(bytes).isEmpty,
          expectedStrip,
        );
        if (!expectedStrip) expect(bytes, orderedEquals(original));
      }
    },
  );

  test(
    'recent images are path-free references and do not load image bytes',
    () async {
      settings = const ShareImageSettings(protectionMode: true);
      final result = await service.prepare(
        'get_recent_images',
        _internalResult(media: false),
      );
      final wire = McpToolAdapter.toCallToolResult(result);
      expect(wire.content.where((c) => c.isImage), isEmpty);
      expect((wire.structuredContent!['images'] as List), hasLength(1));
      expect(jsonEncode(wire.structuredContent), isNot(contains('12345')));
      expect(resolves, 0);
      _expectNoFileShortcuts(wire);
    },
  );

  test('all images are returned in order, not only the first image', () async {
    final payload = {
      'ok': true,
      'images': [
        for (final id in ['image-1', 'image-2']) {'resource_ref': _refJson(id)},
      ],
    };
    final result = await service.prepare(
      'generate_image',
      agentToolJsonResult(payload),
    );
    expect(result.content.whereType<ToolResultImageContent>(), hasLength(2));
    expect(
      (result.details['images'] as List).map(
        (dynamic e) => e['resource_ref']['resourceId'],
      ),
      ['image-1', 'image-2'],
    );
  });

  test(
    'sanitization failure returns no preview, bytes or source path',
    () async {
      final failing = McpImageResponseService(
        resolve: (ref) async => ResolvedAgentResource(
          reference: ref,
          label: 'private',
          bytes: original,
        ),
        shouldStripMetadata: () => true,
        prepareImage: (_, {required fileName, required stripMetadata}) async {
          throw const ImageSanitizeException('C:/private/original.png');
        },
      );
      final result = await failing.prepare('generate_image', _internalResult());
      expect(result.isError, isTrue);
      expect(result.details['code'], 'mcp_image_unavailable');
      expect(result.content.whereType<ToolResultImageContent>(), isEmpty);
      expect(jsonEncode(result.details), isNot(contains('C:/private')));
      expect(
        result.details['message'],
        contains('do not generate or charge again'),
      );
    },
  );

  test(
    'unavailable or corrupt originals never fall back to thumbnails',
    () async {
      for (final bytes in <Uint8List?>[
        null,
        Uint8List.fromList([1, 2, 3]),
      ]) {
        final unavailable = McpImageResponseService(
          resolve: (ref) async => ResolvedAgentResource(
            reference: ref,
            label: 'image',
            bytes: bytes,
          ),
          shouldStripMetadata: () => true,
        );
        final result = await unavailable.prepare(
          'display_images',
          _internalResult(),
        );
        expect(result.isError, isTrue);
        expect(result.content.whereType<ToolResultImageContent>(), isEmpty);
      }
    },
  );

  test('image content without a resource identity is rejected', () async {
    final result = await service.prepare(
      'submit_generation',
      AgentToolResult(content: [_preview()], details: const {}),
    );
    expect(result.isError, isTrue);
    expect(result.content.whereType<ToolResultImageContent>(), isEmpty);
  });

  test(
    'optional display file receives only sanitized full-resolution outgoing bytes',
    () async {
      Uint8List? written;
      var writes = 0;
      final displayPath = p.join(
        Directory.systemTemp.path,
        'display cache',
        'image-safe.png',
      );
      final markdownPath = p.absolute(displayPath).replaceAll('\\', '/');
      final withDisplayFile = McpImageResponseService(
        resolve: (ref) async => ResolvedAgentResource(
          reference: ref,
          label: 'private-source',
          bytes: original,
          filePath: 'C:/private/original.png',
        ),
        shouldStripMetadata: () => true,
        writeDisplayFile: (image) async {
          writes++;
          written = image.bytes;
          return File(displayPath);
        },
      );
      await withDisplayFile.prepare('display_images', _internalResult());
      expect(writes, 0);
      final result = await withDisplayFile.prepare(
        'display_images',
        _internalResult(),
        includeDisplayFile: true,
        style: McpImageDisplayStyle.inlineFile,
      );
      expect(result.isError, isFalse);
      expect(writes, 1);
      expect(written, orderedEquals(_bytes(result)));
      expect(UnifiedMetadataParser.extractPngTextData(written!), isEmpty);
      final decoded = img.decodePng(written!)!;
      expect([decoded.width, decoded.height], [832, 1216]);
      final wire = McpToolAdapter.toCallToolResult(result);
      final entry = (wire.structuredContent!['images'] as List).single as Map;
      expect(entry['display_path'], markdownPath);
      expect(entry['display_markdown'], '![Generated image](<$markdownPath>)');
      expect(
        wire.structuredContent!['display_instructions'],
        contains('final answer'),
      );
      expect(
        wire.structuredContent!['display_instructions'],
        contains('Do not call display_images again'),
      );
      _expectNoFileShortcuts(wire);
      await withDisplayFile.prepare(
        'inspect_images',
        _internalResult(),
        includeDisplayFile: true,
      );
      expect(writes, 1);
    },
  );

  test('display-cache failure never falls back to the source path', () async {
    final failing = McpImageResponseService(
      resolve: (ref) async => ResolvedAgentResource(
        reference: ref,
        label: 'private',
        bytes: original,
        filePath: 'C:/private/original.png',
      ),
      shouldStripMetadata: () => true,
      writeDisplayFile: (_) async =>
          throw const FileSystemException('cache unavailable'),
    );
    final result = await failing.prepare(
      'display_images',
      _internalResult(),
      includeDisplayFile: true,
    );
    expect(result.isError, isTrue);
    expect(result.content.whereType<ToolResultImageContent>(), isEmpty);
    expect(jsonEncode(result.details), isNot(contains('C:/private')));
  });

  test(
    'completed generation survives optional display failures with sanitized media',
    () async {
      final failingDisplay = McpImageResponseService(
        resolve: (ref) async => ResolvedAgentResource(
          reference: ref,
          label: 'private',
          bytes: original,
          filePath: 'C:/private/original.png',
        ),
        shouldStripMetadata: () => true,
        writeDisplayFile: (_) async =>
            throw const FileSystemException('cache unavailable'),
        publishDisplayImage:
            (_, {required mimeType, required metadataStripped}) =>
                throw StateError('display unavailable'),
      );
      final result = await failingDisplay.prepare(
        'submit_generation',
        _internalResult(),
        style: McpImageDisplayStyle.inlineFile,
      );
      expect(result.isError, isFalse);
      expect(result.content.whereType<ToolResultImageContent>(), hasLength(1));
      expect(UnifiedMetadataParser.extractPngTextData(_bytes(result)), isEmpty);
      expect(jsonEncode(result.details), isNot(contains('C:/private')));
      expect(
        result.details['display_instructions'],
        contains('Never regenerate'),
      );
      final descriptor = (result.details['images'] as List).single as Map;
      expect(descriptor['resource_ref'], isNotNull);
      expect(descriptor.containsKey('display_markdown'), isFalse);
    },
  );

  test('Codex generation can explicitly opt out of display files', () async {
    var writes = 0;
    final service = McpImageResponseService(
      resolve: (ref) async => ResolvedAgentResource(
        reference: ref,
        label: 'image',
        bytes: original,
      ),
      shouldStripMetadata: () => false,
      writeDisplayFile: (_) async {
        writes++;
        return File('unused.png');
      },
    );
    final result = await service.prepare(
      'generate_image',
      _internalResult(),
      style: McpImageDisplayStyle.inlineFile,
      includeDisplayFile: false,
    );
    expect(result.isError, isFalse);
    expect(writes, 0);
    expect(result.content.whereType<ToolResultImageContent>(), hasLength(1));
  });

  test(
    'HTTP and local display variants share sanitized original-resolution bytes',
    () async {
      Uint8List? published;
      var publishes = 0;
      final uri = Uri.parse(
        'http://127.0.0.1:20624/mcp/images/test-capability.png',
      );
      final expiry = DateTime.utc(2026, 9, 14, 4);
      final withHttp = McpImageResponseService(
        resolve: (ref) async => ResolvedAgentResource(
          reference: ref,
          label: 'private',
          bytes: original,
        ),
        shouldStripMetadata: () => true,
        writeDisplayFile: (_) async =>
            File(p.join(Directory.systemTemp.path, 'image-safe.png')),
        publishDisplayImage:
            (bytes, {required mimeType, required metadataStripped}) {
              expect(metadataStripped, isTrue);
              expect(mimeType, 'image/png');
              publishes++;
              published = bytes;
              return McpImageDisplayLink(uri, expiry);
            },
      );
      final result = await withHttp.prepare(
        'display_images',
        _internalResult(),
        includeDisplayFile: true,
      );
      final entry = (result.details['images'] as List).single as Map;
      expect(entry['display_url'], uri.toString());
      expect(entry['display_url_expires_at'], expiry.toIso8601String());
      expect(entry['display_markdown'], entry['display_url_markdown']);
      expect(entry['display_file_markdown'], contains('image-safe.png'));
      expect(published, orderedEquals(_bytes(result)));
      expect(UnifiedMetadataParser.extractPngTextData(published!), isEmpty);
      final decoded = img.decodePng(published!)!;
      expect([decoded.width, decoded.height], [832, 1216]);
      _expectNoFileShortcuts(McpToolAdapter.toCallToolResult(result));
      final codex = await withHttp.prepare(
        'display_images',
        _internalResult(),
        includeDisplayFile: true,
        style: McpImageDisplayStyle.inlineFile,
      );
      final codexEntry = (codex.details['images'] as List).single as Map;
      expect(
        codexEntry['display_markdown'],
        codexEntry['display_file_markdown'],
      );
      expect(codexEntry['display_url'], uri.toString());
      final disabled = await withHttp.prepare(
        'display_images',
        _internalResult(),
        includeDisplayUrl: false,
      );
      expect(
        ((disabled.details['images'] as List).single as Map).containsKey(
          'display_url',
        ),
        isFalse,
      );
      await withHttp.prepare('inspect_images', _internalResult());
      await withHttp.prepare('generate_image', _internalResult());
      expect(publishes, 3);
    },
  );

  test(
    'unavailable HTTP publisher preserves native image output without a false link',
    () async {
      final withHttp = McpImageResponseService(
        resolve: (ref) async => ResolvedAgentResource(
          reference: ref,
          label: 'image',
          bytes: original,
        ),
        shouldStripMetadata: () => false,
        publishDisplayImage:
            (_, {required mimeType, required metadataStripped}) => null,
      );
      final result = await withHttp.prepare(
        'display_images',
        _internalResult(),
      );
      expect(result.isError, isFalse);
      expect(_bytes(result), original);
      expect(
        ((result.details['images'] as List).single as Map).containsKey(
          'display_url',
        ),
        isFalse,
      );
      expect(result.details['display_status'], 'requires_client_rendering');
    },
  );

  test('client labels select the display style', () {
    const styles = {
      // Claude Desktop 有点击门，图片之外还要附链接。
      'claude-ai 0.1.0': McpImageDisplayStyle.inlineWithLink,
      'claude-code 2.0.0': McpImageDisplayStyle.link,
      'claude-code 0.1.0': McpImageDisplayStyle.link,
      'local-agent-mode-nai-launcher 1.0.0':
          McpImageDisplayStyle.inlineWorkspaceFile,
      'pi-mcp-nai-launcher 1.0.0': McpImageDisplayStyle.link,
      'codex-mcp-client 0.154.0': McpImageDisplayStyle.inlineFile,
      'Cherry Studio 2.0.14': McpImageDisplayStyle.inlineUrl,
      'unknown client': McpImageDisplayStyle.inlineUrl,
    };
    for (final entry in styles.entries) {
      expect(
        McpImageResponseService.styleForClient(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test(
    'link clients receive a clickable link instead of image Markdown',
    () async {
      final uri = Uri.parse('http://127.0.0.1:20624/mcp/images/link-case.png');
      final displayPath = p
          .absolute(p.join(Directory.systemTemp.path, 'image-link.png'))
          .replaceAll('\\', '/');
      var writes = 0;
      final withLink = McpImageResponseService(
        resolve: (ref) async => ResolvedAgentResource(
          reference: ref,
          label: 'private',
          bytes: original,
        ),
        shouldStripMetadata: () => false,
        writeDisplayFile: (_) async {
          writes++;
          return File(displayPath);
        },
        publishDisplayImage:
            (_, {required mimeType, required metadataStripped}) =>
                McpImageDisplayLink(uri, DateTime.utc(2026, 9, 14, 5)),
      );

      // Both references are prepared even though the caller opted out of each.
      final result = await withLink.prepare(
        'display_images',
        _internalResult(),
        includeDisplayFile: false,
        includeDisplayUrl: false,
        style: McpImageDisplayStyle.link,
      );

      final entry = (result.details['images'] as List).single as Map;
      expect(writes, 1);
      expect(
        entry['display_link_markdown'],
        '[Generated image 832x1216](<$uri>)',
      );
      expect(entry['display_markdown'], entry['display_link_markdown']);
      expect(entry['display_url'], uri.toString());
      expect(entry['display_path'], displayPath);
      expect(
        result.details['display_instructions'],
        contains('clickable link'),
      );
      expect(
        result.details['display_instructions'],
        isNot(contains('display_markdown directly')),
      );
      expect(_bytes(result), original);
      _expectNoFileShortcuts(McpToolAdapter.toCallToolResult(result));

      final generated = await withLink.prepare(
        'generate_image',
        _internalResult(),
        style: McpImageDisplayStyle.link,
      );
      expect(
        generated.details['display_instructions'],
        contains('clickable link'),
      );
      expect(
        ((generated.details['images'] as List).single as Map).containsKey(
          'display_link_markdown',
        ),
        isTrue,
      );
      expect(writes, 2);
    },
  );

  test('a gated client keeps the image and gains a clickable link', () async {
    final uri = Uri.parse('http://127.0.0.1:20624/mcp/images/gated-case.png');
    var writes = 0;
    final gated = McpImageResponseService(
      resolve: (ref) async => ResolvedAgentResource(
        reference: ref,
        label: 'private',
        bytes: original,
      ),
      shouldStripMetadata: () => false,
      writeDisplayFile: (_) async {
        writes++;
        return File(p.join(Directory.systemTemp.path, 'image-gated.png'));
      },
      publishDisplayImage:
          (_, {required mimeType, required metadataStripped}) =>
              McpImageDisplayLink(uri, DateTime.utc(2026, 9, 14, 6)),
    );

    final result = await gated.prepare(
      'display_images',
      _internalResult(),
      style: McpImageDisplayStyle.inlineWithLink,
    );

    final entry = (result.details['images'] as List).single as Map;
    expect(entry['display_markdown'], '![Generated image]($uri)');
    expect(
      entry['display_link_markdown'],
      '[Generated image 832x1216](<$uri>)',
    );
    // 点击门的代价只有一条链接，不该顺带写显示缓存文件。
    expect(writes, 0);
    expect(entry.containsKey('display_path'), isFalse);
    final instructions = result.details['display_instructions'] as String;
    expect(instructions, contains('display_markdown'));
    expect(instructions, contains('clickable link'));
    expect(instructions, contains('one-click reveal'));
    // 合并工具块会吞掉直显的图，只有这个客户端需要这条节奏提示。
    expect(instructions, contains('before any further tool call'));
    expect(instructions.length, lessThan(600));
    for (final style in [
      McpImageDisplayStyle.link,
      McpImageDisplayStyle.inlineFile,
      McpImageDisplayStyle.inlineUrl,
    ]) {
      final other = await gated.prepare(
        'display_images',
        _internalResult(),
        style: style,
      );
      expect(
        other.details['display_instructions'],
        isNot(contains('before any further tool call')),
      );
    }
  });

  test(
    'a link client falls back to the display file when HTTP is unavailable',
    () async {
      final displayPath = p
          .absolute(p.join(Directory.systemTemp.path, 'image-fallback.png'))
          .replaceAll('\\', '/');
      final withoutHttp = McpImageResponseService(
        resolve: (ref) async => ResolvedAgentResource(
          reference: ref,
          label: 'private',
          bytes: original,
        ),
        shouldStripMetadata: () => false,
        writeDisplayFile: (_) async => File(displayPath),
        publishDisplayImage:
            (_, {required mimeType, required metadataStripped}) => null,
      );

      final result = await withoutHttp.prepare(
        'display_images',
        _internalResult(),
        style: McpImageDisplayStyle.link,
      );

      final entry = (result.details['images'] as List).single as Map;
      expect(
        entry['display_link_markdown'],
        '[Generated image 832x1216](<$displayPath>)',
      );
      expect(entry['display_markdown'], entry['display_link_markdown']);
      expect(entry.containsKey('display_url'), isFalse);
    },
  );

  test('a caller save_path replaces the display cache file', () async {
    const savedPath = 'C:/work/out-1.png';
    final uri = Uri.parse('http://127.0.0.1:20624/mcp/images/saved-case.png');
    var writes = 0;
    final withSavePath = McpImageResponseService(
      resolve: (ref) async => ResolvedAgentResource(
        reference: ref,
        label: 'private',
        bytes: original,
      ),
      shouldStripMetadata: () => false,
      writeDisplayFile: (_) async {
        writes++;
        return File(p.join(Directory.systemTemp.path, 'image-saved.png'));
      },
      publishDisplayImage:
          (_, {required mimeType, required metadataStripped}) =>
              McpImageDisplayLink(uri, DateTime.utc(2026, 9, 18)),
    );

    final result = await withSavePath.prepare(
      'submit_generation',
      _internalResult(export: const {'saved_path': savedPath}),
      includeDisplayFile: true,
      style: McpImageDisplayStyle.inlineWorkspaceFile,
    );

    final entry = (result.details['images'] as List).single as Map;
    expect(writes, 0);
    expect(entry['saved_path'], savedPath);
    expect(entry['display_path'], savedPath);
    expect(entry['display_markdown'], '![Generated image](<$savedPath>)');
    expect(result.details['display_markdown'], entry['display_markdown']);
    expect(
      result.details['display_instructions'],
      contains('saved_path is the durable file chosen by the caller'),
    );

    // 终端拿到持久文件后给两条链接，display_link_markdown 仍只是 HTTP。
    final linked = await withSavePath.prepare(
      'submit_generation',
      _internalResult(export: const {'saved_path': savedPath}),
      style: McpImageDisplayStyle.link,
    );
    final linkedEntry = (linked.details['images'] as List).single as Map;
    final savedUri = Uri.file(savedPath, windows: Platform.isWindows);
    expect(writes, 0);
    expect(linkedEntry['display_path'], savedPath);
    expect(
      linkedEntry['display_file_link_markdown'],
      '[Generated image 832x1216](<$savedUri>)',
    );
    expect(
      linkedEntry['display_link_markdown'],
      '[Generated image 832x1216](<$uri>)',
    );
    expect(
      linkedEntry['display_markdown'],
      [
        '[Generated image 832x1216](<$savedUri>)',
        '[Temporary preview link](<$uri>)',
      ].join('\n'),
    );
    expect(
      linked.details['display_instructions'],
      contains('durable local file link first'),
    );
  });

  test(
    'a terminal link stays a single HTTP link without a saved file',
    () async {
      final uri = Uri.parse('http://127.0.0.1:20624/mcp/images/no-save.png');
      final withoutSave = McpImageResponseService(
        resolve: (ref) async => ResolvedAgentResource(
          reference: ref,
          label: 'image',
          bytes: original,
        ),
        shouldStripMetadata: () => false,
        writeDisplayFile: (_) async =>
            File(p.join(Directory.systemTemp.path, 'image-no-save.png')),
        publishDisplayImage:
            (_, {required mimeType, required metadataStripped}) =>
                McpImageDisplayLink(uri, DateTime.utc(2026, 9, 19)),
      );

      final result = await withoutSave.prepare(
        'submit_generation',
        _internalResult(),
        style: McpImageDisplayStyle.link,
      );

      final entry = (result.details['images'] as List).single as Map;
      expect(entry['display_markdown'], '[Generated image 832x1216](<$uri>)');
      expect(entry['display_markdown'], isNot(contains('\n')));
      expect(
        result.details['display_instructions'],
        isNot(contains('durable local file link first')),
      );
    },
  );

  test('a terminal file link is a percent-encoded file URI', () async {
    final savedPath = p
        .absolute(p.join(Directory.systemTemp.path, 'work dir', 'out 1.png'))
        .replaceAll('\\', '/');
    final uri = Uri.parse('http://127.0.0.1:20624/mcp/images/spaced.png');
    final withSpaces = McpImageResponseService(
      resolve: (ref) async => ResolvedAgentResource(
        reference: ref,
        label: 'image',
        bytes: original,
      ),
      shouldStripMetadata: () => false,
      publishDisplayImage:
          (_, {required mimeType, required metadataStripped}) =>
              McpImageDisplayLink(uri, DateTime.utc(2026, 9, 19)),
    );

    final result = await withSpaces.prepare(
      'submit_generation',
      _internalResult(
        export: {'saved_path': savedPath, 'saved_path_source': 'caller'},
      ),
      style: McpImageDisplayStyle.link,
    );

    final entry = (result.details['images'] as List).single as Map;
    final fileLink = entry['display_file_link_markdown'] as String;
    expect(
      fileLink,
      '[Generated image 832x1216]'
      '(<${Uri.file(savedPath, windows: Platform.isWindows)}>)',
    );
    expect(fileLink, startsWith('[Generated image 832x1216](<file:///'));
    expect(fileLink, contains('work%20dir/out%201.png'));
    expect(fileLink, isNot(contains('\\')));
    expect((entry['display_markdown'] as String).split('\n').first, fileLink);
  });

  for (final source in ['caller', 'gallery_original']) {
    test('$source selects the display reference per client style', () async {
      const savedPath = 'C:/work/out-source.png';
      final uri = Uri.parse('http://127.0.0.1:20624/mcp/images/$source.png');
      final sourced = McpImageResponseService(
        resolve: (ref) async => ResolvedAgentResource(
          reference: ref,
          label: 'image',
          bytes: original,
        ),
        shouldStripMetadata: () => false,
        publishDisplayImage:
            (_, {required mimeType, required metadataStripped}) =>
                McpImageDisplayLink(uri, DateTime.utc(2026, 9, 19)),
      );
      final payload = {'saved_path': savedPath, 'saved_path_source': source};

      final workspace = await sourced.prepare(
        'submit_generation',
        _internalResult(export: payload),
        style: McpImageDisplayStyle.inlineWorkspaceFile,
      );
      final workspaceEntry =
          (workspace.details['images'] as List).single as Map;
      expect(workspaceEntry['saved_path_source'], source);
      expect(
        workspaceEntry['display_markdown'],
        source == 'caller'
            ? '![Generated image](<$savedPath>)'
            : '![Generated image]($uri)',
      );

      // Codex 渲染任意绝对路径，三种来源都走文件 Markdown。
      final codex = await sourced.prepare(
        'submit_generation',
        _internalResult(export: payload),
        style: McpImageDisplayStyle.inlineFile,
      );
      final codexEntry = (codex.details['images'] as List).single as Map;
      expect(
        codexEntry['display_markdown'],
        '![Generated image](<$savedPath>)',
      );

      for (final style in [
        McpImageDisplayStyle.inlineUrl,
        McpImageDisplayStyle.inlineWithLink,
      ]) {
        final http = await sourced.prepare(
          'submit_generation',
          _internalResult(export: payload),
          style: style,
        );
        expect(
          ((http.details['images'] as List).single as Map)['display_markdown'],
          '![Generated image]($uri)',
        );
      }
    });
  }

  test('a missing saved_path_source is treated as a caller path', () async {
    const savedPath = 'C:/work/out-legacy.png';
    final uri = Uri.parse('http://127.0.0.1:20624/mcp/images/legacy.png');
    final legacy = McpImageResponseService(
      resolve: (ref) async => ResolvedAgentResource(
        reference: ref,
        label: 'image',
        bytes: original,
      ),
      shouldStripMetadata: () => false,
      publishDisplayImage:
          (_, {required mimeType, required metadataStripped}) =>
              McpImageDisplayLink(uri, DateTime.utc(2026, 9, 19)),
    );

    final result = await legacy.prepare(
      'submit_generation',
      _internalResult(export: const {'saved_path': savedPath}),
      style: McpImageDisplayStyle.inlineWorkspaceFile,
    );

    final entry = (result.details['images'] as List).single as Map;
    expect(entry.containsKey('saved_path_source'), isFalse);
    expect(entry['display_markdown'], '![Generated image](<$savedPath>)');
  });

  test(
    'the source legend reaches the model only when a source is set',
    () async {
      const legend = 'gallery_original for the launcher own gallery file';
      final withoutSource = await service.prepare(
        'submit_generation',
        _internalResult(export: const {'saved_path': 'C:/work/out.png'}),
      );
      expect(
        withoutSource.details['display_instructions'],
        isNot(contains(legend)),
      );

      final withSource = await service.prepare(
        'submit_generation',
        _internalResult(
          export: const {
            'saved_path': 'C:/gallery/original.png',
            'saved_path_source': 'gallery_original',
          },
        ),
      );
      final instructions = withSource.details['display_instructions'] as String;
      expect(instructions, contains(legend));
      expect(instructions, contains('never be deleted, moved or rewritten'));
      expect(instructions, isNot(contains('default_export')));
      expect(
        instructions,
        contains('saved_path is the durable file chosen by the caller'),
      );
      _expectNoFileShortcuts(McpToolAdapter.toCallToolResult(withSource));
    },
  );

  test(
    'a workspace client is told why a launcher path is not inlined',
    () async {
      final result = await service.prepare(
        'submit_generation',
        _internalResult(
          export: const {
            'saved_path': 'C:/gallery/original.png',
            'saved_path_source': 'gallery_original',
          },
        ),
        style: McpImageDisplayStyle.inlineWorkspaceFile,
      );

      final instructions = result.details['display_instructions'] as String;
      expect(
        instructions,
        contains('renders local images only inside its working directory'),
      );
      expect(instructions, contains('save_path you passed yourself'));
      expect(
        instructions,
        contains('falls back to the HTTP URL, which expires'),
      );
    },
  );

  test('a save_error is forwarded without inviting a regeneration', () async {
    const failure = {
      'code': 'destination_exists',
      'message': 'The save_path destination already exists.',
    };

    final result = await service.prepare(
      'submit_generation',
      _internalResult(export: const {'save_error': failure}),
    );

    final entry = (result.details['images'] as List).single as Map;
    expect(entry['save_error'], failure);
    expect(entry.containsKey('saved_path'), isFalse);
    final instructions = result.details['display_instructions'] as String;
    expect(instructions, contains('never regenerate for that'));
    expect(instructions, contains('save_generated_image'));
    expect(instructions, isNot(contains('durable file chosen by the caller')));
    _expectNoFileShortcuts(McpToolAdapter.toCallToolResult(result));
  });

  test(
    'paid preparation and non-image results retain their contracts',
    () async {
      final paid = agentToolJsonResult({
        'ok': true,
        'preparation_id': 'p1',
        'estimated_anlas': 20,
        'confirmation_required': true,
      });
      expect(await service.prepare('generate_image', paid), same(paid));
      final error = agentToolError('not_found', 'Missing preparation');
      expect(await service.prepare('submit_generation', error), same(error));
      expect(
        await service.prepare('get_generation_settings', paid),
        same(paid),
      );
      expect(resolves, 0);
    },
  );
}

void _expectNoFileShortcuts(mcp.CallToolResult wire) {
  final texts = wire.content
      .where((c) => c.isText)
      .map((c) => (c as mcp.TextContent).text);
  expect(jsonDecode(texts.first), wire.structuredContent);
  for (final token in ['"path"', '"files"', 'preferFileImages', 'C:/private']) {
    for (final text in texts) {
      expect(text, isNot(contains(token)));
    }
  }
}

Uint8List _bytes(AgentToolResult result) => base64Decode(
  result.content
      .whereType<ToolResultImageContent>()
      .single
      .image
      .source
      .base64Data!,
);

Map<String, dynamic> _refJson(String id) =>
    AgentChatResourceReferenceCodec.encodeJsonMap(
      AgentChatResourceReference(
        kind: AgentChatResourceKind.generatedImage,
        source: 'generation_history',
        resourceId: id,
        display: const {'title': 'private-file-12345.png'},
        provenance: const {'name': 'private prompt'},
      ),
    );

AgentToolResult _internalResult({
  bool media = true,
  Map<String, dynamic> export = const {},
}) {
  final payload = {
    'ok': true,
    'images': [
      {
        'resource_ref': _refJson('image-1'),
        'seed': 12345,
        'size': '832x1216',
        'saved': true,
        'path': '2026-09-14/private-file-12345.png',
        ...export,
      },
    ],
  };
  return AgentToolResult(
    content: [
      ToolResultTextContent(jsonEncode(payload)),
      if (media) _preview(),
    ],
    details: {
      ...payload,
      'files': ['C:/private/original.png'],
      'preferFileImages': true,
    },
  );
}

ToolResultImageContent _preview() => ToolResultImageContent(
  ImageContent(
    source: ImageSource.base64(
      mimeType: 'image/jpeg',
      base64Data: base64Encode([1, 2, 3]),
    ),
  ),
);

Uint8List _png() {
  final image = img.Image(width: 832, height: 1216, numChannels: 4);
  image.clear(img.ColorRgba8(40, 80, 120, 255));
  image.textData = {
    'Software': 'NovelAI',
    'Comment': '{"prompt":"private prompt"}',
  };
  image.exif.imageIfd['Artist'] = 'private artist';
  return Uint8List.fromList(img.encodePng(image, level: 1));
}
