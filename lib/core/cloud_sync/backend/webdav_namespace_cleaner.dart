import 'dart:convert';

import 'package:xml/xml.dart';

import 'backend_http.dart';
import 'cloud_sync_backend.dart';

/// Deletes only verified files. Collections are deliberately left in place.
class WebDavNamespaceCleaner {
  const WebDavNamespaceCleaner({
    required this.http,
    required this.headers,
    required this.root,
    required this.objects,
    required this.snapshots,
  });

  final BackendHttp http;
  final Map<String, String> headers;
  final Uri root;
  final Uri objects;
  final Uri snapshots;

  Future<void> clean() async {
    final first = await _inventory();
    final verified = await _inventory();
    if (!_sameInventory(first, verified)) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'WebDAV 同步空间在删除前发生变化；并发数据已保留。',
      );
    }
    for (final entry in verified.entries) {
      final response = await http.request(
        'DELETE',
        entry.key,
        headers: {...headers, 'If-Match': entry.value},
      );
      final status = response.statusCode ?? 0;
      if (status == 412 || status == 404) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'WebDAV 对象在删除期间发生变化；其余数据已保留。',
        );
      }
      if (!{200, 202, 204}.contains(status)) {
        throw CloudBackendException(
          _kindFor(status),
          '删除 WebDAV 对象失败（HTTP $status）；其余数据已保留。',
          statusCode: status,
        );
      }
    }
    final remaining = await _inventory();
    if (remaining.isNotEmpty) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        '删除期间出现了新的 WebDAV 对象；并发数据已保留。',
      );
    }
  }

  Future<Map<Uri, String>> _inventory() async {
    final result = <Uri, String>{};
    final rootEntries = await _scan(root, allowNotFound: true);
    for (final entry in rootEntries) {
      if (entry.isCollection) {
        if (entry.uri != objects && entry.uri != snapshots) {
          throw const CloudBackendException(
            CloudBackendErrorKind.conflict,
            'WebDAV 同步空间包含未知目录，已保留全部数据。',
          );
        }
        continue;
      }
      if (entry.uri != root.resolve('HEAD.json')) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'WebDAV 同步空间包含未知文件，已保留全部数据。',
        );
      }
      result[entry.uri] = entry.etag!;
    }
    for (final collection in [objects, snapshots]) {
      for (final entry in await _scan(collection, allowNotFound: true)) {
        if (entry.isCollection) {
          throw const CloudBackendException(
            CloudBackendErrorKind.conflict,
            'WebDAV 数据目录包含未知子目录，已保留全部数据。',
          );
        }
        result[entry.uri] = entry.etag!;
      }
    }
    return result;
  }

  Future<List<_Entry>> _scan(
    Uri collection, {
    required bool allowNotFound,
  }) async {
    final response = await http.request(
      'PROPFIND',
      collection,
      headers: {
        ...headers,
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      data: utf8.encode(
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
        '<d:prop><d:resourcetype/><d:getetag/></d:prop></d:propfind>',
      ),
      maxResponseBytes: maxCloudListingResponseBytes,
    );
    if (allowNotFound && response.statusCode == 404) return const [];
    if (response.statusCode != 207) {
      final status = response.statusCode ?? 0;
      throw CloudBackendException(
        _kindFor(status),
        '读取 WebDAV 删除清单失败（HTTP $status）。',
        statusCode: status,
      );
    }
    try {
      final entries = <_Entry>[];
      final document = XmlDocument.parse(BackendHttp.rawTextOf(response));
      for (final item in document.findAllElements(
        'response',
        namespace: 'DAV:',
      )) {
        final href = item
            .getElement('href', namespace: 'DAV:')
            ?.innerText
            .trim();
        final prop = item
            .findElements('propstat', namespace: 'DAV:')
            .where(
              (node) => _is200(
                node.getElement('status', namespace: 'DAV:')?.innerText,
              ),
            )
            .map((node) => node.getElement('prop', namespace: 'DAV:'))
            .whereType<XmlElement>()
            .firstOrNull;
        if (href == null || prop == null) {
          throw const FormatException('missing DAV properties');
        }
        var uri = collection.resolve(href);
        if (_sameResourcePath(uri.path, collection.path)) {
          continue;
        }
        if (!_isDirectChild(collection, uri)) {
          throw const FormatException('unsafe DAV child');
        }
        final isCollection =
            prop
                .getElement('resourcetype', namespace: 'DAV:')
                ?.findElements('collection', namespace: 'DAV:')
                .isNotEmpty ??
            false;
        if (isCollection && !uri.path.endsWith('/')) {
          uri = uri.replace(path: '${uri.path}/');
        }
        final etag = prop
            .getElement('getetag', namespace: 'DAV:')
            ?.innerText
            .trim();
        if (!isCollection && (etag == null || etag.isEmpty)) {
          throw const FormatException('missing ETag');
        }
        entries.add(_Entry(uri, etag, isCollection));
      }
      return entries;
    } catch (_) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'WebDAV 删除清单无法安全验证，未删除任何数据。',
      );
    }
  }

  bool _isDirectChild(Uri collection, Uri uri) {
    if (uri.scheme != root.scheme ||
        uri.host != root.host ||
        uri.port != root.port ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    final parent = collection.path.endsWith('/')
        ? collection.path
        : '${collection.path}/';
    if (!uri.path.startsWith(parent)) return false;
    var relative = uri.path.substring(parent.length);
    if (relative.endsWith('/')) {
      relative = relative.substring(0, relative.length - 1);
    }
    return relative.isNotEmpty && !relative.contains('/');
  }

  static bool _sameInventory(Map<Uri, String> a, Map<Uri, String> b) =>
      a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);

  static bool _sameResourcePath(String a, String b) =>
      a.replaceFirst(RegExp(r'/$'), '') == b.replaceFirst(RegExp(r'/$'), '');

  static bool _is200(String? value) =>
      value != null && RegExp(r'HTTP/\S+\s+200(?:\s|$)').hasMatch(value);

  static CloudBackendErrorKind _kindFor(int status) => switch (status) {
    401 => CloudBackendErrorKind.authentication,
    403 => CloudBackendErrorKind.authorization,
    409 || 412 => CloudBackendErrorKind.conflict,
    507 => CloudBackendErrorKind.quota,
    _ => CloudBackendErrorKind.invalidResponse,
  };
}

class _Entry {
  const _Entry(this.uri, this.etag, this.isCollection);
  final Uri uri;
  final String? etag;
  final bool isCollection;
}
