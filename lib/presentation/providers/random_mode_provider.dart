import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/prompt/random_prompt_result.dart';
import '../../core/storage/local_storage_service.dart';

part 'random_mode_provider.g.dart';

const _defaultRandomGenerationMode = RandomGenerationMode.naiOfficial;

/// 将持久化字符串还原为随机生成模式。
///
/// 未知值回退到官网模式，避免旧版本或损坏配置阻断启动。
RandomGenerationMode randomGenerationModeFromStorage(String value) {
  return switch (value) {
    'nai_official' => RandomGenerationMode.naiOfficial,
    'custom' => RandomGenerationMode.custom,
    'hybrid' => RandomGenerationMode.hybrid,
    _ => _defaultRandomGenerationMode,
  };
}

/// 随机生成模式持久化值。
extension RandomGenerationModeStorageX on RandomGenerationMode {
  String toStorageValue() {
    return switch (this) {
      RandomGenerationMode.naiOfficial => 'nai_official',
      RandomGenerationMode.custom => 'custom',
      RandomGenerationMode.hybrid => 'hybrid',
    };
  }
}

/// 随机生成模式 Provider
///
/// 管理用户选择的随机提示词生成模式
@Riverpod(keepAlive: true)
class RandomModeNotifier extends _$RandomModeNotifier {
  @override
  RandomGenerationMode build() {
    final storage = ref.read(localStorageServiceProvider);
    return randomGenerationModeFromStorage(storage.getRandomGenerationMode());
  }

  /// 设置生成模式
  Future<void> setMode(RandomGenerationMode mode) async {
    final previousMode = state;
    state = mode;
    try {
      await ref
          .read(localStorageServiceProvider)
          .setRandomGenerationMode(mode.toStorageValue());
    } catch (e, stack) {
      state = previousMode;
      AppLogger.e('Failed to persist random generation mode', e, stack);
    }
  }

  /// 切换到官网模式
  Future<void> useNaiOfficial() {
    return setMode(RandomGenerationMode.naiOfficial);
  }

  /// 切换到自定义模式
  Future<void> useCustom() {
    return setMode(RandomGenerationMode.custom);
  }

  /// 切换到混合模式
  Future<void> useHybrid() {
    return setMode(RandomGenerationMode.hybrid);
  }

  /// 切换模式
  Future<void> toggle() {
    final nextMode = switch (state) {
      RandomGenerationMode.naiOfficial => RandomGenerationMode.custom,
      RandomGenerationMode.custom => RandomGenerationMode.hybrid,
      RandomGenerationMode.hybrid => RandomGenerationMode.naiOfficial,
    };
    return setMode(nextMode);
  }
}

/// 便捷 Provider：是否为官网模式
@riverpod
bool isNaiOfficialMode(Ref ref) {
  return ref.watch(randomModeNotifierProvider) ==
      RandomGenerationMode.naiOfficial;
}

/// 便捷 Provider：是否为自定义模式
@riverpod
bool isCustomMode(Ref ref) {
  return ref.watch(randomModeNotifierProvider) == RandomGenerationMode.custom;
}

/// 便捷 Provider：是否为混合模式
@riverpod
bool isHybridMode(Ref ref) {
  return ref.watch(randomModeNotifierProvider) == RandomGenerationMode.hybrid;
}
