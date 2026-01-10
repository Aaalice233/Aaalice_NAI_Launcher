import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/avatar_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/account_avatar.dart';
import '../common/app_toast.dart';
import 'nickname_edit_dialog.dart';

/// 账号资料底部操作面板
///
/// 用于编辑账号头像、昵称等资料
/// 参考 TagBottomActionSheet 的设计规范：
/// - 毛玻璃背景效果
/// - 顶部拖动指示条
/// - 20px 顶部圆角
/// - isScrollControlled: true
class AccountProfileBottomSheet extends ConsumerStatefulWidget {
  /// 当前账号
  final SavedAccount account;

  const AccountProfileBottomSheet({
    super.key,
    required this.account,
  });

  /// 显示底部操作面板
  static Future<void> show({
    required BuildContext context,
    required SavedAccount account,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountProfileBottomSheet(
        account: account,
      ),
    );
  }

  @override
  ConsumerState<AccountProfileBottomSheet> createState() =>
      _AccountProfileBottomSheetState();
}

class _AccountProfileBottomSheetState
    extends ConsumerState<AccountProfileBottomSheet> {
  /// 头像服务
  final _avatarService = AvatarService();

  /// 操作锁定（防止竞态条件）
  bool _isOperationInProgress = false;

  /// 当前账号（从 Provider 获取最新数据）
  SavedAccount get currentAccount {
    final accounts = ref.read(accountManagerNotifierProvider).accounts;
    return accounts.firstWhere(
      (a) => a.id == widget.account.id,
      orElse: () => widget.account,
    );
  }

  /// 更换头像
  Future<void> _changeAvatar() async {
    // 防止重复点击
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      final result = await _avatarService.pickAndSaveAvatar(currentAccount);

      if (result.isSuccess && result.path != null) {
        final updatedAccount = currentAccount.copyWith(avatarPath: result.path);
        await ref
            .read(accountManagerNotifierProvider.notifier)
            .updateAccount(updatedAccount);

        // 刷新 UI
        setState(() {});

        if (mounted) {
          AppToast.success(context, context.l10n.settings_avatarUpdated);
        }
      } else if (result.isFailure && mounted) {
        // 显示错误信息
        AppToast.error(context, result.errorMessage ?? context.l10n.common_error);
      }
      // 取消操作不需要提示
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.common_error);
      }
    } finally {
      _isOperationInProgress = false;
    }
  }

  /// 移除头像
  Future<void> _removeAvatar() async {
    // 防止重复点击
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      await _avatarService.removeAvatar(currentAccount);

      final updatedAccount = currentAccount.copyWith(avatarPath: null);
      await ref
          .read(accountManagerNotifierProvider.notifier)
          .updateAccount(updatedAccount);

      // 刷新 UI
      setState(() {});

      if (mounted) {
        AppToast.success(context, context.l10n.settings_avatarRemoved);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.common_error);
      }
    } finally {
      _isOperationInProgress = false;
    }
  }

  /// 编辑昵称
  void _editNickname() {
    // 防止重复点击
    if (_isOperationInProgress) return;

    NicknameEditDialog.show(
      context: context,
      account: currentAccount,
      onSave: (newNickname) async {
        _isOperationInProgress = true;
        try {
          final updatedAccount = currentAccount.copyWith(nickname: newNickname);
          await ref
              .read(accountManagerNotifierProvider.notifier)
              .updateAccount(updatedAccount);

          // 刷新 UI
          setState(() {});

          if (mounted) {
            AppToast.success(context, context.l10n.settings_nicknameUpdated);
          }
        } catch (e) {
          if (mounted) {
            AppToast.error(context, context.l10n.common_error);
          }
        } finally {
          _isOperationInProgress = false;
        }
      },
    );
  }

  /// 设为默认账号
  Future<void> _setAsDefault() async {
    // 防止重复点击
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      await ref
          .read(accountManagerNotifierProvider.notifier)
          .setDefaultAccount(currentAccount.id);

      // 刷新 UI
      setState(() {});

      if (mounted) {
        AppToast.success(context, context.l10n.settings_setAsDefaultSuccess);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.common_error);
      }
    } finally {
      _isOperationInProgress = false;
    }
  }

  /// 切换到指定账号
  Future<void> _switchToAccount(SavedAccount account) async {
    // 关闭底部面板
    Navigator.of(context).pop();

    // 切换账号
    final token = await ref
        .read(accountManagerNotifierProvider.notifier)
        .getAccountToken(account.id);

    if (token == null) {
      if (mounted) {
        AppToast.error(context, context.l10n.auth_tokenNotFound);
      }
      return;
    }

    final success = await ref.read(authNotifierProvider.notifier).switchAccount(
          account.id,
          token,
          displayName: account.displayName,
          accountType: account.accountType,
        );

    if (!success && mounted) {
      AppToast.error(context, context.l10n.auth_loginFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 使用 ref.watch 实现响应式更新
    final accounts = ref.watch(accountManagerNotifierProvider).accounts;
    final currentAccountId = ref.watch(authNotifierProvider).accountId;
    final isDefaultAccount = currentAccount.isDefault;
    final hasMultipleAccounts = accounts.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示条
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 内容
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  // 大头像
                  _buildAvatarSection(context),
                  const SizedBox(height: 24),
                  // 头像操作按钮
                  _buildAvatarActions(context),
                  const SizedBox(height: 16),
                  // 分割线
                  Divider(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  // 昵称行
                  _buildNicknameRow(context),
                  const SizedBox(height: 8),
                  // 账号详情
                  _buildAccountDetails(context),
                  const SizedBox(height: 16),
                  // 设为默认（多账号时显示）
                  if (hasMultipleAccounts) ...[
                    _buildSetAsDefaultRow(context, isDefaultAccount),
                    const SizedBox(height: 16),
                  ],
                  // 多账号列表
                  if (hasMultipleAccounts) ...[
                    _buildAccountsList(
                      context,
                      accounts,
                      currentAccountId,
                      currentAccount,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建头像区域
  Widget _buildAvatarSection(BuildContext context) {
    return Column(
      children: [
        // 大头像（可点击）
        GestureDetector(
          onTap: _changeAvatar,
          child: Stack(
            children: [
              AccountAvatar(
                account: currentAccount,
                size: 100,
                showEditBadge: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 提示文本
        Text(
          context.l10n.settings_tapToChangeAvatar,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }

  /// 构建头像操作按钮
  Widget _buildAvatarActions(BuildContext context) {
    final hasCustomAvatar = currentAccount.avatarPath != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 更换头像按钮
        TextButton.icon(
          onPressed: _changeAvatar,
          icon: const Icon(Icons.photo_library),
          label: Text(context.l10n.settings_changeAvatar),
        ),
        if (hasCustomAvatar) ...[
          const SizedBox(width: 16),
          // 移除头像按钮
          TextButton.icon(
            onPressed: _removeAvatar,
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
            label: Text(
              context.l10n.settings_removeAvatar,
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ],
    );
  }

  /// 构建昵称行
  Widget _buildNicknameRow(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: _editNickname,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              Icons.badge_outlined,
              size: 20,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.settings_nickname,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const Spacer(),
            Text(
              currentAccount.displayName,
              style: theme.textTheme.bodyMedium,
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建账号详情
  Widget _buildAccountDetails(BuildContext context) {
    return Column(
      children: [
        // 邮箱
        _buildDetailRow(
          context,
          icon: Icons.email_outlined,
          label: context.l10n.settings_accountEmail,
          value: currentAccount.email,
        ),
        const SizedBox(height: 8),
        // 账号类型
        _buildDetailRow(
          context,
          icon: Icons.account_circle_outlined,
          label: context.l10n.settings_accountType,
          value: currentAccount.accountType == AccountType.credentials
              ? context.l10n.settings_emailAccount
              : context.l10n.settings_tokenAccount,
        ),
      ],
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// 构建设为默认行
  Widget _buildSetAsDefaultRow(
    BuildContext context,
    bool isDefault,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isDefault ? null : _setAsDefault,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              Icons.star_border_outlined,
              size: 20,
              color: isDefault
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.settings_setAsDefault,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    isDefault ? theme.colorScheme.primary : theme.colorScheme.outline,
              ),
            ),
            const Spacer(),
            if (isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.l10n.settings_defaultAccount,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建多账号列表
  Widget _buildAccountsList(
    BuildContext context,
    List<SavedAccount> accounts,
    String? currentAccountId,
    SavedAccount currentProfileAccount,
  ) {
    final theme = Theme.of(context);

    // 过滤掉当前正在编辑的账号
    final otherAccounts = accounts
        .where((account) => account.id != currentProfileAccount.id)
        .toList();

    if (otherAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分隔线和标题
        Divider(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.auth_switchAccount,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 12),
        // 账号列表
        ...otherAccounts.map(
          (account) => _buildAccountListItem(
            context,
            account,
            account.id == currentAccountId,
          ),
        ),
      ],
    );
  }

  /// 构建账号列表项
  Widget _buildAccountListItem(
    BuildContext context,
    SavedAccount account,
    bool isCurrent,
  ) {
    final theme = Theme.of(context);

    // 检查头像文件是否存在
    final avatarPath = account.avatarPath;
    final hasValidAvatar = avatarPath != null &&
        avatarPath.isNotEmpty &&
        File(avatarPath).existsSync();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isCurrent ? null : () => _switchToAccount(account),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 头像
              if (hasValidAvatar)
                CircleAvatar(
                  radius: 20,
                  backgroundImage: FileImage(File(avatarPath)),
                )
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getColorFromName(account.displayName, theme),
                  child: Text(
                    account.displayName.isNotEmpty
                        ? account.displayName.characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              // 名称和邮箱
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (account.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              context.l10n.settings_defaultAccount,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 当前账号标识或切换按钮
              if (isCurrent)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                )
              else
                Icon(
                  Icons.swap_horiz,
                  color: theme.colorScheme.outline,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 根据名称生成稳定的颜色
  Color _getColorFromName(String name, ThemeData theme) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
    ];

    if (name.isEmpty) {
      return theme.colorScheme.primary;
    }

    return colors[name.hashCode.abs() % colors.length];
  }
}
