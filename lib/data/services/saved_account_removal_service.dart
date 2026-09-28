import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_manager_provider.dart';
import 'auth_provider.dart';

/// 从启动器移除已保存账号，NovelAI 账号本身不受影响。
class SavedAccountRemovalService {
  SavedAccountRemovalService(this._ref);

  final Ref _ref;

  /// 当前会话是否绑定在该账号上，移除前需要先退出登录
  bool isSessionAccount(String accountId) =>
      _ref.read(authNotifierProvider).accountId == accountId;

  Future<void> remove(String accountId) async {
    if (isSessionAccount(accountId)) {
      await _ref.read(authNotifierProvider.notifier).logout();
    }
    await _ref
        .read(accountManagerNotifierProvider.notifier)
        .removeAccount(accountId);
  }
}

final savedAccountRemovalServiceProvider = Provider<SavedAccountRemovalService>(
  SavedAccountRemovalService.new,
);
