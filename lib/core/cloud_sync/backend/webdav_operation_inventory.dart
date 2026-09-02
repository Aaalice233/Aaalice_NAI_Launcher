import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import '../telemetry.dart';
import 'backend_http.dart';
import 'cloud_object_naming.dart';
import 'cloud_sync_backend.dart';

/// Reads one strict, operation-scoped inventory of immutable WebDAV objects.
class WebDavOperationInventory {
  const WebDavOperationInventory({
    required this.http,
    required this.headers,
    required this.objects,
    required this.verifiedObjectRevisions,
  });

  final BackendHttp http;
  final Map<String, String> headers;
  final Uri objects;
  final Map<String, String> verifiedObjectRevisions;

  static final Uint8List _properties = Uint8List.fromList(
    utf8.encode(
      '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
      '<d:prop><d:resourcetype/><d:getetag/>'
      '<d:getcontentlength/></d:prop></d:propfind>',
    ),
  );

  Future<Set<String>> findExisting(Map<String, int> expectedObjects) async {
    if (expectedObjects.isEmpty) return const <String>{};
    final response = await http.request(
      'PROPFIND',
      objects,
      headers: {
        ...headers,
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      data: _properties,
      maxResponseBytes: maxCloudListingResponseBytes,
    );
    if (response.statusCode == 404) return const <String>{};
    if (response.statusCode != 207) {
      throw _invalid('读取 WebDAV 对象清单失败（HTTP ${response.statusCode ?? 0}）。');
    }

    try {
      final document = XmlDocument.parse(BackendHttp.rawTextOf(response));
      final found = <String>{};
      final seenNames = <String>{};
      for (final item in document.findAllElements(
        'response',
        namespace: 'DAV:',
      )) {
        final href = item
            .getElement('href', namespace: 'DAV:')
            ?.innerText
            .trim();
        if (href == null || href.isEmpty) {
          throw _invalid('WebDAV 对象清单包含空 href。');
        }
        final resolved = _resolveSafeHref(href);
        if (_sameResource(resolved, objects)) continue;
        final name = _directChildName(resolved);
        CloudObjectNaming.validateId(name);
        if (!seenNames.add(name)) {
          throw _invalid('WebDAV 对象清单包含重复对象。');
        }

        final properties = _successfulProperties(item);
        if (properties == null) continue;
        final resourceType = properties.getElement(
          'resourcetype',
          namespace: 'DAV:',
        );
        if (resourceType == null) {
          throw _invalid('WebDAV 对象清单缺少 resourcetype。');
        }
        if (resourceType
            .findElements('collection', namespace: 'DAV:')
            .isNotEmpty) {
          continue;
        }
        final lengthText = properties
            .getElement('getcontentlength', namespace: 'DAV:')
            ?.innerText
            .trim();
        final length = lengthText == null ? null : int.tryParse(lengthText);
        if (length == null || length < 0) {
          throw _invalid('WebDAV 对象清单包含非法 getcontentlength。');
        }
        final expectedLength = expectedObjects[name];
        if (expectedLength == null) continue;
        if (length != expectedLength) {
          throw const CloudBackendException(
            CloudBackendErrorKind.conflict,
            '远端同名对象的大小与本地内容不一致。',
          );
        }
        final etag = properties
            .getElement('getetag', namespace: 'DAV:')
            ?.innerText
            .trim();
        if (!_isStrongEtag(etag)) continue;
        if (verifiedObjectRevisions[name] != etag) {
          final content = await http.request(
            'GET',
            resolved,
            headers: {...headers, 'If-Match': etag!},
            maxResponseBytes: maxCloudObjectResponseBytes,
          );
          if (content.statusCode == 412) {
            throw const CloudBackendException(
              CloudBackendErrorKind.conflict,
              'WebDAV 对象清单在校验期间发生变化。',
            );
          }
          if (content.statusCode != 200) {
            throw _invalid(
              '读取 WebDAV 不可变对象失败（HTTP ${content.statusCode ?? 0}）。',
            );
          }
          CloudSyncTelemetry.recordHashPass();
          if (sha256.convert(BackendHttp.bytesOf(content)).toString() != name) {
            throw const CloudBackendException(
              CloudBackendErrorKind.conflict,
              'WebDAV 已存在内容不一致的不可变对象。',
            );
          }
          verifiedObjectRevisions[name] = etag;
        }
        found.add(name);
      }
      return Set.unmodifiable(found);
    } on CloudBackendException {
      rethrow;
    } catch (_) {
      throw _invalid('WebDAV 返回了无法解析的对象清单。');
    }
  }

  Uri _resolveSafeHref(String href) {
    final parsed = Uri.parse(href);
    final resolved = objects.resolveUri(parsed);
    if (resolved.scheme != objects.scheme ||
        resolved.host != objects.host ||
        resolved.port != objects.port ||
        resolved.userInfo.isNotEmpty ||
        resolved.query.isNotEmpty ||
        resolved.fragment.isNotEmpty) {
      throw _invalid('WebDAV 对象清单包含越界 href。');
    }
    return resolved;
  }

  String _directChildName(Uri uri) {
    final collectionPath = objects.path.endsWith('/')
        ? objects.path
        : '${objects.path}/';
    if (!uri.path.startsWith(collectionPath)) {
      throw _invalid('WebDAV 对象清单包含越界 href。');
    }
    final encodedName = uri.path.substring(collectionPath.length);
    if (encodedName.isEmpty || encodedName.contains('/')) {
      throw _invalid('WebDAV 对象清单包含非直接子对象 href。');
    }
    final name = Uri.decodeComponent(encodedName);
    if (name.isEmpty || name == '.' || name == '..' || name.contains('/')) {
      throw _invalid('WebDAV 对象清单包含非法 href。');
    }
    return name;
  }

  static XmlElement? _successfulProperties(XmlElement item) {
    for (final propstat in item.findElements('propstat', namespace: 'DAV:')) {
      final status = propstat
          .getElement('status', namespace: 'DAV:')
          ?.innerText;
      if (status != null &&
          RegExp(r'HTTP/\S+\s+200(?:\s|$)').hasMatch(status)) {
        return propstat.getElement('prop', namespace: 'DAV:');
      }
    }
    return null;
  }

  static bool _isStrongEtag(String? etag) =>
      etag != null &&
      !etag.startsWith('W/') &&
      RegExp(r'^"[^"\r\n]*"$').hasMatch(etag);

  static bool _sameResource(Uri first, Uri second) =>
      first.scheme == second.scheme &&
      first.host == second.host &&
      first.port == second.port &&
      first.path.replaceFirst(RegExp(r'/$'), '') ==
          second.path.replaceFirst(RegExp(r'/$'), '');

  static CloudBackendException _invalid(String message) =>
      CloudBackendException(CloudBackendErrorKind.invalidResponse, message);
}
