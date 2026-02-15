import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../providers/auth_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../common/floating_label_input.dart';
import '../common/themed_checkbox.dart';

/// 邮箱密码登录表单
class CredentialsLoginForm extends ConsumerStatefulWidget {
  /// 登录成功回调
  final VoidCallback? onLoginSuccess;

  const CredentialsLoginForm({
    super.key,
    this.onLoginSuccess,
  });

  @override
  ConsumerState<CredentialsLoginForm> createState() =>
      _CredentialsLoginFormState();
}

class _CredentialsLoginFormState extends ConsumerState<CredentialsLoginForm> {
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  final formKey = GlobalKey<FormState>();

  // 本地错误状态（用于添加账号场景，避免影响全局 authState）
  AuthErrorCode? _localErrorCode;
  int? _localHttpStatusCode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 清除可能残留的全局错误状态
    ref.read(authNotifierProvider.notifier).clearError(delayMs: 0);
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obscurePassword = ref.watch(obscurePasswordProvider);
    final authState = ref.watch(authNotifierProvider);

    // 统一错误状态：优先使用本地错误（添加账号场景），否则使用全局状态
    final hasError = _localErrorCode != null || authState.hasError;
    final errorCode = _localErrorCode ?? authState.errorCode;
    final httpStatusCode = _localHttpStatusCode ?? authState.httpStatusCode;
    // 统一加载状态
    final isLoading = _isLoading || authState.isLoading;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 邮箱输入
          FloatingLabelInput(
            label: context.l10n.auth_email,
            controller: emailController,
            hintText: 'user@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            required: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.l10n.auth_emailRequired;
              }
              if (!value.contains('@')) {
                return context.l10n.auth_emailInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 密码输入
          FloatingLabelPasswordInput(
            label: context.l10n.auth_password,
            controller: passwordController,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            required: true,
            isVisible: !obscurePassword,
            onVisibilityChanged: (_) {
              ref
                  .read(authModeNotifierProvider.notifier)
                  .togglePasswordVisibility();
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.l10n.auth_passwordRequired;
              }
              if (value.length < 6) {
                return context.l10n.auth_passwordTooShort;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 自动登录开关
          Row(
            children: [
              ThemedCheckbox(
                value: ref.watch(autoLoginProvider),
                onChanged: (value) {
                  ref.read(authModeNotifierProvider.notifier).toggleAutoLogin();
                },
              ),
              const SizedBox(width: 8),
              Text(context.l10n.auth_autoLogin),
              const Spacer(),
              TextButton(
                onPressed: _openPasswordReset,
                child: Text(context.l10n.auth_forgotPassword),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 登录按钮
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      context.l10n.auth_loginButton,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          // 错误提示
          if (hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getErrorMessage(errorCode),
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 显示恢复建议
                  if (_getErrorRecoveryHint(
                        errorCode,
                        httpStatusCode,
                      ) !=
                      null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        _getErrorRecoveryHint(
                          errorCode,
                          httpStatusCode,
                        )!,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer
                              .withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  // 网络错误显示重试按钮
                  if (_isNetworkError(errorCode)) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _handleLogin,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(context.l10n.common_retry),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
        return context.l10n.auth_error_authFailed;
      case AuthErrorCode.serverError:
        return context.l10n.auth_error_serverError;
      case AuthErrorCode.unknown:
      default:
        return context.l10n.auth_loginFailed;
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

  /// 打开密码重置页面
  Future<void> _openPasswordReset() async {
    const url = ApiConstants.passwordResetUrl;
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  /// 处理登录
  Future<void> _handleLogin() async {
    if (!formKey.currentState!.validate()) return;

    // 清除之前的本地错误状态
    setState(() {
      _localErrorCode = null;
      _localHttpStatusCode = null;
      _isLoading = true;
    });

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final currentAuthState = ref.read(authNotifierProvider);

    // 如果当前已登录（添加账号场景），使用不影响全局状态的登录方法
    if (currentAuthState.isAuthenticated) {
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text.trim();
      final result = await authNotifier.tryAddAccount(
        email,
        password,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        widget.onLoginSuccess?.call();
      } else {
        // 登录失败，设置本地错误状态
        setState(() {
          _localErrorCode = result.errorCode;
          _localHttpStatusCode = result.httpStatusCode;
        });
      }
    } else {
      // 未登录状态，使用正常的登录流程
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text.trim();
      final success = await authNotifier.loginWithCredentials(
        email,
        password,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        widget.onLoginSuccess?.call();
      }
    }
  }
}
