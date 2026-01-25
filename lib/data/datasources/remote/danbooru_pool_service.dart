import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/danbooru/danbooru_pool.dart';
import '../../models/prompt/pool_mapping.dart';
import '../../models/prompt/pool_post.dart';
import '../../models/prompt/pool_sync_config.dart';
import '../../models/prompt/tag_category.dart';
import '../../models/prompt/weighted_tag.dart';
import 'danbooru_api_service.dart';

part 'danbooru_pool_service.g.dart';

/// Pool 同步结果
class PoolSyncResult {
  /// 按分类合并后的标签
  final Map<TagSubCategory, List<WeightedTag>> categoryTags;

  /// 每个 Pool 提取的标签数量（Pool ID -> 标签数）
  final Map<int, int> poolTagCounts;

  const PoolSyncResult({
    required this.categoryTags,
    required this.poolTagCounts,
  });

  bool get isEmpty => categoryTags.isEmpty;
}

/// Danbooru Pool 同步服务
///
/// 负责从 Danbooru Pools 中提取高频标签
class DanbooruPoolService {
  final DanbooruApiService _apiService;

  DanbooruPoolService(this._apiService);

  /// 搜索 Pools
  Future<List<DanbooruPool>> searchPools(String query, {int limit = 20}) {
    return _apiService.searchPoolsTyped(query, limit: limit);
  }

  /// 获取 Pool 详情
  Future<DanbooruPool?> getPool(int poolId) {
    return _apiService.getPool(poolId);
  }

  /// 从单个 Pool 提取标签
  ///
  /// [poolId] Pool ID
  /// [poolName] Pool 名称（用于日志）
  /// [maxPosts] 最大获取帖子数
  /// [minOccurrence] 最小出现次数（用于过滤低频标签）
  Future<List<WeightedTag>> extractTagsFromPool({
    required int poolId,
    required String poolName,
    int maxPosts = 100,
    int minOccurrence = 3,
  }) async {
    try {
      AppLogger.d(
          'Extracting tags from pool: $poolName (ID: $poolId)', 'PoolService',);

      // 获取 Pool 内的帖子
      final posts = await _apiService.getPoolPosts(
        poolId: poolId,
        limit: maxPosts,
      );

      if (posts.isEmpty) {
        AppLogger.w('No posts found in pool: $poolName', 'PoolService');
        return [];
      }

      AppLogger.d(
          'Fetched ${posts.length} posts from pool: $poolName', 'PoolService',);

      // 统计每个标签的出现次数
      final tagCounts = <String, int>{};
      for (final post in posts) {
        for (final tag in post.generalTags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      // 过滤低频标签并计算权重
      final totalPosts = posts.length;
      final weightedTags = <WeightedTag>[];

      for (final entry in tagCounts.entries) {
        if (entry.value >= minOccurrence) {
          // 权重计算：(出现次数 / 总帖子数) * 10，范围 1-10
          final rawWeight = (entry.value / totalPosts) * 10;
          final weight = rawWeight.clamp(1, 10).toInt();

          weightedTags.add(
            WeightedTag.simple(
              entry.key.replaceAll('_', ' '),
              weight,
              TagSource.danbooru,
            ),
          );
        }
      }

      // 按权重降序排序
      weightedTags.sort((a, b) => b.weight.compareTo(a.weight));

      AppLogger.d(
        'Extracted ${weightedTags.length} tags from pool: $poolName (filtered from ${tagCounts.length})',
        'PoolService',
      );

      return weightedTags;
    } catch (e, stack) {
      AppLogger.e('Failed to extract tags from pool: $poolName', e, stack,
          'PoolService',);
      return [];
    }
  }

  /// 同步 Pool 的所有帖子
  ///
  /// 分页获取 Pool 中的所有帖子并转换为 PoolPost 列表
  /// [poolId] Pool ID
  /// [poolName] Pool 名称（用于日志）
  /// [onProgress] 进度回调 (已完成数量, 总数量)
  /// [maxConcurrency] 最大并发数（默认3）
  Future<List<PoolPost>> syncAllPoolPosts({
    required int poolId,
    required String poolName,
    void Function(int completed, int total)? onProgress,
    int maxConcurrency = 3,
  }) async {
    try {
      AppLogger.d('Syncing all posts from pool: $poolName (ID: $poolId)',
          'PoolService',);

      // 1. 获取 Pool 详情确定 post_count
      final pool = await getPool(poolId);
      if (pool == null) {
        AppLogger.w('Pool not found: $poolId', 'PoolService');
        return [];
      }

      final totalPosts = pool.postCount;
      if (totalPosts == 0) {
        AppLogger.w('Pool has no posts: $poolName', 'PoolService');
        return [];
      }

      // 2. 计算总页数（每页最多 200）
      const postsPerPage = 200;
      final totalPages = (totalPosts / postsPerPage).ceil();

      AppLogger.d('Pool $poolName has $totalPosts posts, $totalPages pages',
          'PoolService',);

      // 3. 并发分页获取
      final allPosts = <PoolPost>[];
      final semaphore = _Semaphore(maxConcurrency);
      var completedPages = 0;

      final futures = List.generate(totalPages, (index) async {
        final page = index + 1;
        await semaphore.acquire();
        try {
          final posts = await _apiService.getPoolPosts(
            poolId: poolId,
            limit: postsPerPage,
            page: page,
          );

          // 转换为 PoolPost
          final poolPosts = posts
              .map(
                (p) => PoolPost.fromDanbooruPost({
                  'id': p.id,
                  'tag_string_general': p.generalTags.join(' '),
                  'tag_string_character': p.characterTags.join(' '),
                  'tag_string_copyright': p.copyrightTags.join(' '),
                  'tag_string_artist': p.artistTags.join(' '),
                  'tag_string_meta': p.metaTags.join(' '),
                }),
              )
              .toList();

          completedPages++;
          onProgress?.call(completedPages, totalPages);

          return poolPosts;
        } finally {
          semaphore.release();
        }
      });

      final results = await Future.wait(futures);
      for (final posts in results) {
        allPosts.addAll(posts);
      }

      AppLogger.i(
        'Synced ${allPosts.length} posts from pool: $poolName',
        'PoolService',
      );

      return allPosts;
    } catch (e, stack) {
      AppLogger.e(
          'Failed to sync pool posts: $poolName', e, stack, 'PoolService',);
      return [];
    }
  }

  /// 批量同步多个 Pool 映射（并发执行）
  ///
  /// [mappings] 要同步的 Pool 映射列表
  /// [maxPostsPerPool] 每个 Pool 最大获取帖子数
  /// [minOccurrence] 最小标签出现次数
  /// [onProgress] 进度回调
  /// [maxConcurrency] 最大并发数（默认3，避免触发 API 限流）
  ///
  /// 返回：包含分类标签和每个 Pool 标签数的结果
  Future<PoolSyncResult> syncPoolMappings({
    required List<PoolMapping> mappings,
    int maxPostsPerPool = 100,
    int minOccurrence = 3,
    void Function(PoolSyncProgress progress)? onProgress,
    int maxConcurrency = 3,
  }) async {
    if (mappings.isEmpty) {
      return const PoolSyncResult(categoryTags: {}, poolTagCounts: {});
    }

    final enabledMappings = mappings.where((m) => m.enabled).toList();
    if (enabledMappings.isEmpty) {
      return const PoolSyncResult(categoryTags: {}, poolTagCounts: {});
    }

    onProgress?.call(PoolSyncProgress.initial());

    final totalCount = enabledMappings.length;
    var completedCount = 0;

    // 存储每个 mapping 的结果
    final mappingResults = <PoolMapping, List<WeightedTag>>{};
    // 存储每个 Pool 提取的标签数量
    final poolTagCounts = <int, int>{};

    // 使用信号量控制并发数
    final semaphore = _Semaphore(maxConcurrency);

    // 并发执行所有 Pool 同步任务
    final futures = enabledMappings.map((mapping) async {
      await semaphore.acquire();
      try {
        onProgress?.call(
          PoolSyncProgress.fetching(
            mapping.poolDisplayName,
            completedCount,
            totalCount,
          ),
        );

        final tags = await extractTagsFromPool(
          poolId: mapping.poolId,
          poolName: mapping.poolName,
          maxPosts: maxPostsPerPool,
          minOccurrence: minOccurrence,
        );

        mappingResults[mapping] = tags;
        poolTagCounts[mapping.poolId] = tags.length;
        completedCount++;

        onProgress?.call(
          PoolSyncProgress.fetching(
            mapping.poolDisplayName,
            completedCount,
            totalCount,
          ),
        );
      } catch (e) {
        AppLogger.w('Failed to sync pool: ${mapping.poolName}', 'PoolService');
        mappingResults[mapping] = [];
        poolTagCounts[mapping.poolId] = 0;
        completedCount++;
      } finally {
        semaphore.release();
      }
    });

    // 等待所有任务完成
    await Future.wait(futures);

    onProgress?.call(PoolSyncProgress.merging());

    // 合并结果到分类
    final results = <TagSubCategory, List<WeightedTag>>{};
    for (final mapping in enabledMappings) {
      final tags = mappingResults[mapping] ?? [];
      if (tags.isNotEmpty) {
        // 按目标分类合并
        final existingTags = results[mapping.targetCategory] ?? [];
        final existingNames =
            existingTags.map((t) => t.tag.toLowerCase()).toSet();

        // 添加不重复的标签
        for (final tag in tags) {
          if (!existingNames.contains(tag.tag.toLowerCase())) {
            existingTags.add(tag);
            existingNames.add(tag.tag.toLowerCase());
          }
        }

        results[mapping.targetCategory] = existingTags;
      }
    }

    // 计算总标签数
    final totalTagCount =
        results.values.fold<int>(0, (sum, list) => sum + list.length);

    AppLogger.i(
      'Pool sync completed: $totalTagCount tags from ${enabledMappings.length} pools (concurrent)',
      'PoolService',
    );

    onProgress?.call(PoolSyncProgress.completed(totalTagCount));

    return PoolSyncResult(
      categoryTags: results,
      poolTagCounts: poolTagCounts,
    );
  }
}

/// DanbooruPoolService Provider
@Riverpod(keepAlive: true)
DanbooruPoolService danbooruPoolService(Ref ref) {
  final apiService = ref.watch(danbooruApiServiceProvider);
  return DanbooruPoolService(apiService);
}

/// 简单信号量实现，用于控制并发数
class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _waitQueue = <void Function()>[];

  _Semaphore(this.maxCount);

  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }

    // 等待释放
    final completer = Completer<void>();
    _waitQueue.add(completer.complete);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final next = _waitQueue.removeAt(0);
      next();
    } else {
      _currentCount--;
    }
  }
}
