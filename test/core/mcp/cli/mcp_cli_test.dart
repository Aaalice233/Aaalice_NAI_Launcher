import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/cli/mcp_cli.dart';
import 'package:nai_launcher/core/mcp/mcp_discovery_file.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/unreachable_loopback.dart';

void main() {
  late Directory temp;
  late McpDiscoveryFileStore store;
  late _MemorySink output;
  late _MemorySink diagnostics;

  const String cliPath =
      r'C:\Programs\Aaalice NAI Launcher\nai_launcher_mcp.exe';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mcp-cli-test');
    store = McpDiscoveryFileStore(directory: temp);
    output = _MemorySink();
    diagnostics = _MemorySink();
    addTearDown(() async {
      await output.dispose();
      await diagnostics.dispose();
      if (temp.existsSync()) {
        await temp.delete(recursive: true);
      }
    });
  });

  Future<int> run(
    List<String> args, {
    Map<String, String> environment = const <String, String>{},
  }) => runNaiLauncherMcpCli(
    args,
    input: const Stream<List<int>>.empty(),
    output: output.sink,
    diagnostics: diagnostics.sink,
    discovery: store,
    executablePath: () => cliPath,
    environment: environment,
  );

  Future<McpDiscoveryDocument> publishDiscovery({
    int port = 20624,
    String token = 'discovery-token',
  }) async {
    final document = McpDiscoveryDocument(
      port: port,
      pid: 4242,
      startedAt: DateTime.utc(2026, 9, 13, 8, 30),
      token: token,
      protocolVersions: const ['2025-11-25', '2025-06-18'],
      appVersion: '4.2.1',
    );
    await store.write(document);
    return document;
  }

  group('print-config', () {
    test('renders every client from explicit endpoint and token', () async {
      const args = [
        'print-config',
        'claude-code',
        '--endpoint',
        'http://127.0.0.1:20624/mcp',
        '--token',
        'abc',
      ];

      expect(await run(args), 0);
      expect(
        (await output.text()).trim(),
        'claude mcp add --transport http nai-launcher '
        'http://127.0.0.1:20624/mcp --header "Authorization: Bearer abc"',
      );
    });

    test('accepts global options before the command name', () async {
      expect(
        await run([
          '--endpoint',
          'http://127.0.0.1:20624/mcp',
          '--token',
          'abc',
          'print-config',
          'cursor',
        ]),
        0,
      );
      expect(await output.text(), contains('"Bearer abc"'));
    });

    test('embeds the resolved executable path for claude-desktop', () async {
      expect(
        await run([
          'print-config',
          'claude-desktop',
          '--endpoint',
          'http://127.0.0.1:20624/mcp',
          '--token',
          'abc',
        ]),
        0,
      );
      expect(
        await output.text(),
        contains(r'C:\\Programs\\Aaalice NAI Launcher\\nai_launcher_mcp.exe'),
      );
    });

    test('falls back to the discovery file for endpoint and token', () async {
      await publishDiscovery();

      expect(await run(['print-config', 'codex']), 0);
      final printed = await output.text();
      expect(printed, contains('--url http://127.0.0.1:20624/mcp'));
      expect(printed, contains('NAI_LAUNCHER_MCP_TOKEN=discovery-token'));
    });

    test('rejects an unknown client with a usage exit code', () async {
      expect(
        await run([
          'print-config',
          'zed',
          '--endpoint',
          'http://127.0.0.1:20624/mcp',
          '--token',
          'abc',
        ]),
        64,
      );
      expect(await diagnostics.text(), contains('Unknown MCP client: zed'));
    });

    test('rejects a missing client argument', () async {
      expect(await run(['print-config']), 64);
      expect(await diagnostics.text(), contains('Specify exactly one client'));
    });
  });

  group('token resolution', () {
    test('--token-env wins over the discovery file', () async {
      await publishDiscovery();

      expect(
        await run(
          ['print-config', 'codex', '--token-env', 'MY_TOKEN'],
          environment: const {'MY_TOKEN': 'env-token'},
        ),
        0,
      );
      final printed = await output.text();
      expect(printed, contains('NAI_LAUNCHER_MCP_TOKEN=env-token'));
      expect(printed, isNot(contains('discovery-token')));
    });

    test('--token wins over --token-env', () async {
      expect(
        await run(
          [
            'print-config',
            'codex',
            '--endpoint',
            'http://127.0.0.1:20624/mcp',
            '--token',
            'explicit-token',
            '--token-env',
            'MY_TOKEN',
          ],
          environment: const {'MY_TOKEN': 'env-token'},
        ),
        0,
      );
      expect(
        await output.text(),
        contains('NAI_LAUNCHER_MCP_TOKEN=explicit-token'),
      );
    });

    test(
      'an unset --token-env variable falls back to the discovery file',
      () async {
        await publishDiscovery();

        expect(
          await run(['print-config', 'codex', '--token-env', 'MISSING']),
          0,
        );
        expect(
          await output.text(),
          contains('NAI_LAUNCHER_MCP_TOKEN=discovery-token'),
        );
      },
    );
  });

  group('discovery file failures', () {
    test('reports the searched path and exits 2 when it is missing', () async {
      expect(await run(['print-config', 'cursor']), 2);
      expect(
        (await diagnostics.text()).trim(),
        'NAI Launcher is not running or its MCP server is disabled '
        '(looked for ${store.file.path})',
      );
    });

    test('honours --discovery-file in the not-running message', () async {
      final override = p.join(temp.path, 'does-not-exist.json');

      expect(await run(['status', '--discovery-file', override]), 2);
      expect(
        (await diagnostics.text()).trim(),
        endsWith('(looked for $override)'),
      );
    });

    test(
      'exits 2 for a bare invocation that cannot find the launcher',
      () async {
        expect(await run(const <String>[]), 2);
        expect(
          await diagnostics.text(),
          contains('NAI Launcher is not running'),
        );
      },
    );

    test('exits 3 when the discovery file is not JSON', () async {
      await store.file.writeAsString('not json');

      expect(await run(['status']), 3);
      expect(await diagnostics.text(), contains('is corrupt'));
    });

    test('exits 3 when the discovery schema is unsupported', () async {
      await store.file.writeAsString(jsonEncode({'schema_version': 99}));

      expect(await run(['status']), 3);
      expect(
        await diagnostics.text(),
        contains('Unsupported MCP discovery schema version'),
      );
    });
  });

  group('status', () {
    test(
      'reports an unreachable endpoint without printing the token',
      () async {
        final refusing = await RefusingLoopbackPort.reserve();
        addTearDown(refusing.release);
        final port = refusing.port;
        final document = await publishDiscovery(
          port: port,
          token: 'secret-abc',
        );

        expect(await run(['status']), 0);
        final printed = await output.text();
        expect(printed, contains('endpoint: http://127.0.0.1:$port/mcp'));
        expect(printed, contains('pid: 4242'));
        expect(printed, contains('started_at: 2026-09-13T08:30:00.000Z'));
        expect(printed, contains('app_version: 4.2.1'));
        expect(printed, contains('protocol_versions: 2025-11-25, 2025-06-18'));
        expect(printed, contains('token: hidden (10 characters)'));
        expect(printed, contains('reachable: no'));
        expect(printed, isNot(contains(document.token)));
      },
    );

    test(
      'reports a reachable endpoint when the launcher is listening',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        await publishDiscovery(port: server.port);

        expect(await run(['status']), 0);
        expect(await output.text(), contains('reachable: yes'));
      },
    );
  });

  group('usage errors', () {
    test('rejects an unknown command', () async {
      expect(await run(['bogus']), 64);
      expect(
        await diagnostics.text(),
        contains('Could not find a command named "bogus"'),
      );
    });

    test('rejects an endpoint that is not an http url', () async {
      expect(await run(['status', '--endpoint', 'ftp://example.com/mcp']), 64);
      expect(await diagnostics.text(), contains('Invalid --endpoint value'));
    });

    test('rejects an unknown option', () async {
      expect(await run(['status', '--nope']), 64);
    });
  });
}

/// Collects everything written to an [IOSink] without touching the process.
class _MemorySink {
  _MemorySink() {
    _controller = StreamController<List<int>>();
    _subscription = _controller.stream.listen(_chunks.add);
    sink = IOSink(_controller.sink);
  }

  late final StreamController<List<int>> _controller;
  late final StreamSubscription<List<int>> _subscription;
  late final IOSink sink;
  final List<List<int>> _chunks = <List<int>>[];

  Future<String> text() async {
    await sink.flush();
    await Future<void>.delayed(Duration.zero);
    return utf8.decode(_chunks.expand((chunk) => chunk).toList());
  }

  Future<void> dispose() async {
    await sink.close();
    await _subscription.cancel();
  }
}
