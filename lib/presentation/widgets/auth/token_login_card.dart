import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/datasources/remote/nai_auth_api_service.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_provider.dart';
import '../common/floating_label_input.dart';

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
  void initState() {
    super.initState();
    // 清除可能残留的全局错误状态
    ref.read(authNotifierProvider.notifier).clearError(delayMs: 0);
  }

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

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 昵称输入框（必填）
          FloatingLabelInput(
            label: context.l10n.auth_nicknameOptional
                .replaceAll('（可选）', '')
                .replaceAll('(optional)', ''),
            controller: _nicknameController,
            hintText: context.l10n.auth_nicknameHint,
            prefixIcon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            required: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n.auth_nicknameRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Token 输入框
          FloatingLabelInput(
            label: 'API Token',
            controller: _tokenController,
            hintText: context.l10n.auth_tokenHint,
            prefixIcon: Icons.vpn_key_outlined,
            obscureText: _obscureToken,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            required: true,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 粘贴按钮
                IconButton(
                  icon: const Icon(Icons.paste, size: 20),
                  tooltip: context.l10n.common_paste,
                  onPressed: _pasteFromClipboard,
                  splashRadius: 20,
                ),
                // 显示/隐藏切换
                IconButton(
                  icon: Icon(
                    _obscureToken
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureToken = !_obscureToken;
                    });
                  },
                  splashRadius: 20,
                ),
              ],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.l10n.auth_tokenRequired;
              }
              if (!NAIAuthApiService.isValidTokenFormat(value)) {
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 显示恢复建议
                  if (_getErrorRecoveryHint(
                        authState.errorCode,
                        authState.httpStatusCode,
                      ) !=
                      null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        _getErrorRecoveryHint(
                          authState.errorCode,
                          authState.httpStatusCode,
                        )!,
                        style: TextStyle(
                          color: theme.colorScheme.error.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
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
      // 登录失败
      // 注意：这里不需要手动显示 Toast，因为 LoginScreen 监听了 AuthState 变化
      // 当 AuthState 变为 error 时，LoginScreen 会自动显示 Toast
      // 保留这里的 else 分支是为了逻辑清晰，如果有其他本地状态需要处理可以在这里添加
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

  /// 获取错误恢复建议
  String? _getErrorRecoveryHint(AuthErrorCode? errorCode, int? httpStatusCode) {
    switch (errorCode) {
      case AuthErrorCode.networkTimeout:
        return context.l10n.api_error_timeout_hint;
      case AuthErrorCode.networkError:
        return context.l10n.api_error_network_hint;
      case AuthErrorCode.authFailed:
        if (httpStatusCode == 401) {
          return context.l10n.api_error_401_hint;
        }
        return context.l10n.api_error_401_hint;
      case AuthErrorCode.tokenInvalid:
        return context.l10n.api_error_401_hint;
      case AuthErrorCode.serverError:
        if (httpStatusCode == 503) {
          return context.l10n.api_error_503_hint;
        }
        return context.l10n.api_error_500_hint;
      case AuthErrorCode.unknown:
      default:
        return null;
    }
  }

  /// 检查是否为网络错误
  bool _isNetworkError(AuthErrorCode? errorCode) {
    return errorCode == AuthErrorCode.networkTimeout ||
        errorCode == AuthErrorCode.networkError;
  }
}
