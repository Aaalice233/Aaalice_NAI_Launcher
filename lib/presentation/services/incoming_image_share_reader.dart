import 'dart:typed_data';

import '../utils/dropped_file_reader.dart';

typedef SharedImageDownloader = Future<DroppedFileData?> Function(Uri uri);

class IncomingImageShareReader {
  IncomingImageShareReader({SharedImageDownloader? download})
    : _download = download ?? DroppedFileReader.downloadRemoteImage;

  final SharedImageDownloader _download;

  Future<DroppedFileData> read(Map<Object?, Object?> share) async {
    final bytes = share['bytes'];
    if (bytes is Uint8List && bytes.isNotEmpty) {
      final name = share['fileName'];
      if (name is! String || name.isEmpty) {
        throw const FormatException('Shared image filename is missing');
      }
      return DroppedFileData(fileName: name, bytes: bytes);
    }
    final text = share['text'];
    final uri = text is String
        ? DroppedFileReader.extractImageUriFromText(text)
        : null;
    if (uri == null) {
      throw const FormatException(
        'Share contains no readable image or HTTP link',
      );
    }
    final image = await _download(uri);
    if (image == null) {
      throw const FormatException('Unable to download the shared image');
    }
    return image;
  }
}
