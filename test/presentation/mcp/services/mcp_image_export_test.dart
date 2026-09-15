import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/harness/env/dart_io_execution_env.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_adapter.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_resource_action_service.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_image_response_service.dart';
import 'package:nai_launcher/presentation/providers/share_image_settings_provider.dart';

const _resource = {
  'resource_ref': {
    'version': 1,
    'kind': 'generatedImage',
    'source': 'generation_history',
    'resourceId': 'export-test',
    'display': {'title': 'private-source.png'},
    'provenance': {'prompt': 'private prompt'},
  },
};

void main() {
  late Directory directory;
  late Uint8List original;
  late ShareImageSettings settings;
  late McpImageResponseService responses;
  Uint8List? clipboard;

  ImageResourceActionService actions({
    ImageResourceExportPreparer? prepare,
    bool internal = false,
  }) => ImageResourceActionService(
    resolve: (_) async => ResolvedImageResourceActionSource(
      label: 'private-source.png',
      bytes: original,
    ),
    env: DartIoExecutionEnv(workingDirectory: directory.path),
    prepareExport: internal ? null : prepare ?? responses.prepareExportImage,
    clipboardWriter: (bytes) async {
      clipboard = bytes;
    },
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mcp-image-export-');
    final image = img.Image(width: 128, height: 160, numChannels: 4)
      ..clear(img.ColorRgba8(20, 60, 90, 255))
      ..textData = {
        'Software': 'NovelAI',
        'Comment': '{"prompt":"private prompt","seed":42}',
      };
    image.exif.imageIfd['Artist'] = 'private artist';
    original = Uint8List.fromList(img.encodePng(image));
    settings = const ShareImageSettings(protectionMode: true);
    clipboard = null;
    responses = McpImageResponseService(
      resolve: (_) async => null,
      shouldStripMetadata: () => settings.effectiveStripMetadataForCopyAndDrag,
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'MCP save sanitizes before the exclusive write and preserves originals',
    () async {
      final before = Uint8List.fromList(original);
      final service = actions();
      final result = await service.save({
        ..._resource,
        'destination_path': 'export.png',
      });
      expect(result.isError, isFalse);
      final bytes = await File('${directory.path}/export.png').readAsBytes();
      _expectClean(bytes);
      expect(original, orderedEquals(before));
      expect(UnifiedMetadataParser.extractPngTextData(original), isNotEmpty);
      final wire = McpToolAdapter.toCallToolResult(result);
      expect(wire.structuredContent?['metadata_stripped'], isTrue);
      expect(wire.structuredContent?['mime_type'], 'image/png');
      expect(jsonEncode(wire.structuredContent), isNot(contains('private')));
      expect(wire.structuredContent?['resource_ref'], {
        'version': 1,
        'kind': 'generatedImage',
        'source': 'generation_history',
        'resourceId': 'export-test',
      });
      final repeated = await service.save({
        ..._resource,
        'destination_path': 'export.png',
      });
      expect(repeated.details['code'], 'destination_exists');
      expect(await File('${directory.path}/export.png').readAsBytes(), bytes);
    },
  );

  test(
    'MCP clipboard export uses the same sanitized bytes as file export',
    () async {
      final service = actions();
      final saved = await service.save({
        ..._resource,
        'destination_path': 'export.png',
      });
      final copied = await service.copy(_resource);
      expect(saved.isError, isFalse);
      expect(copied.isError, isFalse);
      expect(copied.details['metadata_stripped'], isTrue);
      expect(
        clipboard,
        await File('${directory.path}/export.png').readAsBytes(),
      );
      _expectClean(clipboard!);
    },
  );

  test(
    'every export re-reads both privacy switches without reusing raw bytes',
    () async {
      final service = actions();
      var index = 0;
      for (final (protection, strip, expected) in [
        (false, true, false),
        (true, true, true),
        (true, false, false),
        (true, true, true),
      ]) {
        settings = ShareImageSettings(
          protectionMode: protection,
          stripMetadataForCopyAndDrag: strip,
        );
        final name = 'image-${index++}.png';
        final result = await service.save({
          ..._resource,
          'destination_path': name,
        });
        expect(result.details['metadata_stripped'], expected);
        final bytes = await File('${directory.path}/$name').readAsBytes();
        if (expected) {
          _expectClean(bytes);
        } else {
          expect(bytes, original);
        }
      }
    },
  );

  test(
    'sanitizer failure produces neither a file nor a clipboard write',
    () async {
      final failing = McpImageResponseService(
        resolve: (_) async => null,
        shouldStripMetadata: () => true,
        prepareImage: (_, {required fileName, required stripMetadata}) async {
          throw const ImageSanitizeException('C:/private/source.png');
        },
      );
      final service = actions(prepare: failing.prepareExportImage);
      final saved = await service.save({
        ..._resource,
        'destination_path': 'failed.png',
      });
      final copied = await service.copy(_resource);
      expect(saved.details['code'], 'image_export_preparation_failed');
      expect(copied.details['code'], 'image_export_preparation_failed');
      expect(await directory.list().toList(), isEmpty);
      expect(clipboard, isNull);
      expect(jsonEncode(saved.details), isNot(contains('C:/private')));
    },
  );

  test(
    'sanitized JPEG exports require a PNG destination rather than mislabeling bytes',
    () async {
      original = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 128, height: 160)),
      );
      final service = actions();
      final invalid = await service.save({
        ..._resource,
        'destination_path': 'image.jpg',
      });
      expect(invalid.details['code'], 'invalid_destination_extension');
      expect(await File('${directory.path}/image.jpg').exists(), isFalse);
      final valid = await service.save({
        ..._resource,
        'destination_path': 'image.png',
      });
      expect(valid.isError, isFalse);
      expect(valid.details['mime_type'], 'image/png');
      _expectClean(
        await File('${directory.path}/image.png').readAsBytes(),
        // JPEG has no alpha payload; the PNG encoder creates opaque alpha.
        alpha: 255,
      );
    },
  );

  test('non-MCP saves retain their existing original-image contract', () async {
    final result = await actions(
      internal: true,
    ).save({..._resource, 'destination_path': 'original.png'});
    expect(result.isError, isFalse);
    expect(result.details.containsKey('metadata_stripped'), isFalse);
    expect(
      await File('${directory.path}/original.png').readAsBytes(),
      original,
    );
  });

  test(
    'file access checks still reject exports outside the workspace',
    () async {
      final result = await actions().save({
        ..._resource,
        'destination_path': '../forbidden.png',
      });
      expect(result.details['code'], 'unsafe_destination');
      expect(await directory.list().toList(), isEmpty);
    },
  );
}

void _expectClean(Uint8List bytes, {int alpha = 254}) {
  final decoded = img.decodePng(bytes)!;
  expect([decoded.width, decoded.height], [128, 160]);
  expect(decoded.numChannels, 4);
  expect(UnifiedMetadataParser.extractPngTextData(bytes), isEmpty);
  expect(decoded.exif.isEmpty, isTrue);
  expect(decoded.textData ?? {}, isEmpty);
  expect(decoded.map((pixel) => pixel.a.toInt()).toSet(), {alpha});
}
