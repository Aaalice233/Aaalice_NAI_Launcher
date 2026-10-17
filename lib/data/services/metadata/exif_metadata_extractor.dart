import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/utils/exif_container.dart';
import 'exif_user_comment_decoder.dart';
import 'image_metadata_container_codec.dart';

class ExifMetadataExtraction {
  const ExifMetadataExtraction({
    this.textData = const {},
    this.errorMessage,
    this.containerDamaged = false,
    this.complete = true,
  });

  final Map<String, String> textData;
  final String? errorMessage;

  /// The container structure is broken or truncated, so the pixels cannot be
  /// trusted for the stealth payload either.
  final bool containerDamaged;

  /// False when the bytes end before every place the container may keep EXIF,
  /// so a longer prefix of the same file could change the answer.
  final bool complete;

  bool get hasMetadata => textData.containsKey('Comment');

  /// [damage] marks a broken structure and explains a missing result.
  ExifMetadataExtraction _endedEarly({String? damage}) =>
      ExifMetadataExtraction(
        textData: textData,
        errorMessage: errorMessage ?? (hasMetadata ? null : damage),
        containerDamaged: damage != null,
        complete: false,
      );
}

/// Extracts NovelAI's file-level metadata from the EXIF block that NovelAI's
/// web reader picks in each container.
///
/// NovelAI stores the generation JSON in EXIF `UserComment`. Other EXIF fields
/// are mapped to the names used by the PNG metadata path so the existing
/// metadata parsers can consume every container.
abstract final class ExifMetadataExtractor {
  static const int _documentNameTag = 0x010d;
  static const int _imageDescriptionTag = 0x010e;
  static const int _modelTag = 0x0110;
  static const int _softwareTag = 0x0131;
  static const int _artistTag = 0x013b;
  static const int _copyrightTag = 0x8298;
  static const int _userCommentTag = 0x9286;
  static const int _ifdEntrySize = 12;
  static final RegExp _trailingNul = RegExp(r'\u0000+$');

  /// Segments read before a truncated or malformed header still count.
  static ExifMetadataExtraction fromJpeg(Uint8List bytes) {
    if (!ExifContainer.isJpeg(bytes)) {
      return const ExifMetadataExtraction(
        errorMessage: 'Not a valid JPEG header',
        containerDamaged: true,
      );
    }
    final (:payloads, :headerComplete) = ExifContainer.scanJpegExif(bytes);
    final tiff = _preferredJpegExif(payloads);
    final extraction = tiff == null
        ? const ExifMetadataExtraction()
        : _fromTiff(tiff);
    return headerComplete
        ? extraction
        : extraction._endedEarly(damage: 'Truncated or malformed JPEG header');
  }

  static ExifMetadataExtraction fromWebp(Uint8List bytes) {
    if (!ExifContainer.isWebp(bytes)) {
      return const ExifMetadataExtraction(
        errorMessage: 'Not a valid WebP RIFF header',
        containerDamaged: true,
      );
    }
    final chunks = <Uint8List>[];
    String? damage;
    try {
      for (final chunk in ExifContainer.webpExifChunks(bytes)) {
        chunks.add(chunk);
      }
    } on FormatException catch (error) {
      damage = error.message;
    }
    // NovelAI's reader keeps the last EXIF chunk
    final exif = chunks.lastOrNull;
    final extraction = exif == null
        ? const ExifMetadataExtraction()
        : _fromTiff(ExifContainer.withoutExifHeader(exif));
    return damage == null ? extraction : extraction._endedEarly(damage: damage);
  }

  /// A PNG without IEND may be a prefix, which is not damage by itself.
  static ExifMetadataExtraction fromPng(Uint8List bytes) {
    final (:payloads, :reachedEnd) = ImageMetadataContainerCodec.scanPngExif(
      bytes,
    );
    // NovelAI's reader keeps the last eXIf chunk
    final exif = payloads.lastOrNull;
    final extraction = exif == null
        ? const ExifMetadataExtraction()
        : _fromTiff(exif);
    return reachedEnd ? extraction : extraction._endedEarly();
  }

  /// NovelAI's reader keeps the first EXIF segment unless a later one scores
  /// strictly higher, which [_jpegExifScore] encodes.
  static Uint8List? _preferredJpegExif(List<Uint8List> payloads) {
    Uint8List? preferred;
    var preferredScore = -1;
    for (final tiff in payloads) {
      final score = _jpegExifScore(tiff);
      if (score > preferredScore) {
        preferred = tiff;
        preferredScore = score;
      }
    }
    return preferred;
  }

  /// A well-formed IFD0 outranks any entry count, which outranks the segment
  /// length; a TIFF header that cannot be read scores zero.
  static int _jpegExifScore(Uint8List tiff) {
    if (tiff.length < 8) return 0;
    final Endian endian;
    if (_asciiAt(tiff, 0, 'II')) {
      endian = Endian.little;
    } else if (_asciiAt(tiff, 0, 'MM')) {
      endian = Endian.big;
    } else {
      return 0;
    }
    final data = ByteData.sublistView(tiff);
    if (data.getUint16(2, endian) != 42) return 0;
    final ifd0Offset = data.getUint32(4, endian);
    if (ifd0Offset + 2 > tiff.length) return 0;
    final entries = data.getUint16(ifd0Offset, endian);
    final wellFormed =
        entries > 0 &&
        ifd0Offset + 2 + entries * _ifdEntrySize + 4 <= tiff.length;
    // The APP1 length field also counts itself and the Exif identifier
    final segmentLength = tiff.length + 8;
    return (wellFormed ? 1000000000 : 0) + entries * 1000000 + segmentLength;
  }

  static ExifMetadataExtraction _fromTiff(Uint8List tiffBytes) {
    try {
      final isLittleEndian = _asciiAt(tiffBytes, 0, 'II');
      final isBigEndian = _asciiAt(tiffBytes, 0, 'MM');
      if (tiffBytes.length < 8 || (!isLittleEndian && !isBigEndian)) {
        return const ExifMetadataExtraction(
          errorMessage: 'Invalid EXIF TIFF header',
        );
      }
      final tiffData = ByteData.sublistView(tiffBytes);
      final endian = isLittleEndian ? Endian.little : Endian.big;
      final firstIfdOffset = tiffData.getUint32(4, endian);
      if (tiffData.getUint16(2, endian) != 42 ||
          firstIfdOffset < 8 ||
          firstIfdOffset + 2 > tiffBytes.length) {
        return const ExifMetadataExtraction(
          errorMessage: 'Invalid EXIF TIFF directory',
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
      if (comment == null) return const ExifMetadataExtraction();

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
      return ExifMetadataExtraction(textData: textData);
    } catch (error) {
      return ExifMetadataExtraction(
        errorMessage: 'Failed to parse EXIF metadata: $error',
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
