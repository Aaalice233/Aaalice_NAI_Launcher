import '../utils/constant_time_equals.dart';

/// Checks `Authorization: Bearer <token>` against the token the launcher
/// published in its discovery file.
class McpBearerAuthenticator {
  McpBearerAuthenticator(this._expectedToken);

  static const String _scheme = 'bearer ';

  final String Function() _expectedToken;

  bool authorize(String? authorizationHeader) {
    final header = authorizationHeader?.trim() ?? '';
    if (header.length <= _scheme.length) {
      return false;
    }
    if (header.substring(0, _scheme.length).toLowerCase() != _scheme) {
      return false;
    }
    final presented = header.substring(_scheme.length).trim();
    return secretsMatch(_expectedToken(), presented);
  }
}
