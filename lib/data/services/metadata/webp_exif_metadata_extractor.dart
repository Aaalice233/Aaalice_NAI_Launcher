import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/utils/exif_container.dart';

class WebpExifMetadataExtraction {
  const WebpExifMetadataExtraction({
    this.textData = const {},
    this.errorMessage,
  });

  final Map<String, String> textData;
  final String? errorMessage;

  bool get hasMetadata => textData.containsKey('Comment');
}

/// Extracts NovelAI's file-level metadata from a WebP RIFF container.
///
/// NovelAI stores the generation JSON in EXIF `UserComment`, prefixed by the
/// EXIF ASCII marker. Other EXIF fields are mapped to the names used by the PNG
/// metadata path so the existing metadata parsers can consume both formats.
class WebpExifMetadataExtractor {
  WebpExifMetadataExtractor._();

  static const List<int> _asciiUserCommentPrefix = [
    0x41,
    0x53,
    0x43,
    0x49,
    0x49,
    0x00,
    0x00,
    0x00,
  ];

  static WebpExifMetadataExtraction extract(Uint8List bytes) {
    if (!ExifContainer.isWebp(bytes)) {
      return const WebpExifMetadataExtraction(
        errorMessage: 'Not a valid WebP RIFF header',
      );
    }
    final Uint8List? exifBytes;
    try {
      exifBytes = ExifContainer.webpExifChunks(bytes).firstOrNull;
    } on FormatException catch (error) {
      return WebpExifMetadataExtraction(errorMessage: error.message);
    }
    return exifBytes == null
        ? const WebpExifMetadataExtraction()
        : _extractExif(exifBytes);
  }

  static WebpExifMetadataExtraction _extractExif(Uint8List exifBytes) {
    try {
      final tiffBytes = ExifContainer.withoutExifHeader(exifBytes);
      final isLittleEndian = _asciiAt(tiffBytes, 0, 'II');
      final isBigEndian = _asciiAt(tiffBytes, 0, 'MM');
      if (tiffBytes.length < 8 || (!isLittleEndian && !isBigEndian)) {
        return const WebpExifMetadataExtraction(
          errorMessage: 'Invalid WebP EXIF TIFF header',
        );
      }
      final tiffData = ByteData.sublistView(tiffBytes);
      final endian = isLittleEndian ? Endian.little : Endian.big;
      final firstIfdOffset = tiffData.getUint32(4, endian);
      if (tiffData.getUint16(2, endian) != 42 ||
          firstIfdOffset < 8 ||
          firstIfdOffset + 2 > tiffBytes.length) {
        return const WebpExifMetadataExtraction(
          errorMessage: 'Invalid WebP EXIF TIFF directory',
        );
      }

      final exif = img.ExifData.fromInputBuffer(img.InputBuffer(tiffBytes));
      final imageIfd = exif.imageIfd;
      final exifIfd = imageIfd.sub.directories['exif'];
      final userCommentValue = exifIfd?.data[0x9286] ?? imageIfd.data[0x9286];
      if (userCommentValue == null) {
        return const WebpExifMetadataExtraction();
      }

      final commentBytes = userCommentValue.toData();
      if (commentBytes.length < _asciiUserCommentPrefix.length ||
          !_startsWith(commentBytes, _asciiUserCommentPrefix)) {
        return const WebpExifMetadataExtraction(
          errorMessage:
              'Unsupported WebP EXIF UserComment encoding; expected ASCII prefix',
        );
      }

      var commentEnd = commentBytes.length;
      while (commentEnd > _asciiUserCommentPrefix.length &&
          commentBytes[commentEnd - 1] == 0) {
        commentEnd--;
      }
      final comment = ascii.decode(
        commentBytes.sublist(_asciiUserCommentPrefix.length, commentEnd),
        allowInvalid: false,
      );
      if (comment.isEmpty) {
        return const WebpExifMetadataExtraction(
          errorMessage: 'WebP EXIF UserComment is empty',
        );
      }

      final textData = <String, String>{'Comment': comment};
      _copyAsciiTag(imageIfd, 0x010d, 'Title', textData);
      _copyAsciiTag(imageIfd, 0x010e, 'Description', textData);
      // NovelAI's WebP mapping stores the PNG `Source` value in EXIF Software.
      _copyAsciiTag(imageIfd, 0x0131, 'Source', textData);
      _copyAsciiTag(imageIfd, 0x013b, 'Artist', textData);
      _copyAsciiTag(imageIfd, 0x8298, 'Copyright', textData);
      return WebpExifMetadataExtraction(textData: textData);
    } catch (error) {
      return WebpExifMetadataExtraction(
        errorMessage: 'Failed to parse WebP EXIF metadata: $error',
      );
    }
  }

  static void _copyAsciiTag(
    img.IfdDirectory ifd,
    int tag,
    String targetKey,
    Map<String, String> target,
  ) {
    final value = ifd.data[tag]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      target[targetKey] = value;
    }
  }

  static bool _asciiAt(Uint8List bytes, int offset, String value) {
    if (offset < 0 || offset + value.length > bytes.length) return false;
    for (var i = 0; i < value.length; i++) {
      if (bytes[offset + i] != value.codeUnitAt(i)) return false;
    }
    return true;
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }
}
