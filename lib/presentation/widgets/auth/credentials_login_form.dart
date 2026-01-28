import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/auth_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../common/inset_shadow_container.dart';
import '../common/themed_checkbox.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

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

  @override
  void initState() {
    super.initState();
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

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 邮箱输入
          InsetShadowContainer(
            borderRadius: 12,
            child: ThemedFormInput(
              controller: emailController,
              decoration: InputDecoration(
                labelText: context.l10n.auth_email,
                hintText: 'user@example.com',
                prefixIcon: const Icon(Icons.email_outlined),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
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
          ),
          const SizedBox(height: 16),

          // 密码输入
          InsetShadowContainer(
            borderRadius: 12,
            child: ThemedFormInput(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: context.l10n.auth_password,
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    ref
                        .read(authModeNotifierProvider.notifier)
                        .togglePasswordVisibility();
                  },
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
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
              onPressed: authState.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: authState.isLoading
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
          if (authState.hasError) ...[
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
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getErrorMessage(authState.errorCode),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
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
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withOpacity(0.8),
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

    // 保存 notifier 引用，避免 widget disposed 后使用 ref
    final authNotifier = ref.read(authNotifierProvider.notifier);

    final success = await authNotifier.loginWithCredentials(
      emailController.text,
      passwordController.text,
    );

    // 检查 widget 是否仍然 mounted
    if (mounted && success && widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    }
  }
}
