import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_user_info_api_service.dart';
import '../../data/models/user/user_subscription.dart';
import 'auth_provider.dart';

part 'subscription_provider.g.dart';

/// 订阅状态 Notifier
///
/// 管理用户订阅信息和 Anlas 余额
@riverpod
class SubscriptionNotifier extends _$SubscriptionNotifier {
  AuthState? _previousAuthState;
  bool _hasInitiallyLoaded = false;

  @override
  SubscriptionState build() {
    // Watch authentication state changes
    final authState = ref.watch(authNotifierProvider);

    // React to authentication state changes
    if (_previousAuthState != null) {
      if (authState.isAuthenticated && !_previousAuthState!.isAuthenticated) {
        // Login succeeded - fetch subscription info
        Future.microtask(() => fetchSubscription());
      } else if (!authState.isAuthenticated &&
          _previousAuthState!.isAuthenticated) {
        // Logged out - clear subscription info
        state = const SubscriptionState.initial();
        _hasInitiallyLoaded = false;
      }
    } else if (authState.isAuthenticated && !_hasInitiallyLoaded) {
      // First build and already authenticated - fetch subscription
      // 使用 _hasInitiallyLoaded 标记避免重复加载（预热阶段可能已加载）
      Future.microtask(() => fetchSubscription());
    }

    // Store current auth state for next comparison
    _previousAuthState = authState;

    return const SubscriptionState.initial();
  }

  /// 获取订阅信息
  Future<void> fetchSubscription() async {
    // 避免重复加载
    if (state.isLoading) return;
    
    // 如果已经加载过且不是错误状态，跳过（使用缓存）
    if (_hasInitiallyLoaded && !state.isError) {
      AppLogger.i('Subscription already loaded, skipping', 'Subscription');
      return;
    }

    state = const SubscriptionState.loading();

    try {
      final apiService = ref.read(naiUserInfoApiServiceProvider);
      final data = await apiService.getUserSubscription();
      final subscription = UserSubscription.fromJson(data);
      state = SubscriptionState.loaded(subscription);
      _hasInitiallyLoaded = true;

      AppLogger.i(
        'Subscription loaded: ${subscription.tierName}, '
            'Anlas: ${subscription.anlasBalance}',
        'Subscription',
      );
    } catch (e) {
      AppLogger.e('Failed to fetch subscription: $e', 'Subscription');
      state = SubscriptionState.error(e.toString());
      // 即使失败也标记为已尝试加载，避免无限重试
      _hasInitiallyLoaded = true;
    }
  }

  /// 重置加载状态（用于强制刷新）
  void resetLoadState() {
    _hasInitiallyLoaded = false;
  }

  /// 刷新余额（生成后调用）
  Future<void> refreshBalance() async {
    // 保持当前状态，静默刷新
    try {
      final apiService = ref.read(naiUserInfoApiServiceProvider);
      final data = await apiService.getUserSubscription();
      final subscription = UserSubscription.fromJson(data);
      state = SubscriptionState.loaded(subscription);
    } catch (e) {
      AppLogger.w('Failed to refresh balance: $e', 'Subscription');
      // 刷新失败不更新状态，保持上次数据
    }
  }
}

/// 便捷的余额 Provider
@riverpod
int? anlasBalance(Ref ref) {
  final subscriptionState = ref.watch(subscriptionNotifierProvider);
  return subscriptionState.balance;
}

/// 便捷的 Opus 状态 Provider
@riverpod
bool isOpusSubscription(Ref ref) {
  final subscriptionState = ref.watch(subscriptionNotifierProvider);
  return subscriptionState.isOpus;
}
