import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/cache/data_source_cache_meta.dart';

void main() {
  test('AutoRefreshInterval 按持久化天数恢复，未知值使用默认档位', () {
    expect(AutoRefreshInterval.fromDays(7), AutoRefreshInterval.days7);
    expect(AutoRefreshInterval.fromDays(15), AutoRefreshInterval.days15);
    expect(AutoRefreshInterval.fromDays(30), AutoRefreshInterval.days30);
    expect(AutoRefreshInterval.fromDays(-1), AutoRefreshInterval.never);
    expect(AutoRefreshInterval.fromDays(999), AutoRefreshInterval.days30);
  });

  test('AutoRefreshInterval 只在达到间隔后刷新', () {
    final now = DateTime.now();

    expect(AutoRefreshInterval.days7.shouldRefresh(null), isTrue);
    expect(
      AutoRefreshInterval.days7.shouldRefresh(
        now.subtract(const Duration(days: 6)),
      ),
      isFalse,
    );
    expect(
      AutoRefreshInterval.days7.shouldRefresh(
        now.subtract(const Duration(days: 8)),
      ),
      isTrue,
    );
    expect(
      AutoRefreshInterval.never.shouldRefresh(
        now.subtract(const Duration(days: 365)),
      ),
      isFalse,
    );
  });
}
