import 'dart:convert';

import '../mcp_server_constants.dart';

/// Environment variable Codex reads the bearer token from.
const String mcpTokenEnvironmentVariable = 'NAI_LAUNCHER_MCP_TOKEN';

/// MCP clients the launcher can hand a ready-to-paste configuration to.
enum McpClientKind {
  claudeCode('claude-code'),
  codex('codex'),
  cursor('cursor'),
  claudeDesktop('claude-desktop');

  const McpClientKind(this.cliName);

  /// Name accepted on the command line and shown in the settings UI.
  final String cliName;

  static McpClientKind? fromCliName(String name) {
    for (final kind in values) {
      if (kind.cliName == name) {
        return kind;
      }
    }
    return null;
  }
}

const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

/// Renders the snippet a user pastes into [kind] to reach this launcher.
///
/// [cliPath] is the absolute path of the bundled stdio proxy and is only used
/// by clients that cannot speak Streamable HTTP.
String renderMcpClientConfig(
  McpClientKind kind, {
  required Uri endpoint,
  required String token,
  required String cliPath,
}) {
  const name = McpServerDefaults.serverName;
  switch (kind) {
    case McpClientKind.claudeCode:
      return 'claude mcp add --transport http $name $endpoint '
          '--header "Authorization: Bearer $token"';
    case McpClientKind.codex:
      return 'codex mcp add $name --url $endpoint '
          '--bearer-token-env-var $mcpTokenEnvironmentVariable\n'
          '$mcpTokenEnvironmentVariable=$token';
    case McpClientKind.cursor:
      return _prettyJson.convert({
        'mcpServers': {
          name: {
            'url': endpoint.toString(),
            'headers': {'Authorization': 'Bearer $token'},
          },
        },
      });
    case McpClientKind.claudeDesktop:
      return _prettyJson.convert({
        'mcpServers': {
          name: {'command': cliPath},
        },
      });
  }
}
