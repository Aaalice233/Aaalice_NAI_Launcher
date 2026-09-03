import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_resource.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_presentation_toolbox.dart';

void main() {
  final references = [_reference('first'), _reference('second')];

  test('conversation presentation reports images as user-visible', () async {
    final service = _service();

    final result = await service.present(
      _args(references),
      presentation: AgentImagePresentation.conversation,
    );

    expect(result.isError, isFalse);
    expect(result.content.whereType<ToolResultImageContent>(), hasLength(2));
    expect(result.details, containsPair('media_presentation', 'conversation'));
    expect(result.details, containsPair('user_visible', true));
    expect(result.details, containsPair('displayed_count', 2));
  });

  test('private inspection explicitly reports images as hidden', () async {
    final service = _service();

    final result = await service.present(
      _args(references.take(1)),
      presentation: AgentImagePresentation.modelOnly,
    );

    expect(result.isError, isFalse);
    expect(result.content.whereType<ToolResultImageContent>(), hasLength(1));
    expect(result.details, containsPair('media_presentation', 'model_only'));
    expect(result.details, containsPair('user_visible', false));
    expect(result.details, containsPair('inspected_count', 1));
  });

  test('presentation emits the owner-normalized reference', () async {
    final service = AgentImagePresentationService(
      resolve: (reference) async => ResolvedAgentResource(
        reference: generationImageResourceReference(reference.resourceId),
        label: reference.resourceId,
        bytes: _onePixelPng,
      ),
    );

    final result = await service.present(
      _args([
        AgentChatResourceReference(
          kind: AgentChatResourceKind.generatedImage,
          source: 'legacy_source',
          resourceId: 'first',
        ),
      ]),
      presentation: AgentImagePresentation.conversation,
    );

    final images = result.details['images'] as List;
    final resourceRef = images.single['resource_ref'] as Map<String, dynamic>;
    expect(resourceRef['source'], generationImageResourceSource);
    expect(resourceRef['resourceId'], 'first');
  });

  test('presentation rejects an invalid stable reference', () async {
    final service = AgentImagePresentationService(resolve: (_) async => null);

    final result = await service.present({
      'resource_refs': [
        {'kind': 'generatedImage', 'resourceId': 'unsafe'},
      ],
    }, presentation: AgentImagePresentation.conversation);

    expect(result.isError, isTrue);
    expect(_text(result), contains('invalid_resource_ref'));
  });

  test('presentation fails when a resource is unavailable', () async {
    final service = AgentImagePresentationService(resolve: (_) async => null);

    final result = await service.present(
      _args(references.take(1)),
      presentation: AgentImagePresentation.conversation,
    );

    expect(result.isError, isTrue);
    expect(_text(result), contains('resource_unavailable'));
    expect(result.content.whereType<ToolResultImageContent>(), isEmpty);
  });

  test('tool descriptions make visibility unambiguous', () {
    final tools = ImagePresentationToolbox.withService(_service()).tools();
    final inspect = tools.singleWhere((tool) => tool.name == 'inspect_images');
    final display = tools.singleWhere((tool) => tool.name == 'display_images');

    expect(inspect.description, contains('NOT shown to the user'));
    expect(display.description, contains('Show 1-12 images'));
  });
}

AgentImagePresentationService _service() => AgentImagePresentationService(
  resolve: (reference) async => ResolvedAgentResource(
    reference: reference,
    label: reference.resourceId,
    bytes: _onePixelPng,
  ),
);

Map<String, dynamic> _args(Iterable<AgentChatResourceReference> references) => {
  'resource_refs': references
      .map(AgentChatResourceReferenceCodec.encodeJsonMap)
      .toList(),
};

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
