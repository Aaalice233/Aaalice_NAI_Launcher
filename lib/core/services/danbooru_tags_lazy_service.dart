import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../../data/models/tag/local_tag.dart';
import '../constants/storage_keys.dart';
import '../database/datasources/danbooru_tag_data_source.dart';
import '../database/datasources/translation_data_source.dart';
import '../database/services/service_providers.dart';
import '../utils/app_logger.dart';
import '../utils/tag_normalizer.dart';
import 'lazy_data_source_service.dart';

part 'danbooru_tags_lazy_service.g.dart';

/// Danbooru 标签懒加载服务 V3
/// 
/// 架构改进：
/// - 同步初始化，要求在构造函数传入 DataSource
/// - 移除 late 字段，消除 LateInitializationError 风险
/// - Provider 使用 FutureProvider 确保服务完全初始化后才可用
/// 
/// 使用方式：
/// ```dart
/// final service = await ref.read(danbooruTagsLazyServiceProvider.future);
/// ```
class DanbooruTagsLazyService implements LazyDataSourceService<LocalTag> {
  static const String _baseUrl = 'https://danbooru.donmai.us';
  static const String _tagsEndpoint = '/tags.json';
  static const int _pageSize = 1000;
  static const int _maxPages = 200;
  static const int _concurrentRequests = 2;  // 降低并发数以减少429错误
  static const int _requestIntervalMs = 500; // 增加请求间隔到500ms
  static const String _cacheDirName = 'tag_cache';
  static const String _metaFileName = 'danbooru_tags_meta.json';

  final DanbooruTagDataSource _tagDataSource;
  final TranslationDataSource? _translationDataSource;
  final Dio _dio;

  final Map<String, LocalTag> _hotDataCache = {};
  bool _isInitialized = false;
  bool _isRefreshing = false;
  DataSourceProgressCallback? _onProgress;
  DateTime? _lastUpdate;
  // 五个类别的独立阈值配置
  int _generalThreshold = 1000;
  int _artistThreshold = 500;
  int _characterThreshold = 100;
  int _copyrightThreshold = 500;
  int _metaThreshold = 10000;
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;
  bool _isCancelled = false;

  @override
  DataSourceProgressCallback? get onProgress => _onProgress;

  /// 主构造函数 - 同步初始化
  ///
  /// [dataSource] 必须已初始化完成
  /// [translationDataSource] 可选，用于获取标签翻译
  DanbooruTagsLazyService({
    required DanbooruTagDataSource dataSource,
    required Dio dio,
    TranslationDataSource? translationDataSource,
  })  : _tagDataSource = dataSource,
        _translationDataSource = translationDataSource,
        _dio = dio;

  @override
  String get serviceName => 'danbooru_tags';

  @override
  Set<String> get hotKeys => const {
    '1girl', 'solo', '1boy', '2girls', 'multiple_girls',
    '2boys', 'multiple_boys', '3girls', '1other', '3boys',
    'long_hair', 'short_hair', 'blonde_hair', 'brown_hair', 'black_hair',
    'blue_eyes', 'red_eyes', 'green_eyes', 'brown_eyes', 'purple_eyes',
    'looking_at_viewer', 'smile', 'open_mouth', 'blush',
    'breasts', 'thighhighs', 'gloves', 'bow', 'ribbon',
  };

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isRefreshing => _isRefreshing;

  @override
  set onProgress(DataSourceProgressCallback? callback) {
    _onProgress = callback;
  }

  DateTime? get lastUpdate => _lastUpdate;
  int get currentThreshold => _generalThreshold; // 兼容旧API
  int get generalThreshold => _generalThreshold;
  int get artistThreshold => _artistThreshold;
  int get characterThreshold => _characterThreshold;
  int get copyrightThreshold => _copyrightThreshold;
  int get metaThreshold => _metaThreshold;
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  /// 设置五个类别的独立阈值
  Future<void> setCategoryThresholds({
    required int generalThreshold,
    required int artistThreshold,
    required int characterThreshold,
    int? copyrightThreshold,
    int? metaThreshold,
  }) async {
    _generalThreshold = generalThreshold;
    _artistThreshold = artistThreshold;
    _characterThreshold = characterThreshold;
    if (copyrightThreshold != null) _copyrightThreshold = copyrightThreshold;
    if (metaThreshold != null) _metaThreshold = metaThreshold;

    AppLogger.i(
      'Category thresholds updated: general=$_generalThreshold, '
      'artist=$_artistThreshold, character=$_characterThreshold, '
      'copyright=$_copyrightThreshold, meta=$_metaThreshold',
      'DanbooruTagsLazy',
    );

    // 保存到SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.danbooruGeneralThreshold, generalThreshold);
    await prefs.setInt(StorageKeys.danbooruArtistThreshold, artistThreshold);
    await prefs.setInt(StorageKeys.danbooruCharacterThreshold, characterThreshold);
    await prefs.setInt(StorageKeys.danbooruCopyrightThreshold, _copyrightThreshold);
    await prefs.setInt(StorageKeys.danbooruMetaThreshold, _metaThreshold);
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _onProgress?.call(0.0, '初始化标签数据...');

      // 确保数据库已初始化
      await _tagDataSource.initialize();
      _onProgress?.call(0.2, '数据库已就绪');

      // 检查数据库中实际有多少记录
      final tagCount = await _tagDataSource.getCount();
      AppLogger.i('Danbooru tag count in database: $tagCount', 'DanbooruTagsLazy');

      // 加载元数据
      await _loadMeta();

      // 如果数据库为空，记录需要下载，但不阻塞初始化
      if (tagCount == 0) {
        AppLogger.w('Database is empty, will download in warmup phase', 'DanbooruTagsLazy');
        _lastUpdate = null;
      }

      // 尝试加载热数据（如果数据库有数据）
      await _loadHotData();

      _onProgress?.call(1.0, '标签数据初始化完成');
      _isInitialized = true;

      AppLogger.i(
        'Danbooru tags lazy service initialized with ${_hotDataCache.length} hot tags',
        'DanbooruTagsLazy',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize Danbooru tags lazy service',
        e,
        stack,
        'DanbooruTagsLazy',
      );
      _isInitialized = true;
    }
  }

  Future<void> _loadHotData() async {
    _onProgress?.call(0.0, '加载热数据...');

    final records = await _tagDataSource.getByNames(hotKeys.toList());

    if (records.isEmpty) {
      _onProgress?.call(1.0, '热数据加载完成');
      AppLogger.i('No hot tags loaded from database', 'DanbooruTagsLazy');
      return;
    }

    // 批量获取翻译
    Map<String, String> translations = {};
    if (_translationDataSource != null) {
      final tagNames = records.map((r) => r.tag).toList();
      translations = await _translationDataSource.queryBatch(tagNames);
    }

    // 构建带翻译的标签列表并加入缓存
    for (final record in records) {
      final translation = translations[record.tag.toLowerCase().trim()];
      final tag = LocalTag(
        tag: record.tag,
        category: record.category,
        count: record.postCount,
        translation: translation,
      );
      _hotDataCache[tag.tag] = tag;
    }

    _onProgress?.call(1.0, '热数据加载完成');
    AppLogger.i(
      'Loaded ${_hotDataCache.length} hot Danbooru tags into memory',
      'DanbooruTagsLazy',
    );
  }

  @override
  Future<LocalTag?> get(String key) async {
    // 统一标准化标签
    final normalizedKey = TagNormalizer.normalize(key);
    AppLogger.d('[DanbooruTagsLazy] get("$key") -> normalizedKey="$normalizedKey"', 'DanbooruTagsLazy');

    // 尝试精确匹配
    if (_hotDataCache.containsKey(normalizedKey)) {
      final cached = _hotDataCache[normalizedKey];
      AppLogger.d('[DanbooruTagsLazy] cache hit: translation="${cached?.translation}"', 'DanbooruTagsLazy');
      return cached;
    }

    final record = await _tagDataSource.getByName(normalizedKey);
    AppLogger.d('[DanbooruTagsLazy] DB record: ${record != null ? "found" : "not found"}', 'DanbooruTagsLazy');
    if (record != null) {
      // 获取翻译（通过 TranslationDataSource）
      String? translation;
      if (_translationDataSource != null) {
        translation = await _translationDataSource.query(normalizedKey);
      }
      AppLogger.d('[DanbooruTagsLazy] DB translation: "$translation"', 'DanbooruTagsLazy');
      return LocalTag(
        tag: record.tag,
        category: record.category,
        count: record.postCount,
        translation: translation,
      );
    }

    return null;
  }

  Future<List<LocalTag>> search(
    String query, {
    int? category,
    int limit = 20,
  }) async {
    // 使用新的数据源搜索标签
    final records = await _tagDataSource.search(
      query,
      limit: limit,
      category: category,
    );

    if (records.isEmpty) {
      return [];
    }

    // 批量获取翻译
    Map<String, String> translations = {};
    if (_translationDataSource != null) {
      final tagNames = records.map((r) => r.tag).toList();
      translations = await _translationDataSource.queryBatch(tagNames);
    }

    // 构建带翻译的标签列表
    final tags = records.map((r) {
      final translation = translations[r.tag.toLowerCase().trim()];
      return LocalTag(
        tag: r.tag,
        category: r.category,
        count: r.postCount,
        translation: translation,
      );
    }).toList();

    return tags;
  }

  Future<List<LocalTag>> getHotTags({
    int? category,
    int minCount = 1000,
    int limit = 100,
  }) async {
    final records = await _tagDataSource.getHotTags(
      limit: limit,
      category: category,
    );

    if (records.isEmpty) {
      return [];
    }

    // 批量获取翻译
    Map<String, String> translations = {};
    if (_translationDataSource != null) {
      final tagNames = records.map((r) => r.tag).toList();
      translations = await _translationDataSource.queryBatch(tagNames);
    }

    // 构建带翻译的标签列表
    final tags = records.map((r) {
      final translation = translations[r.tag.toLowerCase().trim()];
      return LocalTag(
        tag: r.tag,
        category: r.category,
        count: r.postCount,
        translation: translation,
      );
    }).toList();

    return tags;
  }

  @override
  Future<bool> shouldRefresh() async {
    // 首先检查数据库中是否有数据
    final count = await _tagDataSource.getCount();
    AppLogger.i('[shouldRefresh] Total count: $count', 'DanbooruTagsLazy');
    if (count == 0) {
      AppLogger.i('Danbooru tags database is empty, need to fetch', 'DanbooruTagsLazy');
      return true;
    }

    // 检查各分类数据是否齐全（general, character, copyright, meta）
    final generalCount = await _tagDataSource.getCount(category: 0);
    final characterCount = await _tagDataSource.getCount(category: 4);
    final copyrightCount = await _tagDataSource.getCount(category: 3);
    final metaCount = await _tagDataSource.getCount(category: 5);

    AppLogger.i(
      '[shouldRefresh] Category counts: general=$generalCount, '
      'character=$characterCount, copyright=$copyrightCount, meta=$metaCount',
      'DanbooruTagsLazy',
    );

    // 如果任何主要分类为空，需要拉取
    if (generalCount == 0 || characterCount == 0 || copyrightCount == 0 || metaCount == 0) {
      AppLogger.i(
        '[shouldRefresh] Some categories empty, returning TRUE: '
        'general=$generalCount, character=$characterCount, '
        'copyright=$copyrightCount, meta=$metaCount',
        'DanbooruTagsLazy',
      );
      return true;
    }

    // 有数据时检查是否需要刷新（基于时间）
    if (_lastUpdate == null) {
      await _loadMeta();
    }

    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.danbooruTagsRefreshIntervalDays);
    final interval = AutoRefreshInterval.fromDays(days ?? 30);
    final needsTimeRefresh = interval.shouldRefresh(_lastUpdate);

    AppLogger.i(
      '[shouldRefresh] All categories have data, time check: _lastUpdate=$_lastUpdate, '
      'needsTimeRefresh=$needsTimeRefresh',
      'DanbooruTagsLazy',
    );

    return needsTimeRefresh;
  }

  @override
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _isCancelled = false;
    _onProgress?.call(0.0, '开始同步标签...');

    try {
      final allTags = <LocalTag>[];
      
      // 分别拉取三个类别的标签
      // 1. 一般标签 (category = 0)
      _onProgress?.call(0.0, '同步一般标签 (阈值: $_generalThreshold)...');
      final generalTags = await _fetchTagsByCategory(
        category: 0,
        threshold: _generalThreshold,
        maxPages: _maxPages,
        progressPrefix: '一般标签',
        progressStart: 0.0,
        progressEnd: 0.4,
      );
      allTags.addAll(generalTags);
      
      if (_isCancelled) {
        throw Exception('用户取消同步');
      }
      
      // 2. 画师标签 (category = 1)
      _onProgress?.call(0.4, '同步画师标签 (阈值: $_artistThreshold)...');
      final artistTags = await _fetchTagsByCategory(
        category: 1,
        threshold: _artistThreshold,
        maxPages: _maxPages,
        progressPrefix: '画师标签',
        progressStart: 0.4,
        progressEnd: 0.7,
      );
      allTags.addAll(artistTags);
      
      if (_isCancelled) {
        throw Exception('用户取消同步');
      }
      
      // 3. 角色标签 (category = 4)
      _onProgress?.call(0.7, '同步角色标签 (阈值: $_characterThreshold)...');
      final characterTags = await _fetchTagsByCategory(
        category: 4,
        threshold: _characterThreshold,
        maxPages: _maxPages,
        progressPrefix: '角色标签',
        progressStart: 0.7,
        progressEnd: 0.8,
      );
      allTags.addAll(characterTags);

      if (_isCancelled) {
        throw Exception('用户取消同步');
      }

      // 4. 版权标签 (category = 3)
      _onProgress?.call(0.8, '同步版权标签 (阈值: $_copyrightThreshold)...');
      final copyrightTags = await _fetchTagsByCategory(
        category: 3,
        threshold: _copyrightThreshold,
        maxPages: _maxPages,
        progressPrefix: '版权标签',
        progressStart: 0.8,
        progressEnd: 0.9,
      );
      allTags.addAll(copyrightTags);

      if (_isCancelled) {
        throw Exception('用户取消同步');
      }

      // 5. 元标签 (category = 5)
      _onProgress?.call(0.9, '同步元标签 (阈值: $_metaThreshold)...');
      final metaTags = await _fetchTagsByCategory(
        category: 5,
        threshold: _metaThreshold,
        maxPages: _maxPages,
        progressPrefix: '元标签',
        progressStart: 0.9,
        progressEnd: 0.95,
      );
      allTags.addAll(metaTags);

      if (allTags.isEmpty) {
        throw Exception('未拉取到任何标签');
      }

      _onProgress?.call(0.95, '导入数据库...');

      // 导入数据 - 使用新的数据源
      final records = allTags
          .map(
            (t) => DanbooruTagRecord(
              tag: t.tag,
              category: t.category,
              postCount: t.count,
              lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          )
          .toList();

      AppLogger.i('Preparing to import ${records.length} tags...', 'DanbooruTagsLazy');
      await _tagDataSource.upsertBatch(records);
      AppLogger.i('Successfully imported ${records.length} tags', 'DanbooruTagsLazy');

      _onProgress?.call(0.99, '更新热数据...');
      await _loadHotData();
      await _saveMeta(allTags.length);

      _lastUpdate = DateTime.now();

      _onProgress?.call(1.0, '完成');
      AppLogger.i(
        'Danbooru tags refreshed: ${allTags.length} tags',
        'DanbooruTagsLazy',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to refresh Danbooru tags', e, stack, 'DanbooruTagsLazy');
      _onProgress?.call(1.0, '刷新失败: $e');
      // 下载失败时不更新 _lastUpdate，确保下次启动会重新尝试下载
      rethrow;
    } finally {
      _isRefreshing = false;
      _isCancelled = false;
    }
  }

  void cancelRefresh() {
    _isCancelled = true;
  }

  /// 拉取画师标签（category = 1）
  ///
  /// 特点：
  /// - 后台顺序拉取，不阻塞UI
  /// - 使用分页和并发控制避免限流
  /// - 分批写入数据库，避免内存溢出
  /// - 进度回调显示当前页数和数量（不显示总数，因为画师标签数量不固定）
  Future<void> fetchArtistTags({
    required void Function(int currentPage, int importedCount, String message) onProgress,
    int maxPages = 200, // 画师标签量大，最多拉取20万条
  }) async {
    AppLogger.i(
      'Starting artist tags fetch with threshold >= $_artistThreshold...',
      'DanbooruTagsLazy',
    );

    _isRefreshing = true;
    _isCancelled = false;

    var currentPage = 1;
    var importedCount = 0;
    const batchInsertThreshold = 2000; // 每轮并发写入一次
    final records = <LocalTag>[];

    try {
      while (currentPage <= maxPages && !_isCancelled) {
        // 拉取画师标签（2页并发）
        const batchSize = _concurrentRequests;
        final remainingPages = maxPages - currentPage + 1;
        final actualBatchSize = batchSize < remainingPages ? batchSize : remainingPages;

        final futures = List.generate(actualBatchSize, (i) {
          final page = currentPage + i;
          return _fetchArtistTagsPage(
            page: page,
            minPostCount: _artistThreshold,
          );
        });

        final results = await Future.wait(futures);

        var batchHasData = false;
        for (var i = 0; i < results.length; i++) {
          final tags = results[i];
          if (tags != null && tags.isNotEmpty) {
            batchHasData = true;
            records.addAll(tags);
          }
        }

        if (!batchHasData) {
          AppLogger.i('No more artist tags available', 'DanbooruTagsLazy');
          break;
        }

        // 达到阈值，批量写入
        if (records.length >= batchInsertThreshold) {
          final dbRecords = records
              .map((t) => DanbooruTagRecord(
                    tag: t.tag,
                    category: 1, // 画师标签 category = 1
                    postCount: t.count,
                    lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  ),)
              .toList();

          await _tagDataSource.upsertBatch(dbRecords);
          importedCount += records.length;
          records.clear();

          // 进度回调：显示当前页数和数量
          final lastSuccessfulPage = currentPage + actualBatchSize - 1;
          onProgress(
            lastSuccessfulPage,
            importedCount,
            '第 $lastSuccessfulPage 页，已导入 $importedCount 条',
          );

          // 让出时间片，避免阻塞UI
          await Future.delayed(const Duration(milliseconds: 100));
        }

        currentPage += actualBatchSize;

        // 请求间隔，避免限流
        if (currentPage <= maxPages && !_isCancelled) {
          await Future.delayed(const Duration(milliseconds: _requestIntervalMs));
        }
      }

      // 写入剩余数据
      if (records.isNotEmpty && !_isCancelled) {
        final dbRecords = records
            .map((t) => DanbooruTagRecord(
                  tag: t.tag,
                  category: 1,
                  postCount: t.count,
                  lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ),)
            .toList();

        await _tagDataSource.upsertBatch(dbRecords);
        importedCount += records.length;
      }

      onProgress(
        currentPage - 1,
        importedCount,
        '画师标签导入完成，共 $importedCount 条',
      );

      AppLogger.i('Artist tags fetch completed: $importedCount tags', 'DanbooruTagsLazy');
    } catch (e, stack) {
      AppLogger.e('Failed to fetch artist tags', e, stack, 'DanbooruTagsLazy');
      rethrow;
    } finally {
      _isRefreshing = false;
      _isCancelled = false;
    }
  }

  /// 拉取画师标签页（支持阈值）
  Future<List<LocalTag>?> _fetchArtistTagsPage({
    required int page,
    int? minPostCount,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': _pageSize,
        'search[order]': 'count',
        'search[category]': '1', // 只拉取画师标签
      };
      
      // 添加阈值过滤
      final threshold = minPostCount ?? _artistThreshold;
      if (threshold > 0) {
        queryParams['search[post_count]'] = '>=$threshold';
      }
      
      final response = await _dio.get(
        '$_baseUrl$_tagsEndpoint',
        queryParameters: queryParams,
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'NAI-Launcher/1.0',
          },
        ),
      );

      if (response.data is List) {
        final tags = <LocalTag>[];
        for (final item in response.data as List) {
          if (item is Map<String, dynamic>) {
            final tag = LocalTag(
              tag: (item['name'] as String?)?.toLowerCase() ?? '',
              category: item['category'] as int? ?? 0,
              count: item['post_count'] as int? ?? 0,
            );
            if (tag.tag.isNotEmpty) {
              tags.add(tag);
            }
          }
        }
        return tags;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      AppLogger.w('Failed to fetch artist tags page $page: $e', 'DanbooruTagsLazy');
      return null;
    } catch (e) {
      AppLogger.w('Failed to fetch artist tags page $page: $e', 'DanbooruTagsLazy');
      return null;
    }
  }

  /// 按类别拉取标签（支持独立阈值）
  Future<List<LocalTag>> _fetchTagsByCategory({
    required int category,
    required int threshold,
    required int maxPages,
    required String progressPrefix,
    required double progressStart,
    required double progressEnd,
  }) async {
    final tags = <LocalTag>[];
    var currentPage = 1;
    var consecutiveEmpty = 0;
    var downloadFailed = false;

    while (currentPage <= maxPages && !_isCancelled) {
      const batchSize = _concurrentRequests;
      final remainingPages = maxPages - currentPage + 1;
      final actualBatchSize = batchSize < remainingPages ? batchSize : remainingPages;

      final futures = List.generate(actualBatchSize, (i) {
        final page = currentPage + i;
        return _fetchTagsPageWithCategory(
          page: page,
          category: category,
          minPostCount: threshold,
        );
      });

      final results = await Future.wait(futures);

      var batchHasData = false;
      for (var i = 0; i < results.length; i++) {
        final pageTags = results[i];

        if (pageTags == null) {
          AppLogger.w('Failed to fetch $progressPrefix page, stopping', 'DanbooruTagsLazy');
          downloadFailed = true;
          _isCancelled = true;
          break;
        }

        if (pageTags.isEmpty) {
          consecutiveEmpty++;
          if (consecutiveEmpty >= 2) {
            AppLogger.i('No more $progressPrefix available', 'DanbooruTagsLazy');
            // 使用局部变量结束循环，不要设置 _isCancelled，避免影响其他分类
            break;
          }
        } else {
          consecutiveEmpty = 0;
          batchHasData = true;
          tags.addAll(pageTags);
        }
      }

      if (_isCancelled) break;

      // 更新进度（只显示数量，不显示百分比和页数）
      _onProgress?.call(
        0, // 不使用百分比进度
        '$progressPrefix: 已拉取 ${tags.length} 条',
      );

      currentPage += actualBatchSize;

      if (currentPage <= maxPages && !_isCancelled && batchHasData) {
        await Future.delayed(
          const Duration(milliseconds: _requestIntervalMs),
        );
      }
    }

    if (downloadFailed) {
      throw Exception('$progressPrefix 下载失败');
    }

    AppLogger.i(
      'Fetched ${tags.length} $progressPrefix with threshold >= $threshold',
      'DanbooruTagsLazy',
    );

    return tags;
  }

  /// 按类别和阈值拉取标签页（带429错误重试）
  Future<List<LocalTag>?> _fetchTagsPageWithCategory({
    required int page,
    required int category,
    required int minPostCount,
    int maxRetries = 3,
  }) async {
    var retries = 0;
    
    while (retries <= maxRetries) {
      try {
        final queryParams = <String, dynamic>{
          'search[order]': 'count',
          'search[hide_empty]': 'true',
          'search[category]': category.toString(),
          'limit': _pageSize,
          'page': page,
        };

        if (minPostCount > 0) {
          queryParams['search[post_count]'] = '>=$minPostCount';
        }

        final response = await _dio.get(
          '$_baseUrl$_tagsEndpoint',
          queryParameters: queryParams,
          options: Options(
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 10),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'NAI-Launcher/1.0',
            },
          ),
        );

        if (response.data is List) {
          final tags = <LocalTag>[];
          for (final item in response.data as List) {
            if (item is Map<String, dynamic>) {
              // 关键修复：使用传入的 category 参数，而不是依赖 API 返回的 category 字段
              // 因为 API 返回的数据中 category 字段可能为 null 或错误
              final tag = LocalTag(
                tag: (item['name'] as String?)?.toLowerCase() ?? '',
                category: category, // 使用传入的 category，而不是 item['category']
                count: item['post_count'] as int? ?? 0,
              );
              if (tag.tag.isNotEmpty) {
                tags.add(tag);
              }
            }
          }
          return tags;
        }

        return [];
      } on DioException catch (e) {
        // 404 表示没有更多数据，直接返回空列表
        if (e.response?.statusCode == 404) {
          return [];
        }
        
        // 429 限流错误，使用指数退避重试
        if (e.response?.statusCode == 429 && retries < maxRetries) {
          retries++;
          final delayMs = 1000 * (1 << retries); // 指数退避: 2s, 4s, 8s
          AppLogger.w(
            'Rate limited (429) on category $category page $page, '
            'retry $retries/$maxRetries after ${delayMs}ms',
            'DanbooruTagsLazy',
          );
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        
        // 其他错误或重试耗尽
        AppLogger.w('Failed to fetch category $category page $page: $e', 'DanbooruTagsLazy');
        return null;
      } catch (e) {
        AppLogger.w('Failed to fetch category $category page $page: $e', 'DanbooruTagsLazy');
        return null;
      }
    }
    
    return null;
  }

  Future<void> _loadMeta() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _lastUpdate = DateTime.parse(json['lastUpdate'] as String);
        // 兼容旧版本，如果存在 hotThreshold 则作为 generalThreshold
        final oldThreshold = json['hotThreshold'] as int? ?? 1000;
        _generalThreshold = oldThreshold;
      }

      final prefs = await SharedPreferences.getInstance();
      
      // 加载三个类别的独立阈值
      _generalThreshold = prefs.getInt(StorageKeys.danbooruGeneralThreshold) ?? _generalThreshold;
      _artistThreshold = prefs.getInt(StorageKeys.danbooruArtistThreshold) ?? 500;
      _characterThreshold = prefs.getInt(StorageKeys.danbooruCharacterThreshold) ?? 100;
      _copyrightThreshold = prefs.getInt(StorageKeys.danbooruCopyrightThreshold) ?? 500;
      _metaThreshold = prefs.getInt(StorageKeys.danbooruMetaThreshold) ?? 10000;
      
      final days = prefs.getInt(StorageKeys.danbooruTagsRefreshIntervalDays);
      if (days != null) {
        _refreshInterval = AutoRefreshInterval.fromDays(days);
      }
      
      AppLogger.i(
        'Loaded category thresholds: general=$_generalThreshold, '
        'artist=$_artistThreshold, character=$_characterThreshold, '
        'copyright=$_copyrightThreshold, meta=$_metaThreshold',
        'DanbooruTagsLazy',
      );
    } catch (e) {
      AppLogger.w('Failed to load Danbooru tags meta: $e', 'DanbooruTagsLazy');
    }
  }

  Future<void> _saveMeta(int totalTags) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      final now = DateTime.now();
      final json = {
        'lastUpdate': now.toIso8601String(),
        'totalTags': totalTags,
        'generalThreshold': _generalThreshold,
        'artistThreshold': _artistThreshold,
        'characterThreshold': _characterThreshold,
        'copyrightThreshold': _copyrightThreshold,
        'metaThreshold': _metaThreshold,
        'version': 3, // 版本3支持五个独立阈值
      };

      await metaFile.writeAsString(jsonEncode(json));
      _lastUpdate = now;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.danbooruTagsLastUpdate, now.millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.w('Failed to save Danbooru tags meta: $e', 'DanbooruTagsLazy');
    }
  }

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  // 实现 LazyDataSourceService 接口的缺失方法
  @override
  Future<List<LocalTag>> getMultiple(List<String> keys) async {
    final result = <LocalTag>[];
    for (final key in keys) {
      final tag = await get(key);
      if (tag != null) {
        result.add(tag);
      }
    }
    return result;
  }

  @override
  Future<void> clearCache() async {
    AppLogger.i(
      '[ProviderLifecycle] DanbooruTagsLazyService.clearCache() START - hash=$hashCode, _isInitialized=$_isInitialized',
      'DanbooruTagsLazy',
    );

    _hotDataCache.clear();

    // 重置初始化状态（关键：下次初始化时会重新检查并下载数据）
    _isInitialized = false;
    AppLogger.i(
      '[ProviderLifecycle] DanbooruTagsLazyService.clearCache() - _isInitialized reset to false',
      'DanbooruTagsLazy',
    );

    // 清除元数据
    _lastUpdate = null;
    _generalThreshold = 1000;
    _artistThreshold = 500;
    _characterThreshold = 100;
    _copyrightThreshold = 500;
    _metaThreshold = 10000;
    _refreshInterval = AutoRefreshInterval.days30;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.danbooruTagsLastUpdate);
    await prefs.remove(StorageKeys.danbooruTagsRefreshIntervalDays);

    // 清除画师标签相关阈值
    await prefs.remove(StorageKeys.danbooruArtistThreshold);

    // 删除元数据文件（关键：否则重启后会从文件加载旧的 _lastUpdate）
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');
      if (await metaFile.exists()) {
        await metaFile.delete();
        AppLogger.i('Deleted meta file: ${metaFile.path}', 'DanbooruTagsLazy');
      }
    } catch (e) {
      AppLogger.w('Failed to delete meta file: $e', 'DanbooruTagsLazy');
    }

    AppLogger.i(
      '[ProviderLifecycle] DanbooruTagsLazyService.clearCache() END - hash=$hashCode, _isInitialized=$_isInitialized',
      'DanbooruTagsLazy',
    );
  }

  // 兼容旧 API 的方法
  Future<List<LocalTag>> searchTags(String query, {int? category, int limit = 20}) async {
    return search(query, category: category, limit: limit);
  }

  TagHotPreset getHotPreset() {
    return TagHotPreset.fromThreshold(_generalThreshold);
  }

  Future<void> setHotPreset(TagHotPreset preset, {int? customThreshold}) async {
    _generalThreshold = customThreshold ?? preset.threshold;
    // 同时保存到SharedPreferences保持兼容
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.danbooruGeneralThreshold, _generalThreshold);
  }

  AutoRefreshInterval getRefreshInterval() {
    return _refreshInterval;
  }

  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    _refreshInterval = interval;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.danbooruTagsRefreshIntervalDays, interval.days);
  }

  // ===========================================================================
  // V2: 三阶段预热架构支持
  // ===========================================================================

  /// V2: 轻量级初始化（仅检查状态）
  Future<void> initializeLightweight() async {
    if (_isInitialized) return;

    try {
      await _tagDataSource.getCount();
      _isInitialized = true; // 标记为已初始化，即使数据为空
      // 注意：不触发 refresh()，数据下载留到后台阶段
    } catch (e) {
      AppLogger.w('Danbooru tags lightweight init failed: $e', 'DanbooruTagsLazy');
      _isInitialized = true;
    }
  }

  /// V2: 后台预加载
  Future<void> preloadHotDataInBackground() async {
    try {
      _onProgress?.call(0.0, '检查标签数据...');

      // 加载热数据
      await _loadHotData();

      // 检查是否需要后台更新
      final tagCount = await _tagDataSource.getCount();
      if (tagCount == 0) {
        _onProgress?.call(0.5, '需要下载标签数据...');
        // 标记为需要下载，但由用户触发或后台静默下载
      }

      _onProgress?.call(1.0, '标签数据就绪');
    } catch (e) {
      AppLogger.w('Danbooru tags hot data preload failed: $e', 'DanbooruTagsLazy');
    }
  }

  /// 是否应该后台刷新（不阻塞启动）
  Future<bool> shouldRefreshInBackground() async {
    if (_lastUpdate == null) {
      await _loadMeta();
    }
    return _refreshInterval.shouldRefresh(_lastUpdate);
  }

  /// V2: 后台进度回调
  set onBackgroundProgress(DataSourceProgressCallback? callback) {
    _onProgress = callback;
  }

  /// V2: 取消后台操作
  void cancelBackgroundOperation() {
    _isCancelled = true;
  }

  /// 获取当前标签数量（所有类别）
  Future<int> getTagCount() async {
    return await _tagDataSource.getCount();
  }

  /// 获取指定类别的标签数量
  Future<int> getTagCountByCategory(int category) async {
    return await _tagDataSource.getCount(category: category);
  }

  /// 获取标签分类统计
  Future<Map<String, int>> getCategoryStats() async {
    final stats = <String, int>{};

    // 获取总数
    stats['total'] = await _tagDataSource.getCount();

    // 获取各分类数量
    stats['artist'] = await _tagDataSource.getCount(category: 1);
    stats['general'] = await _tagDataSource.getCount(category: 0);
    stats['copyright'] = await _tagDataSource.getCount(category: 3);
    stats['character'] = await _tagDataSource.getCount(category: 4);
    stats['meta'] = await _tagDataSource.getCount(category: 5);

    return stats;
  }

  /// 在所有分类拉取完成后保存元数据
  ///
  /// 这个方法应该在 general, character, copyright, meta 都拉取完成后调用
  /// 它会获取当前总数并设置 _lastUpdate，避免影响后续的判断逻辑
  Future<void> saveMetaAfterFetch() async {
    try {
      // 获取当前总数
      final totalTags = await _tagDataSource.getCount();

      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      final now = DateTime.now();
      final json = {
        'lastUpdate': now.toIso8601String(),
        'totalTags': totalTags,
        'generalThreshold': _generalThreshold,
        'artistThreshold': _artistThreshold,
        'characterThreshold': _characterThreshold,
        'copyrightThreshold': _copyrightThreshold,
        'metaThreshold': _metaThreshold,
        'version': 3,
      };

      await metaFile.writeAsString(jsonEncode(json));
      _lastUpdate = now;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.danbooruTagsLastUpdate, now.millisecondsSinceEpoch);

      AppLogger.i(
        'Tags meta saved after fetch: total=$totalTags, lastUpdate=$now',
        'DanbooruTagsLazy',
      );
    } catch (e) {
      AppLogger.w('Failed to save tags meta after fetch: $e', 'DanbooruTagsLazy');
    }
  }

  // ===========================================================================
  // 分层标签拉取支持（预打包数据库 + 分层获取架构）
  // ===========================================================================

  /// 拉取一般标签（非画师标签，category != 1）
  ///
  /// 用于预热阶段快速拉取高频一般标签，排除数量庞大的画师标签
  Future<void> fetchGeneralTags({
    required int threshold,
    required int maxPages,
  }) async {
    _onProgress?.call(0.0, '准备拉取标签...');

    // 重置取消标志，确保新分类可以正常拉取
    _isCancelled = false;

    final allTags = <LocalTag>[];
    var currentPage = 1;

    while (currentPage <= maxPages && !_isCancelled) {
      // 并发拉取多页
      final remainingPages = maxPages - currentPage + 1;
      final actualBatchSize = _concurrentRequests < remainingPages
          ? _concurrentRequests
          : remainingPages;

      final futures = List.generate(actualBatchSize, (i) {
        final page = currentPage + i;
        // 拉取一般标签 (category=0)，使用指定的阈值
        return _fetchTagsPageWithCategory(
          page: page,
          category: 0,
          minPostCount: threshold,
        );
      });

      final results = await Future.wait(futures);

      for (final tags in results) {
        if (tags != null) {
          allTags.addAll(tags);
        }
      }

      // 报告进度（只显示数量）
      _onProgress?.call(
        0, // 不使用百分比进度
        '一般标签: 已拉取 ${allTags.length} 条',
      );

      currentPage += actualBatchSize;

      // 间隔避免限流
      if (currentPage <= maxPages && !_isCancelled) {
        await Future.delayed(
          const Duration(milliseconds: _requestIntervalMs),
        );
      }
    }

    if (_isCancelled) {
      AppLogger.w('General tags fetch cancelled', 'DanbooruTagsLazy');
      return;
    }

    // 导入数据库
    _onProgress?.call(0.95, '导入数据库...');
    final records = allTags
        .map(
          (t) => DanbooruTagRecord(
            tag: t.tag,
            category: t.category,
            postCount: t.count,
            lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        )
        .toList();

    await _tagDataSource.upsertBatch(records);

    // 注意：不在单独的分类拉取中保存 _lastUpdate，因为这会影响其他分类的判断
    // _lastUpdate 应该在所有分类都拉取完成后统一设置
    _onProgress?.call(1.0, '标签拉取完成');
    AppLogger.i(
      'General tags fetched: ${allTags.length} tags (threshold >= $threshold)',
      'DanbooruTagsLazy',
    );
  }

  /// 拉取角色标签（category = 4）
  ///
  /// 用于预热阶段拉取角色标签
  Future<void> fetchCharacterTags({
    required int threshold,
    required int maxPages,
  }) async {
    _onProgress?.call(0.0, '准备拉取角色标签...');

    // 重置取消标志，确保新分类可以正常拉取
    _isCancelled = false;

    AppLogger.i(
      'Starting character tags fetch with threshold >= $threshold...',
      'DanbooruTagsLazy',
    );

    final characterTags = await _fetchTagsByCategory(
      category: 4,
      threshold: threshold,
      maxPages: maxPages,
      progressPrefix: '角色标签',
      progressStart: 0.0,
      progressEnd: 1.0,
    );

    if (_isCancelled) {
      AppLogger.w('Character tags fetch cancelled', 'DanbooruTagsLazy');
      return;
    }

    if (characterTags.isEmpty) {
      AppLogger.i('No character tags fetched', 'DanbooruTagsLazy');
      return;
    }

    // 导入数据库
    _onProgress?.call(0.95, '导入角色标签...');
    final records = characterTags
        .map(
          (t) => DanbooruTagRecord(
            tag: t.tag,
            category: t.category,
            postCount: t.count,
            lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        )
        .toList();

    await _tagDataSource.upsertBatch(records);

    _onProgress?.call(1.0, '角色标签拉取完成');
    AppLogger.i(
      'Character tags fetched: ${characterTags.length} tags (threshold >= $threshold)',
      'DanbooruTagsLazy',
    );
  }

  /// 拉取版权标签（category = 3）
  ///
  /// 用于预热阶段拉取版权/作品标签
  Future<void> fetchCopyrightTags({
    required int threshold,
    required int maxPages,
  }) async {
    _onProgress?.call(0.0, '准备拉取版权标签...');

    // 重置取消标志，确保新分类可以正常拉取
    _isCancelled = false;

    AppLogger.i(
      'Starting copyright tags fetch with threshold >= $threshold...',
      'DanbooruTagsLazy',
    );

    final copyrightTags = await _fetchTagsByCategory(
      category: 3,
      threshold: threshold,
      maxPages: maxPages,
      progressPrefix: '版权标签',
      progressStart: 0.0,
      progressEnd: 1.0,
    );

    if (_isCancelled) {
      AppLogger.w('Copyright tags fetch cancelled', 'DanbooruTagsLazy');
      return;
    }

    if (copyrightTags.isEmpty) {
      AppLogger.i('No copyright tags fetched', 'DanbooruTagsLazy');
      return;
    }

    // 导入数据库
    _onProgress?.call(0.95, '导入版权标签...');
    final records = copyrightTags
        .map(
          (t) => DanbooruTagRecord(
            tag: t.tag,
            category: t.category,
            postCount: t.count,
            lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        )
        .toList();

    await _tagDataSource.upsertBatch(records);

    _onProgress?.call(1.0, '版权标签拉取完成');
    AppLogger.i(
      'Copyright tags fetched: ${copyrightTags.length} tags (threshold >= $threshold)',
      'DanbooruTagsLazy',
    );
  }

  /// 拉取元标签（category = 5）
  ///
  /// 用于预热阶段拉取元数据标签
  Future<void> fetchMetaTags({
    required int threshold,
    required int maxPages,
  }) async {
    _onProgress?.call(0.0, '准备拉取元标签...');

    // 重置取消标志，确保新分类可以正常拉取
    _isCancelled = false;

    AppLogger.i(
      'Starting meta tags fetch with threshold >= $threshold...',
      'DanbooruTagsLazy',
    );

    final metaTags = await _fetchTagsByCategory(
      category: 5,
      threshold: threshold,
      maxPages: maxPages,
      progressPrefix: '元标签',
      progressStart: 0.0,
      progressEnd: 1.0,
    );

    if (_isCancelled) {
      AppLogger.w('Meta tags fetch cancelled', 'DanbooruTagsLazy');
      return;
    }

    if (metaTags.isEmpty) {
      AppLogger.i('No meta tags fetched', 'DanbooruTagsLazy');
      return;
    }

    // 导入数据库
    _onProgress?.call(0.95, '导入元标签...');
    final records = metaTags
        .map(
          (t) => DanbooruTagRecord(
            tag: t.tag,
            category: t.category,
            postCount: t.count,
            lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        )
        .toList();

    await _tagDataSource.upsertBatch(records);

    _onProgress?.call(1.0, '元标签拉取完成');
    AppLogger.i(
      'Meta tags fetched: ${metaTags.length} tags (threshold >= $threshold)',
      'DanbooruTagsLazy',
    );
  }
}

/// Danbooru 标签懒加载服务 Provider (V3 架构)
///
/// 使用 FutureProvider 确保服务完全初始化后才可用。
/// 调用者必须使用 await ref.read(provider.future) 获取服务。
@Riverpod(keepAlive: true)
Future<DanbooruTagsLazyService> danbooruTagsLazyService(Ref ref) async {
  AppLogger.i(
    '[ProviderLifecycle] danbooruTagsLazyServiceProvider BUILD START',
    'DanbooruTagsLazy',
  );

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  // 等待数据源初始化完成
  AppLogger.i(
    '[ProviderLifecycle] danbooruTagsLazyServiceProvider - waiting for danbooruTagDataSourceProvider',
    'DanbooruTagsLazy',
  );
  final tagDataSource = await ref.read(danbooruTagDataSourceProvider.future);

  // 等待翻译数据源初始化
  AppLogger.i(
    '[ProviderLifecycle] danbooruTagsLazyServiceProvider - waiting for translationDataSourceProvider',
    'DanbooruTagsLazy',
  );
  final translationDataSource = await ref.read(translationDataSourceProvider.future);

  // 创建并初始化服务（同步初始化，DataSource 必须已准备好）
  final service = DanbooruTagsLazyService(
    dataSource: tagDataSource,
    dio: dio,
    translationDataSource: translationDataSource,
  );
  AppLogger.i(
    '[ProviderLifecycle] danbooruTagsLazyServiceProvider - service instance created, hash=${service.hashCode}',
    'DanbooruTagsLazy',
  );

  // 执行服务级初始化（加载热数据等）
  await service.initialize();

  AppLogger.i(
    '[ProviderLifecycle] danbooruTagsLazyServiceProvider BUILD END - service hash=${service.hashCode}',
    'DanbooruTagsLazy',
  );
  return service;
}
