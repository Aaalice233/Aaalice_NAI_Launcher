import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_drop_reader.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../helpers/card_drop_test_utils.dart';

void main() {
  group('accepts', () {
    test('takes app resources, gallery cards and outside images', () {
      expect(
        AgentChatDropReader.accepts([
          TestCardDropItem.resource(
            'tag',
            kind: AgentChatResourceKind.tagLibraryEntry,
          ),
          _galleryItem('G:/gallery/a.png'),
          TestCardDropItem(formats: [Formats.fileUri]),
          TestCardDropItem(formats: [Formats.uri]),
          TestCardDropItem(formats: [Formats.webp]),
        ]),
        isTrue,
      );
    });

    test('rejects empty drops and text that carries no image', () {
      expect(AgentChatDropReader.accepts(const []), isFalse);
      expect(
        AgentChatDropReader.accepts([
          TestCardDropItem(formats: [Formats.png]),
          TestCardDropItem(formats: [Formats.plainText, Formats.htmlText]),
        ]),
        isFalse,
      );
    });
  });

  group('read', () {
    test(
      'keeps app resources as references and inlines outside images',
      () async {
        final png = DroppedFileData(
          fileName: 'shot.png',
          bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        );
        final external = TestCardDropItem(formats: [Formats.png]);
        final reader = AgentChatDropReader(
          galleryImageIdForPath: (path) async =>
              path == 'G:/gallery/a.png' ? 42 : null,
          readExternalImage: (item) async =>
              identical(item, external) ? png : null,
        );

        final payloads = await reader.read([
          TestCardDropItem.resource('vibe-1'),
          _galleryItem('G:/gallery/a.png'),
          external,
        ]);

        expect(
          payloads[0],
          isA<AgentChatDroppedResource>().having(
            (payload) => payload.reference.resourceId,
            'resourceId',
            'vibe-1',
          ),
        );
        expect(
          payloads[1],
          isA<AgentChatDroppedResource>().having(
            (payload) => (payload.reference.kind, payload.reference.resourceId),
            'gallery reference',
            (AgentChatResourceKind.localGalleryImage, '42'),
          ),
        );
        expect(
          payloads[2],
          isA<AgentChatDroppedImage>().having(
            (payload) => payload.file,
            'file',
            same(png),
          ),
        );
      },
    );

    test('an unreadable item fails alone without hiding the rest', () async {
      final png = DroppedFileData(fileName: 'a.png', bytes: Uint8List(4));
      final readable = TestCardDropItem(formats: [Formats.png]);
      final reader = AgentChatDropReader(
        galleryImageIdForPath: (_) async => null,
        readExternalImage: (item) async => identical(item, readable)
            ? png
            : DroppedFileData(fileName: 'empty.png', bytes: Uint8List(0)),
      );

      final payloads = await reader.read([
        TestCardDropItem(formats: [Formats.fileUri]),
        _galleryItem('G:/gallery/removed.png'),
        readable,
      ]);

      expect(
        payloads[0],
        isA<AgentChatDropFailure>().having(
          (failure) => failure.error,
          'error',
          isA<AgentChatUnreadableDropImage>(),
        ),
      );
      expect(
        payloads[1],
        isA<AgentChatDropFailure>().having(
          (failure) => '${failure.error}',
          'error',
          contains('at 2'),
        ),
      );
      expect(payloads[2], isA<AgentChatDroppedImage>());
    });

    test('gallery cards never fall through to the external reader', () async {
      var externalReads = 0;
      final reader = AgentChatDropReader(
        galleryImageIdForPath: (_) async => 7,
        readExternalImage: (_) async {
          externalReads++;
          return null;
        },
      );

      await reader.read([
        _galleryItem('G:/gallery/a.png', formats: [Formats.fileUri]),
      ]);

      expect(externalReads, 0);
    });
  });
}

TestCardDropItem _galleryItem(
  String path, {
  List<DataFormat> formats = const [],
}) => TestCardDropItem(
  localData: {'source': 'gallery_internal', 'path': path},
  formats: formats,
);
