import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth/account_selector.dart';

/// 登录页面
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberPassword = false;
  bool _isLoadingCredentials = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  /// 加载已保存的凭据
  Future<void> _loadSavedCredentials() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final (email, password) = await storage.getSavedCredentials();

      if (email != null && password != null) {
        _emailController.text = email;
        _passwordController.text = password;
        _rememberPassword = true;
        AppLogger.auth('Loaded saved credentials', email: email);
      }
    } catch (e) {
      AppLogger.e('Failed to load saved credentials', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCredentials = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / 标题
                  Icon(
                    Icons.auto_awesome,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.appTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.appSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // 已保存的账号选择器
                  AccountSelector(
                    onAccountSelected: (account, password) {
                      _emailController.text = account.email;
                      if (password != null) {
                        _passwordController.text = password;
                      }
                      _rememberPassword = true;
                      setState(() {});
                    },
                  ),

                  // 邮箱输入框
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: context.l10n.auth_email,
                      hintText: context.l10n.auth_emailHint,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoadingCredentials,
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

                  // 密码输入框
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: context.l10n.auth_password,
                      hintText: context.l10n.auth_passwordHint,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    enabled: !_isLoadingCredentials,
                    onFieldSubmitted: (_) => _handleLogin(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.l10n.auth_passwordRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 记住密码复选框
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberPassword,
                        onChanged: _isLoadingCredentials
                            ? null
                            : (value) {
                                setState(() {
                                  _rememberPassword = value ?? false;
                                });
                              },
                      ),
                      GestureDetector(
                        onTap: _isLoadingCredentials
                            ? null
                            : () {
                                setState(() {
                                  _rememberPassword = !_rememberPassword;
                                });
                              },
                        child: Text(
                          context.l10n.auth_rememberPassword,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 错误信息
                  if (authState.status == AuthStatus.error)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.errorMessage ?? context.l10n.auth_loginFailed,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (authState.status == AuthStatus.error)
                    const SizedBox(height: 16),

                  // 登录按钮
                  FilledButton(
                    onPressed: (authState.isLoading || _isLoadingCredentials)
                        ? null
                        : _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            context.l10n.auth_loginButton,
                            style: const TextStyle(fontSize: 16),
                          ),
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
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    AppLogger.auth('Login attempt', email: email);

    // 保存或清除凭据（兼容旧的单账号存储）
    final storage = ref.read(secureStorageServiceProvider);
    if (_rememberPassword) {
      await storage.saveCredentials(email, password);
      AppLogger.auth('Credentials saved', email: email);

      // 同时保存到多账号系统
      await ref.read(accountManagerNotifierProvider.notifier).addAccount(
        email: email,
        password: password,
      );
    } else {
      await storage.clearCredentials();
      AppLogger.auth('Credentials cleared');
    }

    // 执行登录
    final success = await ref.read(authNotifierProvider.notifier).login(email, password);
    AppLogger.auth('Login result', email: email, success: success);

    // 登录成功后更新账号最后使用时间
    if (success) {
      final account = ref.read(accountManagerNotifierProvider.notifier).findByEmail(email);
      if (account != null) {
        await ref.read(accountManagerNotifierProvider.notifier).updateLastUsed(account.id);
      }
    }
  }
}
