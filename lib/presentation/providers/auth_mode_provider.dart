import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_mode_provider.g.dart';

/// 登录模式枚举
enum AuthMode {
  /// 邮箱+密码登录
  credentials,

  /// Token登录
  token,
}

/// 登录模式状态模型
class AuthModeState {
  final AuthMode currentMode;
  final bool obscurePassword;
  final bool autoLogin;

  const AuthModeState({
    this.currentMode = AuthMode.credentials,
    this.obscurePassword = true,
    this.autoLogin = false,
  });

  AuthModeState copyWith({
    AuthMode? currentMode,
    bool? obscurePassword,
    bool? autoLogin,
  }) {
    return AuthModeState(
      currentMode: currentMode ?? this.currentMode,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      autoLogin: autoLogin ?? this.autoLogin,
    );
  }
}

/// 登录模式状态管理 Notifier
@riverpod
class AuthModeNotifier extends _$AuthModeNotifier {
  static const String _kAutoLoginKey = 'auto_login';

  @override
  AuthModeState build() {
    _loadAutoLoginState();
    return const AuthModeState();
  }

  Future<void> _loadAutoLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final autoLogin = prefs.getBool(_kAutoLoginKey) ?? false;
    state = state.copyWith(autoLogin: autoLogin);
  }

  /// 切换登录模式
  void switchMode(AuthMode mode) {
    state = state.copyWith(currentMode: mode);
  }

  /// 切换密码可见性
  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  /// 切换自动登录状态
  Future<void> toggleAutoLogin() async {
    final newValue = !state.autoLogin;
    state = state.copyWith(autoLogin: newValue);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoLoginKey, newValue);
  }

  /// 重置状态
  void reset() {
    state = const AuthModeState();
    _loadAutoLoginState();
  }
}

/// 当前登录模式 Provider
@riverpod
AuthMode authMode(Ref ref) {
  return ref.watch(authModeNotifierProvider).currentMode;
}

/// 密码是否隐藏 Provider
@riverpod
bool obscurePassword(Ref ref) {
  return ref.watch(authModeNotifierProvider).obscurePassword;
}

/// 自动登录状态 Provider
@riverpod
bool autoLogin(Ref ref) {
  return ref.watch(authModeNotifierProvider).autoLogin;
}
