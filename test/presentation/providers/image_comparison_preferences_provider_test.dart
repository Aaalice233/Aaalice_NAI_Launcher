import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/image_comparison_preferences_provider.dart';

void main() {
  test('follow preference survives provider container recreation', () async {
    final storage = _Storage();
    ProviderContainer open() => ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    final first = open();
    expect(first.read(imageComparisonFollowMouseProvider), isFalse);
    await first
        .read(imageComparisonFollowMouseProvider.notifier)
        .setEnabled(true);
    expect(storage.values[StorageKeys.imageComparisonFollowMouse], isTrue);
    first.dispose();
    final second = open();
    expect(second.read(imageComparisonFollowMouseProvider), isTrue);
    await second
        .read(imageComparisonFollowMouseProvider.notifier)
        .setEnabled(false);
    second.dispose();
    final third = open();
    expect(third.read(imageComparisonFollowMouseProvider), isFalse);
    third.dispose();
  });
}

class _Storage extends LocalStorageService {
  final values = <String, Object?>{};
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      values[key] as T? ?? defaultValue;
  @override
  Future<void> setSetting<T>(String key, T value) async => values[key] = value;
}
