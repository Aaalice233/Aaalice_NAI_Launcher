import 'dart:convert';

/// JWT Token 解析工具
class JWTParser {
  JWTParser._();

  /// 解析 JWT 获取过期时间
  /// 返回 null 表示解析失败或不是 JWT 格式
  static DateTime? parseExpiry(String token) {
    try {
      // JWT 格式：header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // 解码 payload
      final payload = parts[1];
      // 补充 base64 padding
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      // 获取 exp 字段（Unix 时间戳，秒）
      final exp = json['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查 token 是否即将过期
  /// [threshold] 提前多久判定为"即将过期"，默认 5 分钟
  static bool isExpiringSoon(
    String token, {
    Duration threshold = const Duration(minutes: 5),
  }) {
    final expiry = parseExpiry(token);
    if (expiry == null) return false;

    final now = DateTime.now();
    final timeUntilExpiry = expiry.difference(now);

    return timeUntilExpiry <= threshold;
  }

  /// 检查 token 是否已过期
  static bool isExpired(String token) {
    final expiry = parseExpiry(token);
    if (expiry == null) return false;

    return DateTime.now().isAfter(expiry);
  }

  /// 检查是否为 JWT 格式（而非 Persistent Token）
  static bool isJWT(String token) {
    // Persistent Token 格式：pst-xxx
    if (token.startsWith('pst-')) return false;

    // JWT 格式：xxx.xxx.xxx
    final parts = token.split('.');
    return parts.length == 3;
  }
}
