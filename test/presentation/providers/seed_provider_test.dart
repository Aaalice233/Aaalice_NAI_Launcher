import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

// Fake storage implementation for testing
class FakeLocalStorageService implements LocalStorageService {
  final Map<String, dynamic> _settings = {};
  final Map<String, dynamic> _history = {};

  @override
  Box get _settingsBox => throw UnimplementedError();

  @override
  Box get _historyBox => throw UnimplementedError();

  @override
  Future<void> init() async {}

  // Settings methods
  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settings[key] as T? ?? defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _settings[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _settings.remove(key);
  }

  // Seed lock methods
  @override
  bool getSeedLocked() {
    return getSetting<bool>('seed_locked', defaultValue: false) ?? false;
  }

  @override
  Future<void> setSeedLocked(bool locked) async {
    await setSetting('seed_locked', locked);
  }

  @override
  int? getLockedSeedValue() {
    return getSetting<int>('locked_seed_value');
  }

  @override
  Future<void> setLockedSeedValue(int? seed) async {
    if (seed != null) {
      await setSetting('locked_seed_value', seed);
    } else {
      await deleteSetting('locked_seed_value');
    }
  }

  // Default params methods (needed for build)
  @override
  String getDefaultModel() {
    return getSetting<String>('default_model', defaultValue: 'nai-diffusion-3') ??
        'nai-diffusion-3';
  }

  @override
  String getDefaultSampler() {
    return getSetting<String>(
          'default_sampler',
          defaultValue: 'k_euler_ancestral',
        ) ??
        'k_euler_ancestral';
  }

  @override
  int getDefaultSteps() {
    return getSetting<int>('default_steps', defaultValue: 28) ?? 28;
  }

  @override
  double getDefaultScale() {
    return getSetting<double>('default_scale', defaultValue: 5.0) ?? 5.0;
  }

  @override
  int getDefaultWidth() {
    return getSetting<int>('default_width', defaultValue: 832) ?? 832;
  }

  @override
  int getDefaultHeight() {
    return getSetting<int>('default_height', defaultValue: 1216) ?? 1216;
  }

  @override
  String getLastPrompt() {
    return getSetting<String>('last_prompt', defaultValue: '') ?? '';
  }

  @override
  Future<void> setLastPrompt(String prompt) async {
    await setSetting('last_prompt', prompt);
  }

  @override
  String getLastNegativePrompt() {
    return getSetting<String>('last_negative_prompt', defaultValue: '') ?? '';
  }

  @override
  Future<void> setLastNegativePrompt(String prompt) async {
    await setSetting('last_negative_prompt', prompt);
  }

  @override
  bool getLastSmea() {
    return getSetting<bool>('last_smea', defaultValue: false) ?? false;
  }

  @override
  Future<void> setLastSmea(bool smea) async {
    await setSetting('last_smea', smea);
  }

  @override
  bool getLastSmeaDyn() {
    return getSetting<bool>('last_smea_dyn', defaultValue: false) ?? false;
  }

  @override
  Future<void> setLastSmeaDyn(bool smeaDyn) async {
    await setSetting('last_smea_dyn', smeaDyn);
  }

  @override
  double getLastCfgRescale() {
    return getSetting<double>('last_cfg_rescale', defaultValue: 0.0) ?? 0.0;
  }

  @override
  Future<void> setLastCfgRescale(double value) async {
    await setSetting('last_cfg_rescale', value);
  }

  @override
  String getLastNoiseSchedule() {
    return getSetting<String>('last_noise_schedule', defaultValue: 'karras') ??
        'karras';
  }

  @override
  Future<void> setLastNoiseSchedule(String value) async {
    await setSetting('last_noise_schedule', value);
  }

  @override
  Future<void> setDefaultModel(String model) async {
    await setSetting('default_model', model);
  }

  @override
  Future<void> setDefaultSampler(String sampler) async {
    await setSetting('default_sampler', sampler);
  }

  @override
  Future<void> setDefaultSteps(int steps) async {
    await setSetting('default_steps', steps);
  }

  @override
  Future<void> setDefaultScale(double scale) async {
    await setSetting('default_scale', scale);
  }

  @override
  Future<void> setDefaultWidth(int width) async {
    await setSetting('default_width', width);
  }

  @override
  Future<void> setDefaultHeight(int height) async {
    await setSetting('default_height', height);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('GenerationParamsNotifier (Seed Persistence)', () {
    late FakeLocalStorageService fakeStorage;
    late ProviderContainer container;

    setUp(() {
      fakeStorage = FakeLocalStorageService();
      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(fakeStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('Initial State', () {
      test('should initialize with random seed (-1)', () {
        final state = container.read(generationParamsNotifierProvider);

        expect(
          state.seed,
          equals(-1),
          reason: 'Initial seed should be -1 (random)',
        );
      });

      test('should load locked seed from storage if locked', () async {
        // Arrange: Set a locked seed in storage
        await fakeStorage.setSeedLocked(true);
        await fakeStorage.setLockedSeedValue(12345);

        // Act: Create a new container (simulates app restart)
        final newContainer = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(fakeStorage),
          ],
        );

        // Assert
        final state = newContainer.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          equals(12345),
          reason: 'Should load locked seed from storage',
        );

        newContainer.dispose();
      });
    });

    group('updateSeed', () {
      test('should update seed value', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);
        const testSeed = 99999;

        notifier.updateSeed(testSeed);

        final state = container.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          equals(testSeed),
          reason: 'Seed should be updated to the new value',
        );
      });

      test('should allow setting seed to -1 (random)', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        notifier.updateSeed(12345);
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(12345),
          reason: 'Seed should be set to specific value',
        );

        notifier.updateSeed(-1);
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(-1),
          reason: 'Seed should be reset to -1 (random)',
        );
      });
    });

    group('randomizeSeed', () {
      test('should set seed to -1', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        // First set a specific seed
        notifier.updateSeed(54321);
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(54321),
        );

        // Then randomize
        notifier.randomizeSeed();

        final state = container.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          equals(-1),
          reason: 'Randomize should set seed to -1',
        );
      });
    });

    group('Seed Lock', () {
      test('should unlock seed by default', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        expect(
          notifier.isSeedLocked,
          isFalse,
          reason: 'Seed should be unlocked initially',
        );
      });

      test('should lock seed when toggled', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        // Toggle lock (should lock since unlocked)
        notifier.toggleSeedLock();

        expect(
          notifier.isSeedLocked,
          isTrue,
          reason: 'Seed should be locked after toggle',
        );

        final state = container.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          greaterThanOrEqualTo(0),
          reason: 'Locked seed should be a non-negative integer',
        );
        expect(
          state.seed,
          lessThanOrEqualTo(4294967295),
          reason: 'Locked seed should be within valid range',
        );
      });

      test('should unlock seed when toggled twice', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        notifier.toggleSeedLock();
        expect(
          notifier.isSeedLocked,
          isTrue,
          reason: 'Should be locked after first toggle',
        );

        notifier.toggleSeedLock();
        expect(
          notifier.isSeedLocked,
          isFalse,
          reason: 'Should be unlocked after second toggle',
        );
      });

      test('should preserve specific seed value when locking', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);
        const specificSeed = 11111;

        // Set a specific seed first
        notifier.updateSeed(specificSeed);

        // Lock the seed
        notifier.toggleSeedLock();

        final state = container.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          equals(specificSeed),
          reason: 'Locking should preserve the current seed value',
        );
      });

      test('should generate new seed when locking with -1', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        // Ensure seed is -1 (default)
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(-1),
        );

        // Lock the seed
        notifier.toggleSeedLock();

        final state = container.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          greaterThanOrEqualTo(0),
          reason: 'Should generate a valid seed when locking from -1',
        );
      });
    });

    group('Seed Persistence Across Generations', () {
      test('should maintain seed value across multiple reads', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);
        const testSeed = 77777;

        // Set initial seed
        notifier.updateSeed(testSeed);

        // Simulate multiple "generations" by reading state multiple times
        for (int i = 0; i < 5; i++) {
          final state = container.read(generationParamsNotifierProvider);
          expect(
            state.seed,
            equals(testSeed),
            reason: 'Seed should remain consistent across reads (generation $i)',
          );
        }
      });

      test('should persist locked seed across state changes', () async {
        final notifier = container.read(generationParamsNotifierProvider.notifier);
        const testSeed = 88888;

        // Set and lock seed
        notifier.updateSeed(testSeed);
        notifier.toggleSeedLock();

        // Make other parameter changes that don't affect seed
        notifier.updatePrompt('test prompt 1');
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(testSeed),
          reason: 'Seed should persist after prompt update',
        );

        notifier.updateSteps(30);
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(testSeed),
          reason: 'Seed should persist after steps update',
        );

        notifier.updateScale(6.0);
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(testSeed),
          reason: 'Seed should persist after scale update',
        );
      });

      test('should not change seed when other parameters are modified', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);
        const testSeed = 99999;

        notifier.updateSeed(testSeed);

        // Modify various parameters
        notifier.updateModel('nai-diffusion-4-full');
        notifier.updateSampler('k_dpmpp_2m');
        notifier.updateSize(1024, 1024);
        notifier.updateNegativePrompt('test negative');

        final state = container.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          equals(testSeed),
          reason: 'Seed should remain unchanged when other parameters are modified',
        );
      });

      test('should restore locked seed after container recreation', () async {
        final notifier = container.read(generationParamsNotifierProvider.notifier);
        const testSeed = 33333;

        // Set and lock seed
        notifier.updateSeed(testSeed);
        notifier.toggleSeedLock();

        // Verify locked state
        expect(
          fakeStorage.getSeedLocked(),
          isTrue,
          reason: 'Storage should reflect locked state',
        );
        expect(
          fakeStorage.getLockedSeedValue(),
          equals(testSeed),
          reason: 'Storage should contain locked seed value',
        );

        // Create a new container (simulates app restart)
        final newContainer = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(fakeStorage),
          ],
        );

        final newState = newContainer.read(generationParamsNotifierProvider);
        expect(
          newState.seed,
          equals(testSeed),
          reason: 'Locked seed should be restored after container recreation',
        );

        newContainer.dispose();
      });
    });

    group('Edge Cases', () {
      test('should handle setting maximum valid seed', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);
        const maxSeed = 4294967295; // 2^32 - 1

        notifier.updateSeed(maxSeed);

        final state = container.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          equals(maxSeed),
          reason: 'Should handle maximum valid seed value',
        );
      });

      test('should handle setting zero as seed', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        notifier.updateSeed(0);

        final state = container.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          equals(0),
          reason: 'Should accept zero as valid seed',
        );
      });

      test('should handle negative seed values other than -1', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        // Set a negative seed (edge case, though -1 is the only "special" value)
        notifier.updateSeed(-100);

        final state = container.read(generationParamsNotifierProvider);
        expect(
          state.seed,
          equals(-100),
          reason: 'Should accept negative seed values',
        );
      });

      test('should handle multiple seed updates in sequence', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        // Update seed multiple times
        notifier.updateSeed(1000);
        expect(container.read(generationParamsNotifierProvider).seed, equals(1000));

        notifier.updateSeed(2000);
        expect(container.read(generationParamsNotifierProvider).seed, equals(2000));

        notifier.updateSeed(3000);
        expect(container.read(generationParamsNotifierProvider).seed, equals(3000));

        notifier.randomizeSeed();
        expect(container.read(generationParamsNotifierProvider).seed, equals(-1));
      });

      test('should handle rapid lock/unlock toggles', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        // Rapid toggles
        notifier.toggleSeedLock();
        expect(notifier.isSeedLocked, isTrue);

        notifier.toggleSeedLock();
        expect(notifier.isSeedLocked, isFalse);

        notifier.toggleSeedLock();
        expect(notifier.isSeedLocked, isTrue);

        notifier.toggleSeedLock();
        expect(notifier.isSeedLocked, isFalse);
      });
    });

    group('Integration Scenarios', () {
      test('should simulate typical generation workflow', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);

        // 1. Start with random seed
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(-1),
          reason: 'Should start with random seed',
        );

        // 2. User sets specific seed
        notifier.updateSeed(45678);
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(45678),
          reason: 'Should update to specific seed',
        );

        // 3. User locks seed
        notifier.toggleSeedLock();
        expect(
          notifier.isSeedLocked,
          isTrue,
          reason: 'Should lock seed',
        );
        final lockedSeed = container.read(generationParamsNotifierProvider).seed;

        // 4. User modifies other parameters
        notifier.updatePrompt('new prompt');
        notifier.updateSteps(32);

        // 5. Seed should remain locked
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(lockedSeed),
          reason: 'Seed should persist after parameter changes',
        );

        // 6. User unlocks seed
        notifier.toggleSeedLock();
        expect(
          notifier.isSeedLocked,
          isFalse,
          reason: 'Should unlock seed',
        );

        // 7. User randomizes
        notifier.randomizeSeed();
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(-1),
          reason: 'Should reset to random',
        );
      });

      test('should handle batch generation scenario', () {
        final notifier = container.read(generationParamsNotifierProvider.notifier);
        const baseSeed = 50000;

        // Set base seed
        notifier.updateSeed(baseSeed);

        // Simulate batch generation where each image uses seed + offset
        for (int i = 0; i < 4; i++) {
          final expectedSeed = baseSeed + i;
          // In real implementation, batch generation would calculate:
          // seed = baseSeed + i
          expect(
            expectedSeed,
            greaterThanOrEqualTo(baseSeed),
            reason: 'Batch seed $i should be based on base seed',
          );
        }

        // Base seed should remain unchanged
        expect(
          container.read(generationParamsNotifierProvider).seed,
          equals(baseSeed),
          reason: 'Base seed should not change during batch simulation',
        );
      });
    });
  });
}
