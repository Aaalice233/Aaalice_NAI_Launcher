import 'dart:convert';

import '../../constants/community_links.dart';
import '../mcp_server_constants.dart';

/// Setup steps the snippets point a user or an agent at.
const String mcpDocsUrl =
    '${CommunityLinks.github}/blob/main/docs/mcp_server.md';

/// Environment variable Codex reads the bearer token from.
const String mcpTokenEnvironmentVariable = 'NAI_LAUNCHER_MCP_TOKEN';

/// MCP clients the launcher can hand a ready-to-paste configuration to.
enum McpClientKind {
  claudeCode('claude-code'),
  codex('codex'),
  cursor('cursor'),
  cherryStudio('cherry-studio'),
  pi('pi'),
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

/// Clients must outwait the in-app approval window, or they give up before the
/// user can confirm the call.
final Duration _clientCallTimeout = McpServerDefaults.approvalTimeout * 2;

/// Renders the prompt a user hands to an agent so it configures its own host.
///
/// The bundled CLI resolves the endpoint and token from the discovery file, so
/// the prompt carries no credentials into the agent's model context.
String renderMcpAgentSetupPrompt({required String cliPath}) {
  return '''
Configure this agent to use the NAI Launcher MCP server.

1. Run: "$cliPath" print-config <your client>
   Run it without a client argument to see the supported names.
   It resolves the running launcher's endpoint and token by itself, so no
   credentials are needed in this prompt.
2. Merge the printed snippet into your own MCP configuration file. See
   $mcpDocsUrl if you are unsure where that file lives.
3. Restart, then confirm the "${McpServerDefaults.serverName}" server lists its tools.

If the command fails, the launcher is not running or its MCP server is off.
Report that instead of inventing a configuration.''';
}

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
    case McpClientKind.cherryStudio:
      return _prettyJson.convert({
        'mcpServers': {
          name: {
            'name': 'NAI Launcher',
            'type': 'streamableHttp',
            'baseUrl': endpoint.toString(),
            'headers': {'Authorization': 'Bearer $token'},
            'timeout': _clientCallTimeout.inSeconds,
          },
        },
      });
    case McpClientKind.pi:
      // Without an explicit auth type the adapter treats the 401 challenge as
      // an OAuth hint and starts discovery instead of sending the token.
      return _prettyJson.convert({
        'mcpServers': {
          name: {
            'url': endpoint.toString(),
            'auth': 'bearer',
            'bearerToken': token,
            'requestTimeoutMs': _clientCallTimeout.inMilliseconds,
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
