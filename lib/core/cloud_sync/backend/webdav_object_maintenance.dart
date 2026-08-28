import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../models.dart';
import 'backend_http.dart';
import 'cloud_object_naming.dart';
import 'cloud_sync_backend.dart';

class WebDavObjectMaintenance {
  const WebDavObjectMaintenance({
    required this.http,
    required this.headers,
    required this.root,
    required this.objects,
    required this.snapshots,
    required this.head,
    this.gracePeriod = const Duration(days: 7),
  });

  final BackendHttp http;
  final Map<String, String> headers;
  final Uri root;
  final Uri objects;
  final Uri snapshots;
  final Uri head;
  final Duration gracePeriod;

  Future<CloudMaintenanceResult> clean() async {
    final warnings = <String>[];
    try {
      final firstManifests = await _scan(snapshot: true, warnings: warnings);
      final objectScan = await _scan(snapshot: false, warnings: warnings);
      final serverDate = objectScan.serverDate;
      if (serverDate == null) {
        warnings.add('WebDAV 对象列表缺少可信的服务器 Date，已跳过清理。');
        return CloudMaintenanceResult(
          scanned: objectScan.entries.length,
          deleted: 0,
          skipped: objectScan.entries.length + objectScan.rejected,
          warnings: warnings,
        );
      }

      final headSnapshot = await _readHeadSnapshot(warnings);
      final protected = <String>{
        ...firstManifests.entries.map((entry) => entry.name),
        if (headSnapshot != null) headSnapshot,
      };
      final candidates = <_DavEntry>[];
      var skipped = objectScan.rejected;
      for (final entry in objectScan.entries) {
        final owner = CloudObjectNaming.snapshotIdFromObjectId(entry.name);
        if (owner == null || protected.contains(owner)) {
          skipped++;
          continue;
        }
        if (entry.etag == null || entry.lastModified == null) {
          warnings.add('对象 ${entry.name} 缺少 ETag 或 last-modified，已保留。');
          skipped++;
          continue;
        }
        if (!entry.lastModified!.isBefore(serverDate.subtract(gracePeriod))) {
          skipped++;
          continue;
        }
        candidates.add(entry);
      }

      if (candidates.isEmpty) {
        return CloudMaintenanceResult(
          scanned: objectScan.entries.length,
          deleted: 0,
          skipped: skipped,
          warnings: warnings,
        );
      }

      // A second manifest scan closes the upload/GC race before any DELETE.
      final secondManifests = await _scan(snapshot: true, warnings: warnings);
      protected.addAll(secondManifests.entries.map((entry) => entry.name));
      final secondHead = await _readHeadSnapshot(warnings);
      if (secondHead != null) protected.add(secondHead);

      var deleted = 0;
      for (final entry in candidates) {
        final owner = CloudObjectNaming.snapshotIdFromObjectId(entry.name)!;
        if (protected.contains(owner)) {
          skipped++;
          continue;
        }
        final response = await http.request(
          'DELETE',
          entry.uri,
          headers: {...headers, 'If-Match': entry.etag!},
        );
        final status = response.statusCode ?? 0;
        if ({200, 202, 204}.contains(status)) {
          deleted++;
        } else if (status == 404 || status == 412) {
          skipped++;
        } else {
          skipped++;
          warnings.add('清理对象失败（HTTP $status），对象已保留。');
        }
      }
      return CloudMaintenanceResult(
        scanned: objectScan.entries.length,
        deleted: deleted,
        skipped: skipped,
        warnings: warnings,
      );
    } on CloudBackendException catch (error) {
      warnings.add('WebDAV 维护未完成：${error.message}');
      return CloudMaintenanceResult(
        scanned: 0,
        deleted: 0,
        skipped: 0,
        warnings: warnings,
      );
    } catch (_) {
      warnings.add('WebDAV 维护响应无法安全验证，未删除任何对象。');
      return CloudMaintenanceResult(
        scanned: 0,
        deleted: 0,
        skipped: 0,
        warnings: warnings,
      );
    }
  }

  Future<String?> _readHeadSnapshot(List<String> warnings) async {
    final response = await http.request(
      'GET',
      head,
      headers: headers,
      maxResponseBytes: maxCloudHeadResponseBytes,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw CloudBackendException(
        _kindFor(response.statusCode),
        '无法复核 WebDAV HEAD（HTTP ${response.statusCode ?? 0}），清理已停止。',
        statusCode: response.statusCode,
      );
    }
    try {
      return SnapshotHead.decode(BackendHttp.bytesOf(response)).snapshotId;
    } catch (_) {
      warnings.add('WebDAV HEAD 无法验证，已按保守策略跳过孤儿删除。');
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'HEAD 无法验证，清理已停止。',
      );
    }
  }

  Future<_DavScan> _scan({
    required bool snapshot,
    required List<String> warnings,
  }) async {
    final collection = snapshot ? snapshots : objects;
    final response = await http.request(
      'PROPFIND',
      collection,
      headers: {...headers, 'Depth': '1'},
      data: utf8.encode(
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop>'
        '<d:getetag/><d:getlastmodified/><d:getcontentlength/>'
        '<d:resourcetype/></d:prop></d:propfind>',
      ),
      maxResponseBytes: maxCloudListingResponseBytes,
    );
    if (response.statusCode == 404) return const _DavScan(entries: []);
    if (response.statusCode != 207) {
      throw CloudBackendException(
        _kindFor(response.statusCode),
        '读取 WebDAV 维护列表失败（HTTP ${response.statusCode ?? 0}）。',
        statusCode: response.statusCode,
      );
    }
    DateTime? serverDate;
    final date = response.headers.value('date');
    if (date != null) {
      try {
        serverDate = HttpDate.parse(date).toUtc();
      } catch (_) {
        warnings.add('WebDAV 返回了无效的服务器 Date。');
      }
    }
    final entries = <_DavEntry>[];
    var rejected = 0;
    final document = XmlDocument.parse(BackendHttp.rawTextOf(response));
    for (final item in document.findAllElements(
      'response',
      namespace: 'DAV:',
    )) {
      final href = item.getElement('href', namespace: 'DAV:')?.innerText.trim();
      final propstat = item
          .findElements('propstat', namespace: 'DAV:')
          .where(
            (node) =>
                _is200(node.getElement('status', namespace: 'DAV:')?.innerText),
          )
          .firstOrNull;
      final prop = propstat?.getElement('prop', namespace: 'DAV:');
      if (href == null || prop == null) {
        rejected++;
        continue;
      }
      final uri = collection.resolve(href);
      final name = _directChildName(collection, uri);
      final expectedName = name == null
          ? null
          : snapshot
          ? CloudObjectNaming.snapshotIdFromManifestName(name)
          : (CloudObjectNaming.isValidId(name) ? name : null);
      final isCollection =
          prop
              .getElement('resourcetype', namespace: 'DAV:')
              ?.findElements('collection', namespace: 'DAV:')
              .isNotEmpty ??
          false;
      if (expectedName == null || isCollection) {
        rejected++;
        continue;
      }
      entries.add(
        _DavEntry(
          name: expectedName,
          uri: uri,
          etag: _text(prop, 'getetag'),
          lastModified: _httpDate(_text(prop, 'getlastmodified')),
        ),
      );
    }
    return _DavScan(
      entries: entries,
      serverDate: serverDate,
      rejected: rejected,
    );
  }

  String? _directChildName(Uri collection, Uri uri) {
    if (uri.scheme.toLowerCase() != root.scheme.toLowerCase() ||
        uri.host.toLowerCase() != root.host.toLowerCase() ||
        uri.port != root.port ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final parent = collection.path.endsWith('/')
        ? collection.path
        : '${collection.path}/';
    if (!uri.path.startsWith(parent)) return null;
    final relative = uri.path.substring(parent.length);
    if (relative.isEmpty || relative.contains('/')) return null;
    try {
      return Uri.decodeComponent(relative);
    } catch (_) {
      return null;
    }
  }

  static bool _is200(String? value) =>
      value != null && RegExp(r'HTTP/\S+\s+200(?:\s|$)').hasMatch(value);

  static String? _text(XmlElement prop, String name) {
    final value = prop.getElement(name, namespace: 'DAV:')?.innerText.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static DateTime? _httpDate(String? value) {
    if (value == null) return null;
    try {
      return HttpDate.parse(value).toUtc();
    } catch (_) {
      return null;
    }
  }

  static CloudBackendErrorKind _kindFor(int? status) => switch (status) {
    401 => CloudBackendErrorKind.authentication,
    403 => CloudBackendErrorKind.authorization,
    _ => CloudBackendErrorKind.invalidResponse,
  };
}

class _DavEntry {
  const _DavEntry({
    required this.name,
    required this.uri,
    required this.etag,
    required this.lastModified,
  });

  final String name;
  final Uri uri;
  final String? etag;
  final DateTime? lastModified;
}

class _DavScan {
  const _DavScan({required this.entries, this.serverDate, this.rejected = 0});

  final List<_DavEntry> entries;
  final DateTime? serverDate;
  final int rejected;
}
