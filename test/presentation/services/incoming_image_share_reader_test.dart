import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/services/incoming_image_share_reader.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';

void main() {
  test('keeps original shared bytes ahead of accompanying text', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final reader = IncomingImageShareReader(
      download: (_) => throw StateError('No download'),
    );
    final image = await reader.read({
      'fileName': 'original.png',
      'bytes': bytes,
      'text': 'https://example.com/a.png',
    });
    expect(image.bytes, same(bytes));
    expect(image.fileName, 'original.png');
  });

  test(
    'extracts Discord link including signed query without alteration',
    () async {
      const url =
          'https://cdn.discordapp.com/attachments/1/2/original.png?ex=123&is=456&hm=abc';
      final reader = IncomingImageShareReader(
        download: (uri) async {
          expect(uri.toString(), url);
          return DroppedFileData(
            fileName: 'original.png',
            bytes: Uint8List.fromList([1]),
          );
        },
      );
      expect(
        (await reader.read({'text': 'image: $url'})).fileName,
        'original.png',
      );
    },
  );

  for (final share in <Map<Object?, Object?>>[
    {},
    {'text': 'no link'},
    {'text': 'file:///private/image.png'},
    {'bytes': Uint8List(0), 'fileName': 'empty.png'},
  ]) {
    test('rejects unreadable share $share', () async {
      await expectLater(
        IncomingImageShareReader().read(share),
        throwsFormatException,
      );
    });
  }

  test('download failure stays an error', () async {
    final reader = IncomingImageShareReader(download: (_) async => null);
    await expectLater(
      reader.read({'text': 'https://example.com/a.png'}),
      throwsFormatException,
    );
  });
}
