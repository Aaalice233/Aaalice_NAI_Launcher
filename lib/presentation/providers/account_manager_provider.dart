import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/secure_storage_service.dart';
import '../../data/models/auth/saved_account.dart';

part 'account_manager_provider.g.dart';

/// 账号管理状态
class AccountManagerState {
  final List<SavedAccount> accounts;
  final bool isLoading;
  final String? error;

  const AccountManagerState({
    this.accounts = const [],
    this.isLoading = false,
    this.error,
  });

  /// 默认账号
  SavedAccount? get defaultAccount {
    return accounts.where((a) => a.isDefault).firstOrNull ??
        accounts.firstOrNull;
  }

  AccountManagerState copyWith({
    List<SavedAccount>? accounts,
    bool? isLoading,
    String? error,
  }) {
    return AccountManagerState(
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 账号管理器
@riverpod
class AccountManagerNotifier extends _$AccountManagerNotifier {
  static const String _boxName = 'accounts';
  static const String _accountsKey = 'saved_accounts';
  static const String _passwordKeyPrefix = 'account_password_';

  Box? _box;
  SecureStorageService? _secureStorage;

  @override
  AccountManagerState build() {
    _secureStorage = ref.watch(secureStorageServiceProvider);
    _loadAccounts();
    return const AccountManagerState(isLoading: true);
  }

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

      state = AccountManagerState(
        accounts: accounts,
        isLoading: false,
      );
    } catch (e) {
      state = AccountManagerState(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 保存账号列表
  Future<void> _saveAccounts(List<SavedAccount> accounts) async {
    final json = jsonEncode(accounts.map((e) => e.toJson()).toList());
    await _box?.put(_accountsKey, json);
  }

  /// 获取账号密码
  Future<String?> getPassword(String accountId) async {
    return _secureStorage?.getAccessToken();
  }

  /// 保存账号密码
  Future<void> _savePassword(String accountId, String password) async {
    final storage = _secureStorage;
    if (storage != null) {
      await storage.write('$_passwordKeyPrefix$accountId', password);
    }
  }

  /// 获取账号密码（通过 SecureStorage）
  Future<String?> getAccountPassword(String accountId) async {
    final storage = _secureStorage;
    if (storage != null) {
      return storage.read('$_passwordKeyPrefix$accountId');
    }
    return null;
  }

  /// 删除账号密码
  Future<void> _deletePassword(String accountId) async {
    final storage = _secureStorage;
    if (storage != null) {
      await storage.delete('$_passwordKeyPrefix$accountId');
    }
  }

  /// 添加账号
  Future<void> addAccount({
    required String email,
    required String password,
    String? nickname,
    bool setAsDefault = false,
  }) async {
    // 检查是否已存在相同邮箱的账号
    final existingIndex = state.accounts.indexWhere((a) => a.email == email);
    if (existingIndex >= 0) {
      // 更新已有账号
      final existing = state.accounts[existingIndex];
      await _savePassword(existing.id, password);

      final updated = existing.copyWith(
        nickname: nickname ?? existing.nickname,
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

      await _saveAccounts(newAccounts);
      state = state.copyWith(accounts: newAccounts);
      return;
    }

    // 创建新账号
    final newAccount = SavedAccount.create(
      email: email,
      nickname: nickname,
      isDefault: setAsDefault || state.accounts.isEmpty,
    );

    // 保存密码
    await _savePassword(newAccount.id, password);

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
    state = state.copyWith(accounts: newAccounts);
  }

  /// 删除账号
  Future<void> removeAccount(String accountId) async {
    // 删除密码
    await _deletePassword(accountId);

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
    state = state.copyWith(accounts: newAccounts);
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

  /// 按最后使用时间排序的账号列表
  List<SavedAccount> get sortedAccounts {
    final accounts = List<SavedAccount>.from(state.accounts);
    accounts.sort((a, b) {
      // 默认账号优先
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      // 然后按最后使用时间排序
      final aTime = a.lastUsedAt ?? a.createdAt;
      final bTime = b.lastUsedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return accounts;
  }
}
