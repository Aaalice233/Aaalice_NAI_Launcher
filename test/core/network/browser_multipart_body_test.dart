import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/browser_multipart_body.dart';

void main() {
  group('BrowserMultipartBody', () {
    test('writes the Chrome FormData wire format byte for byte', () {
      final body = BrowserMultipartBody.encode([
        BrowserMultipartPart(
          name: 'image',
          bytes: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
          filename: 'blob',
          contentType: 'image/png',
        ),
        BrowserMultipartPart(
          name: 'request',
          bytes: Uint8List.fromList(utf8.encode('{"a":1}')),
          filename: 'blob',
          contentType: 'application/json',
        ),
      ], boundary: '----WebKitFormBoundaryAbCdEf0123456789');

      expect(
        latin1.decode(body.bytes),
        '------WebKitFormBoundaryAbCdEf0123456789\r\n'
        'Content-Disposition: form-data; name="image"; filename="blob"\r\n'
        'Content-Type: image/png\r\n'
        '\r\n'
        '\x89PNG\r\n'
        '------WebKitFormBoundaryAbCdEf0123456789\r\n'
        'Content-Disposition: form-data; name="request"; filename="blob"\r\n'
        'Content-Type: application/json\r\n'
        '\r\n'
        '{"a":1}\r\n'
        '------WebKitFormBoundaryAbCdEf0123456789--\r\n',
      );
      expect(
        body.contentType,
        'multipart/form-data; '
        'boundary=----WebKitFormBoundaryAbCdEf0123456789',
      );
    });

    test('omits filename and content type for plain fields', () {
      final body = BrowserMultipartBody.encode([
        BrowserMultipartPart(
          name: 'field',
          bytes: Uint8List.fromList(utf8.encode('value')),
        ),
      ], boundary: 'b');

      expect(
        latin1.decode(body.bytes),
        '--b\r\n'
        'Content-Disposition: form-data; name="field"\r\n'
        '\r\n'
        'value\r\n'
        '--b--\r\n',
      );
    });

    test('percent-escapes CR, LF and quotes in name and filename', () {
      final body = BrowserMultipartBody.encode([
        BrowserMultipartPart(
          name: 'a"b\rc\nd',
          bytes: Uint8List(0),
          filename: 'x"y\r\nz',
          contentType: 'image/png',
        ),
      ], boundary: 'b');

      expect(
        latin1.decode(body.bytes),
        contains(
          'Content-Disposition: form-data; name="a%22b%0Dc%0Ad"; '
          'filename="x%22y%0D%0Az"',
        ),
      );
    });

    test('generates 16 alphanumeric characters after the WebKit prefix', () {
      final boundaries = List.generate(
        32,
        (_) => BrowserMultipartBody.generateBoundary(),
      );

      for (final boundary in boundaries) {
        expect(boundary, matches(r'^----WebKitFormBoundary[A-Za-z0-9]{16}$'));
      }
      expect(boundaries.toSet().length, greaterThan(1));
    });
  });
}
