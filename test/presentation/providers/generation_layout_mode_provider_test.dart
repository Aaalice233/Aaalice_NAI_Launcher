import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation_layout_mode_provider.dart';

void main() {
  group('GenerationLayoutModeNotifier', () {
    test('真实 storage 缺少布局键时默认 web_style', () {
      final storage = LocalStorageService();
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(storage.getGenerationLayoutMode(), 'web_style');
      expect(
        container.read(generationLayoutModeNotifierProvider),
        GenerationLayoutMode.webStyle,
      );
    });

    test('从 storage 读取 web_style', () {
      final storage = _FakeStorage()..mode = 'web_style';
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(generationLayoutModeNotifierProvider),
        GenerationLayoutMode.webStyle,
      );
    });

    test('未知 storage 值回落到 classic', () {
      final storage = _FakeStorage()..mode = 'bogus_value';
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(generationLayoutModeNotifierProvider),
        GenerationLayoutMode.classic,
      );
    });

    test('setMode 更新状态并写回 storage', () async {
      final storage = _FakeStorage()..mode = 'classic';
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        generationLayoutModeNotifierProvider.notifier,
      );
      await notifier.setMode(GenerationLayoutMode.webStyle);

      expect(
        container.read(generationLayoutModeNotifierProvider),
        GenerationLayoutMode.webStyle,
      );
      expect(storage.mode, 'web_style');
    });
  });
}

class _FakeStorage extends LocalStorageService {
  String mode = 'web_style';

  @override
  String getGenerationLayoutMode() => mode;

  @override
  Future<void> setGenerationLayoutMode(String value) async {
    mode = value;
  }
}
