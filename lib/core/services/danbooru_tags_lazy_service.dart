import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../database/datasources/danbooru_tag_data_source.dart';
import '../database/services/service_providers.dart';
import '../network/network_failure_diagnostics.dart';
import '../utils/app_logger.dart';
import 'danbooru_tags_meta_repository.dart';
import 'danbooru_tags_protocol.dart';
import 'danbooru_tags_refresh_service.dart';

part 'danbooru_tags_lazy_service.g.dart';

/// Coordinates Danbooru tag metadata and refresh operations.
class DanbooruTagsLazyService {
  DanbooruTagsLazyService({
    required DanbooruTagDataSource dataSource,
    required Dio dio,
    DanbooruTagsMetaRepository? metaRepository,
  }) : _tagDataSource = dataSource,
       _state = DanbooruTagsState(),
       _metaRepository = metaRepository ?? DanbooruTagsMetaRepository() {
    _refreshService = DanbooruTagsRefreshService(
      dio: dio,
      tagDataSource: dataSource,
      state: _state,
    );
  }

  final DanbooruTagDataSource _tagDataSource;
  final DanbooruTagsState _state;
  final DanbooruTagsMetaRepository _metaRepository;
  late final DanbooruTagsRefreshService _refreshService;
  Future<void>? _metaLoadFuture;

  DataSourceProgressCallback? get onProgress => _state.onProgress;

  set onProgress(DataSourceProgressCallback? callback) {
    _state.onProgress = callback;
  }

  DateTime? get lastUpdate => _state.lastUpdate;
  int get generalThreshold => _state.thresholds.general;
  int get artistThreshold => _state.thresholds.artist;
  int get characterThreshold => _state.thresholds.character;
  int get copyrightThreshold => _state.thresholds.copyright;
  int get metaThreshold => _state.thresholds.meta;
  AutoRefreshInterval get refreshInterval => _state.refreshInterval;

  Future<void> initialize() async {
    if (_state.isInitialized) return;
    try {
      _state.onProgress?.call(0, '初始化标签数据...');
      await _tagDataSource.initialize();
      await _loadMeta();
      _state.onProgress?.call(1, '标签数据初始化完成');
    } catch (error, stack) {
      AppLogger.e(
        'Failed to initialize Danbooru tags lazy service',
        error,
        stack,
        'DanbooruTagsLazy',
      );
    } finally {
      _state.isInitialized = true;
    }
  }

  Future<void> setCategoryThresholds({
    required int generalThreshold,
    required int artistThreshold,
    required int characterThreshold,
    int? copyrightThreshold,
    int? metaThreshold,
  }) async {
    _state.thresholds = _state.thresholds.copyWith(
      general: generalThreshold,
      artist: artistThreshold,
      character: characterThreshold,
      copyright: copyrightThreshold,
      meta: metaThreshold,
    );
    await _metaRepository.saveThresholds(_state.thresholds);
  }

  Future<void> refresh() async {
    if (_state.isRefreshing) return;
    _state.isRefreshing = true;
    _state.onProgress?.call(0, '开始同步标签...');
    try {
      final count = await _refreshService.refreshAll();
      await _metaRepository.save(_state, count);
      _state.onProgress?.call(1, '完成');
    } catch (error, stack) {
      AppLogger.e(
        'Failed to refresh Danbooru tags',
        error,
        stack,
        'DanbooruTagsLazy',
      );
      _state.onProgress?.call(1, '刷新失败: $error');
      rethrow;
    } finally {
      _state.isRefreshing = false;
    }
  }

  void cancelRefresh() => _refreshService.cancel();

  Future<void> fetchArtistTags({
    required void Function(int currentPage, int importedCount, String message)
    onProgress,
    int maxPages = danbooruTagsMaxPages,
  }) => _runRefresh(
    () => _refreshService.fetchArtist(
      threshold: artistThreshold,
      maxPages: maxPages,
      onProgress: onProgress,
    ),
  );

  Future<void> fetchGeneralTags({
    required int threshold,
    required int maxPages,
  }) => _fetchCategory(0, threshold, maxPages, '一般标签');

  Future<void> fetchCharacterTags({
    required int threshold,
    required int maxPages,
  }) => _fetchCategory(4, threshold, maxPages, '角色标签');

  Future<void> fetchCopyrightTags({
    required int threshold,
    required int maxPages,
  }) => _fetchCategory(3, threshold, maxPages, '版权标签');

  Future<void> fetchMetaTags({required int threshold, required int maxPages}) =>
      _fetchCategory(5, threshold, maxPages, '元标签');

  Future<void> _fetchCategory(
    int category,
    int threshold,
    int maxPages,
    String label,
  ) => _runRefresh(() async {
    await _refreshService.fetchCategory(
      category: category,
      threshold: threshold,
      maxPages: maxPages,
      label: label,
    );
  });

  Future<void> _runRefresh(Future<void> Function() operation) async {
    if (_state.isRefreshing) return;
    _state.isRefreshing = true;
    try {
      await operation();
    } on DanbooruRefreshCancelledException {
      AppLogger.i('Danbooru tag refresh cancelled', 'DanbooruTagsLazy');
    } finally {
      _state.isRefreshing = false;
    }
  }

  Future<void> clearCache() async {
    cancelRefresh();
    _state
      ..isInitialized = false
      ..lastUpdate = null
      ..thresholds = const DanbooruCategoryThresholds()
      ..refreshInterval = AutoRefreshInterval.days30;
    await _metaRepository.clear();
  }

  Future<void> setHotPreset(TagHotPreset preset, {int? customThreshold}) async {
    _state.thresholds = _state.thresholds.copyWith(
      general: customThreshold ?? preset.threshold,
    );
    await _metaRepository.saveThresholds(_state.thresholds);
  }

  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    _state.refreshInterval = interval;
    await _metaRepository.saveRefreshInterval(interval);
  }

  Future<void> _loadMeta() {
    final activeLoad = _metaLoadFuture;
    if (activeLoad != null) return activeLoad;

    final load = _loadMetaOnce();
    _metaLoadFuture = load;
    return load;
  }

  Future<void> _loadMetaOnce() async {
    try {
      await _metaRepository.loadInto(_state);
    } finally {
      _metaLoadFuture = null;
    }
  }

  Future<int> getTagCount() => _tagDataSource.getCount();

  Future<int> getTagCountByCategory(int category) =>
      _tagDataSource.getCount(category: category);

  Future<Map<String, int>> getCategoryStats() async => {
    'total': await _tagDataSource.getCount(),
    'artist': await _tagDataSource.getCount(category: 1),
    'general': await _tagDataSource.getCount(category: 0),
    'copyright': await _tagDataSource.getCount(category: 3),
    'character': await _tagDataSource.getCount(category: 4),
    'meta': await _tagDataSource.getCount(category: 5),
  };
}

@Riverpod(keepAlive: true)
Future<DanbooruTagsLazyService> danbooruTagsLazyService(Ref ref) async {
  final tagDataSource = await ref.read(danbooruTagDataSourceProvider.future);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  addNetworkFailureDiagnostics(dio, scope: 'Danbooru tag refresh');
  ref.onDispose(dio.close);
  final service = DanbooruTagsLazyService(dataSource: tagDataSource, dio: dio);
  await service.initialize();
  return service;
}
