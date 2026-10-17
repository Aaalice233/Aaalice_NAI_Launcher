import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/utils/exif_container.dart';
import 'exif_user_comment_decoder.dart';

class WebpExifMetadataExtraction {
  const WebpExifMetadataExtraction({
    this.textData = const {},
    this.errorMessage,
    this.containerDamaged = false,
  });

  final Map<String, String> textData;
  final String? errorMessage;

  /// The RIFF structure is broken or truncated, so the pixels cannot be
  /// trusted for the stealth payload either.
  final bool containerDamaged;

  bool get hasMetadata => textData.containsKey('Comment');
}

/// Extracts NovelAI's file-level metadata from a WebP RIFF container.
///
/// NovelAI stores the generation JSON in EXIF `UserComment`. Other EXIF fields
/// are mapped to the names used by the PNG metadata path so the existing
/// metadata parsers can consume both formats.
class WebpExifMetadataExtractor {
  WebpExifMetadataExtractor._();

  static const int _documentNameTag = 0x010d;
  static const int _imageDescriptionTag = 0x010e;
  static const int _modelTag = 0x0110;
  static const int _softwareTag = 0x0131;
  static const int _artistTag = 0x013b;
  static const int _copyrightTag = 0x8298;
  static const int _userCommentTag = 0x9286;
  static final RegExp _trailingNul = RegExp(r'\u0000+$');

  static WebpExifMetadataExtraction extract(Uint8List bytes) {
    if (!ExifContainer.isWebp(bytes)) {
      return const WebpExifMetadataExtraction(
        errorMessage: 'Not a valid WebP RIFF header',
        containerDamaged: true,
      );
    }
    final Uint8List? exifBytes;
    try {
      exifBytes = ExifContainer.webpExifChunks(bytes).firstOrNull;
    } on FormatException catch (error) {
      return WebpExifMetadataExtraction(
        errorMessage: error.message,
        containerDamaged: true,
      );
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
      final userCommentValue =
          exifIfd?.data[_userCommentTag] ?? imageIfd.data[_userCommentTag];
      final comment = userCommentValue == null
          ? null
          : ExifUserCommentDecoder.decode(userCommentValue.toData());
      if (comment == null) return const WebpExifMetadataExtraction();

      final textData = <String, String>{'Comment': comment};
      _copyTextTag(imageIfd, _documentNameTag, 'Title', textData);
      _copyTextTag(imageIfd, _imageDescriptionTag, 'Description', textData);
      // NovelAI wrote two IFD0 layouts: older files keep Source in Model and
      // "NovelAI" in Software, newer ones drop Model and keep Source in Software.
      if (_textTag(imageIfd, _modelTag) case final model?) {
        textData['Source'] = model;
        _copyTextTag(imageIfd, _softwareTag, 'Software', textData);
      } else {
        _copyTextTag(imageIfd, _softwareTag, 'Source', textData);
      }
      _copyTextTag(imageIfd, _artistTag, 'Artist', textData);
      _copyTextTag(imageIfd, _copyrightTag, 'Copyright', textData);
      return WebpExifMetadataExtraction(textData: textData);
    } catch (error) {
      return WebpExifMetadataExtraction(
        errorMessage: 'Failed to parse WebP EXIF metadata: $error',
      );
    }
  }

  static void _copyTextTag(
    img.IfdDirectory ifd,
    int tag,
    String targetKey,
    Map<String, String> target,
  ) {
    final value = _textTag(ifd, tag);
    if (value != null) target[targetKey] = value;
  }

  /// package:image reads ASCII values byte-per-character; NovelAI writes them
  /// as UTF-8, so the raw bytes are decoded again.
  static String? _textTag(img.IfdDirectory ifd, int tag) {
    final value = ifd.data[tag];
    if (value == null || value.type != img.IfdValueType.ascii) return null;
    final text = utf8
        .decode(value.toData(), allowMalformed: true)
        .replaceFirst(_trailingNul, '')
        .trim();
    return text.isEmpty ? null : text;
  }

  static bool _asciiAt(Uint8List bytes, int offset, String value) {
    if (offset < 0 || offset + value.length > bytes.length) return false;
    for (var i = 0; i < value.length; i++) {
      if (bytes[offset + i] != value.codeUnitAt(i)) return false;
    }
    return true;
  }
}
