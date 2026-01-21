import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/avatar_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth/account_avatar.dart';
import '../../widgets/auth/login_form_container.dart';
import '../../widgets/common/app_toast.dart';

/// 登录页面 - QQ 风格
class LoginScreen extends ConsumerWidget {
  LoginScreen({super.key});

  static const double _wideScreenBreakpoint = 800;

  /// 头像服务实例
  final _avatarService = AvatarService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountManagerNotifierProvider).accounts;

    // 监听登录错误，显示 Toast
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      AppLogger.d('[LoginScreen] ref.listen triggered: previous=${previous?.status}, next=${next.status}, hasError=${next.hasError}, errorCode=${next.errorCode}', 'LOGIN');
      if (next.hasError && previous?.errorCode != next.errorCode) {
        AppLogger.d('[LoginScreen] Showing error Toast: ${next.errorCode}', 'LOGIN');
        final errorText =
            _getErrorText(context, next.errorCode!, next.httpStatusCode);
        final errorMessage = context.l10n.auth_error_loginFailed(errorText);
        
        // 使用 Navigator.of 来获取 Overlay
        final overlayState = Navigator.of(context, rootNavigator: true).overlay;
        if (overlayState != null) {
          AppLogger.d('[LoginScreen] overlay exists, showing toast...', 'LOGIN');
          AppToast.error(context, errorMessage);
          AppLogger.d('[LoginScreen] toast shown', 'LOGIN');
        } else {
          AppLogger.w('[LoginScreen] overlay is null!', 'LOGIN');
        }
        
        // 清除错误状态（延迟，让 Toast 有时间显示）
        ref.read(authNotifierProvider.notifier).clearError(delayMs: 500);
      } else if (next.hasError && previous?.errorCode == next.errorCode) {
        AppLogger.d('[LoginScreen] Error already shown, clearing...', 'LOGIN');
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= _wideScreenBreakpoint;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / 标题
                  _buildHeader(context, theme),
                  const SizedBox(height: 32),

                  // 根据是否有账号显示不同界面
                  if (accounts.isEmpty)
                    _buildFirstTimeLoginForm(context, theme, isWideScreen)
                  else
                    _buildQuickLoginView(
                      context,
                      ref,
                      theme,
                      isWideScreen,
                      accounts,
                    ),

                  const SizedBox(height: 24),

                  // 提示信息
                  Text(
                    context.l10n.auth_loginTip,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建顶部 Logo 和标题
  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        // App Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.auto_awesome,
            size: 40,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),

        // App Title
        Text(
          context.l10n.appTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // App Subtitle
        Text(
          context.l10n.appSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 首次使用 - 显示登录表单（支持邮箱密码和 Token 两种模式）
  Widget _buildFirstTimeLoginForm(
    BuildContext context,
    ThemeData theme,
    bool isWideScreen,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isWideScreen ? 550 : 420),
      child: const LoginFormContainer(),
    );
  }

  /// 有账号时 - 显示快速登录视图
  Widget _buildQuickLoginView(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool isWideScreen,
    List<SavedAccount> accounts,
  ) {
    // 获取默认账号或第一个账号
    final defaultAccount = accounts.firstWhere(
      (a) => a.isDefault,
      orElse: () => accounts.first,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isWideScreen ? 550 : 420),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isWideScreen
              ? _buildWideScreenQuickLogin(
                  context,
                  ref,
                  theme,
                  defaultAccount,
                  accounts,
                )
              : _buildMobileQuickLogin(
                  context,
                  ref,
                  theme,
                  defaultAccount,
                  accounts,
                ),
        ),
      ),
    );
  }

  /// PC 端快速登录布局（水平）
  Widget _buildWideScreenQuickLogin(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    SavedAccount currentAccount,
    List<SavedAccount> accounts,
  ) {
    return Row(
      children: [
        // 左侧：大头像
        AccountAvatar(
          account: currentAccount,
          size: 100,
          showEditBadge: true,
          onTap: () => _showAvatarOptions(context, ref, currentAccount),
        ),
        const SizedBox(width: 24),

        // 右侧：账号信息和登录按钮
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 账号名（可点击切换）
              InkWell(
                onTap: () => _showAccountSelector(
                  context,
                  ref,
                  accounts,
                  currentAccount,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          currentAccount.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                context.l10n.auth_switchAccount,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),

              // 一键登录按钮
              SizedBox(
                width: double.infinity,
                child:
                    _buildQuickLoginButton(context, ref, theme, currentAccount),
              ),
              const SizedBox(height: 16),

              // 分割线
              Divider(color: theme.colorScheme.outline.withOpacity(0.2)),
              const SizedBox(height: 8),

              // 添加新账号
              _buildAddAccountButton(context, theme),
            ],
          ),
        ),
      ],
    );
  }

  /// 移动端快速登录布局（垂直）
  Widget _buildMobileQuickLogin(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    SavedAccount currentAccount,
    List<SavedAccount> accounts,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 大头像（居中）
        AccountAvatar(
          account: currentAccount,
          size: 100,
          showEditBadge: true,
          onTap: () => _showAvatarOptions(context, ref, currentAccount),
        ),
        const SizedBox(height: 16),

        // 账号名（可点击切换）
        InkWell(
          onTap: () =>
              _showAccountSelector(context, ref, accounts, currentAccount),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentAccount.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
        Text(
          context.l10n.auth_switchAccount,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 24),

        // 一键登录按钮
        SizedBox(
          width: double.infinity,
          child: _buildQuickLoginButton(context, ref, theme, currentAccount),
        ),
        const SizedBox(height: 16),

        // 分割线
        Divider(color: theme.colorScheme.outline.withOpacity(0.2)),
        const SizedBox(height: 8),

        // 添加新账号
        _buildAddAccountButton(context, theme),
      ],
    );
  }

  /// 一键登录按钮
  Widget _buildQuickLoginButton(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    SavedAccount account,
  ) {
    final authState = ref.watch(authNotifierProvider);

    return FilledButton.icon(
      onPressed: authState.isLoading
          ? null
          : () => _handleQuickLogin(context, ref, account),
      icon: authState.isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.login),
      label: Text(context.l10n.auth_quickLogin),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  /// 添加新账号按钮
  Widget _buildAddAccountButton(BuildContext context, ThemeData theme) {
    return TextButton.icon(
      onPressed: () => _showAddAccountDialog(context),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.auth_addAccount),
    );
  }

  /// 处理快速登录
  Future<void> _handleQuickLogin(
    BuildContext context,
    WidgetRef ref,
    SavedAccount account,
  ) async {
    // 如果已经认证（可能自动登录已完成），不执行
    final currentAuth = ref.read(authNotifierProvider);
    if (currentAuth.isAuthenticated) {
      return;
    }

    // 获取 Token
    final token = await ref
        .read(accountManagerNotifierProvider.notifier)
        .getAccountToken(account.id);

    // 检查 widget 是否仍然 mounted
    if (!context.mounted) return;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.auth_tokenNotFound)),
      );
      return;
    }

    // 再次检查是否已认证（在异步操作期间可能已自动登录）
    if (ref.read(authNotifierProvider).isAuthenticated) {
      return;
    }

    // 执行登录 - 根据账号类型选择验证方式
    AppLogger.d('[LoginScreen] _handleQuickLogin: switching account with type ${account.accountType}...', 'LOGIN');
    final success = await ref.read(authNotifierProvider.notifier).switchAccount(
          account.id,
          token,
          displayName: account.displayName,
          accountType: account.accountType,
        );

    // 检查 widget 是否仍然 mounted
    if (!context.mounted) return;

    AppLogger.d('[LoginScreen] _handleQuickLogin: loginWithToken result=$success', 'LOGIN');
    final authState = ref.read(authNotifierProvider);
    AppLogger.d('[LoginScreen] _handleQuickLogin: after login, state=${authState.status}, hasError=${authState.hasError}', 'LOGIN');

    if (success) {
      // 登录成功，更新最后使用时间
      ref
          .read(accountManagerNotifierProvider.notifier)
          .updateLastUsed(account.id);
    }
    // 注意：登录失败的 Toast 由 ref.listen 统一处理，无需在这里重复显示
  }

  /// 显示账号选择器对话框
  void _showAccountSelector(
    BuildContext context,
    WidgetRef ref,
    List<SavedAccount> accounts,
    SavedAccount currentAccount,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Text(context.l10n.auth_selectAccount),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 账号列表
              ...accounts.map(
                (account) => _buildAccountListItem(
                  dialogContext,
                  ref,
                  account,
                  isSelected: account.id == currentAccount.id,
                ),
              ),
              const Divider(),
              // 添加新账号
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(context.l10n.auth_addAccount),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _showAddAccountDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建账号列表项
  Widget _buildAccountListItem(
    BuildContext context,
    WidgetRef ref,
    SavedAccount account, {
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);

    // 格式化创建时间
    final createdDate = _formatDate(account.createdAt);

    return ListTile(
      leading: AccountAvatarSmall(
        account: account,
        size: 40,
        isSelected: isSelected,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              account.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (account.isDefault)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                context.l10n.common_default,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
        ],
      ),
      subtitle: Text(
        context.l10n.auth_createdAt(createdDate),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: () => _showDeleteAccountDialog(context, ref, account),
      ),
      onTap: () {
        Navigator.pop(context);
        // 切换到选中的账号并登录
        _handleQuickLogin(context, ref, account);
      },
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 显示删除账号确认对话框
  void _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
    SavedAccount account,
  ) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.auth_deleteAccount),
        content:
            Text(context.l10n.auth_deleteAccountConfirm(account.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () {
              ref
                  .read(accountManagerNotifierProvider.notifier)
                  .removeAccount(account.id);
              Navigator.pop(dialogContext);
              // 如果还在账号选择对话框中，也关闭它
              Navigator.pop(context);
            },
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
  }

  /// 显示添加账号对话框
  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Text(
                      context.l10n.auth_addAccount,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                // 登录表单（支持邮箱密码和 Token）
                LoginFormContainer(
                  onLoginSuccess: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示头像选项（更换头像）
  void _showAvatarOptions(
    BuildContext context,
    WidgetRef ref,
    SavedAccount account,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.l10n.auth_selectFromGallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImageFromGallery(context, ref, account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(context.l10n.auth_takePhoto),
              onTap: () {
                Navigator.pop(sheetContext);
                // Desktop 平台不支持拍照，使用相同的文件选择逻辑
                _pickImageFromGallery(context, ref, account);
              },
            ),
            if (account.avatarPath != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: Text(
                  context.l10n.auth_removeAvatar,
                  style: TextStyle(color: Colors.red.shade400),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeAvatar(context, ref, account);
                },
              ),
          ],
        ),
      ),
    );
  }
  
  /// 从相册/文件选择头像
  Future<void> _pickImageFromGallery(
    BuildContext context,
    WidgetRef ref,
    SavedAccount account,
  ) async {
    try {
      final result = await _avatarService.pickAndSaveAvatar(account);

      if (result.isSuccess && result.path != null) {
        final updatedAccount = account.copyWith(avatarPath: result.path);
        await ref.read(accountManagerNotifierProvider.notifier).updateAccount(updatedAccount);

        if (context.mounted) {
          AppToast.success(context, context.l10n.common_success);
        }
      } else if (result.isFailure && context.mounted) {
        // 显示错误信息
        AppToast.error(context, result.errorMessage ?? context.l10n.common_error);
      }
      // 取消操作不需要提示
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.common_error);
      }
    }
  }

  /// 移除头像
  Future<void> _removeAvatar(
    BuildContext context,
    WidgetRef ref,
    SavedAccount account,
  ) async {
    try {
      await _avatarService.removeAvatar(account);

      // 更新账号信息（清除头像路径）
      final updatedAccount = account.copyWith(avatarPath: null);
      await ref.read(accountManagerNotifierProvider.notifier).updateAccount(updatedAccount);

      if (context.mounted) {
        AppToast.success(context, context.l10n.common_success);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.common_error);
      }
    }
  }

  /// 获取错误码对应的本地化文本
  String _getErrorText(
    BuildContext context,
    AuthErrorCode errorCode,
    int? httpStatusCode,
  ) {
    final l10n = context.l10n;

    // 401 错误，提供更明确的提示
    if (errorCode == AuthErrorCode.authFailed && httpStatusCode == 401) {
      return l10n.auth_error_authFailed_tokenExpired;
    }

    switch (errorCode) {
      case AuthErrorCode.networkTimeout:
        return l10n.auth_error_networkTimeout;
      case AuthErrorCode.networkError:
        return l10n.auth_error_networkError;
      case AuthErrorCode.authFailed:
        return l10n.auth_error_authFailed;
      case AuthErrorCode.tokenInvalid:
        return l10n.auth_tokenInvalid;
      case AuthErrorCode.serverError:
        return l10n.auth_error_serverError;
      case AuthErrorCode.unknown:
        return l10n.auth_error_unknown;
    }
  }
}
