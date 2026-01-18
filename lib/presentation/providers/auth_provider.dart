import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/crypto/nai_crypto_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_api_service.dart';
import '../../data/models/auth/saved_account.dart';
import 'account_manager_provider.dart';

part 'auth_provider.g.dart';

/// 认证状态
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// 认证错误码
enum AuthErrorCode {
  networkTimeout,
  networkError,
  authFailed,
  tokenInvalid,
  serverError,
  unknown,
}

/// 认证状态模型
class AuthState {
  final AuthStatus status;
  final String? accountId;
  final String? displayName;
  final AuthErrorCode? errorCode;
  final int? httpStatusCode;
  final Map<String, dynamic>? subscriptionInfo;

  const AuthState({
    this.status = AuthStatus.initial,
    this.accountId,
    this.displayName,
    this.errorCode,
    this.httpStatusCode,
    this.subscriptionInfo,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? accountId,
    String? displayName,
    AuthErrorCode? errorCode,
    int? httpStatusCode,
    Map<String, dynamic>? subscriptionInfo,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      displayName: displayName ?? this.displayName,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      httpStatusCode: clearError ? null : (httpStatusCode ?? this.httpStatusCode),
      subscriptionInfo: subscriptionInfo ?? this.subscriptionInfo,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get hasError => errorCode != null;

  /// 从异常解析错误码
  static (AuthErrorCode, int?) parseError(Object e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;

      // 超时错误
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return (AuthErrorCode.networkTimeout, statusCode);
      }

      // 网络连接错误
      if (e.type == DioExceptionType.connectionError ||
          e.error is SocketException ||
          e.error is HandshakeException) {
        return (AuthErrorCode.networkError, statusCode);
      }

      // HTTP 状态码错误
      if (statusCode != null) {
        if (statusCode == 401) {
          return (AuthErrorCode.authFailed, statusCode);
        }
        if (statusCode >= 500) {
          return (AuthErrorCode.serverError, statusCode);
        }
      }

      return (AuthErrorCode.unknown, statusCode);
    }

    // Token 格式无效
    if (e.toString().contains('pst-')) {
      return (AuthErrorCode.tokenInvalid, null);
    }

    return (AuthErrorCode.unknown, null);
  }

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
    // 0. 检查自动登录设置（默认启用，确保重启后自动恢复登录）
    final prefs = await SharedPreferences.getInstance();
    final autoLogin = prefs.getBool('auto_login') ?? true; // 改为默认 true

    if (!autoLogin) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    final storage = ref.read(secureStorageServiceProvider);

    // 1. 检查是否有有效的全局 Token

    final token = await storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      // Token 存在，尝试验证
      try {
        final apiService = ref.read(naiApiServiceProvider);
        final subscriptionInfo = await apiService.validateToken(token);

        // 尝试找到 Token 对应的账号
        final accountManager = ref.read(accountManagerNotifierProvider.notifier);
        final accounts = ref.read(accountManagerNotifierProvider).accounts;
        String? matchedAccountId;
        String? matchedDisplayName;

        for (final account in accounts) {
          final accountToken = await accountManager.getAccountToken(account.id);
          if (accountToken == token) {
            matchedAccountId = account.id;
            matchedDisplayName = account.displayName;
            // 更新最后使用时间
            accountManager.updateLastUsed(account.id);
            break;
          }
        }

        // 如果找到匹配的账号，登录成功
        if (matchedAccountId != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            accountId: matchedAccountId,
            displayName: matchedDisplayName,
            subscriptionInfo: subscriptionInfo,
          );
          AppLogger.auth('Token validation successful, account: $matchedDisplayName');
          return; // 已登录，直接返回
        }

        // Token 有效但找不到对应账号，清除后尝试自动登录
        AppLogger.w('Token valid but no matching account found, trying auto-login...');
        await storage.clearAuth();
      } catch (e) {
        // Token 无效，清除后尝试自动登录
        AppLogger.w('Stored token invalid, trying auto-login...');
        await storage.clearAuth();
      }
    }

    // 2. 尝试使用保存的账号自动登录
    final accountManager = ref.read(accountManagerNotifierProvider.notifier);
    final accounts = ref.read(accountManagerNotifierProvider).accounts;
    // 注意：accounts 已按 lastUsedAt 排序，第一个就是最近登录的账号

    if (accounts.isNotEmpty) {
      // 使用最近登录的账号（accounts 已按 lastUsedAt 降序排序）
      final lastUsedAccount = accounts.first;
      AppLogger.auth('Attempting auto-login with account: ${lastUsedAccount.displayName}');

      // 获取账号的 Token 和类型
      final accountToken = await accountManager.getAccountToken(lastUsedAccount.id);
      final accountType = lastUsedAccount.accountType;

      if (accountToken != null && accountToken.isNotEmpty) {
        try {
          final apiService = ref.read(naiApiServiceProvider);
          Map<String, dynamic> subscriptionInfo;

          // 根据账号类型选择验证方式
          if (accountType == AccountType.credentials) {
            // Credentials 账号：直接验证 accessToken
            AppLogger.auth('Auto-login: validating access token for credentials account...');
            subscriptionInfo = await apiService.validateToken(accountToken);
          } else {
            // Token 账号：先验证格式
            AppLogger.auth('Auto-login: validating token format for token account...');
            if (!NAIApiService.isValidTokenFormat(accountToken)) {
              throw Exception('Token 格式无效，应以 pst- 开头');
            }
            subscriptionInfo = await apiService.validateToken(accountToken);
          }

          // 保存到全局存储
          await storage.saveAuth(
            accessToken: accountToken,
            expiry: DateTime.now().add(const Duration(days: 365 * 10)),
            email: lastUsedAccount.displayName,
          );

          state = AuthState(
            status: AuthStatus.authenticated,
            accountId: lastUsedAccount.id,
            displayName: lastUsedAccount.displayName,
            subscriptionInfo: subscriptionInfo,
          );

          // 更新最后使用时间
          accountManager.updateLastUsed(lastUsedAccount.id);

          AppLogger.auth('Auto-login successful with account: ${lastUsedAccount.displayName}');
          return;
        } catch (e) {
          AppLogger.w('Auto-login failed for ${lastUsedAccount.displayName}: $e');
          // 自动登录失败，设置错误状态
          final (errorCode, httpStatusCode) = AuthState.parseError(e);
          state = AuthState(
            status: AuthStatus.error,
            errorCode: errorCode,
            httpStatusCode: httpStatusCode,
          );
          return;
        }
      }
    }

    // 3. 无法自动登录，显示登录页
    state = const AuthState(status: AuthStatus.unauthenticated);
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
      final (errorCode, httpStatusCode) = AuthState.parseError(e);
      
      state = AuthState(
        status: AuthStatus.error,
        errorCode: errorCode,
        httpStatusCode: httpStatusCode,
      );
      
      return false;
    }
  }

  /// 切换账号（使用已保存的 Token）
  ///
  /// [accountId] 账号ID
  /// [token] 已保存的 Token
  /// [displayName] 显示名称
  /// [accountType] 账号类型（决定验证方式）
  Future<bool> switchAccount(
    String accountId,
    String token, {
    String? displayName,
    required AccountType accountType,
  }) async {
    AppLogger.auth('Switching account: $displayName (type: $accountType)');

    if (accountType == AccountType.credentials) {
      // Credentials 账号：直接使用 accessToken 登录（不检查 pst- 格式）
      return _loginWithAccessToken(
        token,
        accountId: accountId,
        displayName: displayName,
      );
    } else {
      // Token 账号：使用原有的 pst- 格式验证
      return loginWithToken(
        token,
        accountId: accountId,
        displayName: displayName,
      );
    }
  }

  /// 内部方法：使用 accessToken 直接登录（credentials 类型）
  ///
  /// [accessToken] API 返回的 JWT accessToken
  /// [accountId] 账号ID
  /// [displayName] 显示名称
  Future<bool> _loginWithAccessToken(
    String accessToken, {
    String? accountId,
    String? displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final apiService = ref.read(naiApiServiceProvider);
      final storage = ref.read(secureStorageServiceProvider);

      // 直接验证 token（credentials 类型不需要检查 pst- 格式）
      AppLogger.auth('Validating access token for credentials account...');
      final subscriptionInfo = await apiService.validateToken(accessToken);
      AppLogger.auth('Access token validation successful');

      // 保存到全局存储
      await storage.saveAuth(
        accessToken: accessToken,
        expiry: DateTime.now().add(const Duration(days: 30)),
        email: displayName ?? '',
      );

      // 更新状态
      state = AuthState(
        status: AuthStatus.authenticated,
        accountId: accountId,
        displayName: displayName,
        subscriptionInfo: subscriptionInfo,
      );

      AppLogger.auth('Credentials account login successful');
      return true;
    } catch (e) {
      AppLogger.e('Credentials account login failed: $e');
      final (errorCode, httpStatusCode) = AuthState.parseError(e);
      state = AuthState(
        status: AuthStatus.error,
        errorCode: errorCode,
        httpStatusCode: httpStatusCode,
      );
      return false;
    }
  }

  /// 使用邮箱密码登录
  Future<bool> loginWithCredentials(
    String email,
    String password, {
    String? displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final apiService = ref.read(naiApiServiceProvider);
      final cryptoService = ref.read(naiCryptoServiceProvider);
      final storage = ref.read(secureStorageServiceProvider);
      final accountNotifier = ref.read(accountManagerNotifierProvider.notifier);

      // 1. 生成 Access Key（Argon2哈希）
      AppLogger.auth('Generating access key for: $email');
      final accessKey = await cryptoService.deriveAccessKey(email, password);
      AppLogger.auth('Access key generated, length: ${accessKey.length}');

      // 2. 使用 Access Key 登录
      AppLogger.auth('Logging in with access key...');
      final loginResponse = await apiService.loginWithKey(accessKey);
      final accessToken = loginResponse['accessToken'] as String;
      AppLogger.auth('Login successful, received access token');

      // 3. 获取订阅信息
      AppLogger.auth('Fetching subscription info...');
      final subscriptionInfo = await apiService.validateToken(accessToken);

      // 4. 获取显示名称
      final effectiveDisplayName = displayName ?? email.split('@').first;

      // 5. 保存账号到 AccountManager（使用 credentials 类型）
      final account = await accountNotifier.addAccount(
        identifier: email,
        token: accessToken,
        nickname: effectiveDisplayName,
        setAsDefault: true,
        accountType: AccountType.credentials,
      );
      final accountId = account.id;

      // 6. 保存 Token 到安全存储
      await storage.saveAuth(
        accessToken: accessToken,
        expiry: DateTime.now().add(const Duration(days: 30)),
        email: email,
      );

      // 7. 更新状态
      state = AuthState(
        status: AuthStatus.authenticated,
        accountId: accountId,
        displayName: effectiveDisplayName,
        subscriptionInfo: subscriptionInfo,
      );

      AppLogger.auth('Credentials login successful for: $email');
      return true;
    } catch (e) {
      AppLogger.e('Credentials login failed: $e');
      final (errorCode, httpStatusCode) = AuthState.parseError(e);
      state = AuthState(
        status: AuthStatus.error,
        errorCode: errorCode,
        httpStatusCode: httpStatusCode,
      );
      return false;
    }
  }

  /// 登出
  /// 
  /// [errorCode] 和 [httpStatusCode] 用于在登出时保留错误信息，以便 UI 显示提示
  Future<void> logout({AuthErrorCode? errorCode, int? httpStatusCode}) async {
    AppLogger.w('[AuthNotifier] logout() called, errorCode=$errorCode, httpStatusCode=$httpStatusCode', 'AUTH');
    AppLogger.w('[AuthNotifier] current state: status=${state.status}, hasError=${state.hasError}', 'AUTH');
    
    final storage = ref.read(secureStorageServiceProvider);
    await storage.clearAuth();

    if (errorCode != null) {
      // 保留错误信息，让 UI 可以显示错误提示
      state = AuthState(
        status: AuthStatus.error,
        errorCode: errorCode,
        httpStatusCode: httpStatusCode,
      );
      AppLogger.w('[AuthNotifier] state set to error: errorCode=$errorCode', 'AUTH');
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
      AppLogger.w('[AuthNotifier] state set to unauthenticated', 'AUTH');
    }
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
  /// 
  /// [delayMs] 延迟毫秒数，让 UI 有时间显示错误 Toast
  void clearError({int delayMs = 100}) async {
    AppLogger.w('[AuthNotifier] clearError() called, current state: status=${state.status}, hasError=${state.hasError}', 'AUTH');
    
    if (state.hasError || state.status == AuthStatus.error) {
      // 延迟清除，让 UI 有时间显示错误提示
      AppLogger.w('[AuthNotifier] waiting ${delayMs}ms before clearing error...', 'AUTH');
      await Future.delayed(Duration(milliseconds: delayMs));
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearError: true,
      );
      AppLogger.w('[AuthNotifier] error cleared, state now: status=${state.status}', 'AUTH');
    }
  }
}

/// 是否已认证 Provider
@riverpod
bool isAuthenticated(Ref ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
}
