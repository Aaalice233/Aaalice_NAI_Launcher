import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/preview_transparency_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/transparency_background.dart';

void main() {
  group('PreviewTransparencyNotifier', () {
    ProviderContainer containerWith(_FakeStorage storage) {
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('未设置时默认主题棋盘格', () {
      final container = containerWith(_FakeStorage());

      expect(
        container.read(previewTransparencyNotifierProvider),
        TransparencyBackgrounds.checker,
      );
    });

    test('读取已保存的档位', () {
      final container = containerWith(
        _FakeStorage()..style = TransparencyBackgrounds.checkerDark,
      );

      expect(
        container.read(previewTransparencyNotifierProvider),
        TransparencyBackgrounds.checkerDark,
      );
    });

    test('storage 里的非法值回落到默认档位', () {
      final container = containerWith(_FakeStorage()..style = 'bogus');

      expect(
        container.read(previewTransparencyNotifierProvider),
        TransparencyBackgrounds.checker,
      );
    });

    test('setStyle 归一化后写回 storage', () async {
      final storage = _FakeStorage();
      final container = containerWith(storage);
      final notifier = container.read(
        previewTransparencyNotifierProvider.notifier,
      );

      await notifier.setStyle('#AABBCC');

      expect(container.read(previewTransparencyNotifierProvider), '#aabbcc');
      expect(storage.style, '#aabbcc');
    });

    test('setStyle 收到非法值时落到默认档位并持久化', () async {
      final storage = _FakeStorage()..style = 'red';
      final container = containerWith(storage);
      final notifier = container.read(
        previewTransparencyNotifierProvider.notifier,
      );

      await notifier.setStyle('nonsense');

      expect(
        container.read(previewTransparencyNotifierProvider),
        TransparencyBackgrounds.checker,
      );
      expect(storage.style, TransparencyBackgrounds.checker);
    });

    test('重复设置同一档位不再写 storage', () async {
      final storage = _FakeStorage()..style = 'red';
      final container = containerWith(storage);
      final notifier = container.read(
        previewTransparencyNotifierProvider.notifier,
      );

      await notifier.setStyle('red');

      expect(storage.writeCount, 0);
    });
  });
}

class _FakeStorage extends LocalStorageService {
  String? style;
  int writeCount = 0;

  @override
  String? getPreviewTransparencyBackground() => style;

  @override
  Future<void> setPreviewTransparencyBackground(String value) async {
    style = value;
    writeCount++;
  }
}
