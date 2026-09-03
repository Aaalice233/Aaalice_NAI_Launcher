import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../../data/models/tag/local_tag.dart';
import '../database/datasources/danbooru_tag_data_source.dart';
import '../database/datasources/translation_data_source.dart';
import '../database/services/service_providers.dart';
import '../network/network_failure_diagnostics.dart';
import '../utils/app_logger.dart';
import 'danbooru_tags_meta_repository.dart';
import 'danbooru_tags_protocol.dart';
import 'danbooru_tags_query_service.dart';
import 'danbooru_tags_refresh_service.dart';
import 'lazy_data_source_service.dart';

part 'danbooru_tags_lazy_service.g.dart';

/// Stable facade for Danbooru tag storage, queries, metadata, and refreshes.
class DanbooruTagsLazyService implements LazyDataSourceService<LocalTag> {
  DanbooruTagsLazyService({
    required DanbooruTagDataSource dataSource,
    required Dio dio,
    TranslationDataSource? translationDataSource,
    DanbooruTagsMetaRepository? metaRepository,
  }) : _tagDataSource = dataSource,
       _state = DanbooruTagsState(),
       _metaRepository = metaRepository ?? DanbooruTagsMetaRepository() {
    _queryService = DanbooruTagsQueryService(
      tagDataSource: dataSource,
      translationDataSource: translationDataSource,
    );
    _refreshService = DanbooruTagsRefreshService(
      dio: dio,
      tagDataSource: dataSource,
      state: _state,
    );
  }

  final DanbooruTagDataSource _tagDataSource;
  final DanbooruTagsState _state;
  final DanbooruTagsMetaRepository _metaRepository;
  late final DanbooruTagsQueryService _queryService;
  late final DanbooruTagsRefreshService _refreshService;
  Future<void>? _metaLoadFuture;

  @override
  String get serviceName => 'danbooru_tags';

  @override
  Set<String> get hotKeys => danbooruHotKeys;

  @override
  bool get isInitialized => _state.isInitialized;

  @override
  bool get isRefreshing => _state.isRefreshing;

  @override
  DataSourceProgressCallback? get onProgress => _state.onProgress;

  @override
  set onProgress(DataSourceProgressCallback? callback) {
    _state.onProgress = callback;
  }

  DateTime? get lastUpdate => _state.lastUpdate;
  int get currentThreshold => generalThreshold;
  int get generalThreshold => _state.thresholds.general;
  int get artistThreshold => _state.thresholds.artist;
  int get characterThreshold => _state.thresholds.character;
  int get copyrightThreshold => _state.thresholds.copyright;
  int get metaThreshold => _state.thresholds.meta;
  AutoRefreshInterval get refreshInterval => _state.refreshInterval;

  @override
  Future<void> initialize() async {
    if (_state.isInitialized) return;
    try {
      _state.onProgress?.call(0, '初始化标签数据...');
      await _tagDataSource.initialize();
      await _loadMeta();
      await _queryService.loadHotData();
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

  @override
  Future<LocalTag?> get(String key) => _queryService.get(key);

  Future<List<LocalTag>> search(
    String query, {
    int? category,
    int limit = 20,
  }) => _queryService.search(query, category: category, limit: limit);

  Future<List<LocalTag>> searchTags(
    String query, {
    int? category,
    int limit = 20,
  }) => search(query, category: category, limit: limit);

  Future<List<LocalTag>> getHotTags({
    int? category,
    int minCount = 1000,
    int limit = 100,
  }) => _queryService.getHotTags(
    category: category,
    minCount: minCount,
    limit: limit,
  );

  @override
  Future<List<LocalTag>> getMultiple(List<String> keys) async {
    final values = await Future.wait(keys.map(get));
    return values.whereType<LocalTag>().toList();
  }

  @override
  Future<bool> shouldRefresh() async {
    if (await _tagDataSource.getCount() == 0) return true;
    final requiredCategories = await Future.wait([
      _tagDataSource.getCount(category: 0),
      _tagDataSource.getCount(category: 4),
      _tagDataSource.getCount(category: 3),
      _tagDataSource.getCount(category: 5),
    ]);
    if (requiredCategories.any((count) => count == 0)) return true;
    if (_state.lastUpdate == null) await _loadMeta();
    return _state.refreshInterval.shouldRefresh(_state.lastUpdate);
  }

  @override
  Future<void> refresh() async {
    if (_state.isRefreshing) return;
    _state.isRefreshing = true;
    _state.onProgress?.call(0, '开始同步标签...');
    try {
      final count = await _refreshService.refreshAll();
      await _queryService.loadHotData();
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

  @override
  Future<void> clearCache() async {
    cancelRefresh();
    _queryService.clear();
    _state
      ..isInitialized = false
      ..lastUpdate = null
      ..thresholds = const DanbooruCategoryThresholds()
      ..refreshInterval = AutoRefreshInterval.days30;
    await _metaRepository.clear();
  }

  TagHotPreset getHotPreset() => TagHotPreset.fromThreshold(generalThreshold);

  Future<void> setHotPreset(TagHotPreset preset, {int? customThreshold}) async {
    _state.thresholds = _state.thresholds.copyWith(
      general: customThreshold ?? preset.threshold,
    );
    await _metaRepository.saveThresholds(_state.thresholds);
  }

  AutoRefreshInterval getRefreshInterval() => _state.refreshInterval;

  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    _state.refreshInterval = interval;
    await _metaRepository.saveRefreshInterval(interval);
  }

  Future<void> initializeLightweight() async {
    if (_state.isInitialized) return;
    try {
      await _tagDataSource.getCount();
    } finally {
      _state.isInitialized = true;
    }
  }

  Future<void> preloadHotDataInBackground() async {
    try {
      await _queryService.loadHotData();
    } catch (error) {
      AppLogger.w(
        'Danbooru tags hot data preload failed: $error',
        'DanbooruTagsLazy',
      );
    }
  }

  Future<bool> shouldRefreshInBackground() async {
    if (_state.lastUpdate == null) await _loadMeta();
    return _state.refreshInterval.shouldRefresh(_state.lastUpdate);
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

  set onBackgroundProgress(DataSourceProgressCallback? callback) {
    _state.onProgress = callback;
  }

  void cancelBackgroundOperation() => cancelRefresh();

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

  Future<void> saveMetaAfterFetch() async {
    await _metaRepository.save(_state, await _tagDataSource.getCount());
  }
}

@Riverpod(keepAlive: true)
Future<DanbooruTagsLazyService> danbooruTagsLazyService(Ref ref) async {
  final tagDataSource = await ref.read(danbooruTagDataSourceProvider.future);
  final translationDataSource = await ref.read(
    translationDataSourceProvider.future,
  );
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  addNetworkFailureDiagnostics(dio, scope: 'Danbooru tag refresh');
  ref.onDispose(dio.close);
  final service = DanbooruTagsLazyService(
    dataSource: tagDataSource,
    dio: dio,
    translationDataSource: translationDataSource,
  );
  await service.initialize();
  return service;
}
