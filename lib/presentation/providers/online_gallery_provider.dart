import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/online_gallery/danbooru_post.dart';

part 'online_gallery_provider.g.dart';

/// 在线画廊状态
class OnlineGalleryState {
  final List<DanbooruPost> posts;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String source;
  final String rating;
  final int page;
  final bool hasMore;

  const OnlineGalleryState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.source = 'danbooru',
    this.rating = 'all',
    this.page = 1,
    this.hasMore = true,
  });

  OnlineGalleryState copyWith({
    List<DanbooruPost>? posts,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? source,
    String? rating,
    int? page,
    bool? hasMore,
  }) {
    return OnlineGalleryState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      source: source ?? this.source,
      rating: rating ?? this.rating,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// 在线画廊 Notifier
@riverpod
class OnlineGalleryNotifier extends _$OnlineGalleryNotifier {
  late Dio _dio;
  static const int _pageSize = 40;

  @override
  OnlineGalleryState build() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // 配置 HTTP 客户端以支持系统代理和处理证书问题
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      // 使用系统代理
      client.findProxy = HttpClient.findProxyFromEnvironment;
      // 允许自签名证书（用于调试，生产环境应移除）
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };

    return const OnlineGalleryState();
  }

  /// 加载帖子
  Future<void> loadPosts({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.page;

    state = state.copyWith(
      isLoading: true,
      error: null,
      page: page,
      posts: refresh ? [] : state.posts,
    );

    try {
      final posts = await _fetchPosts(
        source: state.source,
        query: state.searchQuery,
        rating: state.rating,
        page: page,
      );

      state = state.copyWith(
        posts: refresh ? posts : [...state.posts, ...posts],
        isLoading: false,
        hasMore: posts.length >= _pageSize,
        page: page,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to load posts: $e', e, stack, 'OnlineGallery');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(page: state.page + 1);
    await loadPosts();
  }

  /// 刷新
  Future<void> refresh() async {
    await loadPosts(refresh: true);
  }

  /// 搜索
  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query.trim());
    await loadPosts(refresh: true);
  }

  /// 设置数据源
  Future<void> setSource(String source) async {
    if (state.source == source) return;
    state = state.copyWith(source: source);
    await loadPosts(refresh: true);
  }

  /// 设置评级筛选
  Future<void> setRating(String rating) async {
    if (state.rating == rating) return;
    state = state.copyWith(rating: rating);
    await loadPosts(refresh: true);
  }

  /// 从 API 获取帖子
  Future<List<DanbooruPost>> _fetchPosts({
    required String source,
    required String query,
    required String rating,
    required int page,
  }) async {
    final baseUrl = _getBaseUrl(source);
    final endpoint = _getEndpoint(source);

    // 构建标签查询
    String tags = query;
    if (rating != 'all') {
      tags = tags.isEmpty ? 'rating:$rating' : '$tags rating:$rating';
    }

    AppLogger.d('Fetching from $source: tags="$tags", page=$page', 'OnlineGallery');

    final response = await _dio.get(
      '$baseUrl$endpoint',
      queryParameters: {
        'tags': tags,
        'page': page,
        'limit': _pageSize,
      },
      options: Options(
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'NAI-Launcher/1.0',
        },
      ),
    );

    if (response.data is List) {
      final posts = (response.data as List)
          .map((item) => _parsePost(source, item as Map<String, dynamic>))
          .where((post) => post.previewUrl.isNotEmpty)
          .toList();

      AppLogger.d('Fetched ${posts.length} posts', 'OnlineGallery');
      return posts;
    }

    return [];
  }

  /// 获取基础 URL
  String _getBaseUrl(String source) {
    switch (source) {
      case 'danbooru':
        return 'https://danbooru.donmai.us';
      case 'safebooru':
        return 'https://safebooru.donmai.us';
      case 'gelbooru':
        return 'https://gelbooru.com';
      default:
        return 'https://danbooru.donmai.us';
    }
  }

  /// 获取 API 端点
  String _getEndpoint(String source) {
    switch (source) {
      case 'gelbooru':
        return '/index.php?page=dapi&s=post&q=index&json=1';
      default:
        return '/posts.json';
    }
  }

  /// 解析帖子数据
  DanbooruPost _parsePost(String source, Map<String, dynamic> json) {
    if (source == 'gelbooru') {
      return _parseGelbooruPost(json);
    }
    return DanbooruPost.fromJson(json);
  }

  /// 解析 Gelbooru 帖子
  DanbooruPost _parseGelbooruPost(Map<String, dynamic> json) {
    return DanbooruPost(
      id: json['id'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      source: json['source'] as String? ?? '',
      md5: json['md5'] as String? ?? '',
      rating: json['rating'] as String? ?? 'g',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      tagString: json['tags'] as String? ?? '',
      fileExt: json['image']?.toString().split('.').last ?? 'jpg',
      fileUrl: json['file_url'] as String?,
      previewFileUrl: json['preview_url'] as String?,
      largeFileUrl: json['sample_url'] as String?,
    );
  }
}
