import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/secure_storage_service.dart';
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
  final String? email;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.email,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      errorMessage: errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
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

    final isValid = await storage.isTokenValid();
    if (isValid) {
      final email = await storage.getUserEmail();
      state = AuthState(
        status: AuthStatus.authenticated,
        email: email,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// 登录
  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final apiService = ref.read(naiApiServiceProvider);
      final storage = ref.read(secureStorageServiceProvider);

      // 调用登录 API
      final authToken = await apiService.login(email, password);

      // 保存认证信息
      await storage.saveAuth(
        accessToken: authToken.accessToken,
        expiry: authToken.expiresAt,
        email: email,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        email: email,
      );

      return true;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.clearAuth();

    state = const AuthState(status: AuthStatus.unauthenticated);
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
