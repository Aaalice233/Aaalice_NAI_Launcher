import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_panel_expansion_provider.dart';

class _MemoryStorage extends LocalStorageService {
  _MemoryStorage([Map<String, Object?>? initial])
    : values = Map<String, Object?>.from(initial ?? const {});

  final Map<String, Object?> values;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = values[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}

void main() {
  ProviderContainer buildContainer(_MemoryStorage storage) {
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('旧用户缺失配置时所有工作台二级菜单默认收起', () {
    final container = buildContainer(_MemoryStorage());
    final state = container.read(generationPanelExpansionProvider);

    for (final panel in GenerationWorkbenchPanel.values) {
      expect(state.isExpanded(panel), isFalse, reason: panel.name);
    }
  });

  test('分别恢复每个菜单状态并忽略异常旧值', () {
    final storage = _MemoryStorage({
      StorageKeys.generationParamsMenuExpanded: true,
      StorageKeys.characterPanelExpanded: true,
      StorageKeys.reversePromptExpanded: false,
      StorageKeys.img2imgExpanded: 'broken',
      StorageKeys.vibeTransferExpanded: true,
      StorageKeys.preciseRefExpanded: true,
    });
    final state = buildContainer(
      storage,
    ).read(generationPanelExpansionProvider);

    expect(
      state.isExpanded(GenerationWorkbenchPanel.generationParameters),
      isTrue,
    );
    expect(state.isExpanded(GenerationWorkbenchPanel.characters), isTrue);
    expect(state.isExpanded(GenerationWorkbenchPanel.reversePrompt), isFalse);
    expect(state.isExpanded(GenerationWorkbenchPanel.img2img), isFalse);
    expect(state.isExpanded(GenerationWorkbenchPanel.vibeTransfer), isTrue);
    expect(state.isExpanded(GenerationWorkbenchPanel.preciseReference), isTrue);
  });

  test('切换只更新目标菜单并写入对应 key', () async {
    final storage = _MemoryStorage({StorageKeys.reversePromptExpanded: true});
    final container = buildContainer(storage);
    final notifier = container.read(generationPanelExpansionProvider.notifier);

    await notifier.toggle(GenerationWorkbenchPanel.characters);

    final state = container.read(generationPanelExpansionProvider);
    expect(state.isExpanded(GenerationWorkbenchPanel.characters), isTrue);
    expect(state.isExpanded(GenerationWorkbenchPanel.reversePrompt), isTrue);
    expect(storage.values[StorageKeys.characterPanelExpanded], isTrue);
    expect(storage.values[StorageKeys.reversePromptExpanded], isTrue);
  });

  test('Provider 重建后从持久化状态恢复', () async {
    final storage = _MemoryStorage();
    final first = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
    );
    await first
        .read(generationPanelExpansionProvider.notifier)
        .setExpanded(GenerationWorkbenchPanel.preciseReference, true);
    first.dispose();

    final second = buildContainer(storage);
    expect(
      second
          .read(generationPanelExpansionProvider)
          .isExpanded(GenerationWorkbenchPanel.preciseReference),
      isTrue,
    );
  });
}
