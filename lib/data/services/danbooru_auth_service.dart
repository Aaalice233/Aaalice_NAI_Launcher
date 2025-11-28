import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../models/danbooru/danbooru_user.dart';

part 'danbooru_auth_service.g.dart';

/// Danbooru 认证状态
class DanbooruAuthState {
  final DanbooruCredentials? credentials;
  final DanbooruUser? user;
  final bool isLoading;
  final String? error;

  const DanbooruAuthState({
    this.credentials,
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isLoggedIn => credentials != null && user != null;

  DanbooruAuthState copyWith({
    DanbooruCredentials? credentials,
    DanbooruUser? user,
    bool? isLoading,
    String? error,
    bool clearCredentials = false,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return DanbooruAuthState(
      credentials: clearCredentials ? null : (credentials ?? this.credentials),
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
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
        await _verifyCredentials(credentials);
      }
    } catch (e, stack) {
      AppLogger.e(
          'Failed to load Danbooru credentials', e, stack, 'DanbooruAuth');
    }
  }

  /// 验证凭据并获取用户信息
  Future<bool> _verifyCredentials(DanbooruCredentials credentials) async {
    try {
      // 这里会被 online_gallery_provider 调用 API 验证
      // 暂时只保存凭据，实际验证在 API 层
      state = state.copyWith(
        credentials: credentials,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '验证失败: $e',
      );
      return false;
    }
  }

  /// 登录
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

      // 保存凭据
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _credentialsKey,
        jsonEncode(credentials.toJson()),
      );

      state = state.copyWith(
        credentials: credentials,
        isLoading: false,
      );

      AppLogger.i('Danbooru login successful: $username', 'DanbooruAuth');
      return true;
    } catch (e, stack) {
      AppLogger.e('Danbooru login failed', e, stack, 'DanbooruAuth');
      state = state.copyWith(
        isLoading: false,
        error: '登录失败: $e',
      );
      return false;
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
