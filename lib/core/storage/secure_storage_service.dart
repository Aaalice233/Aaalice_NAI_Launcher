import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';

part 'secure_storage_service.g.dart';

/// 安全存储服务 - 存储敏感数据（Token、密码等）
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          lOptions: LinuxOptions(),
          wOptions: WindowsOptions(),
        );

  // ==================== Access Token ====================

  /// 保存 Access Token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: StorageKeys.accessToken, value: token);
  }

  /// 获取 Access Token
  Future<String?> getAccessToken() async {
    return _storage.read(key: StorageKeys.accessToken);
  }

  /// 保存 Token 过期时间
  Future<void> saveTokenExpiry(DateTime expiry) async {
    await _storage.write(
      key: StorageKeys.tokenExpiry,
      value: expiry.toIso8601String(),
    );
  }

  /// 获取 Token 过期时间
  Future<DateTime?> getTokenExpiry() async {
    final value = await _storage.read(key: StorageKeys.tokenExpiry);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// 检查 Token 是否有效
  Future<bool> isTokenValid() async {
    final token = await getAccessToken();
    if (token == null) return false;

    final expiry = await getTokenExpiry();
    if (expiry == null) return false;

    return expiry.isAfter(DateTime.now());
  }

  // ==================== User Email ====================

  /// 保存用户邮箱
  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: StorageKeys.userEmail, value: email);
  }

  /// 获取用户邮箱
  Future<String?> getUserEmail() async {
    return _storage.read(key: StorageKeys.userEmail);
  }

  // ==================== Auth Management ====================

  /// 保存完整认证信息
  Future<void> saveAuth({
    required String accessToken,
    required DateTime expiry,
    required String email,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveTokenExpiry(expiry),
      saveUserEmail(email),
    ]);
  }

  /// 清除所有认证信息
  Future<void> clearAuth() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.accessToken),
      _storage.delete(key: StorageKeys.tokenExpiry),
      _storage.delete(key: StorageKeys.userEmail),
    ]);
  }

  /// 清除所有存储数据
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ==================== 记住密码功能 ====================

  /// 保存登录凭据
  Future<void> saveCredentials(String email, String password) async {
    await Future.wait([
      _storage.write(key: StorageKeys.savedEmail, value: email),
      _storage.write(key: StorageKeys.savedPassword, value: password),
      _storage.write(key: StorageKeys.rememberPassword, value: 'true'),
    ]);
  }

  /// 获取已保存的登录凭据
  /// 返回 (email, password) 或 (null, null)
  Future<(String?, String?)> getSavedCredentials() async {
    final rememberPassword = await _storage.read(key: StorageKeys.rememberPassword);
    if (rememberPassword != 'true') {
      return (null, null);
    }
    final email = await _storage.read(key: StorageKeys.savedEmail);
    final password = await _storage.read(key: StorageKeys.savedPassword);
    return (email, password);
  }

  /// 检查是否已保存凭据
  Future<bool> hasCredentials() async {
    final rememberPassword = await _storage.read(key: StorageKeys.rememberPassword);
    return rememberPassword == 'true';
  }

  /// 清除已保存的凭据
  Future<void> clearCredentials() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.savedEmail),
      _storage.delete(key: StorageKeys.savedPassword),
      _storage.delete(key: StorageKeys.rememberPassword),
    ]);
  }
}

/// SecureStorageService Provider
@riverpod
SecureStorageService secureStorageService(Ref ref) {
  return SecureStorageService();
}
