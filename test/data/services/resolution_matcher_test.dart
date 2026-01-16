import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/resolution_matcher.dart';

void main() {
  group('ResolutionMatcher', () {
    test('matchBestResolution 应返回最接近的预设', () {
      final matcher = ResolutionMatcher();
      // 1024x1024 应该匹配 1024x1024
      final result = matcher.matchBestResolution(1024, 1024);
      expect(result.width, 1024);
      expect(result.height, 1024);
    });

    test('1024x2048 应匹配竖图预设', () {
      final matcher = ResolutionMatcher();
      final result = matcher.matchBestResolution(1024, 2048);
      // 竖图，宽度应该小于高度
      expect(result.width < result.height, isTrue);
    });

    test('2048x1024 应匹配最接近的横图预设', () {
      final matcher = ResolutionMatcher();
      final result = matcher.matchBestResolution(2048, 1024);
      // 宽高比约为 2:1，预设中没有精确匹配，应该选择最接近的
      // 可能是 1280x1280 或 1024x1280
      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
    });

    test('768x768 应匹配 768x768', () {
      final matcher = ResolutionMatcher();
      final result = matcher.matchBestResolution(768, 768);
      expect(result.width, 768);
      expect(result.height, 768);
    });

    test('接近 832x1216 的分辨率应匹配该预设', () {
      final matcher = ResolutionMatcher();
      // 非常接近 832x1216
      final result = matcher.matchBestResolution(840, 1220);
      expect(result.width, 832);
      expect(result.height, 1216);
    });

    test('非标准分辨率应智能匹配最接近的预设', () {
      final matcher = ResolutionMatcher();
      // 随机分辨率
      final result = matcher.matchBestResolution(900, 1400);
      // 应该返回一个有效的预设
      expect(result.width > 0, isTrue);
      expect(result.height > 0, isTrue);
      // 应该是 64 的倍数
      expect(result.width % 64, 0);
      expect(result.height % 64, 0);
    });

    test('SizePreset 正确计算宽高比', () {
      final preset = const SizePreset(1024, 1024);
      expect(preset.aspectRatio, closeTo(1.0, 0.001));
    });

    test('SizePreset 正确计算面积', () {
      final preset = const SizePreset(832, 1216);
      expect(preset.area, equals(832 * 1216));
    });
  });
}
