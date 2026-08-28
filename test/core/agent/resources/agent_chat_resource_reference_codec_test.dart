import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_validator.dart';

void main() {
  final kinds = <AgentChatResourceKind, String>{
    AgentChatResourceKind.onlineGalleryMedia: 'onlineGalleryMedia',
    AgentChatResourceKind.localGalleryImage: 'localGalleryImage',
    AgentChatResourceKind.tagLibraryEntry: 'tagLibraryEntry',
    AgentChatResourceKind.vibeLibraryEntry: 'vibeLibraryEntry',
    AgentChatResourceKind.preciseRefLibraryEntry: 'preciseRefLibraryEntry',
  };

  AgentChatResourceReference referenceFor(AgentChatResourceKind kind) {
    return AgentChatResourceReference(
      kind: kind,
      source: 'novelai',
      resourceId: 'resource-42',
      mediaId: 'media-3',
      display: const {'title': 'Example resource', 'subtitle': 'Library'},
      provenance: const {'provider': 'NovelAI', 'creator': 'alice'},
    );
  }

  group('JSON codec', () {
    test('round-trips every supported kind with lightweight metadata', () {
      for (final entry in kinds.entries) {
        final reference = referenceFor(entry.key);
        final payload = AgentChatResourceReferenceCodec.encodeJson(reference);
        final json = jsonDecode(payload) as Map<String, dynamic>;

        expect(json['version'], 1);
        expect(json['kind'], entry.value);
        expect(json['source'], 'novelai');
        expect(json['resourceId'], 'resource-42');
        expect(json['mediaId'], 'media-3');
        expect(AgentChatResourceReferenceCodec.decodeJson(payload), reference);
      }
    });

    test('omits empty optional fields', () {
      final payload = AgentChatResourceReferenceCodec.encodeJson(
        AgentChatResourceReference(
          kind: AgentChatResourceKind.tagLibraryEntry,
          source: 'tagCatalog',
          resourceId: '1234',
        ),
      );
      final json = jsonDecode(payload) as Map<String, dynamic>;

      expect(json.keys, ['version', 'kind', 'source', 'resourceId']);
    });

    test('rejects unknown, missing, and incorrectly typed fields', () {
      final valid = <String, dynamic>{
        'version': 1,
        'kind': 'tagLibraryEntry',
        'source': 'tagCatalog',
        'resourceId': '1234',
      };

      expect(
        () => AgentChatResourceReferenceCodec.decodeJsonMap({
          ...valid,
          'extra': true,
        }),
        throwsFormatException,
      );
      expect(
        () => AgentChatResourceReferenceCodec.decodeJsonMap(
          {...valid}..remove('resourceId'),
        ),
        throwsFormatException,
      );
      expect(
        () => AgentChatResourceReferenceCodec.decodeJsonMap({
          ...valid,
          'display': {'title': 7},
        }),
        throwsFormatException,
      );
      expect(
        () => AgentChatResourceReferenceCodec.decodeJsonMap({
          ...valid,
          'mediaId': null,
        }),
        throwsFormatException,
      );
    });

    test('rejects unsupported versions and kinds', () {
      expect(
        () => AgentChatResourceReferenceCodec.decodeJson(
          '{"version":2,"kind":"tagLibraryEntry",'
          '"source":"tagCatalog","resourceId":"1"}',
        ),
        throwsFormatException,
      );
      expect(
        () => AgentChatResourceReferenceCodec.decodeJson(
          '{"version":1,"kind":"arbitrary",'
          '"source":"tagCatalog","resourceId":"1"}',
        ),
        throwsFormatException,
      );
    });

    test('rejects non-object, list, and oversized payloads', () {
      expect(
        () => AgentChatResourceReferenceCodec.decodeJson('[]'),
        throwsFormatException,
      );
      expect(
        () => AgentChatResourceReferenceCodec.decodeJson(
          '{"version":1,"kind":"tagLibraryEntry",'
          '"source":"tagCatalog","resourceId":"1","display":[]}',
        ),
        throwsFormatException,
      );
      final oversized =
          '{"version":1}${' ' * AgentChatResourceReferenceValidator.maxPayloadBytes}';
      expect(
        () => AgentChatResourceReferenceCodec.decodeJson(oversized),
        throwsFormatException,
      );
    });
  });

  group('MIME codec', () {
    test('round-trips the exact versioned media type', () {
      final reference = referenceFor(AgentChatResourceKind.onlineGalleryMedia);
      final payload = AgentChatResourceReferenceCodec.encodeMime(reference);

      expect(
        payload.mimeType,
        'application/vnd.aaalice.agent-chat-resource+json; version=1',
      );
      expect(
        AgentChatResourceReferenceCodec.decodeMime(
          mimeType: payload.mimeType,
          body: payload.body,
        ),
        reference,
      );
    });

    test('rejects missing, unsupported, and unknown MIME parameters', () {
      final body = AgentChatResourceReferenceCodec.encodeJson(
        referenceFor(AgentChatResourceKind.localGalleryImage),
      );
      for (final mimeType in [
        AgentChatResourceReferenceCodec.mediaType,
        '${AgentChatResourceReferenceCodec.mediaType}; version=2',
        '${AgentChatResourceReferenceCodec.mimeType}; charset=utf-8',
        'application/json; version=1',
      ]) {
        expect(
          () => AgentChatResourceReferenceCodec.decodeMime(
            mimeType: mimeType,
            body: body,
          ),
          throwsFormatException,
        );
      }
    });
  });

  group('URI codec', () {
    test('round-trips a versioned custom URI without embedded bytes', () {
      final reference = referenceFor(
        AgentChatResourceKind.preciseRefLibraryEntry,
      );
      final uri = AgentChatResourceReferenceCodec.encodeUri(reference);

      expect(uri.scheme, 'aaalice-agent-resource');
      expect(uri.host, 'v1');
      expect(uri.queryParameters.keys, ['payload']);
      expect(AgentChatResourceReferenceCodec.decodeUri(uri), reference);
      expect(
        AgentChatResourceReferenceCodec.decodeUri(uri.toString()),
        reference,
      );
    });

    test('rejects altered version, path, fragment, and query fields', () {
      final payload = AgentChatResourceReferenceCodec.encodeJson(
        referenceFor(AgentChatResourceKind.vibeLibraryEntry),
      );
      final encoded = Uri.encodeQueryComponent(payload);
      for (final uri in [
        'aaalice-agent-resource://v2?payload=$encoded',
        'aaalice-agent-resource://v1/path?payload=$encoded',
        'aaalice-agent-resource://v1?payload=$encoded#fragment',
        'aaalice-agent-resource://v1?payload=$encoded&extra=1',
        'https://v1?payload=$encoded',
      ]) {
        expect(
          () => AgentChatResourceReferenceCodec.decodeUri(uri),
          throwsFormatException,
        );
      }
    });
  });
}
