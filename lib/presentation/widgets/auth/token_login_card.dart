import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/datasources/remote/nai_api_service.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_provider.dart';
import '../common/app_toast.dart';

/// Token 登录卡片组件
class TokenLoginCard extends ConsumerStatefulWidget {
  /// 登录成功回调
  final VoidCallback? onLoginSuccess;

  const TokenLoginCard({
    super.key,
    this.onLoginSuccess,
  });

  @override
  ConsumerState<TokenLoginCard> createState() => _TokenLoginCardState();
}

class _TokenLoginCardState extends ConsumerState<TokenLoginCard> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _obscureToken = true;

  @override
  void dispose() {
    _tokenController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.key_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.auth_tokenLogin,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 昵称输入框（必填）
              TextFormField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  labelText: '${context.l10n.auth_nicknameOptional.replaceAll('（可选）', '').replaceAll('(optional)', '')} *',
                  hintText: context.l10n.auth_nicknameHint,
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.auth_nicknameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Token 输入框
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'API Token *',
                  hintText: context.l10n.auth_tokenHint,
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 粘贴按钮
                      IconButton(
                        icon: const Icon(Icons.paste),
                        tooltip: context.l10n.common_paste,
                        onPressed: _pasteFromClipboard,
                      ),
                      // 显示/隐藏切换
                      IconButton(
                        icon: Icon(
                          _obscureToken
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureToken = !_obscureToken;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                obscureText: _obscureToken,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleLogin(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.l10n.auth_tokenRequired;
                  }
                  if (!NAIApiService.isValidTokenFormat(value)) {
                    return context.l10n.auth_tokenInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 登录按钮
              FilledButton.icon(
                onPressed: authState.isLoading ? null : _handleLogin,
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
                label: Text(context.l10n.auth_validateAndLogin),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              // 错误提示
              if (authState.hasError) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getErrorMessage(authState.errorCode),
                              style: TextStyle(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 网络错误显示重试按钮
                      if (_isNetworkError(authState.errorCode)) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: authState.isLoading ? null : _handleLogin,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(context.l10n.common_retry),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Token 获取指引
              InkWell(
                onTap: _openTokenGuide,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.auth_tokenGuide,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 从剪贴板粘贴
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _tokenController.text = data!.text!.trim();
    }
  }

  /// 打开 Token 获取指引
  Future<void> _openTokenGuide() async {
    const url = 'https://novelai.net/settings';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  /// 处理登录
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final token = _tokenController.text.trim();
    final nickname = _nicknameController.text.trim();

    // 保存 notifier 引用，避免 widget disposed 后使用 ref
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final accountNotifier = ref.read(accountManagerNotifierProvider.notifier);

    // 执行登录验证
    final success = await authNotifier.loginWithToken(
      token,
      displayName: nickname,
    );

    if (success) {
      // 默认保存账号（首次使用）
      final identifier = 'token_${DateTime.now().millisecondsSinceEpoch}';
      final account = await accountNotifier.addAccount(
        identifier: identifier,
        token: token,
        nickname: nickname,
        setAsDefault: true,
      );

      // 更新 AuthState 中的 accountId
      await authNotifier.loginWithToken(
        token,
        accountId: account.id,
        displayName: account.displayName,
      );

      // 检查 widget 是否仍然 mounted
      if (mounted) {
        widget.onLoginSuccess?.call();
      }
    } else {
      // 登录失败，显示错误提示
      if (mounted) {
        final authState = ref.read(authNotifierProvider);
        String errorMessage;

        if (authState.hasError) {
          // 根据错误码显示相应提示
          switch (authState.errorCode) {
            case AuthErrorCode.tokenInvalid:
              errorMessage = context.l10n.auth_tokenInvalid;
              break;
            case AuthErrorCode.authFailed:
              errorMessage = context.l10n.auth_error_authFailed;
              break;
            case AuthErrorCode.networkTimeout:
              errorMessage = context.l10n.auth_error_networkTimeout;
              break;
            case AuthErrorCode.networkError:
              errorMessage = context.l10n.auth_error_networkError;
              break;
            case AuthErrorCode.serverError:
              errorMessage = context.l10n.auth_error_serverError;
              break;
            default:
              errorMessage = context.l10n.auth_error_unknown;
          }
        } else {
          errorMessage = context.l10n.auth_error_unknown;
        }

        AppToast.error(context, errorMessage);
      }
    }
  }

  String _getErrorMessage(AuthErrorCode? errorCode) {
    switch (errorCode) {
      case AuthErrorCode.networkTimeout:
        return context.l10n.auth_error_networkTimeout;
      case AuthErrorCode.networkError:
        return context.l10n.auth_error_networkError;
      case AuthErrorCode.authFailed:
        return context.l10n.auth_error_authFailed;
      case AuthErrorCode.tokenInvalid:
        return context.l10n.auth_tokenInvalid;
      case AuthErrorCode.serverError:
        return context.l10n.auth_error_serverError;
      case AuthErrorCode.unknown:
      default:
        return context.l10n.auth_error_unknown;
    }
  }

  /// 检查是否为网络错误
  bool _isNetworkError(AuthErrorCode? errorCode) {
    return errorCode == AuthErrorCode.networkTimeout ||
        errorCode == AuthErrorCode.networkError;
  }
}
