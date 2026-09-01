import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../utils/app_logger.dart';
import 'backend_http.dart';
import 'cloud_sync_backend.dart';

class OneDriveItem {
  const OneDriveItem({
    required this.id,
    required this.name,
    required this.eTag,
    required this.size,
    required this.isFolder,
  });

  final String? id;
  final String name;
  final String eTag;
  final int size;
  final bool isFolder;
}

Dio _createOneDriveDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ),
);

class OneDriveApiClient {
  OneDriveApiClient({
    required Future<String> Function() accessTokenProvider,
    Dio? dio,
    Uri? graphBaseUri,
  }) : _accessTokenProvider = accessTokenProvider,
       _dio = dio ?? _createOneDriveDio(),
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
      dio: _createOneDriveDio()..httpClientAdapter = _dio.httpClientAdapter,
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
    var parentItem = await _ensureAppRoot();
    var parentPath = '';
    for (final name in path.split('/')) {
      final parentId = parentItem.id;
      if (parentId == null || parentId.isEmpty) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'OneDrive 父目录响应缺少 id。',
        );
      }
      final response = await _graphRequest(
        'POST',
        'me/drive/items/${Uri.encodeComponent(parentId)}/children',
        action: '创建 OneDrive 应用目录',
        accepted: const {201},
        data: {'name': name, 'folder': <String, Object?>{}},
        allowConflict: true,
        retryable: true,
      );
      final currentPath = parentPath.isEmpty ? name : '$parentPath/$name';
      final folder = response == null
          ? await metadata(currentPath)
          : _decodeItem(_decodeMap(response, 'OneDrive 目录创建结果'));
      if (folder == null ||
          !folder.isFolder ||
          folder.name != name ||
          folder.id == null ||
          folder.id!.isEmpty) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'OneDrive 中存在同名文件，无法创建同步目录。',
          statusCode: 409,
        );
      }
      parentItem = folder;
      parentPath = currentPath;
    }
  }

  Future<OneDriveItem> _ensureAppRoot() async {
    final response = await _graphRequest(
      'GET',
      _appRoot,
      action: '初始化 OneDrive 应用目录',
      retryable: false,
    );
    final item = _decodeItem(_decodeMap(response!, 'OneDrive 应用目录'));
    if (!item.isFolder || item.id == null || item.id!.isEmpty) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'OneDrive 应用目录响应缺少文件夹或 id。',
      );
    }
    return item;
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
    final stopwatch = Stopwatch()..start();
    AppLogger.i(
      'Microsoft Graph request started: action=$action, method=$method',
      'OneDrive',
    );
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
      receiveTimeout: const Duration(seconds: 30),
    );
    final status = response.statusCode ?? 0;
    AppLogger.i(
      'Microsoft Graph request completed: action=$action, method=$method, '
          'status=$status, elapsedMs=${stopwatch.elapsedMilliseconds}, '
          'errorCode=${_graphErrorCode(response) ?? 'none'}, '
          'errorMessage=${_graphErrorMessage(response) ?? 'none'}',
      'OneDrive',
    );
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
    final id = value['id'];
    final name = value['name'];
    final eTag = value['eTag'] ?? value['@odata.etag'];
    final size = value['size'];
    if ((id != null && id is! String) ||
        name is! String ||
        eTag is! String ||
        size is! int) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'OneDrive 文件项目缺少有效的 id、name、eTag 或 size。',
      );
    }
    return OneDriveItem(
      id: id as String?,
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
    final graphCodes = _graphErrorCodes(response);
    throw CloudBackendException(
      kind,
      _graphFailureMessage(
        action,
        status,
        graphCodes,
        _graphErrorMessage(response),
      ),
      statusCode: status,
      retryAfter: _retryAfter(response.headers),
    );
  }

  static String _graphFailureMessage(
    String action,
    int status,
    List<String> codes,
    String? providerMessage,
  ) {
    if (codes.contains('itemDisabledDueToPendingProvisioning')) {
      return 'Microsoft 正在为此账号开通 OneDrive 应用目录，目前尚未完成，请稍后重试。';
    }
    if (codes.contains('serviceReadOnly')) {
      return 'Microsoft OneDrive 当前处于只读状态，暂时无法建立同步连接，请稍后重试。';
    }
    if (codes.contains('serviceNotAvailable')) {
      return 'Microsoft OneDrive 应用目录服务暂时不可用，请稍后重试。';
    }
    final providerDetail = [
      if (codes.isNotEmpty) codes.join('/'),
      if (providerMessage != null) providerMessage,
    ].join(': ');
    return providerDetail.isEmpty
        ? '$action失败（HTTP $status）。'
        : '$action失败（HTTP $status，Microsoft: $providerDetail）。';
  }

  static String? _graphErrorCode(Response<Uint8List> response) {
    final codes = _graphErrorCodes(response);
    return codes.isEmpty ? null : codes.join('/');
  }

  static String? _graphErrorMessage(Response<Uint8List> response) {
    try {
      final decoded = jsonDecode(BackendHttp.rawTextOf(response));
      if (decoded is! Map || decoded['error'] is! Map) return null;
      final message = (decoded['error'] as Map)['message'];
      if (message is! String) return null;
      final sanitized = message
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ')
          .trim();
      if (sanitized.isEmpty) return null;
      return sanitized.length <= 300
          ? sanitized
          : '${sanitized.substring(0, 300)}…';
    } on FormatException {
      return null;
    }
  }

  static List<String> _graphErrorCodes(Response<Uint8List> response) {
    try {
      final decoded = jsonDecode(BackendHttp.rawTextOf(response));
      if (decoded is! Map) return const [];
      final codes = <String>[];
      Object? current = decoded['error'];
      for (var depth = 0; depth < 4 && current is Map; depth++) {
        final code = current['code'];
        if (code is String &&
            code.isNotEmpty &&
            code.length <= 80 &&
            RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(code)) {
          codes.add(code);
        }
        current = current['innerError'];
      }
      return codes;
    } on FormatException {
      return const [];
    }
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
