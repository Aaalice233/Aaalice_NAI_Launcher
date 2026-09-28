import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/secure_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/jwt_parser.dart';
import 'account_manager_provider.dart';
import '../datasources/remote/nai_auth_api_service.dart';
import '../models/auth/saved_account.dart';

part 'token_refresh_service.g.dart';

/// 刷新当前会话 token 的结果
enum TokenRefreshOutcome {
  /// 新 token 已写入当前会话
  refreshed,

  /// 无法刷新：不是 JWT、找不到对应账号、缺少 accessKey 或请求失败
  failed,

  /// 请求期间会话已被退出或切换，结果没有写入会话
  sessionChanged,
}

/// Token 刷新服务
///
/// 负责在 JWT token 过期时自动刷新，使用保存的 accessKey 重新获取 token。
@Riverpod(keepAlive: true)
class TokenRefreshService extends _$TokenRefreshService {
  Future<TokenRefreshOutcome>? _inFlight;

  @override
  void build() {
    // 服务初始化，无需特别操作
    AppLogger.d('TokenRefreshService initialized', 'TokenRefresh');
  }

  /// 刷新当前会话的 token，并发调用共享同一次刷新
  Future<TokenRefreshOutcome> refreshCurrentToken() {
    // 两个 Dio 各有拦截器，同时收到 401 时若第二个直接判失败会误触发登出
    return _inFlight ??= _refreshCurrentTokenSafely().whenComplete(
      () => _inFlight = null,
    );
  }

  Future<TokenRefreshOutcome> _refreshCurrentTokenSafely() async {
    try {
      return await _performRefresh();
    } catch (e, stack) {
      AppLogger.e('Token refresh failed: $e', e, stack, 'TokenRefresh');
      return TokenRefreshOutcome.failed;
    }
  }

  /// 执行刷新逻辑
  Future<TokenRefreshOutcome> _performRefresh() async {
    final storage = ref.read(secureStorageServiceProvider);
    final accountManager = ref.read(accountManagerNotifierProvider.notifier);
    final accounts = ref.read(accountManagerNotifierProvider).accounts;

    // 1. 获取当前 token
    final currentToken = await storage.getAccessToken();
    if (currentToken == null || currentToken.isEmpty) {
      AppLogger.w('No token to refresh', 'TokenRefresh');
      return TokenRefreshOutcome.failed;
    }

    // 2. 检查是否为 JWT（Persistent Token 不需要刷新）
    if (!JWTParser.isJWT(currentToken)) {
      AppLogger.d(
        'Token is not JWT (probably pst-xxx), skip refresh',
        'TokenRefresh',
      );
      return TokenRefreshOutcome.failed;
    }

    // 3. 查找对应的账号
    SavedAccount? currentAccount;
    for (final account in accounts) {
      final accountToken = await accountManager.getAccountToken(account.id);
      if (accountToken == currentToken) {
        currentAccount = account;
        break;
      }
    }

    if (currentAccount == null) {
      AppLogger.w('Cannot find account for current token', 'TokenRefresh');
      return TokenRefreshOutcome.failed;
    }

    // 4. 只刷新 credentials 类型的账号
    if (currentAccount.accountType != AccountType.credentials) {
      AppLogger.d(
        'Account type is ${currentAccount.accountType}, skip refresh',
        'TokenRefresh',
      );
      return TokenRefreshOutcome.failed;
    }

    // 5. 获取保存的 accessKey
    final accessKey = await storage.getAccountAccessKey(currentAccount.id);
    if (accessKey == null || accessKey.isEmpty) {
      AppLogger.w(
        'No accessKey found for account ${currentAccount.id}, cannot refresh',
        'TokenRefresh',
      );
      return TokenRefreshOutcome.failed;
    }

    // 6. 使用 accessKey 重新登录获取新 token
    AppLogger.d(
      'Refreshing token for account: ${currentAccount.displayName}',
      'TokenRefresh',
    );

    final apiService = ref.read(naiAuthApiServiceProvider);
    final loginResponse = await apiService.loginWithKey(accessKey);
    final newToken = loginResponse['accessToken'] as String;

    // 7. 会话仍停在刷新前的 token 上时才写入全局存储
    final applied = await storage.replaceAuthIfCurrent(
      expectedToken: currentToken,
      accessToken: newToken,
      expiry: DateTime.now().add(const Duration(days: 30)),
      email: currentAccount.email,
    );

    // 8. 更新账号管理器中的 token；它按账号存放，会话已变也不会串到别的账号
    await accountManager.updateAccountToken(currentAccount.id, newToken);

    if (!applied) {
      AppLogger.w(
        'Session changed during token refresh, result not applied',
        'TokenRefresh',
      );
      return TokenRefreshOutcome.sessionChanged;
    }

    AppLogger.d('Token refreshed successfully', 'TokenRefresh');
    return TokenRefreshOutcome.refreshed;
  }

  /// 为指定账号刷新 token（用于 401 错误时的重试）
  ///
  /// 返回新 token，如果刷新失败返回 null
  Future<String?> refreshTokenForAccount(String accountId) async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final accountManager = ref.read(accountManagerNotifierProvider.notifier);
      final accounts = ref.read(accountManagerNotifierProvider).accounts;

      // 获取账号信息
      final account = accounts.where((a) => a.id == accountId).firstOrNull;
      if (account == null) {
        AppLogger.w('Account $accountId not found', 'TokenRefresh');
        return null;
      }

      // 只刷新 credentials 类型
      if (account.accountType != AccountType.credentials) {
        AppLogger.d(
          'Account type is ${account.accountType}, cannot refresh',
          'TokenRefresh',
        );
        return null;
      }

      // 获取 accessKey
      final accessKey = await storage.getAccountAccessKey(accountId);
      if (accessKey == null || accessKey.isEmpty) {
        AppLogger.w('No accessKey for account $accountId', 'TokenRefresh');
        return null;
      }
      final previousToken = await accountManager.getAccountToken(accountId);

      // 重新登录
      final apiService = ref.read(naiAuthApiServiceProvider);
      final loginResponse = await apiService.loginWithKey(accessKey);
      final newToken = loginResponse['accessToken'] as String;

      await accountManager.updateAccountToken(accountId, newToken);
      // 只有会话正停在该账号的旧 token 上才同步全局存储，否则会顶掉别的会话
      if (previousToken != null) {
        await storage.replaceAuthIfCurrent(
          expectedToken: previousToken,
          accessToken: newToken,
          expiry: DateTime.now().add(const Duration(days: 30)),
          email: account.email,
        );
      }

      AppLogger.d('Token refreshed for account $accountId', 'TokenRefresh');
      return newToken;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to refresh token for account $accountId: $e',
        e,
        stack,
        'TokenRefresh',
      );
      return null;
    }
  }

  /// 检查当前 token 是否即将过期，如果是则刷新
  ///
  /// 用于主动刷新策略
  Future<void> checkAndRefreshIfNeeded() async {
    final storage = ref.read(secureStorageServiceProvider);
    final token = await storage.getAccessToken();

    if (token == null || token.isEmpty) return;

    // 只检查 JWT
    if (!JWTParser.isJWT(token)) return;

    // 检查是否即将过期（5 分钟内）
    if (JWTParser.isExpiringSoon(token)) {
      AppLogger.d('Token expiring soon, triggering refresh', 'TokenRefresh');
      await refreshCurrentToken();
    }
  }
}
