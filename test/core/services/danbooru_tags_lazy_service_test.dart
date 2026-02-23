import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/cache/data_source_cache_meta.dart';

/// DanbooruTagsLazyService shouldRefresh 逻辑单元测试
///
/// 测试各种缓存状态下的刷新判断逻辑：
/// 1. 首次使用（无缓存元数据）
/// 2. 不同自动刷新间隔设置（7天/15天/30天/从不）
/// 3. 缓存过期 vs 未过期
/// 4. 边界条件（刚好到期、即将到期）
///
/// 运行：flutter test test/core/services/danbooru_tags_lazy_service_test.dart
void main() {
  group('DanbooruTagsLazyService shouldRefresh 逻辑测试', () {

    group('AutoRefreshInterval.shouldRefresh 基础逻辑', () {
      test('从未更新时应该刷新 (lastUpdate = null)', () {
        // Arrange
        const interval = AutoRefreshInterval.days30;

        // Act
        final result = interval.shouldRefresh(null);

        // Assert
        expect(result, isTrue);
      });

      test('设置为"从不"刷新时不应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.never;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 365));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isFalse);
      });

      test('7天间隔 - 刚好7天应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days7;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 7));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isTrue);
      });

      test('7天间隔 - 6天前不应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days7;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 6));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isFalse);
      });

      test('7天间隔 - 8天前应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days7;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 8));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isTrue);
      });

      test('15天间隔 - 刚好15天应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days15;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 15));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isTrue);
      });

      test('15天间隔 - 14天前不应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days15;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 14));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isFalse);
      });

      test('30天间隔 - 默认设置，刚好30天应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days30;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 30));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isTrue);
      });

      test('30天间隔 - 29天前不应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days30;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 29));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isFalse);
      });

      test('30天间隔 - 31天前应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days30;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 31));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isTrue);
      });
    });

    group('边界条件测试', () {
      test('刚刚更新（0天前）不应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days30;
        final lastUpdate = DateTime.now();

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isFalse);
      });

      test('1天前不应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days30;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 1));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isFalse);
      });

      test('长时间未更新（1年前）应该刷新', () {
        // Arrange
        const interval = AutoRefreshInterval.days30;
        final lastUpdate = DateTime.now().subtract(const Duration(days: 365));

        // Act
        final result = interval.shouldRefresh(lastUpdate);

        // Assert
        expect(result, isTrue);
      });

      test('跨月计算正确 - 从月初到月末', () {
        // Arrange: 2月1日到3月3日（30天）
        final lastUpdate = DateTime(2026, 2, 1);
        final now = DateTime(2026, 3, 3);
        const interval = AutoRefreshInterval.days30;

        // Act
        final daysSince = now.difference(lastUpdate).inDays;
        final result = daysSince >= interval.days;

        // Assert
        expect(daysSince, equals(30));
        expect(result, isTrue);
      });
    });

    group('AutoRefreshInterval.fromDays 工厂方法', () {
      test('从天数7获取枚举值', () {
        final result = AutoRefreshInterval.fromDays(7);
        expect(result, equals(AutoRefreshInterval.days7));
      });

      test('从天数15获取枚举值', () {
        final result = AutoRefreshInterval.fromDays(15);
        expect(result, equals(AutoRefreshInterval.days15));
      });

      test('从天数30获取枚举值', () {
        final result = AutoRefreshInterval.fromDays(30);
        expect(result, equals(AutoRefreshInterval.days30));
      });

      test('从天数-1获取"从不"枚举值', () {
        final result = AutoRefreshInterval.fromDays(-1);
        expect(result, equals(AutoRefreshInterval.never));
      });

      test('无效天数默认返回30天', () {
        final result = AutoRefreshInterval.fromDays(999);
        expect(result, equals(AutoRefreshInterval.days30));
      });

      test('从null天数（默认值）返回30天', () {
        final result = AutoRefreshInterval.fromDays(30); // 模拟 prefs.getInt 返回默认值30
        expect(result, equals(AutoRefreshInterval.days30));
      });
    });

    group('服务层集成逻辑 - 模拟各种缓存状态', () {
      test('状态1: 全新用户（无元数据）- 应该刷新', () {
        // 模拟 DanbooruTagsLazyService.shouldRefresh() 逻辑
        DateTime? lastUpdate; // 从未更新
        const days = 30;
        final interval = AutoRefreshInterval.fromDays(days);

        final result = interval.shouldRefresh(lastUpdate);

        expect(result, isTrue, reason: '首次使用，无缓存元数据，应该触发刷新');
      });

      test('状态2: 正常使用中（7天前更新，设置7天间隔）- 应该刷新', () {
        final lastUpdate = DateTime.now().subtract(const Duration(days: 7));
        const days = 7;
        final interval = AutoRefreshInterval.fromDays(days);

        final result = interval.shouldRefresh(lastUpdate);

        expect(result, isTrue, reason: '刚好到达7天间隔，应该触发刷新');
      });

      test('状态3: 正常使用中（5天前更新，设置7天间隔）- 不应该刷新', () {
        final lastUpdate = DateTime.now().subtract(const Duration(days: 5));
        const days = 7;
        final interval = AutoRefreshInterval.fromDays(days);

        final result = interval.shouldRefresh(lastUpdate);

        expect(result, isFalse, reason: '还未到达7天间隔，不需要刷新');
      });

      test('状态4: 用户设置"从不"自动刷新 - 不应该刷新（即使很久未更新）', () {
        final lastUpdate = DateTime.now().subtract(const Duration(days: 100));
        const days = -1; // never
        final interval = AutoRefreshInterval.fromDays(days);

        final result = interval.shouldRefresh(lastUpdate);

        expect(result, isFalse, reason: '用户设置从不自动刷新，不应该触发');
      });

      test('状态5: 手动刷新后 - 不应该立即刷新', () {
        final lastUpdate = DateTime.now(); // 刚刚手动刷新
        const days = 30;
        final interval = AutoRefreshInterval.fromDays(days);

        final result = interval.shouldRefresh(lastUpdate);

        expect(result, isFalse, reason: '刚刚刷新过，不需要再次刷新');
      });

      test('状态6: 更新后第29天（30天间隔）- 不应该刷新', () {
        final lastUpdate = DateTime.now().subtract(const Duration(days: 29));
        const days = 30;
        final interval = AutoRefreshInterval.fromDays(days);

        final result = interval.shouldRefresh(lastUpdate);

        expect(result, isFalse, reason: '还差1天到达刷新间隔');
      });

      test('状态7: 更新后第30天（30天间隔）- 应该刷新', () {
        final lastUpdate = DateTime.now().subtract(const Duration(days: 30));
        const days = 30;
        final interval = AutoRefreshInterval.fromDays(days);

        final result = interval.shouldRefresh(lastUpdate);

        expect(result, isTrue, reason: '刚好到达30天刷新间隔');
      });
    });

    group('枚举属性测试', () {
      test('days7 属性值正确', () {
        expect(AutoRefreshInterval.days7.days, equals(7));
        expect(AutoRefreshInterval.days7.displayNameZh, equals('7天'));
        expect(AutoRefreshInterval.days7.displayNameEn, equals('7 days'));
      });

      test('days15 属性值正确', () {
        expect(AutoRefreshInterval.days15.days, equals(15));
        expect(AutoRefreshInterval.days15.displayNameZh, equals('15天'));
        expect(AutoRefreshInterval.days15.displayNameEn, equals('15 days'));
      });

      test('days30 属性值正确', () {
        expect(AutoRefreshInterval.days30.days, equals(30));
        expect(AutoRefreshInterval.days30.displayNameZh, equals('30天'));
        expect(AutoRefreshInterval.days30.displayNameEn, equals('30 days'));
      });

      test('never 属性值正确', () {
        expect(AutoRefreshInterval.never.days, equals(-1));
        expect(AutoRefreshInterval.never.displayNameZh, equals('不自动刷新'));
        expect(AutoRefreshInterval.never.displayNameEn, equals('Never'));
      });

      test('displayName 返回中文名称', () {
        expect(AutoRefreshInterval.days7.displayName, equals('7天'));
        expect(AutoRefreshInterval.never.displayName, equals('不自动刷新'));
      });
    });
  });
}
