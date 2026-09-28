import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Builds a 1×1 lossless WebP with NovelAI's EXIF UserComment layout.
///
/// The `ASCII\0\0\0 + JSON` mapping follows NovelAI's official
/// `novelai-image-metadata` verifier. The pixel chunk comes from a
/// Pillow-encoded transparent 1×1 WebP; EXIF and RIFF chunks are assembled here
/// so fixtures stay small and auditable.
Uint8List buildNovelAiWebpFixture({
  Map<String, dynamic>? comment,
  bool includeUnknownChunk = true,
  bool invalidUserCommentPrefix = false,
}) {
  final chunks = <int>[
    ..._riffChunk('VP8X', [
      0x08, // EXIF metadata flag.
      0,
      0,
      0,
      0,
      0,
      0, // canvas width - 1 (24-bit little endian).
      0,
      0,
      0, // canvas height - 1.
    ]),
    if (includeUnknownChunk) ..._riffChunk('JUNK', [1, 2, 3]),
    if (comment != null)
      ..._riffChunk(
        'EXIF',
        _buildExif(
          jsonEncode(comment),
          invalidUserCommentPrefix: invalidUserCommentPrefix,
        ),
      ),
    // VP8L payload from a lossless transparent 1×1 WebP encoded by Pillow.
    ..._riffChunk('VP8L', [
      0x2f,
      0x00,
      0x00,
      0x00,
      0x10,
      0x07,
      0x10,
      0x11,
      0x11,
      0x88,
      0x88,
      0xfe,
      0x07,
    ]),
  ];

  final output = BytesBuilder(copy: false)
    ..add(ascii.encode('RIFF'))
    ..add(_uint32LittleEndian(chunks.length + 4))
    ..add(ascii.encode('WEBP'))
    ..add(chunks);
  return output.takeBytes();
}

List<int> _buildExif(String comment, {required bool invalidUserCommentPrefix}) {
  final exif = img.ExifData();
  exif.imageIfd['DocumentName'] = 'NovelAI image';
  exif.imageIfd['ImageDescription'] = 'NovelAI generated image';
  exif.imageIfd['Software'] = 'NovelAI Diffusion V4.5';
  exif.exifIfd['UserComment'] = [
    ...ascii.encode(
      invalidUserCommentPrefix ? 'UNICODE\x00' : 'ASCII\x00\x00\x00',
    ),
    ...ascii.encode(comment),
    0,
  ];

  final output = img.OutputBuffer();
  exif.write(output);
  return output.getBytes();
}

List<int> _riffChunk(String type, List<int> payload) => [
  ...ascii.encode(type),
  ..._uint32LittleEndian(payload.length),
  ...payload,
  if (payload.length.isOdd) 0,
];

Uint8List _uint32LittleEndian(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
