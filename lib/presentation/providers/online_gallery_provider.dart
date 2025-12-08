import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/models/online_gallery/danbooru_post.dart';
import '../../data/services/danbooru_auth_service.dart';

part 'online_gallery_provider.g.dart';

/// 画廊视图模式
enum GalleryViewMode {
  search, // 搜索模式
  popular, // 排行榜模式
  favorites, // 收藏夹模式
}

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

  /// 视图模式
  final GalleryViewMode viewMode;

  /// 排行榜时间范围
  final PopularScale popularScale;

  /// 排行榜日期
  final DateTime? popularDate;

  /// 已收藏的帖子 ID 集合（用于快速查找）
  final Set<int> favoritedPostIds;

  const OnlineGalleryState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.source = 'danbooru',
    this.rating = 'all',
    this.page = 1,
    this.hasMore = true,
    this.viewMode = GalleryViewMode.search,
    this.popularScale = PopularScale.day,
    this.popularDate,
    this.favoritedPostIds = const {},
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
    GalleryViewMode? viewMode,
    PopularScale? popularScale,
    DateTime? popularDate,
    Set<int>? favoritedPostIds,
    bool clearError = false,
    bool clearPopularDate = false,
  }) {
    return OnlineGalleryState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      source: source ?? this.source,
      rating: rating ?? this.rating,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      viewMode: viewMode ?? this.viewMode,
      popularScale: popularScale ?? this.popularScale,
      popularDate: clearPopularDate ? null : (popularDate ?? this.popularDate),
      favoritedPostIds: favoritedPostIds ?? this.favoritedPostIds,
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
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // 配置 HTTP 客户端以支持系统代理和处理证书问题
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.findProxy = HttpClient.findProxyFromEnvironment;
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };

    return const OnlineGalleryState();
  }

  /// 获取 API 服务
  DanbooruApiService get _apiService => ref.read(danbooruApiServiceProvider);

  /// 获取认证状态
  DanbooruAuthState get _authState => ref.read(danbooruAuthProvider);

  // ==================== 视图模式切换 ====================

  /// 切换到搜索模式
  Future<void> switchToSearch() async {
    if (state.viewMode == GalleryViewMode.search) return;
    state =
        state.copyWith(viewMode: GalleryViewMode.search, posts: [], page: 1);
    await loadPosts(refresh: true);
  }

  /// 切换到排行榜模式
  Future<void> switchToPopular() async {
    if (state.viewMode == GalleryViewMode.popular) return;
    state =
        state.copyWith(viewMode: GalleryViewMode.popular, posts: [], page: 1);
    await _loadPopularPosts(refresh: true);
  }

  /// 切换到收藏夹模式
  Future<void> switchToFavorites() async {
    if (!_authState.isLoggedIn) {
      state = state.copyWith(error: '请先登录 Danbooru 账号');
      return;
    }
    if (state.viewMode == GalleryViewMode.favorites) return;
    state =
        state.copyWith(viewMode: GalleryViewMode.favorites, posts: [], page: 1);
    await _loadFavorites(refresh: true);
  }

  // ==================== 排行榜功能 ====================

  /// 设置排行榜时间范围
  Future<void> setPopularScale(PopularScale scale) async {
    if (state.popularScale == scale) return;
    state = state.copyWith(popularScale: scale);
    if (state.viewMode == GalleryViewMode.popular) {
      await _loadPopularPosts(refresh: true);
    }
  }

  /// 设置排行榜日期
  Future<void> setPopularDate(DateTime? date) async {
    state = state.copyWith(
      popularDate: date,
      clearPopularDate: date == null,
    );
    if (state.viewMode == GalleryViewMode.popular) {
      await _loadPopularPosts(refresh: true);
    }
  }

  /// 加载排行榜帖子
  Future<void> _loadPopularPosts({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.page;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      page: page,
      posts: refresh ? [] : state.posts,
    );

    try {
      String? dateStr;
      if (state.popularDate != null) {
        dateStr =
            '${state.popularDate!.year}-${state.popularDate!.month.toString().padLeft(2, '0')}-${state.popularDate!.day.toString().padLeft(2, '0')}';
      }

      final posts = await _apiService.getPopularPosts(
        scale: state.popularScale,
        date: dateStr,
        page: page,
      );

      // 过滤评级
      final filteredPosts = _filterByRating(posts);

      state = state.copyWith(
        posts: refresh ? filteredPosts : [...state.posts, ...filteredPosts],
        isLoading: false,
        hasMore: posts.length >= 20, // 排行榜每页较少
        page: page,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load popular posts: $e',
        e,
        stack,
        'OnlineGallery',
      );
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // ==================== 收藏夹功能 ====================

  /// 加载收藏夹
  Future<void> _loadFavorites({bool refresh = false}) async {
    if (state.isLoading) return;

    final authState = _authState;
    if (!authState.isLoggedIn || authState.user == null) {
      state = state.copyWith(error: '请先登录 Danbooru 账号');
      return;
    }

    final page = refresh ? 1 : state.page;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      page: page,
      posts: refresh ? [] : state.posts,
    );

    try {
      final posts = await _apiService.getFavorites(
        userId: authState.user!.id,
        page: page,
        limit: _pageSize,
      );

      // 更新收藏状态
      final favoritedIds = {...state.favoritedPostIds};
      for (final post in posts) {
        favoritedIds.add(post.id);
      }

      state = state.copyWith(
        posts: refresh ? posts : [...state.posts, ...posts],
        isLoading: false,
        hasMore: posts.length >= _pageSize,
        page: page,
        favoritedPostIds: favoritedIds,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to load favorites: $e', e, stack, 'OnlineGallery');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 添加收藏
  Future<bool> addFavorite(int postId) async {
    if (!_authState.isLoggedIn) return false;

    final success = await _apiService.addFavorite(postId);
    if (success) {
      state = state.copyWith(
        favoritedPostIds: {...state.favoritedPostIds, postId},
      );
    }
    return success;
  }

  /// 移除收藏
  Future<bool> removeFavorite(int postId) async {
    if (!_authState.isLoggedIn) return false;

    final success = await _apiService.removeFavorite(postId);
    if (success) {
      final newIds = {...state.favoritedPostIds};
      newIds.remove(postId);
      state = state.copyWith(favoritedPostIds: newIds);

      // 如果在收藏夹视图中，从列表中移除
      if (state.viewMode == GalleryViewMode.favorites) {
        state = state.copyWith(
          posts: state.posts.where((p) => p.id != postId).toList(),
        );
      }
    }
    return success;
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(int postId) async {
    if (state.favoritedPostIds.contains(postId)) {
      return await removeFavorite(postId);
    } else {
      return await addFavorite(postId);
    }
  }

  /// 检查是否已收藏
  bool isFavorited(int postId) {
    return state.favoritedPostIds.contains(postId);
  }

  // ==================== 通用功能 ====================

  /// 加载帖子（根据当前模式）
  Future<void> loadPosts({bool refresh = false}) async {
    switch (state.viewMode) {
      case GalleryViewMode.search:
        await _loadSearchPosts(refresh: refresh);
        break;
      case GalleryViewMode.popular:
        await _loadPopularPosts(refresh: refresh);
        break;
      case GalleryViewMode.favorites:
        await _loadFavorites(refresh: refresh);
        break;
    }
  }

  /// 加载搜索帖子
  Future<void> _loadSearchPosts({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.page;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
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
    state = state.copyWith(
      searchQuery: query.trim(),
      viewMode: GalleryViewMode.search,
    );
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

  /// 根据评级过滤帖子
  List<DanbooruPost> _filterByRating(List<DanbooruPost> posts) {
    if (state.rating == 'all') return posts;
    return posts.where((p) => p.rating == state.rating).toList();
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

    AppLogger.d(
      'Fetching from $source: tags="$tags", page=$page',
      'OnlineGallery',
    );

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
