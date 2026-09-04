import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../core/services/avatar_service.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/account_avatar.dart';
import '../common/app_toast.dart';
import '../common/themed_divider.dart';
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
  final bool presentationManaged;

  const AccountProfileBottomSheet({
    super.key,
    required this.account,
    this.presentationManaged = false,
  });

  /// 显示底部操作面板
  static Future<void> show({
    required BuildContext context,
    required SavedAccount account,
  }) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      dialogWidth: 520,
      titleBuilder: (panelContext) => Row(
        children: [
          const Icon(Icons.manage_accounts_outlined, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              panelContext.l10n.settings_account,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                panelContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      builder: (panelContext, scrollController) => AccountProfileBottomSheet(
        account: account,
        presentationManaged: true,
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

  void _setOperationInProgress(bool value) {
    if (!mounted || _isOperationInProgress == value) return;
    setState(() => _isOperationInProgress = value);
  }

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
    _setOperationInProgress(true);

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
        AppToast.error(
          context,
          result.errorMessage ?? context.l10n.common_error,
        );
      }
      // 取消操作不需要提示
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.common_error);
      }
    } finally {
      _setOperationInProgress(false);
    }
  }

  /// 移除头像
  Future<void> _removeAvatar() async {
    // 防止重复点击
    if (_isOperationInProgress) return;
    _setOperationInProgress(true);

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
      _setOperationInProgress(false);
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
        _setOperationInProgress(true);
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
          _setOperationInProgress(false);
        }
      },
    );
  }

  /// 设为默认账号
  Future<void> _setAsDefault() async {
    // 防止重复点击
    if (_isOperationInProgress) return;
    _setOperationInProgress(true);

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
      _setOperationInProgress(false);
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

    final success = await ref
        .read(authNotifierProvider.notifier)
        .switchAccount(
          account.id,
          token,
          displayName: account.displayName,
          accountType: account.accountType,
        );

    if (!success && mounted) {
      AppToast.error(context, context.l10n.auth_loginFailed);
    }
  }

  Future<void> _logout() async {
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    Navigator.of(context).pop();
    await WidgetsBinding.instance.endOfFrame;
    await authNotifier.logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 使用 ref.watch 实现响应式更新
    final accounts = ref.watch(accountManagerNotifierProvider).accounts;
    final authState = ref.watch(authNotifierProvider);
    final currentAccountId = authState.accountId;
    final isCurrentAccount =
        authState.isAuthenticated && currentAccountId == currentAccount.id;
    final defaultAccount = ref
        .read(accountManagerNotifierProvider.notifier)
        .defaultAccount;
    final isDefaultAccount = defaultAccount?.id == currentAccount.id;
    final hasMultipleAccounts = accounts.length > 1;

    final content = Column(
      mainAxisSize: widget.presentationManaged
          ? MainAxisSize.max
          : MainAxisSize.min,
      children: [
        if (!widget.presentationManaged)
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                const ThemedDivider(),
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
        if (isCurrentAccount) _buildLogoutFooter(context),
      ],
    );
    if (widget.presentationManaged) return content;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: content,
    );
  }

  Widget _buildLogoutFooter(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            key: const Key('account-profile-logout-button'),
            onPressed: _isOperationInProgress ? null : _logout,
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.l10n.auth_logout),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建头像区域
  Widget _buildAvatarSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Semantics(
          button: true,
          label: context.l10n.settings_changeAvatar,
          child: InkResponse(
            onTap: _isOperationInProgress ? null : _changeAvatar,
            radius: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AccountAvatar(
                  account: currentAccount,
                  size: 100,
                  showEditBadge: !_isOperationInProgress,
                ),
                if (_isOperationInProgress)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.scrim.withValues(alpha: 0.38),
                    ),
                    alignment: Alignment.center,
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        value: MediaQuery.disableAnimationsOf(context)
                            ? 0.72
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
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
    final theme = Theme.of(context);
    final hasCustomAvatar = currentAccount.avatarPath != null;
    final policyExtent = context.interactionPolicy.minimumControlExtent;
    final minimumHeight = policyExtent < 44 ? 44.0 : policyExtent;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: _isOperationInProgress ? null : _changeAvatar,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(context.l10n.settings_changeAvatar),
          style: TextButton.styleFrom(minimumSize: Size(0, minimumHeight)),
        ),
        if (hasCustomAvatar)
          TextButton.icon(
            onPressed: _isOperationInProgress ? null : _removeAvatar,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(context.l10n.settings_removeAvatar),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: Size(0, minimumHeight),
            ),
          ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(1) >= 2;
            final label = Text(
              context.l10n.settings_nickname,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            );
            final value = Text(
              currentAccount.displayName,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: compact ? TextAlign.start : TextAlign.end,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.badge_outlined,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [label, const SizedBox(height: 2), value],
                        )
                      : Row(
                          children: [
                            label,
                            const SizedBox(width: 16),
                            Expanded(child: value),
                          ],
                        ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建账号详情
  Widget _buildAccountDetails(BuildContext context) {
    final endpoint = ref
        .watch(accountManagerNotifierProvider)
        .accountApiEndpoints[currentAccount.id];
    final isThirdParty = endpoint?.isThirdParty ?? false;

    return Column(
      children: [
        if (currentAccount.accountType == AccountType.credentials) ...[
          _buildDetailRow(
            context,
            icon: Icons.email_outlined,
            label: context.l10n.settings_accountEmail,
            value: currentAccount.maskedEmail,
          ),
          const SizedBox(height: 8),
        ],
        // 账号类型
        _buildDetailRow(
          context,
          icon: Icons.account_circle_outlined,
          label: context.l10n.settings_accountType,
          value: isThirdParty
              ? context.l10n.settings_thirdPartyApiAccount
              : currentAccount.accountType == AccountType.credentials
              ? context.l10n.settings_emailAccount
              : context.l10n.settings_tokenAccount,
        ),
        if (isThirdParty && endpoint != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            context,
            icon: Icons.public_outlined,
            label: context.l10n.settings_apiSite,
            value: endpoint.mainBaseUrl,
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: theme.colorScheme.outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final labelText = Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
                final valueText = SelectableText(
                  value,
                  maxLines: 2,
                  style: theme.textTheme.bodyMedium,
                  textAlign: compact ? TextAlign.start : TextAlign.end,
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [labelText, const SizedBox(height: 2), valueText],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelText,
                    const SizedBox(width: 16),
                    Expanded(child: valueText),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建设为默认行
  Widget _buildSetAsDefaultRow(BuildContext context, bool isDefault) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isDefault ? null : _setAsDefault,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final label = Text(
              context.l10n.settings_setAsDefault,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDefault
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            );
            final badge = isDefault
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
                  )
                : null;
            final compact =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(1) >= 2;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.star_border_outlined,
                    size: 20,
                    color: isDefault
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: compact && badge != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [label, const SizedBox(height: 8), badge],
                        )
                      : Row(
                          children: [
                            Expanded(child: label),
                            if (badge != null) badge,
                          ],
                        ),
                ),
              ],
            );
          },
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
        Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
            ref
                    .read(accountManagerNotifierProvider.notifier)
                    .defaultAccount
                    ?.id ==
                account.id,
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
    bool isDefault,
  ) {
    final theme = Theme.of(context);

    // 检查头像文件是否存在
    final avatarPath = account.avatarPath;
    final hasValidAvatar =
        avatarPath != null &&
        avatarPath.isNotEmpty &&
        File(avatarPath).existsSync();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: isCurrent
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? BorderSide(color: theme.colorScheme.primary)
            : BorderSide.none,
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
                  backgroundColor: _getColorFromName(
                    account.displayName,
                    theme,
                  ),
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
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
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
