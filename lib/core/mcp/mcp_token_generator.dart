import 'dart:convert';
import 'dart:math';

/// 32 bytes of entropy, base64url without padding so the token survives
/// client config files, shell arguments and HTTP headers unescaped.
String generateMcpServerToken({Random? random}) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => source.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
