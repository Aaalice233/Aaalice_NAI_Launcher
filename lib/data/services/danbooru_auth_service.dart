import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../datasources/remote/danbooru_api_service.dart';
import '../models/danbooru/danbooru_user.dart';

part 'danbooru_auth_service.g.dart';

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
        lastVerifiedAt: clearVerifiedAt 
          ? null 
          : (lastVerifiedAt ?? this.lastVerifiedAt),
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
        final isValid = await _verifyCredentials(credentials);

        // 如果验证失败，清除已保存的凭据
        if (!isValid) {
          await prefs.remove(_credentialsKey);
          AppLogger.w('Saved credentials invalid, cleared', 'DanbooruAuth');
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

  /// 验证凭据并获取用户信息
  Future<bool> _verifyCredentials(DanbooruCredentials credentials) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final user = await _fetchUserProfile(credentials);

      if (user != null) {
        state = state.copyWith(
          credentials: credentials,
          user: user,
          isLoading: false,
          lastVerifiedAt: DateTime.now(),
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: '无法验证凭据，请检查用户名和 API Key 是否正确',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '验证失败: $e',
      );
      return false;
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
      
      final user = await _fetchUserProfile(credentials);
      
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: '无法验证凭据，请检查用户名和 API Key 是否正确',
        );
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

  /// 从API获取用户信息
  ///
  /// 使用 DanbooruApiService 验证凭据并获取用户信息
  Future<DanbooruUser?> _fetchUserProfile(DanbooruCredentials credentials) async {
    try {
      AppLogger.i('Fetching user profile for: ${credentials.username}', 'DanbooruAuth');

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

      final user = await apiService.verifyCredentials(credentials);

      if (user != null) {
        AppLogger.i('User profile fetched successfully: ${user.name}', 'DanbooruAuth');
      } else {
        AppLogger.w('Failed to fetch user profile or invalid credentials', 'DanbooruAuth');
      }

      return user;
    } catch (e, stack) {
      AppLogger.e('Failed to fetch user profile', e, stack, 'DanbooruAuth');
      return null;
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
