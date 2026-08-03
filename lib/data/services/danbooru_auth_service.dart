import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/secure_storage_service.dart';
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
      lastVerifiedAt: clearVerifiedAt
          ? null
          : (lastVerifiedAt ?? this.lastVerifiedAt),
    );
  }
}

class DanbooruCredentialVerifier {
  const DanbooruCredentialVerifier();

  Future<(DanbooruUser?, bool isNetworkError)> verify(
    DanbooruCredentials credentials,
  ) async {
    final apiService = DanbooruApiService(
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      ),
    );
    return apiService.verifyCredentialsWithErrorType(credentials);
  }
}

@Riverpod(keepAlive: true)
DanbooruCredentialVerifier danbooruCredentialVerifier(Ref ref) {
  return const DanbooruCredentialVerifier();
}

/// Danbooru 认证服务
@Riverpod(keepAlive: true)
class DanbooruAuth extends _$DanbooruAuth {
  static const legacyCredentialsKey = 'danbooru_credentials';
  late final Future<void> _initialization;

  @override
  DanbooruAuthState build() {
    _initialization = _loadSavedCredentials();
    return const DanbooruAuthState();
  }

  Future<void> ensureInitialized() => _initialization;

  /// 加载保存的凭据
  Future<void> _loadSavedCredentials() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final prefs = await SharedPreferences.getInstance();
      final secureJson = await storage.getDanbooruCredentials();
      DanbooruCredentials? credentials = _decodeCredentials(secureJson);
      var hasDurableSecureCopy = credentials != null;

      if (credentials == null) {
        final legacyJson = prefs.getString(legacyCredentialsKey);
        credentials = _decodeCredentials(legacyJson);
        if (credentials != null && legacyJson != null) {
          try {
            await storage.saveDanbooruCredentials(legacyJson);
            final readBack = _decodeCredentials(
              await storage.getDanbooruCredentials(),
            );
            hasDurableSecureCopy =
                readBack != null && _sameCredentials(credentials, readBack);
            if (hasDurableSecureCopy) {
              await prefs.remove(legacyCredentialsKey);
              AppLogger.i(
                'Migrated Danbooru credentials to secure storage',
                'DanbooruAuth',
              );
            }
          } catch (_) {
            // Keep the legacy value as the durable copy and continue this login.
            hasDurableSecureCopy = false;
            AppLogger.w(
              'Danbooru credential migration deferred',
              'DanbooruAuth',
            );
          }
        }
      } else if (prefs.containsKey(legacyCredentialsKey)) {
        await prefs.remove(legacyCredentialsKey);
      }

      if (credentials == null) return;

      state = state.copyWith(credentials: credentials, isLoading: true);
      final result = await _verifyCredentialsWithResult(credentials);

      switch (result) {
        case CredentialVerifyResult.success:
          AppLogger.i(
            'Saved credentials verified successfully',
            'DanbooruAuth',
          );
          break;
        case CredentialVerifyResult.invalidCredentials:
          if (hasDurableSecureCopy) {
            await storage.deleteDanbooruCredentials();
          }
          await prefs.remove(legacyCredentialsKey);
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
          state = state.copyWith(
            credentials: credentials,
            isLoading: false,
            clearVerifiedAt: true,
          );
          AppLogger.w(
            'Network error during credential verification, keeping credentials for retry',
            'DanbooruAuth',
          );
          break;
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

  DanbooruCredentials? _decodeCredentials(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final credentials = DanbooruCredentials.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      if (credentials.username.trim().isEmpty ||
          credentials.apiKey.trim().isEmpty) {
        return null;
      }
      return credentials;
    } catch (_) {
      return null;
    }
  }

  bool _sameCredentials(DanbooruCredentials first, DanbooruCredentials second) {
    return first.username == second.username && first.apiKey == second.apiKey;
  }

  /// 验证凭据并获取用户信息（返回详细结果）
  ///
  /// 区分网络错误和凭据无效，避免网络问题导致凭据被误删
  Future<CredentialVerifyResult> _verifyCredentialsWithResult(
    DanbooruCredentials credentials,
  ) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final (user, isNetworkError) = await _fetchUserProfileWithErrorType(
        credentials,
      );

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
        state = state.copyWith(isLoading: false, error: '网络连接失败，将在网络恢复后重试');
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
      state = state.copyWith(isLoading: false, error: '验证失败: $e');
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

      final (user, isNetworkError) = await _fetchUserProfileWithErrorType(
        credentials,
      );

      if (user == null) {
        if (isNetworkError) {
          state = state.copyWith(isLoading: false, error: '网络连接失败，请检查网络连接');
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
      final storage = ref.read(secureStorageServiceProvider);
      final encoded = jsonEncode(credentials.toJson());
      await storage.saveDanbooruCredentials(encoded);
      final readBack = _decodeCredentials(
        await storage.getDanbooruCredentials(),
      );
      if (readBack == null || !_sameCredentials(credentials, readBack)) {
        throw const FormatException('Credential read-back failed');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(legacyCredentialsKey);

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
      state = state.copyWith(isLoading: false, error: '登录失败，请检查网络连接');
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

      final (user, isNetworkError) = await ref
          .read(danbooruCredentialVerifierProvider)
          .verify(credentials);

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
      await Future.wait([
        ref.read(secureStorageServiceProvider).deleteDanbooruCredentials(),
        prefs.remove(legacyCredentialsKey),
      ]);

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

    final encoded = base64Encode(
      utf8.encode('${creds.username}:${creds.apiKey}'),
    );
    return 'Basic $encoded';
  }
}
