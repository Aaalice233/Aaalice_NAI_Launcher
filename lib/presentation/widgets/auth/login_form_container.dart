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
        // 使用 AnimatedSize 处理高度变化的平滑过渡
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            // 使用更自然的曲线
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            // 自定义过渡动画：淡入淡出 + 轻微垂直位移
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.05), // 从下方 5% 处滑入
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            // 布局构建器，确保动画期间顶部对齐
            layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
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
        ),
      ],
    );
  }
}
