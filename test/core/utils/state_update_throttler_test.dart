import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/state_update_throttler.dart';

/// 状态更新节流器全面测试
///
/// 测试内容：
/// 1. 基本节流功能
/// 2. leading 参数行为
/// 3. trailing 参数行为
/// 4. 批量更新功能
/// 5. flush 和 cancel 方法
/// 6. reset 和 dispose 方法
/// 7. 节流器管理器功能
void main() {
  group('StateUpdateThrottler 测试', () {
    group('基本节流功能', () {
      test('首次调用立即执行（leading=true）', () async {
        final updatedValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          onUpdate: updatedValues.add,
        );

        throttler.throttle(1);

        // 立即执行
        expect(updatedValues, equals([1]));
        expect(throttler.isThrottling, isTrue);

        throttler.dispose();
      });

      test('首次调用不立即执行（leading=false）', () async {
        final updatedValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: false,
          onUpdate: updatedValues.add,
        );

        throttler.throttle(1);

        // 不立即执行
        expect(updatedValues, isEmpty);
        expect(throttler.hasPendingUpdate, isTrue);
        expect(throttler.pendingValue, equals(1));

        // 等待节流间隔结束，触发 trailing 更新
        await Future.delayed(const Duration(milliseconds: 150));

        expect(updatedValues, equals([1]));
        throttler.dispose();
      });

      test('节流间隔内调用只保留最新值', () async {
        final updatedValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          onUpdate: updatedValues.add,
        );

        throttler.throttle(1);
        throttler.throttle(2);
        throttler.throttle(3);

        // 只立即执行了第一个值
        expect(updatedValues, equals([1]));
        expect(throttler.pendingValue, equals(3));

        // 等待 trailing 执行
        await Future.delayed(const Duration(milliseconds: 150));

        // 只执行了最新的挂起值
        expect(updatedValues, equals([1, 3]));
        throttler.dispose();
      });

      test('超出节流间隔后调用立即执行', () async {
        final updatedValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 50),
          leading: true,
          onUpdate: updatedValues.add,
        );

        throttler.throttle(1);
        await Future.delayed(const Duration(milliseconds: 100));
        throttler.throttle(2);
        await Future.delayed(const Duration(milliseconds: 100));
        throttler.throttle(3);

        expect(updatedValues, equals([1, 2, 3]));
        throttler.dispose();
      });
    });

    group('trailing 参数测试', () {
      test('trailing=true 时在间隔结束时执行挂起更新', () async {
        final updatedValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          trailing: true,
          onUpdate: updatedValues.add,
        );

        throttler.throttle(1);
        throttler.throttle(2);

        expect(updatedValues, equals([1]));

        await Future.delayed(const Duration(milliseconds: 150));

        // trailing 执行了挂起的值
        expect(updatedValues, equals([1, 2]));
        throttler.dispose();
      });

      test('trailing=false 时不执行挂起更新', () async {
        final updatedValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          trailing: false,
          onUpdate: updatedValues.add,
        );

        throttler.throttle(1);
        throttler.throttle(2);

        expect(updatedValues, equals([1]));

        await Future.delayed(const Duration(milliseconds: 150));

        // trailing 不执行，所以只有第一个值
        expect(updatedValues, equals([1]));
        throttler.dispose();
      });
    });

    group('批量更新测试', () {
      test('throttleAll 立即批量执行（leading=true）', () async {
        final batchValues = <List<int>>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          onBatchUpdate: batchValues.add,
        );

        throttler.throttleAll([1, 2, 3]);

        expect(batchValues, equals([[1, 2, 3]]));
        throttler.dispose();
      });

      test('throttleAll 在节流间隔内收集批量值', () async {
        final batchValues = <List<int>>[];
        final singleValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          trailing: true,
          onUpdate: singleValues.add,
          onBatchUpdate: batchValues.add,
        );

        throttler.throttle(1);
        throttler.throttleAll([2, 3]);
        throttler.throttle(4);

        expect(singleValues, equals([1]));
        expect(throttler.pendingBatch, equals([2, 3, 4]));

        await Future.delayed(const Duration(milliseconds: 150));

        // 批量回调优先于单个回调
        expect(batchValues, equals([[1], [2, 3, 4]]));
        expect(singleValues, equals([1]));
        throttler.dispose();
      });

      test('throttleAll 空列表不执行', () async {
        final batchValues = <List<int>>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          onBatchUpdate: batchValues.add,
        );

        throttler.throttleAll([]);

        expect(batchValues, isEmpty);
        throttler.dispose();
      });
    });

    group('flush 方法测试', () {
      test('flush 立即执行挂起的批量更新', () async {
        final batchValues = <List<int>>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          onBatchUpdate: batchValues.add,
        );

        throttler.throttle(1);
        throttler.throttle(2);
        throttler.throttle(3);

        expect(batchValues, equals([[1]]));

        throttler.flush();

        // flush 执行了挂起的批量值
        expect(batchValues, equals([[1], [2, 3]]));
        expect(throttler.hasPendingUpdate, isFalse);
        expect(throttler.isThrottling, isFalse);
        throttler.dispose();
      });

      test('flush 立即执行挂起的单个值', () async {
        final singleValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: false,
          trailing: false,
          onUpdate: singleValues.add,
        );

        throttler.throttle(1);
        expect(singleValues, isEmpty);

        throttler.flush();

        expect(singleValues, equals([1]));
        expect(throttler.hasPendingUpdate, isFalse);
        throttler.dispose();
      });
    });

    group('cancel 方法测试', () {
      test('cancel 清除挂起的更新不执行', () async {
        final singleValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          trailing: true,
          onUpdate: singleValues.add,
        );

        throttler.throttle(1);
        throttler.throttle(2);

        expect(throttler.hasPendingUpdate, isTrue);

        throttler.cancel();

        expect(throttler.hasPendingUpdate, isFalse);
        expect(throttler.isThrottling, isFalse);

        // 等待原定时器时间
        await Future.delayed(const Duration(milliseconds: 150));

        // 没有执行 trailing 更新
        expect(singleValues, equals([1]));
        throttler.dispose();
      });
    });

    group('reset 方法测试', () {
      test('reset 恢复到初始状态', () async {
        final singleValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          onUpdate: singleValues.add,
        );

        throttler.throttle(1);
        throttler.throttle(2);

        expect(singleValues, equals([1]));

        throttler.reset();

        // 重置后再次调用应该像首次调用一样
        throttler.throttle(3);

        // 因为 leading=true，应该立即执行
        expect(singleValues, equals([1, 3]));
        throttler.dispose();
      });

      test('reset 清除所有状态', () {
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          onUpdate: (_) {},
        );

        throttler.throttle(1);
        expect(throttler.timeSinceLastUpdate, isNotNull);

        throttler.reset();

        expect(throttler.timeSinceLastUpdate, isNull);
        expect(throttler.hasPendingUpdate, isFalse);
        expect(throttler.isThrottling, isFalse);
        throttler.dispose();
      });
    });

    group('dispose 方法测试', () {
      test('dispose 释放资源', () {
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          onUpdate: (_) {},
        );

        throttler.throttle(1);
        throttler.throttle(2);

        expect(throttler.isThrottling, isTrue);
        expect(throttler.hasPendingUpdate, isTrue);

        throttler.dispose();

        expect(throttler.isThrottling, isFalse);
        expect(throttler.pendingBatch, isEmpty);
      });
    });

    group('属性 getter 测试', () {
      test('timeSinceLastUpdate 返回正确时间差', () async {
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
          onUpdate: (_) {},
        );

        expect(throttler.timeSinceLastUpdate, isNull);

        throttler.throttle(1);
        final time1 = throttler.timeSinceLastUpdate;
        expect(time1, isNotNull);

        await Future.delayed(const Duration(milliseconds: 50));
        final time2 = throttler.timeSinceLastUpdate;
        expect(time2, greaterThan(time1!));

        throttler.dispose();
      });

      test('pendingBatch 返回不可修改列表', () {
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: false,
          onUpdate: (_) {},
        );

        throttler.throttle(1);
        throttler.throttle(2);

        final batch = throttler.pendingBatch;
        expect(batch, equals([1, 2]));

        // 尝试修改应该抛出异常
        expect(() => (batch as List<int>).add(3), throwsUnsupportedError);

        throttler.dispose();
      });
    });

    group('边界情况测试', () {
      test('密集调用只按预期频率执行', () async {
        final singleValues = <int>[];
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 50),
          leading: true,
          trailing: true,
          onUpdate: singleValues.add,
        );

        // 快速连续调用 10 次
        for (int i = 0; i < 10; i++) {
          throttler.throttle(i);
        }

        // 等待所有 trailing 更新完成
        await Future.delayed(const Duration(milliseconds: 100));

        // 第一次立即执行，最后一次 trailing 执行
        // 中间的值被合并
        expect(singleValues.length, lessThan(10));
        expect(singleValues.first, equals(0));
        expect(singleValues.last, equals(9));

        throttler.dispose();
      });

      test('没有回调时不抛出异常', () {
        final throttler = StateUpdateThrottler<int>(
          throttleInterval: const Duration(milliseconds: 100),
          leading: true,
        );

        // 没有设置 onUpdate 和 onBatchUpdate
        expect(() => throttler.throttle(1), returnsNormally);
        expect(() => throttler.throttleAll([1, 2]), returnsNormally);
        expect(() => throttler.flush(), returnsNormally);

        throttler.dispose();
      });
    });
  });

  group('StateUpdateThrottlerManager 测试', () {
    tearDown(() {
      StateUpdateThrottlerManager.clear();
    });

    test('getOrCreate 创建新节流器', () {
      final throttler = StateUpdateThrottlerManager.getOrCreate<int>(
        'test_key',
        throttleInterval: const Duration(milliseconds: 100),
        onUpdate: (_) {},
      );

      expect(throttler, isNotNull);
      expect(StateUpdateThrottlerManager.keys, equals(['test_key']));
      expect(StateUpdateThrottlerManager.hasKey('test_key'), isTrue);
    });

    test('getOrCreate 返回已存在的节流器', () {
      final throttler1 = StateUpdateThrottlerManager.getOrCreate<int>(
        'test_key',
        throttleInterval: const Duration(milliseconds: 100),
        onUpdate: (_) {},
      );

      final throttler2 = StateUpdateThrottlerManager.getOrCreate<int>(
        'test_key',
        throttleInterval: const Duration(milliseconds: 200), // 不同参数
        onUpdate: (_) {},
      );

      expect(throttler1, same(throttler2));
    });

    test('get 返回已存在的节流器', () {
      final throttler = StateUpdateThrottlerManager.getOrCreate<int>(
        'test_key',
        throttleInterval: const Duration(milliseconds: 100),
        onUpdate: (_) {},
      );

      final retrieved = StateUpdateThrottlerManager.get<int>('test_key');

      expect(retrieved, same(throttler));
    });

    test('get 返回 null 如果不存在', () {
      final retrieved = StateUpdateThrottlerManager.get<int>('non_existent');
      expect(retrieved, isNull);
    });

    test('remove 移除指定节流器', () {
      StateUpdateThrottlerManager.getOrCreate<int>(
        'key1',
        throttleInterval: const Duration(milliseconds: 100),
        onUpdate: (_) {},
      );
      StateUpdateThrottlerManager.getOrCreate<int>(
        'key2',
        throttleInterval: const Duration(milliseconds: 100),
        onUpdate: (_) {},
      );

      expect(StateUpdateThrottlerManager.keys.length, equals(2));

      StateUpdateThrottlerManager.remove('key1');

      expect(StateUpdateThrottlerManager.keys, equals(['key2']));
      expect(StateUpdateThrottlerManager.hasKey('key1'), isFalse);
    });

    test('clear 移除所有节流器', () {
      StateUpdateThrottlerManager.getOrCreate<int>(
        'key1',
        throttleInterval: const Duration(milliseconds: 100),
        onUpdate: (_) {},
      );
      StateUpdateThrottlerManager.getOrCreate<int>(
        'key2',
        throttleInterval: const Duration(milliseconds: 100),
        onUpdate: (_) {},
      );

      expect(StateUpdateThrottlerManager.keys.length, equals(2));

      StateUpdateThrottlerManager.clear();

      expect(StateUpdateThrottlerManager.keys, isEmpty);
    });

    test('keys 返回不可修改列表', () {
      StateUpdateThrottlerManager.getOrCreate<int>(
        'key1',
        throttleInterval: const Duration(milliseconds: 100),
        onUpdate: (_) {},
      );

      final keys = StateUpdateThrottlerManager.keys;
      expect(keys, equals(['key1']));

      // 尝试修改应该抛出异常
      expect(() => (keys as List<String>).add('key2'), throwsUnsupportedError);
    });
  });
}
