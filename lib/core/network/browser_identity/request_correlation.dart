import 'dart:math';

/// 官网每个请求携带的追踪头取值。
class RequestCorrelation {
  RequestCorrelation._();

  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz123456789';
  static const int _idLength = 6;

  static final Random _random = Random.secure();

  static String newCorrelationId() {
    return List.generate(
      _idLength,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
      growable: false,
    ).join();
  }

  /// 浏览器的 `toISOString()` 固定 3 位小数，Dart 在 Windows 上会带 6 位微秒。
  static String formatInitiatedAt(DateTime time) {
    return DateTime.fromMillisecondsSinceEpoch(
      time.toUtc().millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
  }

  static String nowInitiatedAt() => formatInitiatedAt(DateTime.now());
}
