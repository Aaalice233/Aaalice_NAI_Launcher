import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_mode_provider.dart';
import 'auth_mode_switcher.dart';
import 'credentials_login_form.dart';
import 'token_login_card.dart';

/// 登录表单容器 - 支持邮箱密码和 Token 两种登录模式
class LoginFormContainer extends ConsumerWidget {
  /// 登录成功回调
  final VoidCallback? onLoginSuccess;

  const LoginFormContainer({
    super.key,
    this.onLoginSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(authModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 登录模式切换器
        const AuthModeSwitcher(),
        const SizedBox(height: 24),

        // 根据当前模式显示对应的登录表单
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: switch (currentMode) {
            AuthMode.credentials => CredentialsLoginForm(
                key: const Key('credentials_form'),
                onLoginSuccess: onLoginSuccess,
              ),
            AuthMode.token => TokenLoginCard(
                key: const Key('token_form'),
                onLoginSuccess: onLoginSuccess,
              ),
          },
        ),
      ],
    );
  }
}
