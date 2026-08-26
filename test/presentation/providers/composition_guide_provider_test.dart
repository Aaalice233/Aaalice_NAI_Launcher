import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/composition_guide_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/composition_guide.dart';

void main() {
  group('CompositionGuideNotifier', () {
    ProviderContainer containerWith(_FakeStorage storage) {
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('未设置时关闭参考线并用 3×3 网格', () {
      final container = containerWith(_FakeStorage());
      final settings = container.read(compositionGuideNotifierProvider);

      expect(settings.mode, CompositionGuideMode.none);
      expect(settings.columns, CompositionGuide.defaultDivisions);
      expect(settings.rows, CompositionGuide.defaultDivisions);
    });

    test('读取已保存的档位与网格', () {
      final container = containerWith(
        _FakeStorage()
          ..mode = 'phi'
          ..columns = 5
          ..rows = 8,
      );
      final settings = container.read(compositionGuideNotifierProvider);

      expect(settings.mode, CompositionGuideMode.phi);
      expect(settings.columns, 5);
      expect(settings.rows, 8);
    });

    test('storage 里的越界网格读出后夹到合法区间', () {
      final container = containerWith(
        _FakeStorage()
          ..columns = 999
          ..rows = 1,
      );
      final settings = container.read(compositionGuideNotifierProvider);

      expect(settings.columns, CompositionGuide.maxDivisions);
      expect(settings.rows, CompositionGuide.minDivisions);
    });

    test('storage 里的非法档位回落到 none', () {
      final container = containerWith(_FakeStorage()..mode = 'bogus');

      expect(
        container.read(compositionGuideNotifierProvider).mode,
        CompositionGuideMode.none,
      );
    });

    test('setMode 写回 storage 且不动网格', () async {
      final storage = _FakeStorage()..columns = 4;
      final container = containerWith(storage);
      final notifier = container.read(
        compositionGuideNotifierProvider.notifier,
      );

      await notifier.setMode(CompositionGuideMode.grid);

      expect(storage.mode, 'grid');
      expect(container.read(compositionGuideNotifierProvider).columns, 4);
    });

    test('setColumns/setRows 夹到合法区间后持久化', () async {
      final storage = _FakeStorage();
      final container = containerWith(storage);
      final notifier = container.read(
        compositionGuideNotifierProvider.notifier,
      );

      await notifier.setColumns(99);
      await notifier.setRows(0);

      final settings = container.read(compositionGuideNotifierProvider);
      expect(settings.columns, CompositionGuide.maxDivisions);
      expect(settings.rows, CompositionGuide.minDivisions);
      expect(storage.columns, CompositionGuide.maxDivisions);
      expect(storage.rows, CompositionGuide.minDivisions);
    });

    test('重复设置同一值不再写 storage', () async {
      final storage = _FakeStorage()
        ..mode = 'thirds'
        ..rows = CompositionGuide.minDivisions;
      final container = containerWith(storage);
      final notifier = container.read(
        compositionGuideNotifierProvider.notifier,
      );

      await notifier.setMode(CompositionGuideMode.thirds);
      await notifier.setColumns(CompositionGuide.defaultDivisions);
      // 夹取后与当前值相同，同样不该写盘
      await notifier.setRows(1);

      expect(storage.writeCount, 0);
    });
  });
}

class _FakeStorage extends LocalStorageService {
  String? mode;
  int columns = CompositionGuide.defaultDivisions;
  int rows = CompositionGuide.defaultDivisions;
  int writeCount = 0;

  @override
  String? getCompositionGuideMode() => mode;

  @override
  Future<void> setCompositionGuideMode(String value) async {
    mode = value;
    writeCount++;
  }

  @override
  int getCompositionGuideColumns() => columns;

  @override
  Future<void> setCompositionGuideColumns(int value) async {
    columns = value;
    writeCount++;
  }

  @override
  int getCompositionGuideRows() => rows;

  @override
  Future<void> setCompositionGuideRows(int value) async {
    rows = value;
    writeCount++;
  }
}
