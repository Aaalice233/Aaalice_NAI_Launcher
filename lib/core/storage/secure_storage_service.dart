import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';

part 'secure_storage_service.g.dart';

/// 安全存储服务 - 存储敏感数据（Token、密码等）
/// 使用内存缓存 + 持久化存储双重保障
class SecureStorageService {
  final FlutterSecureStorage _storage;

  /// 内存缓存 - 解决 Windows 上 secure storage 写入后立即读取为 null 的问题
  static final Map<String, String> _memoryCache = {};

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          lOptions: LinuxOptions(),
          // Windows: 使用默认配置
          wOptions: WindowsOptions(),
        );

  // ==================== Access Token ====================

  /// 保存 Access Token
  Future<void> saveAccessToken(String token) async {
    // 先保存到内存缓存
    _memoryCache[StorageKeys.accessToken] = token;

    try {
      await _storage.write(key: StorageKeys.accessToken, value: token);
    } catch (e) {
      AppLogger.w('Failed to save token to disk: $e', 'SecureStorage');
      // 内存缓存仍然有效，不影响本次会话
    }
  }

  /// 获取 Access Token
  Future<String?> getAccessToken() async {
    // 优先从内存缓存读取
    final cached = _memoryCache[StorageKeys.accessToken];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // 从持久化存储读取
    try {
      final token = await _storage.read(key: StorageKeys.accessToken);
      if (token != null && token.isNotEmpty) {
        // 同步到内存缓存
        _memoryCache[StorageKeys.accessToken] = token;
      }
      return token;
    } catch (e) {
      AppLogger.w('Failed to read token: $e', 'SecureStorage');
      return null;
    }
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
    // 清除内存缓存
    _memoryCache.remove(StorageKeys.accessToken);

    await Future.wait([
      _storage.delete(key: StorageKeys.accessToken),
      _storage.delete(key: StorageKeys.tokenExpiry),
      _storage.delete(key: StorageKeys.userEmail),
    ]);
  }

  /// 清除所有存储数据
  Future<void> clearAll() async {
    // 清除所有内存缓存
    _memoryCache.clear();

    await _storage.deleteAll();
  }

  // ==================== 账号 Token 存储 ====================

  /// 保存账号 Token
  Future<void> saveAccountToken(String accountId, String token) async {
    await _storage.write(
      key: '${StorageKeys.accountTokenPrefix}$accountId',
      value: token,
    );
  }

  /// 获取账号 Token
  Future<String?> getAccountToken(String accountId) async {
    return _storage.read(key: '${StorageKeys.accountTokenPrefix}$accountId');
  }

  /// 删除账号 Token
  Future<void> deleteAccountToken(String accountId) async {
    await _storage.delete(key: '${StorageKeys.accountTokenPrefix}$accountId');
  }

  /// 检查账号是否有 Token
  Future<bool> hasAccountToken(String accountId) async {
    final token = await getAccountToken(accountId);
    return token != null && token.isNotEmpty;
  }

  // ==================== 通用存储方法 ====================

  /// 写入任意 key-value
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// 读取任意 key
  Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  /// 删除任意 key
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}

/// SecureStorageService Provider
/// keepAlive 确保实例在应用生命周期内保持存活
@Riverpod(keepAlive: true)
SecureStorageService secureStorageService(Ref ref) {
  return SecureStorageService();
}
