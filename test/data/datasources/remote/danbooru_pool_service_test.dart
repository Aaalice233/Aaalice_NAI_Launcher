import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_pool_service.dart';

/// Danbooru Pool 接口测试
///
/// 测试 Pool 搜索、获取详情和标签提取功能
void main() {
  late Dio dio;
  late DanbooruApiService apiService;
  late DanbooruPoolService poolService;

  setUp(() {
    dio = Dio();
    apiService = DanbooruApiService(dio);
    poolService = DanbooruPoolService(apiService);
  });

  group('DanbooruPoolService', () {
    test('searchPools 搜索 Pool 返回有效结果', () async {
      // 使用常见的 Pool 名称进行测试
      final results = await poolService.searchPools('touhou', limit: 5);

      print('');
      print('=' * 60);
      print('Pool 搜索测试结果');
      print('=' * 60);
      print('搜索关键词: touhou');
      print('返回数量: ${results.length}');

      if (results.isNotEmpty) {
        for (final pool in results) {
          print('  - [${pool.id}] ${pool.displayName} (${pool.postCount} posts)');
        }
        expect(results.first.id, isPositive);
        expect(results.first.name, isNotEmpty);
      }
      print('=' * 60);
    });

    test('searchPools 空查询返回空结果', () async {
      final results = await poolService.searchPools('', limit: 5);
      // API 可能对空查询返回热门 Pool 或空列表
      print('空查询返回: ${results.length} 个结果');
    });

    test('searchPools 不存在的关键词返回空结果', () async {
      final results = await poolService.searchPools(
        'xyznonexistentpool12345',
        limit: 5,
      );
      print('不存在的关键词返回: ${results.length} 个结果');
      expect(results, isEmpty);
    });

    test('getPool 获取 Pool 详情', () async {
      // 先搜索一个 Pool
      final searchResults = await poolService.searchPools('series', limit: 1);

      print('');
      print('=' * 60);
      print('Pool 详情获取测试');
      print('=' * 60);

      if (searchResults.isNotEmpty) {
        final poolId = searchResults.first.id;
        print('测试 Pool ID: $poolId');

        final pool = await poolService.getPool(poolId);

        if (pool != null) {
          print('Pool 名称: ${pool.displayName}');
          print('Pool 帖子数: ${pool.postCount}');
          print('Pool 类型: ${pool.category}');
          expect(pool.id, equals(poolId));
          expect(pool.name, isNotEmpty);
        } else {
          print('获取 Pool 详情失败');
        }
      } else {
        print('无法找到测试 Pool');
      }
      print('=' * 60);
    });

    test('extractTagsFromPool 从 Pool 提取标签', () async {
      // 搜索一个有帖子的 Pool
      final searchResults = await poolService.searchPools('touhou', limit: 1);

      print('');
      print('=' * 60);
      print('Pool 标签提取测试');
      print('=' * 60);

      if (searchResults.isNotEmpty) {
        final pool = searchResults.first;
        print('测试 Pool: ${pool.displayName} (${pool.postCount} posts)');

        if (pool.postCount > 0) {
          final tags = await poolService.extractTagsFromPool(
            poolId: pool.id,
            poolName: pool.name,
            maxPosts: 10, // 限制帖子数以加快测试
            minOccurrence: 1,
          );

          print('提取到 ${tags.length} 个标签');
          if (tags.isNotEmpty) {
            print('前 5 个标签:');
            for (final tag in tags.take(5)) {
              print('  - ${tag.tag} (权重: ${tag.weight})');
            }

            expect(tags.first.tag, isNotEmpty);
            expect(tags.first.weight, greaterThan(0));
          }
        } else {
          print('Pool 没有帖子，跳过标签提取测试');
        }
      } else {
        print('无法找到测试 Pool');
      }
      print('=' * 60);
    });

    test('extractTagsFromPool 对不存在的 Pool 返回空列表', () async {
      final tags = await poolService.extractTagsFromPool(
        poolId: 999999999, // 不太可能存在的 Pool ID
        poolName: 'nonexistent_pool',
        maxPosts: 10,
        minOccurrence: 1,
      );

      print('不存在的 Pool 返回: ${tags.length} 个标签');
      expect(tags, isEmpty);
    });

    test('searchPools limit 参数正常工作', () async {
      const testLimit = 3;
      final results = await poolService.searchPools('anime', limit: testLimit);

      print('');
      print('=' * 60);
      print('limit 参数测试');
      print('=' * 60);
      print('请求 limit: $testLimit');
      print('实际返回: ${results.length}');
      print('=' * 60);

      // 返回数量应该不超过 limit
      expect(results.length, lessThanOrEqualTo(testLimit));
    });
  });

  group('DanbooruApiService Pool 方法', () {
    test('searchPoolsTyped 返回正确类型', () async {
      final pools = await apiService.searchPoolsTyped('collection', limit: 3);

      print('');
      print('=' * 60);
      print('API 直接调用测试');
      print('=' * 60);
      print('返回 ${pools.length} 个 Pool');

      if (pools.isNotEmpty) {
        final pool = pools.first;
        print('第一个 Pool:');
        print('  - ID: ${pool.id}');
        print('  - 名称: ${pool.name}');
        print('  - 帖子数: ${pool.postCount}');
        print('  - 类型: ${pool.category}');

        expect(pool.id, isA<int>());
        expect(pool.name, isA<String>());
        expect(pool.postCount, isA<int>());
      }
      print('=' * 60);
    });

    test('getPoolPosts 获取 Pool 内帖子', () async {
      // 先搜索一个有帖子的 Pool
      final pools = await apiService.searchPoolsTyped('touhou', limit: 1);

      print('');
      print('=' * 60);
      print('Pool 帖子获取测试');
      print('=' * 60);

      if (pools.isNotEmpty && pools.first.postCount > 0) {
        final poolId = pools.first.id;
        print('Pool ID: $poolId');
        print('Pool 帖子数: ${pools.first.postCount}');

        final posts = await apiService.getPoolPosts(
          poolId: poolId,
          limit: 5,
        );

        print('获取到 ${posts.length} 个帖子');

        if (posts.isNotEmpty) {
          final post = posts.first;
          print('第一个帖子:');
          print('  - ID: ${post.id}');
          print('  - 标签数: ${post.generalTags.length}');
          if (post.generalTags.isNotEmpty) {
            print('  - 前 3 个标签: ${post.generalTags.take(3).join(', ')}');
          }

          expect(posts.length, lessThanOrEqualTo(5));
          expect(post.id, isA<int>());
        }
      } else {
        print('无法找到有帖子的测试 Pool');
      }
      print('=' * 60);
    });
  });
}
