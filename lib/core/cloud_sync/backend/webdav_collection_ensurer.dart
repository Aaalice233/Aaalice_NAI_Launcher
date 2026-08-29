import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'backend_http.dart';
import 'cloud_sync_backend.dart';

class WebDavCollectionEnsurer {
  WebDavCollectionEnsurer({
    required this.http,
    required this.headers,
    required this.baseUri,
  });

  final BackendHttp http;
  final Map<String, String> headers;
  final Uri baseUri;
  final Map<Uri, DateTime> _recentCollections = {};

  static const _cacheTtl = Duration(seconds: 30);
  static final Uint8List _collectionProperties = Uint8List.fromList(
    utf8.encode(
      '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
      '<d:prop><d:resourcetype/></d:prop></d:propfind>',
    ),
  );

  Future<void> ensure(Uri collection) async {
    final segments = collection.pathSegments
        .where((value) => value.isNotEmpty)
        .toList();
    final baseCount = baseUri.pathSegments
        .where((value) => value.isNotEmpty)
        .length;
    var current = baseUri;
    for (final segment in segments.skip(baseCount)) {
      current = current.resolve('${Uri.encodeComponent(segment)}/');
      final checkedAt = _recentCollections[current];
      if (checkedAt != null &&
          DateTime.now().toUtc().difference(checkedAt) < _cacheTtl) {
        continue;
      }
      await _ensureOne(current);
      _recentCollections[current] = DateTime.now().toUtc();
    }
  }

  Future<void> _ensureOne(Uri collection) async {
    final created = await http.request(
      'MKCOL',
      collection,
      headers: {...headers, 'Content-Length': '0'},
    );
    final status = created.statusCode ?? 0;
    if (const {200, 201, 204}.contains(status)) return;

    // Several widely used servers return a non-standard 400 or 409 when the
    // collection already exists; 405 is standard but can also describe a file.
    // Verify the resource instead of hiding malformed paths and file conflicts.
    if (const {400, 405, 409}.contains(status) &&
        await _isExistingCollection(collection)) {
      return;
    }
    throw _failure(status);
  }

  Future<bool> _isExistingCollection(Uri collection) async {
    final response = await http.request(
      'PROPFIND',
      collection,
      headers: {
        ...headers,
        'Depth': '0',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      data: _collectionProperties,
      maxResponseBytes: 64 * 1024,
    );
    if (response.statusCode == 404) return false;
    if (response.statusCode != 207) return false;
    try {
      return XmlDocument.parse(
        BackendHttp.rawTextOf(response),
      ).findAllElements('response', namespace: 'DAV:').any((item) {
        final href = item
            .getElement('href', namespace: 'DAV:')
            ?.innerText
            .trim();
        if (href == null ||
            !_sameResource(collection, collection.resolve(href))) {
          return false;
        }
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
          final type = propstat
              .getElement('prop', namespace: 'DAV:')
              ?.getElement('resourcetype', namespace: 'DAV:');
          if (type?.findElements('collection', namespace: 'DAV:').isNotEmpty ??
              false) {
            return true;
          }
        }
        return false;
      });
    } catch (_) {
      return false;
    }
  }

  static bool _sameResource(Uri expected, Uri actual) =>
      expected.scheme == actual.scheme &&
      expected.host == actual.host &&
      expected.port == actual.port &&
      expected.query.isEmpty &&
      actual.query.isEmpty &&
      expected.fragment.isEmpty &&
      actual.fragment.isEmpty &&
      expected.path.replaceFirst(RegExp(r'/$'), '') ==
          actual.path.replaceFirst(RegExp(r'/$'), '');

  static CloudBackendException _failure(int status) => CloudBackendException(
    switch (status) {
      401 => CloudBackendErrorKind.authentication,
      403 => CloudBackendErrorKind.authorization,
      409 || 412 => CloudBackendErrorKind.conflict,
      413 || 507 => CloudBackendErrorKind.quota,
      _ => CloudBackendErrorKind.invalidResponse,
    },
    status == 400
        ? '创建 WebDAV 目录失败（HTTP 400）。请确认 WebDAV 地址指向可写目录。'
        : '创建 WebDAV 目录失败（HTTP $status）。',
    statusCode: status,
  );
}
