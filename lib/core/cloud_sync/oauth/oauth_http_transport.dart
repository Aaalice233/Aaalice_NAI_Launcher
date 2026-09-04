import 'package:dio/dio.dart';

final class OAuthHttpException implements Exception {
  const OAuthHttpException({
    required this.statusCode,
    required this.error,
    this.description,
  });

  final int statusCode;
  final String error;
  final String? description;

  @override
  String toString() => 'OAuthHttpException($statusCode, $error)';
}

abstract interface class OAuthHttpTransport {
  Future<Map<String, dynamic>> postForm(
    Uri uri,
    Map<String, String> fields, {
    Map<String, String> headers = const {},
  });

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  });

  Future<void> postFormNoContent(Uri uri, Map<String, String> fields);
}

final class DioOAuthHttpTransport implements OAuthHttpTransport {
  DioOAuthHttpTransport({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> postForm(
    Uri uri,
    Map<String, String> fields, {
    Map<String, String> headers = const {},
  }) async {
    final response = await _dio.post<Object?>(
      uri.toString(),
      data: fields,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: headers,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final body = _requireJsonObject(response.data);
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw OAuthHttpException(
        statusCode: statusCode,
        error: body['error'] is String ? body['error'] as String : 'http_error',
        description: body['error_description'] is String
            ? body['error_description'] as String
            : null,
      );
    }
    return body;
  }

  @override
  Future<void> postFormNoContent(Uri uri, Map<String, String> fields) async {
    await _dio.post<void>(
      uri.toString(),
      data: fields,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
  }

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final response = await _dio.get<Object?>(
      uri.toString(),
      options: Options(headers: headers, responseType: ResponseType.json),
    );
    return _requireJsonObject(response.data);
  }

  Map<String, dynamic> _requireJsonObject(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw const FormatException('OAuth endpoint did not return a JSON object');
  }
}
