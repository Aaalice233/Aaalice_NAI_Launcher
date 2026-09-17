import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/pixel_snap/internal/pixel_snap_executor.dart';

void main() {
  group('IsolatePixelSnapExecutor.balanceByPitch', () {
    test('每个下标恰好出现一次', () {
      final List<double> pitches = <double>[3, 4, 5, 6, 8, 12, 16, 24, 3.5, 7];
      final List<List<int>> groups = IsolatePixelSnapExecutor.balanceByPitch(
        pitches,
        4,
      );
      final List<int> flat = groups.expand((List<int> g) => g).toList()..sort();
      expect(flat, List<int>.generate(pitches.length, (int i) => i));
    });

    test('把最贵的条目摊开而不是堆在同一片', () {
      // 三个间距 3 的条目开销相同，平均切片会把它们分到同一片。
      final List<double> pitches = <double>[3, 3, 3, 24, 24, 24];
      final List<List<int>> groups = IsolatePixelSnapExecutor.balanceByPitch(
        pitches,
        3,
      );
      for (final List<int> group in groups) {
        final int expensive = group.where((int i) => pitches[i] == 3).length;
        expect(expensive, 1);
      }
    });

    test('分片数多于条目数时不产生空分片', () {
      final List<List<int>> groups = IsolatePixelSnapExecutor.balanceByPitch(
        <double>[4, 8],
        8,
      );
      expect(groups.length, 2);
      expect(groups.every((List<int> g) => g.isNotEmpty), isTrue);
    });

    test('worker 数留一个核给 UI 并封顶 8', () {
      expect(IsolatePixelSnapExecutor.defaultWorkerCount(processorCount: 1), 1);
      expect(IsolatePixelSnapExecutor.defaultWorkerCount(processorCount: 4), 3);
      expect(
        IsolatePixelSnapExecutor.defaultWorkerCount(processorCount: 32),
        8,
      );
    });
  });
}
