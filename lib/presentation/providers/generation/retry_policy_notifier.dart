import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/local_storage_service.dart';

part 'retry_policy_notifier.g.dart';

/// 重试策略配置
///
/// 包含图片生成失败时的重试逻辑配置：
/// - 最大重试次数
/// - 重试间隔
/// - 是否启用重试
/// - 退避倍数
@Riverpod(keepAlive: true)
class RetryPolicyNotifier extends _$RetryPolicyNotifier {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  RetryPolicy build() {
    return RetryPolicy(
      maxRetries: _storage.getSetting<int>(
            _StorageKeys.maxRetries,
            defaultValue: RetryPolicy.defaultMaxRetries,
          ) ??
          RetryPolicy.defaultMaxRetries,
      retryIntervalMs: _storage.getSetting<int>(
            _StorageKeys.retryIntervalMs,
            defaultValue: RetryPolicy.defaultRetryIntervalMs,
          ) ??
          RetryPolicy.defaultRetryIntervalMs,
      retryEnabled: _storage.getSetting<bool>(
            _StorageKeys.retryEnabled,
            defaultValue: RetryPolicy.defaultRetryEnabled,
          ) ??
          RetryPolicy.defaultRetryEnabled,
      backoffMultiplier: _storage.getSetting<double>(
            _StorageKeys.backoffMultiplier,
            defaultValue: RetryPolicy.defaultBackoffMultiplier,
          ) ??
          RetryPolicy.defaultBackoffMultiplier,
    );
  }

  /// 设置最大重试次数
  void setMaxRetries(int value) {
    final clampedValue = value.clamp(0, 10);
    state = state.copyWith(maxRetries: clampedValue);
    _storage.setSetting(_StorageKeys.maxRetries, clampedValue);
  }

  /// 设置重试间隔（毫秒）
  void setRetryIntervalMs(int value) {
    final clampedValue = value.clamp(500, 30000);
    state = state.copyWith(retryIntervalMs: clampedValue);
    _storage.setSetting(_StorageKeys.retryIntervalMs, clampedValue);
  }

  /// 切换重试启用状态
  void toggleRetryEnabled() => setRetryEnabled(!state.retryEnabled);

  /// 设置是否启用重试
  void setRetryEnabled(bool value) {
    state = state.copyWith(retryEnabled: value);
    _storage.setSetting(_StorageKeys.retryEnabled, value);
  }

  /// 设置退避倍数
  void setBackoffMultiplier(double value) {
    final clampedValue = value.clamp(1.0, 5.0);
    state = state.copyWith(backoffMultiplier: clampedValue);
    _storage.setSetting(_StorageKeys.backoffMultiplier, clampedValue);
  }

  /// 重置为默认配置
  void resetToDefaults() {
    state = const RetryPolicy();
    _storage
      ..setSetting(_StorageKeys.maxRetries, RetryPolicy.defaultMaxRetries)
      ..setSetting(
          _StorageKeys.retryIntervalMs, RetryPolicy.defaultRetryIntervalMs)
      ..setSetting(_StorageKeys.retryEnabled, RetryPolicy.defaultRetryEnabled)
      ..setSetting(
          _StorageKeys.backoffMultiplier, RetryPolicy.defaultBackoffMultiplier);
  }

  /// 获取指定重试次数的延迟时间（支持指数退避）
  Duration getRetryDelay(int attempt) {
    if (!state.retryEnabled || attempt >= state.maxRetries) {
      return Duration.zero;
    }
    final delayMs =
        state.retryIntervalMs * state.backoffMultiplier.pow(attempt);
    return Duration(milliseconds: delayMs.toInt());
  }

  /// 检查是否应该重试
  bool shouldRetry(int currentAttempt) {
    return state.retryEnabled && currentAttempt < state.maxRetries;
  }
}

/// 重试策略配置数据类
class RetryPolicy {
  final int maxRetries;
  final int retryIntervalMs;
  final bool retryEnabled;
  final double backoffMultiplier;

  const RetryPolicy({
    this.maxRetries = defaultMaxRetries,
    this.retryIntervalMs = defaultRetryIntervalMs,
    this.retryEnabled = defaultRetryEnabled,
    this.backoffMultiplier = defaultBackoffMultiplier,
  });

  static const int defaultMaxRetries = 3;
  static const int defaultRetryIntervalMs = 1000;
  static const bool defaultRetryEnabled = true;
  static const double defaultBackoffMultiplier = 1.5;

  RetryPolicy copyWith({
    int? maxRetries,
    int? retryIntervalMs,
    bool? retryEnabled,
    double? backoffMultiplier,
  }) {
    return RetryPolicy(
      maxRetries: maxRetries ?? this.maxRetries,
      retryIntervalMs: retryIntervalMs ?? this.retryIntervalMs,
      retryEnabled: retryEnabled ?? this.retryEnabled,
      backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
    );
  }
}

/// 存储键名
class _StorageKeys {
  static const String maxRetries = 'image_generation_max_retries';
  static const String retryIntervalMs = 'image_generation_retry_interval_ms';
  static const String retryEnabled = 'image_generation_retry_enabled';
  static const String backoffMultiplier = 'image_generation_backoff_multiplier';
}

/// 扩展方法：计算幂
extension _DoublePowExtension on double {
  double pow(int exponent) {
    if (exponent == 0) return 1.0;
    var result = 1.0;
    var base = this;
    var exp = exponent;
    while (exp > 0) {
      if (exp % 2 == 1) {
        result *= base;
      }
      base *= base;
      exp ~/= 2;
    }
    return result;
  }
}
