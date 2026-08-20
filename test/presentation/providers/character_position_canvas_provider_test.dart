import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/character_position_canvas_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_maximize_provider.dart';

final _availabilityProvider = StateProvider<bool>((ref) => true);

void main() {
  test('availability requires positioning support, characters and an idle non-error state', () {
    expect(
      isCharacterPositionCanvasAvailable(
        supportsCharacterPositioning: true,
        hasCharacters: true,
        isGenerating: false,
        hasError: false,
      ),
      isTrue,
    );
    expect(
      isCharacterPositionCanvasAvailable(
        supportsCharacterPositioning: false,
        hasCharacters: true,
        isGenerating: false,
        hasError: false,
      ),
      isFalse,
    );
    expect(
      isCharacterPositionCanvasAvailable(
        supportsCharacterPositioning: true,
        hasCharacters: false,
        isGenerating: false,
        hasError: false,
      ),
      isFalse,
    );
    expect(
      isCharacterPositionCanvasAvailable(
        supportsCharacterPositioning: true,
        hasCharacters: true,
        isGenerating: true,
        hasError: false,
      ),
      isFalse,
    );
    expect(
      isCharacterPositionCanvasAvailable(
        supportsCharacterPositioning: true,
        hasCharacters: true,
        isGenerating: false,
        hasError: true,
      ),
      isFalse,
    );
  });

  group('CharacterPositionCanvas', () {
    test('web style keeps the persisted classic maximize preference', () async {
      final storage = _FakeCanvasStorage(
        generationLayoutMode: 'web_style',
        promptMaximized: true,
      );
      final container = _buildContainer(storage);
      addTearDown(container.dispose);
      final subscription = container.listen<bool>(
        characterPositionCanvasProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      container.read(characterPositionCanvasProvider.notifier).open();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(characterPositionCanvasProvider), isTrue);
      expect(container.read(promptMaximizeNotifierProvider), isTrue);
      expect(storage.promptMaximized, isTrue);
    });

    test('classic style exits maximize before opening the canvas', () async {
      final storage = _FakeCanvasStorage(
        generationLayoutMode: 'classic',
        promptMaximized: true,
      );
      final container = _buildContainer(storage);
      addTearDown(container.dispose);
      final subscription = container.listen<bool>(
        characterPositionCanvasProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      container.read(characterPositionCanvasProvider.notifier).open();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(characterPositionCanvasProvider), isTrue);
      expect(container.read(promptMaximizeNotifierProvider), isFalse);
      expect(storage.promptMaximized, isFalse);
    });

    test('becoming unavailable closes an open canvas', () async {
      final container = _buildContainer(_FakeCanvasStorage());
      addTearDown(container.dispose);
      final subscription = container.listen<bool>(
        characterPositionCanvasProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      container.read(characterPositionCanvasProvider.notifier).open();
      expect(container.read(characterPositionCanvasProvider), isTrue);

      container.read(_availabilityProvider.notifier).state = false;
      await Future<void>.delayed(Duration.zero);

      expect(container.read(characterPositionCanvasProvider), isFalse);
    });

    test('cannot open while the canvas is unavailable', () {
      final container = _buildContainer(_FakeCanvasStorage());
      addTearDown(container.dispose);
      container.read(_availabilityProvider.notifier).state = false;

      container.read(characterPositionCanvasProvider.notifier).open();

      expect(container.read(characterPositionCanvasProvider), isFalse);
    });
  });
}

ProviderContainer _buildContainer(_FakeCanvasStorage storage) {
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWith((ref) => storage),
      characterPositionCanvasAvailableProvider.overrideWith(
        (ref) => ref.watch(_availabilityProvider),
      ),
    ],
  );
}

class _FakeCanvasStorage extends LocalStorageService {
  _FakeCanvasStorage({
    this.generationLayoutMode = 'web_style',
    this.promptMaximized = false,
  });

  String generationLayoutMode;
  bool promptMaximized;

  @override
  String getGenerationLayoutMode() => generationLayoutMode;

  @override
  bool getPromptMaximized() => promptMaximized;

  @override
  Future<void> setPromptMaximized(bool value) async {
    promptMaximized = value;
  }
}
