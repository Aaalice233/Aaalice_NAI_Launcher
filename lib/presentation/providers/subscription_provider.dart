import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_api_service.dart';
import '../../data/models/user/user_subscription.dart';
import 'auth_provider.dart';

part 'subscription_provider.g.dart';

/// 订阅状态 Notifier
///
/// 管理用户订阅信息和 Anlas 余额
@riverpod
class SubscriptionNotifier extends _$SubscriptionNotifier {
  @override
  SubscriptionState build() {
    // 监听认证状态变化
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        // 登录成功后自动获取订阅信息
        fetchSubscription();
      } else if (!next.isAuthenticated && previous?.isAuthenticated == true) {
        // 登出后清除订阅信息
        state = const SubscriptionState.initial();
      }
    });

    // 如果已认证，立即获取订阅信息
    final authState = ref.read(authNotifierProvider);
    if (authState.isAuthenticated) {
      Future.microtask(() => fetchSubscription());
    }

    return const SubscriptionState.initial();
  }

  /// 获取订阅信息
  Future<void> fetchSubscription() async {
    // 避免重复加载
    if (state.isLoading) return;

    state = const SubscriptionState.loading();

    try {
      final apiService = ref.read(naiApiServiceProvider);
      final data = await apiService.getUserSubscription();
      final subscription = UserSubscription.fromJson(data);
      state = SubscriptionState.loaded(subscription);

      AppLogger.i(
        'Subscription loaded: ${subscription.tierName}, '
        'Anlas: ${subscription.anlasBalance}',
        'Subscription',
      );
    } catch (e) {
      AppLogger.e('Failed to fetch subscription: $e', 'Subscription');
      state = SubscriptionState.error(e.toString());
    }
  }

  /// 刷新余额（生成后调用）
  Future<void> refreshBalance() async {
    // 保持当前状态，静默刷新
    try {
      final apiService = ref.read(naiApiServiceProvider);
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
