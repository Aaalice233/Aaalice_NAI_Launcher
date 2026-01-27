import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../presentation/providers/auth_provider.dart';
import '../utils/app_logger.dart';

/// 认证错误信息
/// 包含错误文本和恢复建议
class AuthErrorMessage {
  final String errorText;
  final String? recoveryHint;

  const AuthErrorMessage(this.errorText, this.recoveryHint);

  /// 是否有恢复建议
  bool get hasRecoveryHint => recoveryHint != null;

  @override
  String toString() =>
      'AuthErrorMessage(errorText: $errorText, recoveryHint: $recoveryHint)';
}

/// 认证错误服务
/// 封装认证错误消息格式化逻辑
/// 负责将错误码和HTTP状态码映射为用户友好的错误消息
class AuthErrorService {
  /// 获取错误文本
  ///
  /// 根据 [errorCode] 和可选的 [httpStatusCode] 返回对应的本地化错误文本
  /// 使用 [l10n] 提供本地化支持
  String getErrorText(
    AppLocalizations l10n,
    AuthErrorCode errorCode,
    int? httpStatusCode,
  ) {
    // 401 错误，提供更明确的提示
    if (errorCode == AuthErrorCode.authFailed && httpStatusCode == 401) {
      AppLogger.d(
        'Auth failed with 401 status - token expired',
        'AuthErrorService',
      );
      return l10n.auth_error_authFailed_tokenExpired;
    }

    switch (errorCode) {
      case AuthErrorCode.networkTimeout:
        AppLogger.d('Network timeout error', 'AuthErrorService');
        return l10n.auth_error_networkTimeout;
      case AuthErrorCode.networkError:
        AppLogger.d('Network error', 'AuthErrorService');
        return l10n.auth_error_networkError;
      case AuthErrorCode.authFailed:
        AppLogger.d('Authentication failed', 'AuthErrorService');
        return l10n.auth_error_authFailed;
      case AuthErrorCode.tokenInvalid:
        AppLogger.d('Invalid token', 'AuthErrorService');
        return l10n.auth_tokenInvalid;
      case AuthErrorCode.serverError:
        AppLogger.d('Server error', 'AuthErrorService');
        return l10n.auth_error_serverError;
      case AuthErrorCode.unknown:
        AppLogger.d('Unknown error', 'AuthErrorService');
        return l10n.auth_error_unknown;
    }
  }

  /// 获取错误恢复建议
  ///
  /// 根据 [errorCode] 和可选的 [httpStatusCode] 返回对应的恢复建议
  /// 如果没有特定的恢复建议，返回 null
  /// 使用 [l10n] 提供本地化支持
  String? getErrorRecoveryHint(
    AppLocalizations l10n,
    AuthErrorCode errorCode,
    int? httpStatusCode,
  ) {
    switch (errorCode) {
      case AuthErrorCode.networkTimeout:
        AppLogger.d('Providing timeout recovery hint', 'AuthErrorService');
        return l10n.api_error_timeout_hint;
      case AuthErrorCode.networkError:
        AppLogger.d(
            'Providing network error recovery hint', 'AuthErrorService',
        );
        return l10n.api_error_network_hint;
      case AuthErrorCode.authFailed:
        if (httpStatusCode == 401) {
          AppLogger.d(
            'Providing 401 unauthorized recovery hint',
            'AuthErrorService',
          );
          return l10n.api_error_401_hint;
        }
        AppLogger.d('Providing auth failed recovery hint', 'AuthErrorService');
        return l10n.api_error_401_hint;
      case AuthErrorCode.tokenInvalid:
        AppLogger.d(
            'Providing token invalid recovery hint', 'AuthErrorService',
        );
        return l10n.api_error_401_hint;
      case AuthErrorCode.serverError:
        if (httpStatusCode == 503) {
          AppLogger.d(
            'Providing 503 service unavailable recovery hint',
            'AuthErrorService',
          );
          return l10n.api_error_503_hint;
        }
        AppLogger.d(
          'Providing 500 internal server error recovery hint',
          'AuthErrorService',
        );
        return l10n.api_error_500_hint;
      case AuthErrorCode.unknown:
        AppLogger.d('No recovery hint for unknown error', 'AuthErrorService');
        return null;
    }
  }

  /// 获取完整的错误消息对象
  ///
  /// 便捷方法，同时获取错误文本和恢复建议
  /// 返回包含错误文本和可选恢复建议的 [AuthErrorMessage] 对象
  AuthErrorMessage getErrorMessage(
    AppLocalizations l10n,
    AuthErrorCode errorCode,
    int? httpStatusCode,
  ) {
    final errorText = getErrorText(l10n, errorCode, httpStatusCode);
    final recoveryHint = getErrorRecoveryHint(l10n, errorCode, httpStatusCode);

    return AuthErrorMessage(errorText, recoveryHint);
  }
}
