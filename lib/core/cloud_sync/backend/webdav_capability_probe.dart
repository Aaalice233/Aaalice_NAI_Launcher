import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import 'backend_http.dart';
import 'cloud_sync_backend.dart';
import 'webdav_etag_reader.dart';

class WebDavCapabilityProbe {
  const WebDavCapabilityProbe({
    required this.http,
    required this.headers,
    required this.baseUri,
    required this.root,
    required this.objects,
    required this.snapshots,
  });

  final BackendHttp http;
  final Map<String, String> headers;
  final Uri baseUri;
  final Uri root;
  final Uri objects;
  final Uri snapshots;

  Future<CloudBackendCapability> run() async {
    await _ensureCollection(root);
    await _ensureCollection(objects);
    await _ensureCollection(snapshots);
    final id =
        'capability-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final object = objects.resolve(id);
    final manifest = snapshots.resolve('$id.json');
    String? objectEtag;
    String? manifestEtag;
    String? manualReason;
    try {
      final maximum = Uint8List(maxCloudObjectResponseBytes);
      maximum[0] = 1;
      maximum[maximum.length - 1] = 2;
      final initial = await http.request(
        'PUT',
        object,
        headers: {...headers, 'If-None-Match': '*'},
        data: maximum,
      );
      _expect(initial, const {200, 201, 204}, '写入服务商大小探针');
      objectEtag = initial.headers.value('etag') ?? await _readEtag(object);
      final downloaded = await _get(object, maxCloudObjectResponseBytes);
      if (downloaded.length != maximum.length ||
          downloaded.first != 1 ||
          downloaded.last != 2) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          '服务器未能完整读回最大对象探针。',
        );
      }
      if (objectEtag == null || objectEtag.isEmpty) {
        manualReason = '服务器未返回 ETag；手动备份将使用非 CAS 写入。';
      } else {
        final initialEtag = objectEtag;
        final createRejected = await http.request(
          'PUT',
          object,
          headers: {...headers, 'If-None-Match': '*'},
          data: Uint8List.fromList(const [2]),
        );
        final matchRejected = await http.request(
          'PUT',
          object,
          headers: {...headers, 'If-Match': '"aaalice-invalid-etag"'},
          data: Uint8List.fromList(const [2]),
        );
        final matched = await http.request(
          'PUT',
          object,
          headers: {...headers, 'If-Match': objectEtag},
          data: Uint8List.fromList(const [3]),
        );
        final matchedEtag =
            matched.headers.value('etag') ?? await _readEtag(object);
        final staleRejected = await http.request(
          'PUT',
          object,
          headers: {...headers, 'If-Match': initialEtag},
          data: Uint8List.fromList(const [4]),
        );
        objectEtag = await _readEtag(object) ?? matchedEtag;
        final matchedBytes = await _get(object, maxCloudObjectResponseBytes);
        if (createRejected.statusCode != 412 ||
            matchRejected.statusCode != 412 ||
            !const {200, 201, 204}.contains(matched.statusCode) ||
            staleRejected.statusCode != 412 ||
            objectEtag == null ||
            matchedBytes.length != 1 ||
            matchedBytes.single != 3) {
          manualReason = '服务器未可靠执行 If-Match 或 If-None-Match。';
          objectEtag = await _readEtag(object) ?? objectEtag;
        }
      }

      final historyWrite = await http.request(
        'PUT',
        manifest,
        headers: {...headers, 'If-None-Match': '*'},
        data: Uint8List.fromList(const [4]),
      );
      _expect(historyWrite, const {200, 201, 204}, '写入历史探针');
      manifestEtag =
          historyWrite.headers.value('etag') ?? await _readEtag(manifest);
      final historyCreateRejected = await http.request(
        'PUT',
        manifest,
        headers: {...headers, 'If-None-Match': '*'},
        data: Uint8List.fromList(const [5]),
      );
      final historyBytes = await _get(manifest, 1);
      final historyListed = await _historyContains(id);
      if (historyCreateRejected.statusCode != 412) {
        manualReason ??= '服务器未可靠执行历史对象的 If-None-Match。';
      }
      final expectedHistoryByte = historyCreateRejected.statusCode == 412
          ? 4
          : 5;
      if (!historyListed ||
          historyBytes.length != 1 ||
          historyBytes.single != expectedHistoryByte) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          '服务器无法安全创建、列出或读回历史探针。',
        );
      }

      if (objectEtag == null) {
        await _deleteUniqueProbe(object, action: '删除无 ETag 对象探针');
      } else {
        await _deleteExact(object, objectEtag, action: '删除对象探针');
      }
      objectEtag = null;
      if (await _exists(object)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          '删除探针后对象仍然可读。',
        );
      }
      if (manifestEtag == null) {
        await _deleteUniqueProbe(manifest, action: '删除无 ETag 历史探针');
      } else {
        await _deleteExact(manifest, manifestEtag, action: '删除历史探针');
      }
      manifestEtag = null;
      if (await _exists(manifest)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          '删除探针后历史仍然可读。',
        );
      }
      if (manualReason != null) return _manual(manualReason);
      return const CloudBackendCapability(
        mode: CloudBackendMode.bidirectional,
        message: 'WebDAV 已验证认证、读写、条件更新、历史、删除与 4 MiB 对象限制。',
        supportsHistory: true,
        supportsDelete: true,
      );
    } finally {
      if (objectEtag != null) {
        await _deleteExact(object, objectEtag, action: '清理对象探针');
      } else {
        await _deleteUniqueProbe(object, action: '清理无 ETag 对象探针');
      }
      if (manifestEtag != null) {
        await _deleteExact(manifest, manifestEtag, action: '清理历史探针');
      } else if (await _exists(manifest)) {
        await _deleteUniqueProbe(manifest, action: '清理无 ETag 历史探针');
      }
    }
  }

  Future<Uint8List> _get(Uri uri, int maxBytes) async {
    final response = await http.request(
      'GET',
      uri,
      headers: headers,
      maxResponseBytes: maxBytes,
    );
    _expect(response, const {200}, '读取能力探针');
    return BackendHttp.bytesOf(response);
  }

  Future<bool> _exists(Uri uri) async {
    final response = await http.request('HEAD', uri, headers: headers);
    if (response.statusCode == 404) return false;
    _expect(response, const {200, 204}, '复核探针删除');
    return true;
  }

  Future<String?> _readEtag(Uri uri) =>
      WebDavEtagReader(http: http, headers: headers).read(uri);

  Future<bool> _historyContains(String id) async {
    final response = await http.request(
      'PROPFIND',
      snapshots,
      headers: {
        ...headers,
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      data: utf8.encode(
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
        '<d:allprop/></d:propfind>',
      ),
      maxResponseBytes: maxCloudListingResponseBytes,
    );
    _expect(response, const {207}, '列出历史探针');
    try {
      return XmlDocument.parse(BackendHttp.rawTextOf(response))
          .findAllElements('href', namespace: 'DAV:')
          .any(
            (node) => Uri.decodeComponent(node.innerText).endsWith('/$id.json'),
          );
    } catch (_) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'WebDAV 历史探针列表无法解析。',
      );
    }
  }

  Future<void> _deleteExact(
    Uri uri,
    String etag, {
    required String action,
  }) async {
    final response = await http.request(
      'DELETE',
      uri,
      headers: {...headers, 'If-Match': etag},
    );
    _expect(response, const {200, 202, 204, 404}, action);
  }

  Future<void> _deleteUniqueProbe(Uri uri, {required String action}) async {
    final response = await http.request('DELETE', uri, headers: headers);
    _expect(response, const {200, 202, 204, 404}, action);
  }

  Future<void> _ensureCollection(Uri uri) async {
    final segments = uri.pathSegments
        .where((value) => value.isNotEmpty)
        .toList();
    final baseCount = baseUri.pathSegments
        .where((value) => value.isNotEmpty)
        .length;
    var current = baseUri;
    for (final segment in segments.skip(baseCount)) {
      current = current.resolve('${Uri.encodeComponent(segment)}/');
      final response = await http.request(
        'MKCOL',
        current,
        headers: {...headers, 'Content-Length': '0'},
      );
      _expect(response, const {200, 201, 204, 405}, '创建 WebDAV 目录');
    }
  }

  static CloudBackendCapability _manual(String message) =>
      CloudBackendCapability(
        mode: CloudBackendMode.manualBackupOnly,
        message: '$message 只能使用手动云备份。',
        supportsHistory: false,
        supportsDelete: false,
        warnings: const ['服务器不满足 CAS 条件；仅允许手动备份，后写入可能覆盖同一 HEAD。'],
      );

  static void _expect(
    Response<Uint8List> response,
    Set<int> accepted,
    String action,
  ) {
    final status = response.statusCode ?? 0;
    if (accepted.contains(status)) return;
    throw CloudBackendException(
      switch (status) {
        401 => CloudBackendErrorKind.authentication,
        403 => CloudBackendErrorKind.authorization,
        409 || 412 => CloudBackendErrorKind.conflict,
        413 || 507 => CloudBackendErrorKind.quota,
        _ => CloudBackendErrorKind.invalidResponse,
      },
      '$action失败（HTTP $status）。',
      statusCode: status,
    );
  }
}
