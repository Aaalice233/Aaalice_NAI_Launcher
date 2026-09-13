import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/cli/mcp_client_config_printer.dart';

void main() {
  final endpoint = Uri.parse('http://127.0.0.1:20624/mcp');
  const token = 'tok_abcdef0123456789';
  const windowsCliPath =
      r'C:\Users\alice\AppData\Local\Programs\Aaalice NAI Launcher'
      r'\nai_launcher_mcp.exe';

  String render(McpClientKind kind, {String cliPath = windowsCliPath}) =>
      renderMcpClientConfig(
        kind,
        endpoint: endpoint,
        token: token,
        cliPath: cliPath,
      );

  group('McpClientKind', () {
    test('maps every CLI name back to its kind', () {
      expect(McpClientKind.values.map((kind) => kind.cliName), [
        'claude-code',
        'codex',
        'cursor',
        'claude-desktop',
      ]);
      for (final kind in McpClientKind.values) {
        expect(McpClientKind.fromCliName(kind.cliName), kind);
      }
    });

    test('returns null for an unknown CLI name', () {
      expect(McpClientKind.fromCliName('claude'), isNull);
      expect(McpClientKind.fromCliName(''), isNull);
    });
  });

  group('renderMcpClientConfig', () {
    test('claude-code prints an http transport add command', () {
      expect(
        render(McpClientKind.claudeCode),
        'claude mcp add --transport http nai-launcher '
        'http://127.0.0.1:20624/mcp '
        '--header "Authorization: Bearer tok_abcdef0123456789"',
      );
    });

    test('codex prints the add command plus the token variable', () {
      expect(
        render(McpClientKind.codex),
        'codex mcp add nai-launcher --url http://127.0.0.1:20624/mcp '
        '--bearer-token-env-var NAI_LAUNCHER_MCP_TOKEN\n'
        'NAI_LAUNCHER_MCP_TOKEN=tok_abcdef0123456789',
      );
    });

    test('cursor prints pretty mcpServers JSON with the bearer header', () {
      expect(render(McpClientKind.cursor), '''
{
  "mcpServers": {
    "nai-launcher": {
      "url": "http://127.0.0.1:20624/mcp",
      "headers": {
        "Authorization": "Bearer tok_abcdef0123456789"
      }
    }
  }
}''');
    });

    test('claude-desktop prints the stdio command with escaped separators', () {
      expect(render(McpClientKind.claudeDesktop), '''
{
  "mcpServers": {
    "nai-launcher": {
      "command": "C:\\\\Users\\\\alice\\\\AppData\\\\Local\\\\Programs\\\\Aaalice NAI Launcher\\\\nai_launcher_mcp.exe"
    }
  }
}''');
    });

    test('claude-desktop keeps POSIX paths unescaped', () {
      expect(
        render(
          McpClientKind.claudeDesktop,
          cliPath:
              '/Applications/Aaalice NAI Launcher.app/Contents/MacOS/'
              'nai_launcher_mcp',
        ),
        '''
{
  "mcpServers": {
    "nai-launcher": {
      "command": "/Applications/Aaalice NAI Launcher.app/Contents/MacOS/nai_launcher_mcp"
    }
  }
}''',
      );
    });

    test('claude-desktop does not leak the token', () {
      expect(render(McpClientKind.claudeDesktop), isNot(contains(token)));
    });
  });
}
