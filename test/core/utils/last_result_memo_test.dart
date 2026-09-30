import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/last_result_memo.dart';

void main() {
  group('LastResultMemo', () {
    test('相等的键直接返回上一次结果，不再计算', () {
      final memo = LastResultMemo<(String, int), List<String>>();
      var computeCount = 0;
      List<String> compute((String, int) key) {
        computeCount++;
        return List.filled(key.$2, key.$1);
      }

      final first = memo.resolve(('a', 2), compute);
      final second = memo.resolve(('a', 2), compute);

      expect(second, same(first));
      expect(computeCount, 1);
    });

    test('键变化时重新计算，并只保留最新一份结果', () {
      final memo = LastResultMemo<String, String>();
      final computed = <String>[];
      String compute(String key) {
        computed.add(key);
        return key.toUpperCase();
      }

      expect(memo.resolve('a', compute), 'A');
      expect(memo.resolve('b', compute), 'B');
      expect(memo.resolve('a', compute), 'A');
      expect(computed, ['a', 'b', 'a']);
    });

    test('列表键按身份判等，内容相同的新列表也会重新计算', () {
      final memo = LastResultMemo<List<int>, int>();
      var computeCount = 0;
      int sum(List<int> values) {
        computeCount++;
        return values.fold(0, (total, value) => total + value);
      }

      final values = [1, 2, 3];
      expect(memo.resolve(values, sum), 6);
      expect(memo.resolve(values, sum), 6);
      expect(computeCount, 1);

      expect(memo.resolve([1, 2, 3], sum), 6);
      expect(computeCount, 2);
    });

    test('计算抛错不会留下结果，下一次同键调用会重新计算', () {
      final memo = LastResultMemo<String, String>()
        ..resolve('stale', (key) => key);
      var attempts = 0;
      String flaky(String key) {
        attempts++;
        if (attempts == 1) throw StateError('compute failed');
        return 'value-$key';
      }

      expect(() => memo.resolve('key', flaky), throwsStateError);
      expect(memo.resolve('key', flaky), 'value-key');
      expect(attempts, 2);
    });

    test('可空结果同样被记忆', () {
      final memo = LastResultMemo<String, String?>();
      var computeCount = 0;
      String? compute(String key) {
        computeCount++;
        return null;
      }

      expect(memo.resolve('key', compute), isNull);
      expect(memo.resolve('key', compute), isNull);
      expect(computeCount, 1);
    });
  });
}
