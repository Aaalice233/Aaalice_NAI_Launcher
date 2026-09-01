import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/nai_api_endpoint.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../data/models/auth/saved_account.dart';

part 'account_manager_provider.g.dart';

/// 账号管理状态
class AccountManagerState {
  final List<SavedAccount> accounts;
  final Map<String, NaiApiEndpointConfig> accountApiEndpoints;
  final bool isLoading;
  final String? error;

  const AccountManagerState({
    this.accounts = const [],
    this.accountApiEndpoints = const {},
    this.isLoading = false,
    this.error,
  });

  AccountManagerState copyWith({
    List<SavedAccount>? accounts,
    Map<String, NaiApiEndpointConfig>? accountApiEndpoints,
    bool? isLoading,
    String? error,
  }) {
    return AccountManagerState(
      accounts: accounts ?? this.accounts,
      accountApiEndpoints: accountApiEndpoints ?? this.accountApiEndpoints,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 账号管理器
@Riverpod(keepAlive: true)
class AccountManagerNotifier extends _$AccountManagerNotifier {
  static const String _boxName = 'accounts';
  static const String _accountsKey = 'saved_accounts';
  static const String _accountApiEndpointsKey = 'account_api_endpoints';

  Box? _box;
  late Future<void> _initialLoad;

  @override
  AccountManagerState build() {
    _initialLoad = _loadAccounts();
    return const AccountManagerState(isLoading: true);
  }

  Future<void> get whenLoaded => _initialLoad;

  /// 获取 SecureStorageService
  SecureStorageService get _secureStorage =>
      ref.read(secureStorageServiceProvider);

  /// 加载账号列表
  Future<void> _loadAccounts() async {
    try {
      _box = await Hive.openBox(_boxName);
      final accountsJson = _box?.get(_accountsKey) as String?;

      List<SavedAccount> accounts = [];
      if (accountsJson != null) {
        final List<dynamic> decoded = jsonDecode(accountsJson);
        accounts = decoded
            .map((e) => SavedAccount.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      Map<String, NaiApiEndpointConfig> accountApiEndpoints = {};
      final endpointsJson = _box?.get(_accountApiEndpointsKey) as String?;
      if (endpointsJson != null) {
        final decoded = jsonDecode(endpointsJson) as Map<String, dynamic>;
        accountApiEndpoints = decoded.map(
          (accountId, value) => MapEntry(
            accountId,
            NaiApiEndpointConfig.fromJson(value as Map<String, dynamic>),
          ),
        );
      }

      state = AccountManagerState(
        accounts: accounts,
        accountApiEndpoints: accountApiEndpoints,
        isLoading: false,
      );
    } catch (e) {
      state = AccountManagerState(isLoading: false, error: e.toString());
    }
  }

  /// 保存账号列表
  Future<void> _saveAccounts(List<SavedAccount> accounts) async {
    final json = jsonEncode(accounts.map((e) => e.toJson()).toList());
    await _box?.put(_accountsKey, json);
  }

  /// 保存账号 API 端点配置
  Future<void> _saveAccountApiEndpoints(
    Map<String, NaiApiEndpointConfig> endpoints,
  ) async {
    final json = jsonEncode(
      endpoints.map((accountId, endpoint) {
        return MapEntry(accountId, endpoint.toJson());
      }),
    );
    await _box?.put(_accountApiEndpointsKey, json);
  }

  /// 获取账号 Token
  Future<String?> getAccountToken(String accountId) async {
    return _secureStorage.getAccountToken(accountId);
  }

  /// 保存账号 Token
  Future<void> _saveAccountToken(String accountId, String token) async {
    await _secureStorage.saveAccountToken(accountId, token);
  }

  /// 删除账号 Token
  Future<void> _deleteAccountToken(String accountId) async {
    await _secureStorage.deleteAccountToken(accountId);
  }

  /// 获取账号 API 端点配置；未配置时使用 NovelAI 官方端点。
  NaiApiEndpointConfig getAccountApiEndpoint(String accountId) {
    return state.accountApiEndpoints[accountId] ??
        NaiApiEndpointConfig.official;
  }

  /// 判断账号是否使用第三方 API 端点。
  bool hasCustomApiEndpoint(String accountId) {
    return getAccountApiEndpoint(accountId).isThirdParty;
  }

  /// 添加账号
  ///
  /// [identifier] 账号标识符（用于内部存储）
  /// [token] API Token
  /// [nickname] 昵称（必填，用于显示和生成默认头像）
  /// [setAsDefault] 是否设为默认账号
  /// [accountType] 账号类型（Token 或 Credentials）
  Future<SavedAccount> addAccount({
    required String identifier,
    required String token,
    required String nickname,
    bool setAsDefault = false,
    AccountType accountType = AccountType.token,
    NaiApiEndpointConfig apiEndpoint = NaiApiEndpointConfig.official,
  }) async {
    // 检查是否已存在相同标识符的账号
    final existingIndex = state.accounts.indexWhere(
      (a) => a.email == identifier,
    );
    if (existingIndex >= 0) {
      // 更新已有账号
      final existing = state.accounts[existingIndex];
      await _saveAccountToken(existing.id, token);

      final updated = existing.copyWith(
        nickname: nickname,
        accountType: accountType,
        lastUsedAt: DateTime.now(),
      );

      final newAccounts = List<SavedAccount>.from(state.accounts);
      newAccounts[existingIndex] = updated;

      if (setAsDefault) {
        // 取消其他默认
        for (int i = 0; i < newAccounts.length; i++) {
          if (i == existingIndex) {
            newAccounts[i] = newAccounts[i].copyWith(isDefault: true);
          } else {
            newAccounts[i] = newAccounts[i].copyWith(isDefault: false);
          }
        }
      }

      final endpoints = Map<String, NaiApiEndpointConfig>.from(
        state.accountApiEndpoints,
      );
      if (apiEndpoint.isOfficial) {
        endpoints.remove(existing.id);
      } else {
        endpoints[existing.id] = apiEndpoint;
      }
      await _saveAccounts(newAccounts);
      await _saveAccountApiEndpoints(endpoints);
      state = state.copyWith(
        accounts: newAccounts,
        accountApiEndpoints: endpoints,
      );
      return newAccounts[existingIndex];
    }

    // 创建新账号
    final newAccount = SavedAccount.create(
      email: identifier,
      nickname: nickname,
      isDefault: setAsDefault || state.accounts.isEmpty,
      accountType: accountType,
    );

    // 保存 Token
    await _saveAccountToken(newAccount.id, token);

    final endpoints = Map<String, NaiApiEndpointConfig>.from(
      state.accountApiEndpoints,
    );
    if (apiEndpoint.isThirdParty) {
      endpoints[newAccount.id] = apiEndpoint;
    }

    // 更新账号列表
    var newAccounts = [...state.accounts, newAccount];

    // 如果设为默认，取消其他默认
    if (setAsDefault && newAccounts.length > 1) {
      newAccounts = newAccounts.map((a) {
        if (a.id == newAccount.id) return a;
        return a.copyWith(isDefault: false);
      }).toList();
    }

    await _saveAccounts(newAccounts);
    await _saveAccountApiEndpoints(endpoints);
    state = state.copyWith(
      accounts: newAccounts,
      accountApiEndpoints: endpoints,
    );
    return newAccount;
  }

  /// 删除账号
  Future<void> removeAccount(String accountId) async {
    // 删除 Token
    await _deleteAccountToken(accountId);
    // 删除 accessKey（用于 token 刷新）
    await _secureStorage.deleteAccountAccessKey(accountId);
    final endpoints = Map<String, NaiApiEndpointConfig>.from(
      state.accountApiEndpoints,
    )..remove(accountId);

    // 更新账号列表
    final newAccounts = state.accounts.where((a) => a.id != accountId).toList();

    // 如果删除的是默认账号，设置第一个为默认
    if (newAccounts.isNotEmpty) {
      final hasDefault = newAccounts.any((a) => a.isDefault);
      if (!hasDefault) {
        newAccounts[0] = newAccounts[0].copyWith(isDefault: true);
      }
    }

    await _saveAccounts(newAccounts);
    await _saveAccountApiEndpoints(endpoints);
    state = state.copyWith(
      accounts: newAccounts,
      accountApiEndpoints: endpoints,
    );
  }

  /// 更新账号信息
  Future<void> updateAccount(SavedAccount account) async {
    final newAccounts = state.accounts.map((a) {
      if (a.id == account.id) return account;
      return a;
    }).toList();

    await _saveAccounts(newAccounts);
    state = state.copyWith(accounts: newAccounts);
  }

  /// 设置默认账号
  Future<void> setDefaultAccount(String accountId) async {
    final newAccounts = state.accounts.map((a) {
      return a.copyWith(isDefault: a.id == accountId);
    }).toList();

    await _saveAccounts(newAccounts);
    state = state.copyWith(accounts: newAccounts);
  }

  /// 更新最后使用时间
  Future<void> updateLastUsed(String accountId) async {
    final newAccounts = state.accounts.map((a) {
      if (a.id == accountId) {
        return a.copyWith(lastUsedAt: DateTime.now());
      }
      return a;
    }).toList();

    await _saveAccounts(newAccounts);
    state = state.copyWith(accounts: newAccounts);
  }

  /// 根据邮箱查找账号
  SavedAccount? findByEmail(String email) {
    return state.accounts.where((a) => a.email == email).firstOrNull;
  }

  /// 更新账号的 Token（用于 token 刷新后更新）
  Future<void> updateAccountToken(String accountId, String newToken) async {
    await _saveAccountToken(accountId, newToken);
  }

  /// 按最后使用时间排序的账号列表（最近使用的在前）
  List<SavedAccount> get sortedAccounts {
    final accounts = List<SavedAccount>.from(state.accounts);
    accounts.sort((a, b) {
      // 按最后使用时间排序，最新的在前
      final aTime = a.lastUsedAt ?? a.createdAt;
      final bTime = b.lastUsedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return accounts;
  }

  /// 默认账号（最近使用的账号）
  SavedAccount? get defaultAccount {
    if (state.accounts.isEmpty) return null;

    // 按最后使用时间排序，返回最近使用的账号
    final sorted = List<SavedAccount>.from(state.accounts);
    sorted.sort((a, b) {
      final aTime = a.lastUsedAt ?? a.createdAt;
      final bTime = b.lastUsedAt ?? b.createdAt;
      return bTime.compareTo(aTime); // 降序，最新的在前
    });
    return sorted.first;
  }
}
