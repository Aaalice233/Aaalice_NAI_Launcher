import 'dart:convert';
import 'dart:typed_data';

/// One decoded part of a browser-shaped multipart body.
class DecodedMultipartPart {
  DecodedMultipartPart({
    required this.name,
    required this.bytes,
    this.filename,
    this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String? filename;
  final String? contentType;

  String get text => utf8.decode(bytes);
}

/// Reads back the wire format produced by `BrowserMultipartBody`.
///
/// Asserts the exact byte layout as it goes, so a malformed body fails here
/// instead of surfacing as a confusing missing part.
List<DecodedMultipartPart> parseBrowserMultipart(
  Uint8List body,
  String boundary,
) {
  final delimiter = ascii.encode('--$boundary\r\n');
  final closing = ascii.encode('--$boundary--\r\n');
  final headerTerminator = ascii.encode('\r\n\r\n');

  if (!_startsWith(body, delimiter, 0)) {
    throw const FormatException('Body does not open with the boundary delimiter');
  }
  if (!_startsWith(body, closing, body.length - closing.length)) {
    throw const FormatException('Body does not end with the closing delimiter');
  }

  final parts = <DecodedMultipartPart>[];
  var cursor = delimiter.length;

  while (cursor < body.length - closing.length) {
    final headerEnd = _indexOf(body, headerTerminator, cursor);
    if (headerEnd < 0) throw const FormatException('Unterminated part headers');
    final headerBlock = ascii.decode(body.sublist(cursor, headerEnd));
    final contentStart = headerEnd + headerTerminator.length;

    final nextDelimiter = _indexOf(body, delimiter, contentStart);
    final nextClosing = _indexOf(body, closing, contentStart);
    final contentEnd = nextDelimiter < 0 || nextClosing < nextDelimiter
        ? nextClosing
        : nextDelimiter;
    if (contentEnd < 0) throw const FormatException('Unterminated part content');

    final headers = <String, String>{};
    for (final line in headerBlock.split('\r\n')) {
      final separator = line.indexOf(': ');
      if (separator < 0) throw FormatException('Malformed part header: $line');
      headers[line.substring(0, separator)] = line.substring(separator + 2);
    }

    final disposition = headers['Content-Disposition'];
    if (disposition == null) {
      throw const FormatException('Part is missing Content-Disposition');
    }

    parts.add(
      DecodedMultipartPart(
        name: _attribute(disposition, 'name')!,
        filename: _attribute(disposition, 'filename'),
        contentType: headers['Content-Type'],
        bytes: Uint8List.sublistView(body, contentStart, contentEnd - 2),
      ),
    );
    cursor = contentEnd + delimiter.length;
  }

  return parts;
}

/// Pulls the boundary out of a `multipart/form-data` content type.
String boundaryOf(String contentType) {
  const marker = 'boundary=';
  final index = contentType.indexOf(marker);
  if (index < 0) throw FormatException('No boundary in "$contentType"');
  return contentType.substring(index + marker.length);
}

String? _attribute(String disposition, String name) {
  final match = RegExp('$name="([^"]*)"').firstMatch(disposition);
  return match?.group(1);
}

bool _startsWith(Uint8List haystack, List<int> needle, int offset) {
  if (offset < 0 || offset + needle.length > haystack.length) return false;
  for (var i = 0; i < needle.length; i++) {
    if (haystack[offset + i] != needle[i]) return false;
  }
  return true;
}

int _indexOf(Uint8List haystack, List<int> needle, int from) {
  for (var i = from; i <= haystack.length - needle.length; i++) {
    if (_startsWith(haystack, needle, i)) return i;
  }
  return -1;
}
