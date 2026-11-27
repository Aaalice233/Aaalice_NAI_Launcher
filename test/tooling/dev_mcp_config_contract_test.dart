import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project-level Dart MCP configs exist and share start_dart_mcp.ps1', () {
    final scriptFile = File('scripts/start_dart_mcp.ps1');
    expect(scriptFile.existsSync(), isTrue);

    final codexConfig = File('.codex/config.toml').readAsStringSync();
    expect(codexConfig, contains('[mcp_servers.dart]'));
    expect(codexConfig, contains('scripts/start_dart_mcp.ps1'));

    final pluginManifest =
        jsonDecode(
              File('.agents/plugins/dart-mcp/plugin.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(pluginManifest['name'], 'dart-mcp');

    for (final path in [
      '.agents/plugins/dart-mcp/mcp_config.json',
      '.mcp.json',
    ]) {
      final configFile = File(path);
      expect(configFile.existsSync(), isTrue, reason: 'Missing $path');

      final decoded =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final servers = decoded['mcpServers'] as Map<String, dynamic>?;
      expect(servers, isNotNull, reason: '$path should define mcpServers');

      final dartServer = servers!['dart'] as Map<String, dynamic>?;
      expect(
        dartServer,
        isNotNull,
        reason: '$path should define mcpServers.dart',
      );
      expect(dartServer!['command'], 'pwsh');

      final args = (dartServer['args'] as List<dynamic>).cast<String>();
      expect(
        args.join(' '),
        contains('scripts/start_dart_mcp.ps1'),
        reason: '$path should launch scripts/start_dart_mcp.ps1',
      );
      expect(
        args.join(' '),
        isNot(matches(RegExp(r'[A-Za-z]:[/\\]|/Users/'))),
        reason: '$path must remain machine-independent',
      );
    }
  });
}
