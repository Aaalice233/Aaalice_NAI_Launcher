import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'cloud_sync_backend.dart';

class BackendHttp {
  BackendHttp({Dio? dio}) : dio = dio ?? Dio();

  final Dio dio;

  Future<Response<Uint8List>> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? data,
    CancelToken? cancelToken,
    int maxResponseBytes = 1024 * 1024,
    CloudBackendErrorKind tooLargeKind = CloudBackendErrorKind.invalidResponse,
  }) async {
    return _request(
      method,
      uri,
      headers: headers,
      data: data is List<int> && data is! Uint8List
          ? Uint8List.fromList(data)
          : data,
      cancelToken: cancelToken,
      maxResponseBytes: maxResponseBytes,
      tooLargeKind: tooLargeKind,
      redirectsRemaining: 5,
    );
  }

  Future<Response<Uint8List>> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? data,
    CancelToken? cancelToken,
    required int maxResponseBytes,
    required CloudBackendErrorKind tooLargeKind,
    required int redirectsRemaining,
  }) async {
    try {
      final streamed = await dio.request<ResponseBody>(
        uri.toString(),
        data: data,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final response = await _bufferResponse(
        streamed,
        maxResponseBytes: maxResponseBytes,
        tooLargeKind: tooLargeKind,
      );
      final status = response.statusCode ?? 0;
      if ({301, 302, 303, 307, 308}.contains(status)) {
        final location = response.headers.value('location');
        if (location == null || redirectsRemaining == 0) {
          throw CloudBackendException(
            CloudBackendErrorKind.redirectRejected,
            '服务器返回了无效或过多的重定向。',
            statusCode: status,
          );
        }
        final target = uri.resolve(location);
        if (!_sameOrigin(uri, target)) {
          throw CloudBackendException(
            CloudBackendErrorKind.redirectRejected,
            '服务器尝试重定向到其他主机；请求已拦截，认证信息未发送。',
            statusCode: status,
          );
        }
        final becomesGet =
            status == 303 ||
            ((status == 301 || status == 302) && method == 'POST');
        return _request(
          becomesGet ? 'GET' : method,
          target,
          headers: headers,
          data: becomesGet ? null : data,
          cancelToken: cancelToken,
          maxResponseBytes: maxResponseBytes,
          tooLargeKind: tooLargeKind,
          redirectsRemaining: redirectsRemaining - 1,
        );
      }
      return response;
    } on CloudBackendException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw CloudBackendException(
        CloudBackendErrorKind.network,
        '网络请求失败（${error.type.name}）。',
        cause: error,
      );
    }
  }

  Future<Response<Uint8List>> _bufferResponse(
    Response<ResponseBody> response, {
    required int maxResponseBytes,
    required CloudBackendErrorKind tooLargeKind,
  }) async {
    if (maxResponseBytes < 0) throw ArgumentError.value(maxResponseBytes);
    final declared = int.tryParse(
      response.headers.value('content-length') ?? '',
    );
    final status = response.statusCode ?? 0;
    final method = response.requestOptions.method.toUpperCase();
    final responseMustBeBodyless =
        method == 'HEAD' ||
        status == 204 ||
        status == 304 ||
        (status >= 100 && status < 200);
    if (responseMustBeBodyless) {
      final body = response.data;
      if (body != null) {
        final subscription = body.stream.listen((_) {});
        await subscription.cancel();
      }
      return _copyResponse(response, Uint8List(0));
    }
    if (declared != null && declared > maxResponseBytes) {
      throw CloudBackendException(
        tooLargeKind,
        '服务器响应超过允许的大小上限。',
        statusCode: response.statusCode,
      );
    }
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk
        in response.data?.stream ?? const Stream<Uint8List>.empty()) {
      received += chunk.length;
      if (received > maxResponseBytes) {
        throw CloudBackendException(
          tooLargeKind,
          '服务器响应超过允许的大小上限。',
          statusCode: response.statusCode,
        );
      }
      builder.add(chunk);
    }
    return _copyResponse(response, builder.takeBytes());
  }

  static Response<Uint8List> _copyResponse(
    Response<ResponseBody> response,
    Uint8List bytes,
  ) {
    return Response<Uint8List>(
      data: bytes,
      headers: response.headers,
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      redirects: response.redirects,
      extra: response.extra,
      isRedirect: response.isRedirect,
    );
  }

  static Uint8List bytesOf(Response<Uint8List> response) =>
      response.data ?? Uint8List(0);

  static String textOf(Response<Uint8List> response, {int max = 512}) {
    final text = rawTextOf(response).trim();
    final withoutHtml = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final normalized = withoutHtml.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= max ? normalized : normalized.substring(0, max);
  }

  static String rawTextOf(Response<Uint8List> response) =>
      utf8.decode(bytesOf(response), allowMalformed: true);

  static bool _sameOrigin(Uri first, Uri second) =>
      first.scheme.toLowerCase() == second.scheme.toLowerCase() &&
      first.host.toLowerCase() == second.host.toLowerCase() &&
      first.port == second.port;
}
