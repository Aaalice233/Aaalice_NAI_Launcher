import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/secure_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_api_service.dart';

part 'auth_provider.g.dart';

/// 认证状态
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// 认证状态模型
class AuthState {
  final AuthStatus status;
  final String? accountId;
  final String? displayName;
  final String? errorMessage;
  final Map<String, dynamic>? subscriptionInfo;

  const AuthState({
    this.status = AuthStatus.initial,
    this.accountId,
    this.displayName,
    this.errorMessage,
    this.subscriptionInfo,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? accountId,
    String? displayName,
    String? errorMessage,
    Map<String, dynamic>? subscriptionInfo,
  }) {
    return AuthState(
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      displayName: displayName ?? this.displayName,
      errorMessage: errorMessage,
      subscriptionInfo: subscriptionInfo ?? this.subscriptionInfo,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  /// 获取 Anlas 余额
  int get anlasBalance {
    if (subscriptionInfo == null) return 0;
    final trainingStepsLeft = subscriptionInfo!['trainingStepsLeft'];
    if (trainingStepsLeft is Map) {
      return (trainingStepsLeft['fixedTrainingStepsLeft'] ?? 0) +
          (trainingStepsLeft['purchasedTrainingSteps'] ?? 0);
    }
    return 0;
  }
}

/// 认证状态 Notifier
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    // 初始化时检查已存储的认证状态
    _checkExistingAuth();
    return const AuthState(status: AuthStatus.loading);
  }

  /// 检查已存储的认证状态
  Future<void> _checkExistingAuth() async {
    final storage = ref.read(secureStorageServiceProvider);

    // 检查是否有有效 Token
    final token = await storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      // Token 存在，尝试验证
      try {
        final apiService = ref.read(naiApiServiceProvider);
        final subscriptionInfo = await apiService.validateToken(token);

        state = AuthState(
          status: AuthStatus.authenticated,
          subscriptionInfo: subscriptionInfo,
        );
        AppLogger.auth('Token validation successful');
      } catch (e) {
        // Token 无效，清除并要求重新登录
        AppLogger.w('Stored token invalid, clearing auth');
        await storage.clearAuth();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// 使用 Token 登录
  ///
  /// [token] Persistent API Token (格式: pst-xxxx)
  /// [accountId] 账号ID（用于关联存储）
  /// [displayName] 显示名称
  Future<bool> loginWithToken(
    String token, {
    String? accountId,
    String? displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // 1. 验证 Token 格式
      if (!NAIApiService.isValidTokenFormat(token)) {
        throw Exception('Token 格式无效，应以 pst- 开头');
      }

      final apiService = ref.read(naiApiServiceProvider);
      final storage = ref.read(secureStorageServiceProvider);

      // 2. 验证 Token 有效性
      AppLogger.auth('Validating token...');
      final subscriptionInfo = await apiService.validateToken(token);
      AppLogger.auth('Token validation successful');

      // 3. 保存 Token 到全局存储（用于 API 调用）
      // Persistent Token 不会过期，设置一个远期过期时间
      AppLogger.auth('Saving token to storage, length: ${token.length}');
      await storage.saveAuth(
        accessToken: token,
        expiry: DateTime.now().add(const Duration(days: 365 * 10)),
        email: displayName ?? 'Token User',
      );

      // 验证 token 确实被保存了
      final savedToken = await storage.getAccessToken();
      AppLogger.auth('Token saved verification: ${savedToken != null ? "OK, length: ${savedToken.length}" : "FAILED - token is null"}');

      // 4. 更新状态
      state = AuthState(
        status: AuthStatus.authenticated,
        accountId: accountId,
        displayName: displayName,
        subscriptionInfo: subscriptionInfo,
      );

      return true;
    } catch (e) {
      AppLogger.e('Token login failed: $e');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// 切换账号（使用已保存的 Token）
  Future<bool> switchAccount(String accountId, String token, {String? displayName}) async {
    return loginWithToken(token, accountId: accountId, displayName: displayName);
  }

  /// 登出
  Future<void> logout() async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.clearAuth();

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// 刷新订阅信息
  Future<void> refreshSubscription() async {
    if (!state.isAuthenticated) return;

    try {
      final apiService = ref.read(naiApiServiceProvider);
      final subscriptionInfo = await apiService.getUserSubscription();
      state = state.copyWith(subscriptionInfo: subscriptionInfo);
    } catch (e) {
      AppLogger.e('Failed to refresh subscription: $e');
    }
  }

  /// 清除错误状态
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }
}

/// 是否已认证 Provider
@riverpod
bool isAuthenticated(Ref ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
}
