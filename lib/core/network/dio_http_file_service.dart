import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Dio HTTP 文件服务
///
/// 桥接 `flutter_cache_manager` 和 `Dio`，使图片缓存能够复用 Dio 的 HTTP/2 连接池。
/// 这解决了 `CachedNetworkImage` 默认使用系统 HttpClient 时的并发限制问题。
class DioHttpFileService extends FileService {
  final Dio _dio;

  DioHttpFileService(this._dio);

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers,}) async {
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      return DioFileServiceResponse(response.data!);
    } on DioException catch (e) {
      throw NetworkException('Dio request failed: ${e.message}', e);
    } catch (e, stack) {
      throw NetworkException('Failed to download file: $url', e, stack);
    }
  }
}

/// Dio 文件服务响应
///
/// 将 Dio 的 `ResponseBody` 转换为 `flutter_cache_manager` 所需的 `FileServiceResponse`。
class DioFileServiceResponse implements FileServiceResponse {
  final ResponseBody _response;

  DioFileServiceResponse(this._response);

  @override
  int get statusCode => _response.statusCode;

  @override
  String get fileExtension {
    final contentType =
        _response.headers['content-type']?.first ?? 'image/jpeg';
    final extension = contentType.split('/').last;
    switch (extension.toLowerCase()) {
      case 'jpeg':
        return 'jpg';
      case 'x-icon':
        return 'ico';
      default:
        return extension;
    }
  }

  @override
  Stream<List<int>> get content => _response.stream;

  @override
  int get contentLength => _response.contentLength;

  Map<String, String> get headers {
    final headers = <String, String>{};
    _response.headers.forEach((key, values) {
      if (values.isNotEmpty) {
        headers[key] = values.first;
      }
    });
    return headers;
  }

  bool get hasError => statusCode >= 400;

  @override
  String? get eTag => headers['etag'];

  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 7));

  void dispose() {
    // Dio 管理自己的资源，无需手动关闭
  }
}

/// 网络异常
class NetworkException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  NetworkException(this.message, [this.originalError, this.stackTrace]);

  @override
  String toString() => message;
}
