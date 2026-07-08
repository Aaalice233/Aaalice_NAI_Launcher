import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation_layout_mode_provider.dart';

void main() {
  group('GenerationLayoutModeNotifier', () {
    test('storage 为空时默认 classic', () {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => _FakeStorage()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(generationLayoutModeNotifierProvider),
        GenerationLayoutMode.classic,
      );
    });

    test('从 storage 读取 web_style', () {
      final storage = _FakeStorage()..mode = 'web_style';
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
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
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(generationLayoutModeNotifierProvider),
        GenerationLayoutMode.classic,
      );
    });

    test('setMode 更新状态并写回 storage', () async {
      final storage = _FakeStorage();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(generationLayoutModeNotifierProvider.notifier);
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
  String mode = 'classic';

  @override
  String getGenerationLayoutMode() => mode;

  @override
  Future<void> setGenerationLayoutMode(String value) async {
    mode = value;
  }
}
