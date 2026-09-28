import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_validator.dart';

void main() {
  AgentChatResourceReference reference({
    String source = 'localGallery',
    String resourceId = 'image-42',
    String? mediaId,
    Map<String, String> display = const {},
    Map<String, String> provenance = const {},
  }) {
    return AgentChatResourceReference(
      kind: AgentChatResourceKind.localGalleryImage,
      source: source,
      resourceId: resourceId,
      mediaId: mediaId,
      display: display,
      provenance: provenance,
    );
  }

  test('accepts opaque stable identifiers and bounded metadata', () {
    expect(
      () => AgentChatResourceReferenceValidator.validate(
        reference(
          resourceId: 'sha256:abc-123_example',
          mediaId: 'page.2',
          display: const {'title': 'A local image'},
          provenance: const {'collection': 'Favorites'},
        ),
      ),
      returnsNormally,
    );
  });

  test('rejects absolute paths, URLs, and traversal', () {
    final invalidReferences = [
      reference(resourceId: r'C:\Users\alice\image.png'),
      reference(resourceId: '/home/alice/image.png'),
      reference(resourceId: '../image.png'),
      reference(display: const {'title': 'https://example.com/image.png'}),
      reference(provenance: const {'location': r'\\server\share\image'}),
      reference(provenance: const {'location': 'folder/../image'}),
    ];

    for (final invalid in invalidReferences) {
      expect(
        () => AgentChatResourceReferenceValidator.validate(invalid),
        throwsFormatException,
      );
    }
  });

  test('rejects embedded data and base64-looking payloads', () {
    for (final value in ['data:image/png;base64,iVBORw0KGgo=', 'A' * 128]) {
      expect(
        () => AgentChatResourceReferenceValidator.validate(
          reference(display: {'preview': value}),
        ),
        throwsFormatException,
      );
    }

    final json = <String, dynamic>{
      'version': 1,
      'kind': 'localGalleryImage',
      'source': 'localGallery',
      'resourceId': 'image-42',
      'bytes': Uint8List.fromList([1, 2, 3]),
    };
    expect(
      () => AgentChatResourceReferenceCodec.decodeJsonMap(json),
      throwsFormatException,
    );
  });

  test('rejects excessive or malformed lightweight metadata', () {
    expect(
      () => AgentChatResourceReferenceValidator.validate(
        reference(
          display: {
            for (
              var index = 0;
              index <= AgentChatResourceReferenceValidator.maxMetadataEntries;
              index++
            )
              'key$index': 'value',
          },
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => AgentChatResourceReferenceValidator.validate(
        reference(display: const {'bad key': 'value'}),
      ),
      throwsFormatException,
    );
    expect(
      () => AgentChatResourceReferenceValidator.validate(
        reference(display: const {'title': 'line\nbreak'}),
      ),
      throwsFormatException,
    );
  });

  test('defensively copies metadata maps', () {
    final display = {'title': 'Before'};
    final value = reference(display: display);

    display['title'] = 'After';

    expect(value.display, {'title': 'Before'});
    expect(() => value.display['title'] = 'Changed', throwsUnsupportedError);
  });
}
