import 'dart:convert';

import 'package:xml/xml.dart';

import 'backend_http.dart';
import 'cloud_sync_backend.dart';

class WebDavEtagReader {
  const WebDavEtagReader({required this.http, required this.headers});

  final BackendHttp http;
  final Map<String, String> headers;

  Future<String?> read(Uri uri) async {
    final head = await http.request('HEAD', uri, headers: headers);
    if (head.statusCode == 404) return null;
    _expect(head.statusCode ?? 0, const {200, 204});
    final direct = head.headers.value('etag')?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final response = await http.request(
      'PROPFIND',
      uri,
      headers: {
        ...headers,
        'Depth': '0',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      data: utf8.encode(
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
        '<d:allprop/></d:propfind>',
      ),
      maxResponseBytes: 64 * 1024,
    );
    if (response.statusCode == 404) return null;
    _expect(response.statusCode ?? 0, const {207});
    try {
      final document = XmlDocument.parse(BackendHttp.rawTextOf(response));
      final items = document
          .findAllElements('response', namespace: 'DAV:')
          .toList(growable: false);
      // Depth 0 has exactly one resource. Using that response also supports
      // servers that canonicalize or decode the returned href differently.
      if (items.length != 1) return null;
      for (final item in items) {
        for (final propstat in item.findElements(
          'propstat',
          namespace: 'DAV:',
        )) {
          final status = propstat
              .getElement('status', namespace: 'DAV:')
              ?.innerText;
          if (status == null ||
              !RegExp(r'HTTP/\S+\s+200(?:\s|$)').hasMatch(status)) {
            continue;
          }
          final etag = propstat
              .getElement('prop', namespace: 'DAV:')
              ?.getElement('getetag', namespace: 'DAV:')
              ?.innerText
              .trim();
          if (etag != null && etag.isNotEmpty) return etag;
        }
      }
    } catch (_) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'WebDAV ETag 响应无法解析。',
      );
    }
    return null;
  }

  static void _expect(int status, Set<int> accepted) {
    if (accepted.contains(status)) return;
    throw CloudBackendException(
      switch (status) {
        401 => CloudBackendErrorKind.authentication,
        403 => CloudBackendErrorKind.authorization,
        409 || 412 => CloudBackendErrorKind.conflict,
        507 => CloudBackendErrorKind.quota,
        _ => CloudBackendErrorKind.invalidResponse,
      },
      '读取 WebDAV ETag 失败（HTTP $status）。',
      statusCode: status,
    );
  }
}
