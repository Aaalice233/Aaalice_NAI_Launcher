import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/prompt_maximize_provider.dart';

void main() {
  test('setting the current value does not notify or persist again', () async {
    final storage = _FakeLocalStorage();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    var notifications = 0;
    final subscription = container.listen<bool>(
      promptMaximizeNotifierProvider,
      (_, _) => notifications++,
    );
    addTearDown(subscription.close);

    await container
        .read(promptMaximizeNotifierProvider.notifier)
        .setMaximized(false);

    expect(container.read(promptMaximizeNotifierProvider), isFalse);
    expect(notifications, 0);
    expect(storage.persistCount, 0);

    await container
        .read(promptMaximizeNotifierProvider.notifier)
        .setMaximized(true);

    expect(container.read(promptMaximizeNotifierProvider), isTrue);
    expect(notifications, 1);
    expect(storage.persistCount, 1);
  });
}

class _FakeLocalStorage extends LocalStorageService {
  bool maximized = false;
  int persistCount = 0;

  @override
  bool getPromptMaximized() => maximized;

  @override
  Future<void> setPromptMaximized(bool value) async {
    maximized = value;
    persistCount++;
  }
}
