/// Loopback-only `Origin` gate for the MCP endpoint, which is what keeps a
/// browser page on a remote site from driving the launcher via DNS rebinding.
abstract final class McpOriginPolicy {
  static const Set<String> _allowedHosts = {
    '127.0.0.1',
    'localhost',
    '::1',
    '[::1]',
  };

  /// Non-browser clients omit `Origin` entirely, so an absent header is not a
  /// rebinding signal and stays allowed.
  static bool allows(String? origin) {
    if (origin == null) {
      return true;
    }
    final trimmed = origin.trim();
    if (trimmed.isEmpty) {
      return true;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return false;
    }
    return _allowedHosts.contains(uri.host.toLowerCase());
  }
}
