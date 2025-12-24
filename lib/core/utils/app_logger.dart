import 'package:logger/logger.dart';

/// 应用日志工具类
/// 提供统一的日志接口，方便调试和问题排查
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.debug,
  );

  /// 初始化日志系统（保留接口兼容性）
  static Future<void> init() async {
    // 无需初始化
  }

  /// 调试日志
  static void d(String message, [String? tag]) {
    final tagPrefix = tag != null ? '[$tag] ' : '';
    _logger.d('$tagPrefix$message');
  }

  /// 信息日志
  static void i(String message, [String? tag]) {
    final tagPrefix = tag != null ? '[$tag] ' : '';
    _logger.i('$tagPrefix$message');
  }

  /// 警告日志
  static void w(String message, [String? tag]) {
    final tagPrefix = tag != null ? '[$tag] ' : '';
    _logger.w('$tagPrefix$message');
  }

  /// 错误日志
  static void e(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    final tagPrefix = tag != null ? '[$tag] ' : '';
    _logger.e('$tagPrefix$message', error: error, stackTrace: stackTrace);
  }

  /// 网络请求日志
  static void network(String method, String url, {dynamic data, dynamic response, dynamic error}) {
    if (error != null) {
      _logger.e('[HTTP] $method $url', error: error);
    } else if (response != null) {
      _logger.i('[HTTP] $method $url\nResponse: ${_truncate(response.toString(), 500)}');
    } else {
      _logger.d('[HTTP] $method $url\nData: ${_truncate(data?.toString() ?? 'null', 500)}');
    }
  }

  /// 加密相关日志（敏感数据脱敏）
  static void crypto(String operation, {String? email, int? keyLength, bool? success}) {
    final emailMasked = email != null ? _maskEmail(email) : null;
    final parts = <String>[
      '[Crypto] $operation',
      if (emailMasked != null) 'email: $emailMasked',
      if (keyLength != null) 'keyLength: $keyLength',
      if (success != null) 'success: $success',
    ];
    _logger.i(parts.join(' | '));
  }

  /// 认证相关日志
  static void auth(String action, {String? email, bool? success, String? error}) {
    final emailMasked = email != null ? _maskEmail(email) : null;
    final parts = <String>[
      '[Auth] $action',
      if (emailMasked != null) 'email: $emailMasked',
      if (success != null) 'success: $success',
      if (error != null) 'error: $error',
    ];
    if (success == false || error != null) {
      _logger.w(parts.join(' | '));
    } else {
      _logger.i(parts.join(' | '));
    }
  }

  /// 脱敏邮箱地址
  static String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return '***';
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }
    return '${name.substring(0, 2)}***@$domain';
  }

  /// 截断过长字符串
  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}... (truncated)';
  }
}
