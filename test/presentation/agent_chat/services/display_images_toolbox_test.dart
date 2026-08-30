import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/display_images_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_resource.dart';

void main() {
  final references = [_reference('first'), _reference('second')];

  test('display_images returns multiple bounded image contents', () async {
    final service = DisplayImagesService(
      resolve: (reference) async => ResolvedAgentResource(
        reference: reference,
        label: reference.resourceId,
        bytes: _onePixelPng,
      ),
    );

    final result = await service.display({
      'resource_refs': references
          .map(AgentChatResourceReferenceCodec.encodeJsonMap)
          .toList(),
    });

    expect(result.isError, isFalse);
    expect(result.content.whereType<ToolResultImageContent>(), hasLength(2));
    expect(result.details, containsPair('count', 2));
  });

  test('display_images emits the owner-normalized reference', () async {
    final service = DisplayImagesService(
      resolve: (reference) async => ResolvedAgentResource(
        reference: generationImageResourceReference(reference.resourceId),
        label: reference.resourceId,
        bytes: _onePixelPng,
      ),
    );

    final result = await service.display({
      'resource_refs': [
        AgentChatResourceReferenceCodec.encodeJsonMap(
          AgentChatResourceReference(
            kind: AgentChatResourceKind.generatedImage,
            source: 'legacy_source',
            resourceId: 'first',
          ),
        ),
      ],
    });

    final images = result.details['images'] as List;
    final resourceRef = images.single['resource_ref'] as Map<String, dynamic>;
    expect(resourceRef['source'], generationImageResourceSource);
    expect(resourceRef['resourceId'], 'first');
  });

  test('display_images rejects an invalid stable reference', () async {
    final service = DisplayImagesService(resolve: (_) async => null);

    final result = await service.display({
      'resource_refs': [
        {'kind': 'generatedImage', 'resourceId': 'unsafe'},
      ],
    });

    expect(result.isError, isTrue);
    expect(_text(result), contains('invalid_resource_ref'));
  });

  test(
    'display_images fails when a referenced resource is unavailable',
    () async {
      final service = DisplayImagesService(resolve: (_) async => null);

      final result = await service.display({
        'resource_refs': [
          AgentChatResourceReferenceCodec.encodeJsonMap(references.first),
        ],
      });

      expect(result.isError, isTrue);
      expect(_text(result), contains('resource_unavailable'));
      expect(result.content.whereType<ToolResultImageContent>(), isEmpty);
    },
  );
}

String _text(AgentToolResult result) =>
    result.content.whereType<ToolResultTextContent>().single.text;

AgentChatResourceReference _reference(String id) => AgentChatResourceReference(
  kind: AgentChatResourceKind.generatedImage,
  source: 'generation_history',
  resourceId: id,
);

final Uint8List _onePixelPng = Uint8List.fromList(
  image_lib.encodePng(image_lib.Image(width: 1, height: 1)),
);
