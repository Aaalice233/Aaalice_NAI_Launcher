import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';

void main() {
  group('SidebarWidthStatePersistence', () {
    late Box settingsBox;

    setUp(() async {
      // Initialize Hive for testing
      Hive.init('./test_hive');

      // Open settings box
      settingsBox = await Hive.openBox(StorageKeys.settingsBox);
    });

    tearDown(() async {
      // 清理测试数据
      await settingsBox.delete(StorageKeys.historyPanelWidth);
      await settingsBox.close();
      await Hive.close();
    });

    test('should return default width when no value is stored', () async {
      final savedWidth = settingsBox.get(
        StorageKeys.historyPanelWidth,
        defaultValue: 280.0,
      ) as double;

      expect(savedWidth, 280.0,
          reason: 'Should return default width of 280.0 when no value is stored');
    });

    test('should save width to storage', () async {
      const testWidth = 350.0;

      await settingsBox.put(StorageKeys.historyPanelWidth, testWidth);

      final retrievedWidth =
          settingsBox.get(StorageKeys.historyPanelWidth) as double;

      expect(retrievedWidth, testWidth,
          reason: 'Should save and retrieve the correct width value');
    });

    test('should retrieve previously saved width', () async {
      const testWidth = 320.0;

      // 保存宽度
      await settingsBox.put(StorageKeys.historyPanelWidth, testWidth);

      // 重新获取
      final retrievedWidth = settingsBox.get(
        StorageKeys.historyPanelWidth,
        defaultValue: 280.0,
      ) as double;

      expect(retrievedWidth, testWidth,
          reason: 'Should retrieve the previously saved width value');
    });

    test('should persist width across box reopen', () async {
      const testWidth = 300.0;

      // 在第一个 box 实例中保存宽度
      await settingsBox.put(StorageKeys.historyPanelWidth, testWidth);
      expect(
          settingsBox.get(StorageKeys.historyPanelWidth) as double, testWidth);

      // 关闭并重新打开 box (模拟应用重启)
      await settingsBox.close();

      // Reopen the box and update the reference
      settingsBox = await Hive.openBox(StorageKeys.settingsBox);

      // 新 box 实例应该能读取到之前保存的宽度
      final retrievedWidth = settingsBox.get(
        StorageKeys.historyPanelWidth,
        defaultValue: 280.0,
      ) as double;

      expect(retrievedWidth, testWidth,
          reason: 'Width should persist across box reopen (app restart)');
    });

    test('should update width when saved multiple times', () async {
      const width1 = 290.0;
      const width2 = 340.0;
      const width3 = 310.0;

      // 保存不同的宽度值
      await settingsBox.put(StorageKeys.historyPanelWidth, width1);
      expect(settingsBox.get(StorageKeys.historyPanelWidth) as double, width1);

      await settingsBox.put(StorageKeys.historyPanelWidth, width2);
      expect(settingsBox.get(StorageKeys.historyPanelWidth) as double, width2);

      await settingsBox.put(StorageKeys.historyPanelWidth, width3);
      expect(settingsBox.get(StorageKeys.historyPanelWidth) as double, width3);

      expect(
          settingsBox.get(StorageKeys.historyPanelWidth) as double, width3,
          reason: 'Should update to the most recently saved width');
    });

    test('should handle minimum width boundary', () async {
      const minWidth = 200.0;

      await settingsBox.put(StorageKeys.historyPanelWidth, minWidth);

      final retrievedWidth =
          settingsBox.get(StorageKeys.historyPanelWidth) as double;

      expect(retrievedWidth, minWidth,
          reason: 'Should handle minimum width boundary (200.0)');
    });

    test('should handle maximum width boundary', () async {
      const maxWidth = 400.0;

      await settingsBox.put(StorageKeys.historyPanelWidth, maxWidth);

      final retrievedWidth =
          settingsBox.get(StorageKeys.historyPanelWidth) as double;

      expect(retrievedWidth, maxWidth,
          reason: 'Should handle maximum width boundary (400.0)');
    });

    test('should handle values within valid range', () async {
      final validWidths = [220.0, 280.0, 310.0, 350.0, 380.0];

      for (final width in validWidths) {
        await settingsBox.put(StorageKeys.historyPanelWidth, width);
        final retrievedWidth =
            settingsBox.get(StorageKeys.historyPanelWidth) as double;

        expect(retrievedWidth, width,
            reason: 'Should correctly store and retrieve width: $width');
      }
    });

    test('should handle rapid save operations', () async {
      // 快速保存多个不同的宽度值
      for (var i = 0; i < 50; i++) {
        final width = 200.0 + (i * 4); // 200.0 to 396.0
        await settingsBox.put(StorageKeys.historyPanelWidth, width);
      }

      // 最后保存的值应该是 396.0
      final finalWidth =
          settingsBox.get(StorageKeys.historyPanelWidth) as double;

      expect(finalWidth, 396.0,
          reason: 'Should handle rapid save operations correctly');
    });

    test('should delete width value', () async {
      const testWidth = 300.0;

      // 保存宽度
      await settingsBox.put(StorageKeys.historyPanelWidth, testWidth);
      expect(settingsBox.get(StorageKeys.historyPanelWidth), testWidth);

      // 删除宽度
      await settingsBox.delete(StorageKeys.historyPanelWidth);

      // 删除后应该返回默认值
      final retrievedWidth = settingsBox.get(
        StorageKeys.historyPanelWidth,
        defaultValue: 280.0,
      ) as double;

      expect(retrievedWidth, 280.0,
          reason: 'Should return default value after deletion');
    });

    test('should handle floating point precision correctly', () async {
      const preciseWidth = 314.159265359;

      await settingsBox.put(StorageKeys.historyPanelWidth, preciseWidth);

      final retrievedWidth =
          settingsBox.get(StorageKeys.historyPanelWidth) as double;

      expect(
          retrievedWidth,
          closeTo(preciseWidth, 0.0001),
          reason:
              'Should handle floating point precision correctly within tolerance');
    });

    test('should handle zero width value', () async {
      const zeroWidth = 0.0;

      await settingsBox.put(StorageKeys.historyPanelWidth, zeroWidth);

      final retrievedWidth =
          settingsBox.get(StorageKeys.historyPanelWidth) as double;

      expect(retrievedWidth, zeroWidth,
          reason: 'Should handle zero width value (though UI should clamp it)');
    });

    test('should handle negative width value', () async {
      const negativeWidth = -100.0;

      await settingsBox.put(StorageKeys.historyPanelWidth, negativeWidth);

      final retrievedWidth =
          settingsBox.get(StorageKeys.historyPanelWidth) as double;

      expect(retrievedWidth, negativeWidth,
          reason:
              'Should store negative value (though UI should clamp to valid range)');
    });

    test('should handle very large width value', () async {
      const largeWidth = 99999.0;

      await settingsBox.put(StorageKeys.historyPanelWidth, largeWidth);

      final retrievedWidth =
          settingsBox.get(StorageKeys.historyPanelWidth) as double;

      expect(retrievedWidth, largeWidth,
          reason:
              'Should store very large value (though UI should clamp to valid range)');
    });

    test('should verify width persistence after clear', () async {
      const testWidth = 350.0;

      // 保存宽度
      await settingsBox.put(StorageKeys.historyPanelWidth, testWidth);
      expect(settingsBox.get(StorageKeys.historyPanelWidth), testWidth);

      // 清空整个 box
      await settingsBox.clear();

      // 清空后应该返回默认值
      final retrievedWidth = settingsBox.get(
        StorageKeys.historyPanelWidth,
        defaultValue: 280.0,
      ) as double;

      expect(retrievedWidth, 280.0,
          reason: 'Should return default value after clearing the box');
    });

    test('should contain the key after saving', () async {
      const testWidth = 330.0;

      expect(settingsBox.containsKey(StorageKeys.historyPanelWidth), false,
          reason: 'Key should not exist before saving');

      await settingsBox.put(StorageKeys.historyPanelWidth, testWidth);

      expect(settingsBox.containsKey(StorageKeys.historyPanelWidth), true,
          reason: 'Key should exist after saving');
    });

    test('should not contain the key after deletion', () async {
      const testWidth = 330.0;

      await settingsBox.put(StorageKeys.historyPanelWidth, testWidth);
      expect(settingsBox.containsKey(StorageKeys.historyPanelWidth), true);

      await settingsBox.delete(StorageKeys.historyPanelWidth);

      expect(settingsBox.containsKey(StorageKeys.historyPanelWidth), false,
          reason: 'Key should not exist after deletion');
    });
  });
}
