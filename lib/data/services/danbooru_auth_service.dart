import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../datasources/remote/danbooru_api_service.dart';
import '../models/danbooru/danbooru_user.dart';

part 'danbooru_auth_service.g.dart';

/// 凭据验证结果
enum CredentialVerifyResult {
  /// 验证成功
  success,

  /// 凭据无效（需要清除）
  invalidCredentials,

  /// 网络错误（保留凭据）
  networkError,
}

/// Danbooru 认证状态
class DanbooruAuthState {
  final DanbooruCredentials? credentials;
  final DanbooruUser? user;
  final bool isLoading;
  final String? error;
  final DateTime? lastVerifiedAt;

  const DanbooruAuthState({
    this.credentials,
    this.user,
    this.isLoading = false,
    this.error,
    this.lastVerifiedAt,
  });

  /// 是否已登录
  ///
  /// 判断逻辑：
  /// 1. 必须有凭据
  /// 2. 必须有用户信息（表示API验证成功）
  /// 3. 24小时内验证过
  bool get isLoggedIn {
    if (credentials == null || user == null) return false;

    // 检查是否在验证有效期内（24小时）
    final verifiedAt = lastVerifiedAt;
    if (verifiedAt != null) {
      final hoursSinceVerify = DateTime.now().difference(verifiedAt).inHours;
      if (hoursSinceVerify >= 24) return false;
    } else {
      return false;
    }

    return true;
  }

  /// 是否需要重新验证
  bool get needsReverification {
    final verifiedAt = lastVerifiedAt;
    if (verifiedAt == null) return true;

    final hoursSinceVerify = DateTime.now().difference(verifiedAt).inHours;
    return hoursSinceVerify >= 24;
  }

  DanbooruAuthState copyWith({
    DanbooruCredentials? credentials,
    DanbooruUser? user,
    bool? isLoading,
    String? error,
    bool clearCredentials = false,
    bool clearUser = false,
    bool clearError = false,
    DateTime? lastVerifiedAt,
    bool clearVerifiedAt = false,
  }) {
    return DanbooruAuthState(
      credentials: clearCredentials ? null : (credentials ?? this.credentials),
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastVerifiedAt:
          clearVerifiedAt ? null : (lastVerifiedAt ?? this.lastVerifiedAt),
    );
  }
}

/// Danbooru 认证服务
@Riverpod(keepAlive: true)
class DanbooruAuth extends _$DanbooruAuth {
  static const _credentialsKey = 'danbooru_credentials';

  @override
  DanbooruAuthState build() {
    // 初始化时加载保存的凭据
    _loadSavedCredentials();
    return const DanbooruAuthState();
  }

  /// 加载保存的凭据
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString(_credentialsKey);

      if (credentialsJson != null) {
        final credentials = DanbooruCredentials.fromJson(
          jsonDecode(credentialsJson) as Map<String, dynamic>,
        );
        state = state.copyWith(credentials: credentials, isLoading: true);

        // 验证凭据
        final result = await _verifyCredentialsWithResult(credentials);

        switch (result) {
          case CredentialVerifyResult.success:
            // 验证成功，状态已在 _verifyCredentialsWithResult 中更新
            AppLogger.i(
              'Saved credentials verified successfully',
              'DanbooruAuth',
            );
            break;

          case CredentialVerifyResult.invalidCredentials:
            // 凭据无效（如401错误），清除已保存的凭据
            await prefs.remove(_credentialsKey);
            state = state.copyWith(
              clearCredentials: true,
              clearUser: true,
              isLoading: false,
              error: '凭据已失效，请重新登录',
            );
            AppLogger.w(
              'Saved credentials invalid (401), cleared',
              'DanbooruAuth',
            );
            break;

          case CredentialVerifyResult.networkError:
            // 网络错误，保留凭据但标记为未验证状态
            // 允许离线使用，下次网络恢复时重试验证
            state = state.copyWith(
              credentials: credentials,
              isLoading: false,
              clearVerifiedAt: true, // 清除验证时间，标记为需要重新验证
            );
            AppLogger.w(
              'Network error during credential verification, keeping credentials for retry',
              'DanbooruAuth',
            );
            break;
        }
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load Danbooru credentials',
        e,
        stack,
        'DanbooruAuth',
      );
    }
  }

  /// 验证凭据并获取用户信息（返回详细结果）
  ///
  /// 区分网络错误和凭据无效，避免网络问题导致凭据被误删
  Future<CredentialVerifyResult> _verifyCredentialsWithResult(
    DanbooruCredentials credentials,
  ) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final (user, isNetworkError) =
          await _fetchUserProfileWithErrorType(credentials);

      if (user != null) {
        state = state.copyWith(
          credentials: credentials,
          user: user,
          isLoading: false,
          lastVerifiedAt: DateTime.now(),
        );
        return CredentialVerifyResult.success;
      } else if (isNetworkError) {
        // 网络错误，保留凭据
        state = state.copyWith(
          isLoading: false,
          error: '网络连接失败，将在网络恢复后重试',
        );
        return CredentialVerifyResult.networkError;
      } else {
        // 凭据无效
        state = state.copyWith(
          isLoading: false,
          error: '无法验证凭据，请检查用户名和 API Key 是否正确',
        );
        return CredentialVerifyResult.invalidCredentials;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '验证失败: $e',
      );
      // 未知异常视为网络错误，不删除凭据
      return CredentialVerifyResult.networkError;
    }
  }

  /// 登录
  ///
  /// 流程：
  /// 1. 验证输入
  /// 2. 调用API验证凭据
  /// 3. 验证成功后才保存凭据
  /// 4. 更新状态
  Future<bool> login(String username, String apiKey) async {
    if (username.isEmpty || apiKey.isEmpty) {
      state = state.copyWith(error: '用户名和 API Key 不能为空');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final credentials = DanbooruCredentials(
        username: username,
        apiKey: apiKey,
      );

      // 先验证凭据是否有效
      AppLogger.i('Verifying Danbooru credentials...', 'DanbooruAuth');

      final (user, isNetworkError) =
          await _fetchUserProfileWithErrorType(credentials);

      if (user == null) {
        if (isNetworkError) {
          state = state.copyWith(
            isLoading: false,
            error: '网络连接失败，请检查网络连接',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            error: '无法验证凭据，请检查用户名和 API Key 是否正确',
          );
        }
        AppLogger.w('Danbooru credential verification failed', 'DanbooruAuth');
        return false;
      }

      // 验证成功，保存凭据
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _credentialsKey,
        jsonEncode(credentials.toJson()),
      );

      state = state.copyWith(
        credentials: credentials,
        user: user,
        isLoading: false,
        error: null,
        lastVerifiedAt: DateTime.now(),
      );

      AppLogger.i('Danbooru login successful: $username', 'DanbooruAuth');
      return true;
    } catch (e, stack) {
      AppLogger.e('Danbooru login failed', e, stack, 'DanbooruAuth');
      state = state.copyWith(
        isLoading: false,
        error: '登录失败，请检查网络连接',
      );
      return false;
    }
  }

  /// 从API获取用户信息（带错误类型）
  ///
  /// 返回 (用户信息, 是否为网络错误)
  /// - 成功: (user, false)
  /// - 凭据无效: (null, false)
  /// - 网络错误: (null, true)
  Future<(DanbooruUser?, bool isNetworkError)> _fetchUserProfileWithErrorType(
    DanbooruCredentials credentials,
  ) async {
    try {
      AppLogger.i(
        'Fetching user profile for: ${credentials.username}',
        'DanbooruAuth',
      );

      // 使用 DanbooruApiService 验证凭据
      final apiService = DanbooruApiService(
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
          ),
        ),
      );

      final (user, isNetworkError) =
          await apiService.verifyCredentialsWithErrorType(credentials);

      if (user != null) {
        AppLogger.i(
          'User profile fetched successfully: ${user.name}',
          'DanbooruAuth',
        );
      } else if (isNetworkError) {
        AppLogger.w(
          'Network error while fetching user profile',
          'DanbooruAuth',
        );
      } else {
        AppLogger.w(
          'Failed to fetch user profile - invalid credentials',
          'DanbooruAuth',
        );
      }

      return (user, isNetworkError);
    } catch (e, stack) {
      AppLogger.e('Failed to fetch user profile', e, stack, 'DanbooruAuth');
      // 未知异常视为网络错误
      return (null, true);
    }
  }

  /// 设置用户信息（由 API 调用后设置）
  void setUser(DanbooruUser user) {
    state = state.copyWith(user: user);
  }

  /// 登出
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_credentialsKey);

      state = const DanbooruAuthState();
      AppLogger.i('Danbooru logout successful', 'DanbooruAuth');
    } catch (e, stack) {
      AppLogger.e('Danbooru logout failed', e, stack, 'DanbooruAuth');
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 获取 Basic Auth 头
  String? getAuthHeader() {
    final creds = state.credentials;
    if (creds == null) return null;

    final encoded =
        base64Encode(utf8.encode('${creds.username}:${creds.apiKey}'));
    return 'Basic $encoded';
  }
}
