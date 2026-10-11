import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// multipart/form-data 的一个分块。
class BrowserMultipartPart {
  const BrowserMultipartPart({
    required this.name,
    required this.bytes,
    this.filename,
    this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String? filename;
  final String? contentType;
}

/// 按 Chrome `FormData` 的线格式编码 multipart 请求体。
///
/// Dio 的 `FormData` 用 `--dio-boundary-` 前缀和小写分块头，和浏览器请求
/// 一眼可辨。
class BrowserMultipartBody {
  BrowserMultipartBody._(this.boundary, this.bytes);

  factory BrowserMultipartBody.encode(
    List<BrowserMultipartPart> parts, {
    String? boundary,
  }) {
    final effectiveBoundary = boundary ?? generateBoundary();
    final builder = BytesBuilder(copy: false);

    for (final part in parts) {
      builder.add(ascii.encode('--$effectiveBoundary$_crlf'));
      builder.add(utf8.encode(_contentDispositionLine(part)));
      if (part.contentType != null) {
        builder.add(utf8.encode('Content-Type: ${part.contentType}$_crlf'));
      }
      builder.add(ascii.encode(_crlf));
      builder.add(part.bytes);
      builder.add(ascii.encode(_crlf));
    }
    builder.add(ascii.encode('--$effectiveBoundary--$_crlf'));

    return BrowserMultipartBody._(effectiveBoundary, builder.takeBytes());
  }

  static const String _crlf = '\r\n';
  static const String _boundaryPrefix = '----WebKitFormBoundary';
  static const int _boundarySuffixLength = 16;
  static const String _boundaryAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  static final Random _random = Random.secure();

  final String boundary;
  final Uint8List bytes;

  String get contentType => 'multipart/form-data; boundary=$boundary';

  static String generateBoundary() {
    final suffix = List.generate(
      _boundarySuffixLength,
      (_) => _boundaryAlphabet[_random.nextInt(_boundaryAlphabet.length)],
      growable: false,
    ).join();
    return '$_boundaryPrefix$suffix';
  }

  static String _contentDispositionLine(BrowserMultipartPart part) {
    final buffer = StringBuffer('Content-Disposition: form-data; name="')
      ..write(_escapeHeaderValue(part.name))
      ..write('"');
    final filename = part.filename;
    if (filename != null) {
      buffer
        ..write('; filename="')
        ..write(_escapeHeaderValue(filename))
        ..write('"');
    }
    buffer.write(_crlf);
    return buffer.toString();
  }

  /// HTML 表单编码算法规定的三个转义，不做通用百分号编码。
  static String _escapeHeaderValue(String value) => value
      .replaceAll('\r', '%0D')
      .replaceAll('\n', '%0A')
      .replaceAll('"', '%22');
}
