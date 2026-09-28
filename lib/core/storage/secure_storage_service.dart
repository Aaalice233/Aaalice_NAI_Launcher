import 'dart:convert';

import 'package:crypto/crypto.dart';
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

  static final RegExp _bearerPrefixRegex = RegExp(
    r'^Bearer\s+',
    caseSensitive: false,
  );
  static final RegExp _allWhitespaceRegex = RegExp(r'\s+');

  /// 内存缓存 - 解决 Windows 上 secure storage 写入后立即读取为 null 的问题
  static final Map<String, String> _memoryCache = {};

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            lOptions: LinuxOptions(),
            // Windows: 使用默认配置
            wOptions: WindowsOptions(),
            // macOS: 使用传统 login keychain（useDataProtectionKeyChain: false）。
            // data protection keychain 需要 keychain-access-groups entitlement，
            // 而该 entitlement 要求开发者证书签名，ad-hoc 无证书时无法构建。
            mOptions: MacOsOptions(useDataProtectionKeyChain: false),
          );

  // ==================== Access Token ====================

  /// 保存 Access Token
  Future<void> saveAccessToken(String token) async {
    final normalizedToken = _normalizeToken(token);

    // 先保存到内存缓存
    _memoryCache[StorageKeys.accessToken] = normalizedToken;

    try {
      await _storage.write(
        key: StorageKeys.accessToken,
        value: normalizedToken,
      );
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
      return _normalizeToken(cached);
    }

    // 从持久化存储读取
    try {
      final token = await _storage.read(key: StorageKeys.accessToken);
      if (token != null && token.isNotEmpty) {
        final normalizedToken = _normalizeToken(token);
        // 同步到内存缓存
        _memoryCache[StorageKeys.accessToken] = normalizedToken;
        return normalizedToken;
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
    final normalizedToken = _normalizeToken(token);
    await _storage.write(
      key: '${StorageKeys.accountTokenPrefix}$accountId',
      value: normalizedToken,
    );
  }

  /// 获取账号 Token
  Future<String?> getAccountToken(String accountId) async {
    final token = await _storage.read(
      key: '${StorageKeys.accountTokenPrefix}$accountId',
    );
    if (token == null || token.isEmpty) {
      return token;
    }
    return _normalizeToken(token);
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

  Future<void> saveCloudSyncCredentials(String encodedCredentials) =>
      _saveCloudSecret(StorageKeys.cloudSyncCredentials, encodedCredentials);

  Future<String?> getCloudSyncCredentials() =>
      _getCloudSecret(StorageKeys.cloudSyncCredentials);

  String _cloudDriveIdentityKey(
    String prefix,
    String providerId,
    String accountId,
  ) {
    final accountHash = sha256.convert(utf8.encode(accountId)).toString();
    return '$prefix${providerId}_$accountHash';
  }

  String _cloudDriveOAuthSessionKey(String providerId, String accountId) =>
      _cloudDriveIdentityKey(
        StorageKeys.cloudDriveOAuthSessionPrefix,
        providerId,
        accountId,
      );

  Future<void> saveCloudDriveOAuthSession({
    required String providerId,
    required String accountId,
    required String encodedSession,
  }) => _saveCloudSecret(
    _cloudDriveOAuthSessionKey(providerId, accountId),
    encodedSession,
  );

  Future<String?> getCloudDriveOAuthSession({
    required String providerId,
    required String accountId,
  }) => _getCloudSecret(_cloudDriveOAuthSessionKey(providerId, accountId));

  Future<void> deleteCloudDriveOAuthSession({
    required String providerId,
    required String accountId,
  }) => _deleteCloudSecret(_cloudDriveOAuthSessionKey(providerId, accountId));

  Future<void> clearCloudSyncSecrets() async {
    const keys = [StorageKeys.cloudSyncCredentials];
    for (final key in keys) {
      _memoryCache.remove(key);
    }
    await Future.wait(keys.map((key) => _storage.delete(key: key)));
  }

  Future<void> _deleteCloudSecret(String key) async {
    await _storage.delete(key: key);
    _memoryCache.remove(key);
  }

  Future<void> _saveCloudSecret(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      // Never let the Windows process cache make a failed write look durable.
      _memoryCache[key] = value;
    } catch (error) {
      AppLogger.w(
        'Failed to persist cloud sync secret: ${error.runtimeType}',
        'SecureStorage',
      );
      rethrow;
    }
  }

  Future<String?> _getCloudSecret(String key) async {
    final cached = _memoryCache[key];
    if (cached != null) return cached;
    try {
      final value = await _storage.read(key: key);
      if (value != null) _memoryCache[key] = value;
      return value;
    } catch (error) {
      AppLogger.w(
        'Failed to read cloud sync secret: ${error.runtimeType}',
        'SecureStorage',
      );
      rethrow;
    }
  }

  // ==================== Online Gallery Credentials ====================

  Future<void> saveDanbooruCredentials(String credentialsJson) async {
    await _saveOnlineGalleryCredentials(
      StorageKeys.onlineGalleryDanbooruCredentialsV1,
      credentialsJson,
    );
  }

  Future<String?> getDanbooruCredentials() {
    return _getOnlineGalleryCredentials(
      StorageKeys.onlineGalleryDanbooruCredentialsV1,
    );
  }

  Future<void> deleteDanbooruCredentials() {
    return _deleteOnlineGalleryCredentials(
      StorageKeys.onlineGalleryDanbooruCredentialsV1,
    );
  }

  Future<void> saveGelbooruCredentials(String credentialsJson) async {
    await _saveOnlineGalleryCredentials(
      StorageKeys.onlineGalleryGelbooruCredentialsV1,
      credentialsJson,
    );
  }

  Future<String?> getGelbooruCredentials() {
    return _getOnlineGalleryCredentials(
      StorageKeys.onlineGalleryGelbooruCredentialsV1,
    );
  }

  Future<void> deleteGelbooruCredentials() {
    return _deleteOnlineGalleryCredentials(
      StorageKeys.onlineGalleryGelbooruCredentialsV1,
    );
  }

  Future<void> _saveOnlineGalleryCredentials(
    String key,
    String credentialsJson,
  ) async {
    // Persist first. Caching a failed write could make a migration delete its
    // only durable copy after a misleading read-back on Windows.
    await _storage.write(key: key, value: credentialsJson);
    _memoryCache[key] = credentialsJson;
  }

  Future<String?> _getOnlineGalleryCredentials(String key) async {
    final cached = _memoryCache[key];
    if (cached != null) return cached;

    try {
      final value = await _storage.read(key: key);
      if (value != null) {
        _memoryCache[key] = value;
      }
      return value;
    } catch (e) {
      AppLogger.w('Failed to read online gallery credentials', 'SecureStorage');
      return null;
    }
  }

  Future<void> _deleteOnlineGalleryCredentials(String key) async {
    await _storage.delete(key: key);
    _memoryCache.remove(key);
  }

  // ==================== Prompt Assistant API Key ====================

  String _promptAssistantKey(String providerId) =>
      '${StorageKeys.promptAssistantApiKeyPrefix}$providerId';

  Future<void> savePromptAssistantApiKey(
    String providerId,
    String apiKey,
  ) async {
    final key = _promptAssistantKey(providerId);
    final value = apiKey.trim();
    _memoryCache[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      AppLogger.w('Failed to save prompt assistant key: $e', 'SecureStorage');
    }
  }

  Future<String?> getPromptAssistantApiKey(String providerId) async {
    final key = _promptAssistantKey(providerId);
    final cached = _memoryCache[key];
    if (cached != null) return cached;
    try {
      final value = await _storage.read(key: key);
      if (value != null) {
        _memoryCache[key] = value;
      }
      return value;
    } catch (e) {
      AppLogger.w('Failed to read prompt assistant key: $e', 'SecureStorage');
      return null;
    }
  }

  Future<void> deletePromptAssistantApiKey(String providerId) async {
    final key = _promptAssistantKey(providerId);
    _memoryCache.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (e) {
      AppLogger.w('Failed to delete prompt assistant key: $e', 'SecureStorage');
    }
  }

  // ==================== Agent Web Access ====================

  Future<void> saveAgentWebAccessExaApiKey(String apiKey) async {
    final value = apiKey.trim();
    if (value.isEmpty) {
      await deleteAgentWebAccessExaApiKey();
      return;
    }
    try {
      await _storage.write(
        key: StorageKeys.agentWebAccessExaApiKey,
        value: value,
      );
      _memoryCache[StorageKeys.agentWebAccessExaApiKey] = value;
    } catch (e) {
      AppLogger.w('Failed to save Exa API key: $e', 'SecureStorage');
      rethrow;
    }
  }

  Future<String?> getAgentWebAccessExaApiKey() async {
    final cached = _memoryCache[StorageKeys.agentWebAccessExaApiKey];
    if (cached != null) return cached;
    try {
      final value = await _storage.read(
        key: StorageKeys.agentWebAccessExaApiKey,
      );
      if (value != null) {
        _memoryCache[StorageKeys.agentWebAccessExaApiKey] = value;
      }
      return value;
    } catch (e) {
      AppLogger.w('Failed to read Exa API key: $e', 'SecureStorage');
      return null;
    }
  }

  Future<void> deleteAgentWebAccessExaApiKey() async {
    try {
      await _storage.delete(key: StorageKeys.agentWebAccessExaApiKey);
      _memoryCache.remove(StorageKeys.agentWebAccessExaApiKey);
    } catch (e) {
      AppLogger.w('Failed to delete Exa API key: $e', 'SecureStorage');
      rethrow;
    }
  }

  // ==================== Account Access Key 存储 ====================
  // 用于 JWT token 刷新，accessKey 可用于重新获取 token

  /// 保存账号的 accessKey（用于 token 刷新）
  Future<void> saveAccountAccessKey(String accountId, String accessKey) async {
    await _storage.write(
      key: '${StorageKeys.accountAccessKeyPrefix}$accountId',
      value: accessKey,
    );
  }

  /// 获取账号的 accessKey
  Future<String?> getAccountAccessKey(String accountId) async {
    return _storage.read(
      key: '${StorageKeys.accountAccessKeyPrefix}$accountId',
    );
  }

  /// 删除账号的 accessKey
  Future<void> deleteAccountAccessKey(String accountId) async {
    await _storage.delete(
      key: '${StorageKeys.accountAccessKeyPrefix}$accountId',
    );
  }

  String _normalizeToken(String token) {
    final trimmedToken = token.trim();
    final unquotedToken = _stripWrappingQuotes(trimmedToken);

    // 循环移除所有 Bearer 前缀（处理重复添加的情况）
    var normalizedToken = unquotedToken;
    var previousToken = '';
    while (normalizedToken != previousToken) {
      previousToken = normalizedToken;
      normalizedToken = normalizedToken
          .replaceFirst(_bearerPrefixRegex, '')
          .trim();
    }

    // 移除所有空白字符
    normalizedToken = normalizedToken.replaceAll(_allWhitespaceRegex, '');

    // 验证 token 格式
    if (normalizedToken.startsWith('pst-') && normalizedToken.length < 14) {
      AppLogger.w(
        'Token normalization warning: pst- token too short (${normalizedToken.length} chars)',
        'SecureStorage',
      );
    }

    return normalizedToken;
  }

  String _stripWrappingQuotes(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == '\'' && last == '\'')) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }
}

/// SecureStorageService Provider
/// keepAlive 确保实例在应用生命周期内保持存活
@Riverpod(keepAlive: true)
SecureStorageService secureStorageService(Ref ref) {
  return SecureStorageService();
}
