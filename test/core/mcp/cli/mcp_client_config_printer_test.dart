import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/cli/mcp_client_config_printer.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';

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
        'cherry-studio',
        'pi',
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

  group('renderMcpAgentSetupPrompt', () {
    test('points the agent at the bundled CLI and the docs', () {
      final prompt = renderMcpAgentSetupPrompt(cliPath: windowsCliPath);

      expect(prompt, contains('"$windowsCliPath" print-config <your client>'));
      expect(prompt, contains(mcpDocsUrl));
      expect(prompt, contains(McpServerDefaults.serverName));
    });

    test('names no client, leaving the list to the CLI', () {
      final prompt = renderMcpAgentSetupPrompt(cliPath: windowsCliPath);

      for (final kind in McpClientKind.values) {
        expect(prompt, isNot(contains(kind.cliName)));
      }
      expect(prompt, contains('without a client argument'));
    });

    test('carries no credentials into the agent context', () {
      final prompt = renderMcpAgentSetupPrompt(cliPath: windowsCliPath);

      expect(prompt, isNot(contains(token)));
      expect(prompt, isNot(contains('Bearer')));
      expect(prompt, isNot(contains(mcpTokenEnvironmentVariable)));
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

    test('cherry-studio prints an importable streamableHttp entry', () {
      expect(render(McpClientKind.cherryStudio), '''
{
  "mcpServers": {
    "nai-launcher": {
      "name": "NAI Launcher",
      "type": "streamableHttp",
      "baseUrl": "http://127.0.0.1:20624/mcp",
      "headers": {
        "Authorization": "Bearer tok_abcdef0123456789"
      },
      "timeout": 600
    }
  }
}''');
    });

    test('pi prints a bearer entry for the mcp adapter', () {
      expect(render(McpClientKind.pi), '''
{
  "mcpServers": {
    "nai-launcher": {
      "url": "http://127.0.0.1:20624/mcp",
      "auth": "bearer",
      "bearerToken": "tok_abcdef0123456789",
      "requestTimeoutMs": 600000
    }
  }
}''');
    });

    Map<String, dynamic> serverEntry(McpClientKind kind) {
      final servers =
          (jsonDecode(render(kind)) as Map<String, dynamic>)['mcpServers']
              as Map<String, dynamic>;
      return servers[McpServerDefaults.serverName] as Map<String, dynamic>;
    }

    test('http clients outwait the in-app approval window', () {
      const approval = McpServerDefaults.approvalTimeout;

      expect(
        serverEntry(McpClientKind.cherryStudio)['timeout'] as int,
        greaterThan(approval.inSeconds),
      );
      expect(
        serverEntry(McpClientKind.pi)['requestTimeoutMs'] as int,
        greaterThan(approval.inMilliseconds),
      );
    });

    test('pi leaves protocol negotiation on the legacy default', () {
      final entry = serverEntry(McpClientKind.pi);

      expect(entry.containsKey('protocolVersion'), isFalse);
      expect(entry.containsKey('httpTransport'), isFalse);
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
