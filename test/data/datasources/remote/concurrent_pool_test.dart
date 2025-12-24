import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// 并发池测试
///
/// 测试并发执行任务的辅助方法性能和正确性
/// 模拟 DanbooruTagGroupService._runConcurrent 的行为
void main() {
  group('并发池性能测试', () {
    /// 模拟 _runConcurrent 方法
    Future<List<R>> runConcurrent<T, R>({
      required List<T> items,
      required int maxConcurrency,
      required Future<R> Function(T) task,
      void Function(T item, R result)? onItemComplete,
    }) async {
      if (items.isEmpty) return [];

      final results = List<R?>.filled(items.length, null);
      final activeTasks = <int, Future<void>>{};
      var nextIndex = 0;
      final completer = Completer<void>();
      var completedCount = 0;

      void startNextTask() {
        while (
            activeTasks.length < maxConcurrency && nextIndex < items.length) {
          final currentIndex = nextIndex++;
          final item = items[currentIndex];

          final future = task(item).then((result) {
            results[currentIndex] = result;
            onItemComplete?.call(item, result);
            completedCount++;
            activeTasks.remove(currentIndex);

            if (completedCount == items.length) {
              completer.complete();
            } else {
              startNextTask();
            }
          }).catchError((e) {
            completedCount++;
            activeTasks.remove(currentIndex);

            if (completedCount == items.length) {
              completer.complete();
            } else {
              startNextTask();
            }
          });

          activeTasks[currentIndex] = future;
        }
      }

      startNextTask();

      if (items.isNotEmpty) {
        await completer.future;
      }

      return results.cast<R>();
    }

    /// 模拟网络请求延迟
    Future<String> simulateNetworkRequest(int id, {int delayMs = 100}) async {
      await Future.delayed(Duration(milliseconds: delayMs));
      return 'Result-$id';
    }

    test('并发数=2 (旧配置) vs 并发数=6 (新配置) 性能对比', () async {
      const taskCount = 12;
      const taskDelayMs = 50; // 模拟每个请求 50ms

      final items = List.generate(taskCount, (i) => i);

      // 测试旧配置: 并发数=2
      final stopwatch1 = Stopwatch()..start();
      await runConcurrent<int, String>(
        items: items,
        maxConcurrency: 2,
        task: (id) => simulateNetworkRequest(id, delayMs: taskDelayMs),
      );
      stopwatch1.stop();
      final oldTime = stopwatch1.elapsedMilliseconds;

      // 测试新配置: 并发数=6
      final stopwatch2 = Stopwatch()..start();
      await runConcurrent<int, String>(
        items: items,
        maxConcurrency: 6,
        task: (id) => simulateNetworkRequest(id, delayMs: taskDelayMs),
      );
      stopwatch2.stop();
      final newTime = stopwatch2.elapsedMilliseconds;

      // 输出结果
      print('');
      print('=' * 60);
      print('并发池性能测试结果');
      print('=' * 60);
      print('任务数量: $taskCount');
      print('单任务延迟: ${taskDelayMs}ms');
      print('-' * 60);
      print('旧配置 (并发=2): ${oldTime}ms');
      print('新配置 (并发=6): ${newTime}ms');
      print('加速比: ${(oldTime / newTime).toStringAsFixed(2)}x');
      print('=' * 60);

      // 理论时间计算
      // 并发=2: ceil(12/2) * 50 = 6 * 50 = 300ms
      // 并发=6: ceil(12/6) * 50 = 2 * 50 = 100ms
      // 加速比应接近 3x

      expect(newTime, lessThan(oldTime), reason: '新配置应该更快');
      expect(oldTime / newTime, greaterThan(2.0), reason: '加速比应大于 2x');
    });

    test('并发数=3 (旧子分组) vs 并发数=8 (新子分组) 性能对比', () async {
      const taskCount = 24;
      const taskDelayMs = 30;

      final items = List.generate(taskCount, (i) => i);

      // 旧配置: 并发数=3
      final stopwatch1 = Stopwatch()..start();
      await runConcurrent<int, String>(
        items: items,
        maxConcurrency: 3,
        task: (id) => simulateNetworkRequest(id, delayMs: taskDelayMs),
      );
      stopwatch1.stop();
      final oldTime = stopwatch1.elapsedMilliseconds;

      // 新配置: 并发数=8
      final stopwatch2 = Stopwatch()..start();
      await runConcurrent<int, String>(
        items: items,
        maxConcurrency: 8,
        task: (id) => simulateNetworkRequest(id, delayMs: taskDelayMs),
      );
      stopwatch2.stop();
      final newTime = stopwatch2.elapsedMilliseconds;

      print('');
      print('=' * 60);
      print('子分组并发性能测试结果');
      print('=' * 60);
      print('任务数量: $taskCount');
      print('单任务延迟: ${taskDelayMs}ms');
      print('-' * 60);
      print('旧配置 (并发=3): ${oldTime}ms');
      print('新配置 (并发=8): ${newTime}ms');
      print('加速比: ${(oldTime / newTime).toStringAsFixed(2)}x');
      print('=' * 60);

      // 理论时间:
      // 并发=3: ceil(24/3) * 30 = 8 * 30 = 240ms
      // 并发=8: ceil(24/8) * 30 = 3 * 30 = 90ms
      // 加速比应接近 2.67x

      expect(newTime, lessThan(oldTime));
      expect(oldTime / newTime, greaterThan(2.0));
    });

    test('模拟完整同步场景 (嵌套并发)', () async {
      // 模拟: 6个顶级组，每个组有4个子组
      const topLevelCount = 6;
      const childPerGroup = 4;
      const requestDelayMs = 20;

      // 模拟旧配置: 外层并发=2, 内层并发=3
      Future<List<String>> syncWithOldConfig() async {
        final results = <String>[];
        await runConcurrent<int, void>(
          items: List.generate(topLevelCount, (i) => i),
          maxConcurrency: 2, // 旧: 顶级并发=2
          task: (groupId) async {
            // 每个顶级组获取子组
            final childResults = await runConcurrent<int, String>(
              items: List.generate(childPerGroup, (i) => i),
              maxConcurrency: 3, // 旧: 子分组并发=3
              task: (childId) => simulateNetworkRequest(
                groupId * 10 + childId,
                delayMs: requestDelayMs,
              ),
            );
            results.addAll(childResults);
          },
        );
        return results;
      }

      // 模拟新配置: 外层并发=6, 内层并发=8
      Future<List<String>> syncWithNewConfig() async {
        final results = <String>[];
        await runConcurrent<int, void>(
          items: List.generate(topLevelCount, (i) => i),
          maxConcurrency: 6, // 新: 顶级并发=6
          task: (groupId) async {
            final childResults = await runConcurrent<int, String>(
              items: List.generate(childPerGroup, (i) => i),
              maxConcurrency: 8, // 新: 子分组并发=8
              task: (childId) => simulateNetworkRequest(
                groupId * 10 + childId,
                delayMs: requestDelayMs,
              ),
            );
            results.addAll(childResults);
          },
        );
        return results;
      }

      final stopwatch1 = Stopwatch()..start();
      final oldResults = await syncWithOldConfig();
      stopwatch1.stop();
      final oldTime = stopwatch1.elapsedMilliseconds;

      final stopwatch2 = Stopwatch()..start();
      final newResults = await syncWithNewConfig();
      stopwatch2.stop();
      final newTime = stopwatch2.elapsedMilliseconds;

      print('');
      print('=' * 60);
      print('完整同步场景模拟 (嵌套并发)');
      print('=' * 60);
      print('顶级组数: $topLevelCount');
      print('每组子分组数: $childPerGroup');
      print('总请求数: ${topLevelCount * childPerGroup}');
      print('单请求延迟: ${requestDelayMs}ms');
      print('-' * 60);
      print('旧配置 (外=2, 内=3): ${oldTime}ms');
      print('新配置 (外=6, 内=8): ${newTime}ms');
      print('加速比: ${(oldTime / newTime).toStringAsFixed(2)}x');
      print('=' * 60);

      // 验证结果数量正确
      expect(oldResults.length, equals(topLevelCount * childPerGroup));
      expect(newResults.length, equals(topLevelCount * childPerGroup));

      // 新配置应该更快
      expect(newTime, lessThan(oldTime));
    });

    test('错误处理: 部分任务失败不影响整体', () async {
      var successCount = 0;

      await runConcurrent<int, String?>(
        items: List.generate(10, (i) => i),
        maxConcurrency: 4,
        task: (id) async {
          await Future.delayed(const Duration(milliseconds: 10));
          if (id % 3 == 0) {
            throw Exception('Simulated failure for task $id');
          }
          return 'Success-$id';
        },
        onItemComplete: (item, result) {
          if (result != null) {
            successCount++;
          }
        },
      );

      // 任务 0, 3, 6, 9 会失败 (4个)
      // 任务 1, 2, 4, 5, 7, 8 成功 (6个)
      print('');
      print('错误处理测试: 成功=$successCount, 失败=${10 - successCount}');
      expect(successCount, equals(6));
    });

    test('边界情况: 空列表', () async {
      final results = await runConcurrent<int, String>(
        items: [],
        maxConcurrency: 4,
        task: (id) => simulateNetworkRequest(id),
      );

      expect(results, isEmpty);
    });

    test('边界情况: 并发数大于任务数', () async {
      final stopwatch = Stopwatch()..start();
      final results = await runConcurrent<int, String>(
        items: [1, 2, 3],
        maxConcurrency: 10, // 并发数 > 任务数
        task: (id) => simulateNetworkRequest(id, delayMs: 50),
      );
      stopwatch.stop();

      // 所有任务应该同时执行，总时间接近单个任务时间
      expect(results.length, equals(3));
      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // 应接近 50ms
    });
  });
}
