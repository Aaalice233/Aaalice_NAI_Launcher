import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/online_gallery/danbooru_post.dart';
import '../../models/online_gallery/gelbooru_credentials.dart';
import '../../models/online_gallery/gelbooru_post_parser.dart';

part 'gelbooru_api_service.g.dart';

enum GelbooruApiErrorType {
  invalidCredentials,
  rateLimited,
  timeout,
  server,
  network,
  cancelled,
  malformedResponse,
  unknown,
}

class GelbooruApiException implements Exception {
  final GelbooruApiErrorType type;
  final int? statusCode;

  const GelbooruApiException(this.type, {this.statusCode});

  @override
  String toString() {
    return 'GelbooruApiException(type: ${type.name}, statusCode: $statusCode)';
  }
}

class GelbooruPostPage {
  final List<DanbooruPost> posts;
  final int rawCount;

  const GelbooruPostPage({required this.posts, required this.rawCount});
}

class GelbooruApiService {
  static const String endpoint = 'https://gelbooru.com/index.php';

  final Dio _dio;

  GelbooruApiService(this._dio);

  Future<void> verifyCredentials(GelbooruCredentials credentials) async {
    await _requestPosts(credentials: credentials, tags: '', pid: 0, limit: 1);
  }

  Future<GelbooruPostPage> searchPosts({
    required GelbooruCredentials credentials,
    required String tags,
    required int pid,
    int limit = 40,
    CancelToken? cancelToken,
  }) {
    return _requestPosts(
      credentials: credentials,
      tags: tags,
      pid: pid,
      limit: limit,
      cancelToken: cancelToken,
    );
  }

  Future<GelbooruPostPage> getFavorites({
    required GelbooruCredentials credentials,
    required int pid,
    int limit = 40,
    CancelToken? cancelToken,
  }) {
    return _requestPosts(
      credentials: credentials,
      tags: 'fav:${credentials.userId} sort:id:desc',
      pid: pid,
      limit: limit,
      cancelToken: cancelToken,
    );
  }

  Future<GelbooruPostPage> _requestPosts({
    required GelbooruCredentials credentials,
    required String tags,
    required int pid,
    required int limit,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        endpoint,
        queryParameters: {
          'page': 'dapi',
          's': 'post',
          'q': 'index',
          'json': 1,
          'tags': tags,
          'limit': limit,
          'pid': pid,
          'user_id': credentials.userId,
          'api_key': credentials.apiKey,
        },
        options: Options(
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'NAI-Launcher/1.0',
          },
        ),
        cancelToken: cancelToken,
      );

      final data = _decodeResponse(response.data);
      if (!_isPostResponse(data)) {
        throw const GelbooruApiException(
          GelbooruApiErrorType.malformedResponse,
        );
      }
      final rawList = extractPostListFromResponse(data, 'gelbooru');
      return GelbooruPostPage(
        posts: parseGelbooruPostList(rawList),
        rawCount: rawList.length,
      );
    } on GelbooruApiException {
      rethrow;
    } on DioException catch (error) {
      throw _safeException(error);
    } on FormatException {
      throw const GelbooruApiException(GelbooruApiErrorType.malformedResponse);
    } catch (_) {
      throw const GelbooruApiException(GelbooruApiErrorType.unknown);
    }
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is String) {
      if (data.trim().isEmpty) {
        throw const FormatException('Empty Gelbooru response');
      }
      return jsonDecode(data);
    }
    return data;
  }

  bool _isPostResponse(dynamic data) {
    if (data is List) return true;
    if (data is! Map) return false;
    return data.containsKey('post') ||
        data.containsKey('posts') ||
        data.containsKey('@attributes');
  }

  GelbooruApiException _safeException(DioException error) {
    final statusCode = error.response?.statusCode;
    if (error.type == DioExceptionType.cancel) {
      return GelbooruApiException(
        GelbooruApiErrorType.cancelled,
        statusCode: statusCode,
      );
    }
    if (statusCode == 401 || statusCode == 403) {
      return GelbooruApiException(
        GelbooruApiErrorType.invalidCredentials,
        statusCode: statusCode,
      );
    }
    if (statusCode == 429) {
      return GelbooruApiException(
        GelbooruApiErrorType.rateLimited,
        statusCode: statusCode,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return GelbooruApiException(
        GelbooruApiErrorType.server,
        statusCode: statusCode,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return GelbooruApiException(
          GelbooruApiErrorType.timeout,
          statusCode: statusCode,
        );
      case DioExceptionType.connectionError:
        return GelbooruApiException(
          GelbooruApiErrorType.network,
          statusCode: statusCode,
        );
      default:
        return GelbooruApiException(
          GelbooruApiErrorType.unknown,
          statusCode: statusCode,
        );
    }
  }
}

@Riverpod(keepAlive: true)
GelbooruApiService gelbooruApiService(Ref ref) {
  return GelbooruApiService(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
      ),
    ),
  );
}
