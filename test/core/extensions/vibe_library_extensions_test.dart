import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/extensions/vibe_library_extensions.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';

VibeLibraryEntry _entry(
  String name, {
  String encoding = '',
  Uint8List? thumbnail,
}) => VibeLibraryEntry.create(
  name: name,
  vibeDisplayName: name,
  vibeEncoding: encoding,
  thumbnail: thumbnail,
);

Uint8List _image(int seed) =>
    Uint8List.fromList(List.generate(64, (index) => (index * 7 + seed) & 0xff));

void main() {
  group('deduplicateByEncodingAndThumbnail', () {
    test('无编码条目按缩略图内容去重，内容相同的不同实例只保留第一条', () {
      final entries = [
        _entry('first', thumbnail: _image(1)),
        _entry('copy', thumbnail: _image(1)),
        _entry('same-length-other', thumbnail: _image(2)),
      ];

      final unique = entries.deduplicateByEncodingAndThumbnail();

      expect(unique.map((entry) => entry.name), [
        'first',
        'same-length-other',
      ]);
    });

    test('编码优先去重，缩略图与名称兜底，并遵守数量上限', () {
      final entries = [
        _entry('a', encoding: 'enc-1', thumbnail: _image(1)),
        _entry('b', encoding: 'enc-1', thumbnail: _image(2)),
        _entry('c', thumbnail: _image(1)),
        _entry('d'),
        _entry('D'),
        _entry('e', encoding: 'enc-2'),
        _entry('f', encoding: 'enc-3'),
      ];

      final unique = entries.deduplicateByEncodingAndThumbnail(limit: 4);

      expect(unique.map((entry) => entry.name), ['a', 'c', 'd', 'e']);
    });
  });
}
