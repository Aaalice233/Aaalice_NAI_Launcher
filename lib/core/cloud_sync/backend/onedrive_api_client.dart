import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'backend_http.dart';
import 'cloud_sync_backend.dart';

class OneDriveItem {
  const OneDriveItem({
    required this.name,
    required this.eTag,
    required this.size,
    required this.isFolder,
  });

  final String name;
  final String eTag;
  final int size;
  final bool isFolder;
}

class OneDriveApiClient {
  OneDriveApiClient({
    required Future<String> Function() accessTokenProvider,
    Dio? dio,
    Uri? graphBaseUri,
  }) : _accessTokenProvider = accessTokenProvider,
       _dio = dio ?? Dio(),
       _graphBase =
           graphBaseUri ?? Uri.parse('https://graph.microsoft.com/v1.0/') {
    if (!_graphBase.isAbsolute || !_graphBase.path.endsWith('/')) {
      throw ArgumentError.value(
        _graphBase,
        'graphBaseUri',
        'Graph base must be an absolute directory URI',
      );
    }
    _graphHttp = BackendHttp(dio: _dio);
    // Signed upload/download URLs are pre-authenticated. A clean Dio instance
    // prevents caller-installed Graph interceptors from attaching bearer tokens.
    _signedHttp = BackendHttp(
      dio: Dio()..httpClientAdapter = _dio.httpClientAdapter,
    );
  }

  static const String _appRoot = 'me/drive/special/approot';

  final Future<String> Function() _accessTokenProvider;
  final Dio _dio;
  final Uri _graphBase;
  late final BackendHttp _graphHttp;
  late final BackendHttp _signedHttp;

  Future<OneDriveItem?> metadata(String path) async {
    final response = await _graphRequest(
      'GET',
      _itemEndpoint(path),
      action: '读取 OneDrive 文件信息',
      allowNotFound: true,
    );
    if (response == null) return null;
    return _decodeItem(_decodeMap(response, 'OneDrive 文件信息'));
  }

  Future<Uint8List> download(
    String path, {
    required String expectedETag,
    required int maxBytes,
  }) async {
    final redirect = await _downloadRedirect(
      _graphUri('${_itemEndpoint(path)}:/content'),
      expectedETag: expectedETag,
      maxBytes: maxBytes,
    );
    if (redirect.bytes != null) return redirect.bytes!;
    final response = await _signedHttp.request(
      'GET',
      redirect.location!,
      headers: const {'Accept-Encoding': 'identity'},
      maxResponseBytes: maxBytes,
      tooLargeKind: CloudBackendErrorKind.invalidResponse,
    );
    if (response.statusCode != 200) {
      _throwResponse(response, '下载 OneDrive 文件');
    }
    return BackendHttp.bytesOf(response);
  }

  Future<void> ensureFolder(String path) async {
    var parent = '';
    for (final name in path.split('/')) {
      final endpoint = parent.isEmpty
          ? '$_appRoot/children'
          : '${_itemEndpoint(parent)}:/children';
      final response = await _graphRequest(
        'POST',
        endpoint,
        action: '创建 OneDrive 应用目录',
        accepted: const {201},
        data: {
          'name': name,
          'folder': <String, Object?>{},
          '@microsoft.graph.conflictBehavior': 'fail',
        },
        allowConflict: true,
        retryable: true,
      );
      if (response == null) {
        final existing = await metadata(
          parent.isEmpty ? name : '$parent/$name',
        );
        if (existing == null || !existing.isFolder) {
          throw const CloudBackendException(
            CloudBackendErrorKind.conflict,
            'OneDrive 中存在同名文件，无法创建同步目录。',
            statusCode: 409,
          );
        }
      }
      parent = parent.isEmpty ? name : '$parent/$name';
    }
  }

  Future<OneDriveItem> upload(
    String path,
    Uint8List bytes, {
    required String? expectedETag,
  }) async {
    final response = await _graphRequest(
      'POST',
      '${_itemEndpoint(path)}:/createUploadSession',
      action: '创建 OneDrive 上传会话',
      accepted: const {200, 201},
      headers: {if (expectedETag != null) 'If-Match': expectedETag},
      data: {
        'item': {
          '@microsoft.graph.conflictBehavior': expectedETag == null
              ? 'fail'
              : 'replace',
          'name': path.split('/').last,
        },
      },
      retryable: true,
    );
    final session = _decodeMap(response!, 'OneDrive 上传会话');
    final rawUploadUrl = session['uploadUrl'];
    if (rawUploadUrl is! String) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'OneDrive 上传会话缺少 uploadUrl。',
      );
    }
    final uploadUri = Uri.tryParse(rawUploadUrl);
    if (uploadUri == null ||
        !uploadUri.isAbsolute ||
        uploadUri.scheme != 'https') {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'OneDrive 返回了不安全的上传地址。',
      );
    }
    final uploaded = await _signedHttp.request(
      'PUT',
      uploadUri,
      headers: {
        'Content-Length': '${bytes.length}',
        'Content-Range': bytes.isEmpty
            ? 'bytes */0'
            : 'bytes 0-${bytes.length - 1}/${bytes.length}',
        'Content-Type': 'application/octet-stream',
      },
      data: bytes,
      retryable: true,
      maxResponseBytes: maxCloudJsonApiResponseBytes,
    );
    if (uploaded.statusCode != 200 && uploaded.statusCode != 201) {
      _throwResponse(uploaded, '上传 OneDrive 文件');
    }
    return _decodeItem(_decodeMap(uploaded, 'OneDrive 上传结果'));
  }

  Future<List<OneDriveItem>> listChildren(String path) async {
    final items = <OneDriveItem>[];
    final visited = <Uri>{};
    Uri? next = _graphUri(
      '${_itemEndpoint(path)}:/children?%24select=name,eTag,size,file,folder&%24top=200',
    );
    var accumulatedBytes = 0;
    while (next != null) {
      if (!visited.add(next)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'OneDrive children 分页形成循环。',
        );
      }
      final response = await _graphRequestUri(
        'GET',
        next,
        action: '读取 OneDrive 快照列表',
        allowNotFound: true,
      );
      if (response == null) return const [];
      accumulatedBytes += BackendHttp.bytesOf(response).length;
      if (accumulatedBytes > maxCloudListingResponseBytes) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'OneDrive 快照列表超过允许的大小。',
        );
      }
      final decoded = _decodeMap(response, 'OneDrive children');
      final values = decoded['value'];
      if (values is! List) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'OneDrive children 响应缺少 value。',
        );
      }
      for (final value in values) {
        if (value is! Map) {
          throw const CloudBackendException(
            CloudBackendErrorKind.invalidResponse,
            'OneDrive children 包含无效项目。',
          );
        }
        items.add(_decodeItem(value.cast<String, dynamic>()));
      }
      final rawNext = decoded['@odata.nextLink'];
      if (rawNext == null) {
        next = null;
      } else if (rawNext is String) {
        next = _trustedGraphLink(rawNext);
      } else {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'OneDrive children 分页地址无效。',
        );
      }
    }
    return items;
  }

  Future<void> delete(String path) async {
    final response = await _graphRequest(
      'DELETE',
      _itemEndpoint(path),
      action: '删除 OneDrive 同步数据',
      accepted: const {204},
      allowNotFound: true,
      retryable: true,
    );
    if (response == null) return;
  }

  Future<Response<Uint8List>?> _graphRequest(
    String method,
    String endpoint, {
    required String action,
    Set<int> accepted = const {200},
    Map<String, String>? headers,
    Object? data,
    bool allowNotFound = false,
    bool allowConflict = false,
    bool? retryable,
  }) => _graphRequestUri(
    method,
    _graphUri(endpoint),
    action: action,
    accepted: accepted,
    headers: headers,
    data: data,
    allowNotFound: allowNotFound,
    allowConflict: allowConflict,
    retryable: retryable,
  );

  Future<Response<Uint8List>?> _graphRequestUri(
    String method,
    Uri uri, {
    required String action,
    Set<int> accepted = const {200},
    Map<String, String>? headers,
    Object? data,
    bool allowNotFound = false,
    bool allowConflict = false,
    bool? retryable,
  }) async {
    _requireTrustedGraphUri(uri);
    final token = await _accessTokenProvider();
    if (token.trim().isEmpty) {
      throw const CloudBackendException(
        CloudBackendErrorKind.authentication,
        'Microsoft access token 为空。',
      );
    }
    final response = await _graphHttp.request(
      method,
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Accept-Encoding': 'identity',
        if (data != null) 'Content-Type': 'application/json',
        ...?headers,
      },
      data: data == null ? null : jsonEncode(data),
      retryable: retryable,
      maxResponseBytes: maxCloudJsonApiResponseBytes,
    );
    final status = response.statusCode ?? 0;
    if (accepted.contains(status)) return response;
    if (allowNotFound && status == 404) return null;
    if (allowConflict && status == 409) return null;
    _throwResponse(response, action);
  }

  Future<_DownloadRedirect> _downloadRedirect(
    Uri uri, {
    required String expectedETag,
    required int maxBytes,
  }) async {
    _requireTrustedGraphUri(uri);
    const transient = {408, 425, 429, 500, 502, 503, 504};
    for (var attempt = 1; attempt <= 3; attempt++) {
      final token = await _accessTokenProvider();
      if (token.trim().isEmpty) {
        throw const CloudBackendException(
          CloudBackendErrorKind.authentication,
          'Microsoft access token 为空。',
        );
      }
      Response<ResponseBody> streamed;
      try {
        streamed = await _dio.request<ResponseBody>(
          uri.toString(),
          options: Options(
            method: 'GET',
            headers: {
              'Authorization': 'Bearer $token',
              'If-Match': expectedETag,
              'Accept-Encoding': 'identity',
            },
            responseType: ResponseType.stream,
            followRedirects: false,
            validateStatus: (_) => true,
          ),
        );
      } on DioException catch (error) {
        if (attempt < 3) {
          await Future<void>.delayed(
            Duration(milliseconds: attempt == 1 ? 300 : 900),
          );
          continue;
        }
        throw CloudBackendException(
          CloudBackendErrorKind.network,
          '无法连接 OneDrive，请检查网络、代理和 Microsoft 登录状态。',
          cause: error,
        );
      }
      final status = streamed.statusCode ?? 0;
      if (transient.contains(status) && attempt < 3) {
        await _discard(streamed.data);
        await Future<void>.delayed(_retryDelay(streamed.headers, attempt));
        continue;
      }
      if ({301, 302, 303, 307, 308}.contains(status)) {
        final location = streamed.headers.value('location');
        await _discard(streamed.data);
        final target = location == null ? null : uri.resolve(location);
        if (target == null || !target.isAbsolute || target.scheme != 'https') {
          throw CloudBackendException(
            CloudBackendErrorKind.redirectRejected,
            'OneDrive 返回了无效或不安全的下载地址。',
            statusCode: status,
          );
        }
        return _DownloadRedirect(location: target);
      }
      if (status == 200) {
        final bytes = await _buffer(streamed, maxBytes);
        return _DownloadRedirect(bytes: bytes);
      }
      final bytes = await _buffer(streamed, maxCloudJsonApiResponseBytes);
      _throwResponse(
        Response<Uint8List>(
          requestOptions: streamed.requestOptions,
          statusCode: streamed.statusCode,
          headers: streamed.headers,
          data: bytes,
        ),
        '获取 OneDrive 下载地址',
      );
    }
    throw StateError('unreachable');
  }

  Future<Uint8List> _buffer(
    Response<ResponseBody> response,
    int maxBytes,
  ) async {
    final declared = int.tryParse(
      response.headers.value('content-length') ?? '',
    );
    if (declared != null && declared > maxBytes) {
      await _discard(response.data);
      throw CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'OneDrive 文件超过允许的下载大小。',
        statusCode: response.statusCode,
      );
    }
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk
        in response.data?.stream ?? const Stream<Uint8List>.empty()) {
      length += chunk.length;
      if (length > maxBytes) {
        throw CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'OneDrive 文件超过允许的下载大小。',
          statusCode: response.statusCode,
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static Future<void> _discard(ResponseBody? body) async {
    if (body == null) return;
    final subscription = body.stream.listen((_) {});
    await subscription.cancel();
  }

  Map<String, dynamic> _decodeMap(Response<Uint8List> response, String label) {
    try {
      final value = jsonDecode(BackendHttp.rawTextOf(response));
      if (value is Map) return value.cast<String, dynamic>();
    } on FormatException {
      // Report a provider response error below without including its body.
    }
    throw CloudBackendException(
      CloudBackendErrorKind.invalidResponse,
      '$label 响应格式无效。',
      statusCode: response.statusCode,
    );
  }

  OneDriveItem _decodeItem(Map<String, dynamic> value) {
    final name = value['name'];
    final eTag = value['eTag'] ?? value['@odata.etag'];
    final size = value['size'];
    if (name is! String || eTag is! String || size is! int) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'OneDrive 文件项目缺少 name、eTag 或 size。',
      );
    }
    return OneDriveItem(
      name: name,
      eTag: eTag,
      size: size,
      isFolder: value['folder'] is Map,
    );
  }

  String _itemEndpoint(String path) =>
      '$_appRoot:/${path.split('/').map(Uri.encodeComponent).join('/')}';

  Uri _graphUri(String endpoint) => _graphBase.resolve(endpoint);

  Uri _trustedGraphLink(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'OneDrive 返回了无效的分页地址。',
      );
    }
    _requireTrustedGraphUri(uri);
    return uri;
  }

  void _requireTrustedGraphUri(Uri uri) {
    if (uri.scheme.toLowerCase() != _graphBase.scheme.toLowerCase() ||
        uri.host.toLowerCase() != _graphBase.host.toLowerCase() ||
        uri.port != _graphBase.port ||
        !uri.path.startsWith(_graphBase.path)) {
      throw const CloudBackendException(
        CloudBackendErrorKind.redirectRejected,
        'OneDrive Graph 地址越过了受信任的 API 边界。',
      );
    }
  }

  static Never _throwResponse(Response<Uint8List> response, String action) {
    final status = response.statusCode ?? 0;
    final kind = switch (status) {
      401 => CloudBackendErrorKind.authentication,
      403 => CloudBackendErrorKind.authorization,
      404 => CloudBackendErrorKind.notFound,
      409 || 412 => CloudBackendErrorKind.conflict,
      413 || 507 => CloudBackendErrorKind.quota,
      429 => CloudBackendErrorKind.rateLimited,
      >= 500 => CloudBackendErrorKind.network,
      _ => CloudBackendErrorKind.invalidResponse,
    };
    throw CloudBackendException(
      kind,
      '$action失败（HTTP $status）。',
      statusCode: status,
      retryAfter: _retryAfter(response.headers),
    );
  }

  static DateTime? _retryAfter(Headers headers) {
    final value = headers.value('retry-after');
    if (value == null) return null;
    final seconds = int.tryParse(value);
    if (seconds != null) {
      return DateTime.now().toUtc().add(Duration(seconds: seconds));
    }
    try {
      return HttpDate.parse(value).toUtc();
    } on FormatException {
      return DateTime.tryParse(value)?.toUtc();
    }
  }

  static Duration _retryDelay(Headers headers, int attempt) {
    final rawRetryAfter = headers.value('retry-after');
    final seconds = int.tryParse(rawRetryAfter ?? '');
    if (seconds != null) {
      return Duration(seconds: seconds.clamp(0, 30));
    }
    final retryAt = _retryAfter(headers);
    if (retryAt != null) {
      final delay = retryAt.difference(DateTime.now().toUtc());
      if (!delay.isNegative) {
        return delay > const Duration(seconds: 30)
            ? const Duration(seconds: 30)
            : delay;
      }
    }
    return Duration(milliseconds: attempt == 1 ? 300 : 900);
  }
}

class _DownloadRedirect {
  const _DownloadRedirect({this.location, this.bytes});

  final Uri? location;
  final Uint8List? bytes;
}
