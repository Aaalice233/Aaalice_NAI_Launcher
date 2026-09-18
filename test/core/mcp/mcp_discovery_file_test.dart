import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_discovery_file.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';

void main() {
  late Directory tempDir;
  late McpDiscoveryFileStore store;

  McpDiscoveryDocument document({int port = 20624}) => McpDiscoveryDocument(
    port: port,
    pid: 4242,
    startedAt: DateTime.utc(2026, 5, 7, 10, 30),
    token: 'discovery-token',
    protocolVersions: const ['2025-06-18', '2025-11-25'],
    appVersion: '4.2.1',
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mcp_discovery_file_test_');
    store = McpDiscoveryFileStore(directory: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('endpoint points at the loopback MCP path', () {
    expect(
      document(port: 20624).endpoint.toString(),
      'http://${McpServerDefaults.loopbackHost}:20624'
      '${McpServerDefaults.endpointPath}',
    );
  });

  test('write then read round-trips every field', () async {
    await store.write(document());

    final restored = await store.read();

    expect(restored, isNotNull);
    expect(restored!.schemaVersion, McpDiscoveryDocument.currentSchemaVersion);
    expect(restored.port, 20624);
    expect(restored.pid, 4242);
    expect(restored.startedAt, DateTime.utc(2026, 5, 7, 10, 30));
    expect(restored.token, 'discovery-token');
    expect(restored.protocolVersions, ['2025-06-18', '2025-11-25']);
    expect(restored.appVersion, '4.2.1');
  });

  test('write leaves no temp files behind', () async {
    await store.write(document());
    await store.write(document(port: 14020));

    final names = tempDir
        .listSync()
        .map((entity) => entity.uri.pathSegments.last)
        .toList();

    expect(names, [McpServerDefaults.discoveryFileName]);
    expect((await store.read())!.port, 14020);
  });

  test('a failed write surfaces the error and leaves no temp file', () async {
    // A directory sitting on the target path makes the final rename fail.
    await Directory(store.file.path).create();

    await expectLater(
      store.write(document()),
      throwsA(isA<FileSystemException>()),
    );

    final entries = tempDir.listSync();
    expect(entries, hasLength(1));
    expect(entries.where((entity) => entity.path.endsWith('.tmp')), isEmpty);
  });

  test('reading a missing file returns null', () async {
    expect(await store.read(), isNull);
  });

  test('reading a corrupt file surfaces a FormatException', () async {
    await store.file.writeAsString('not json at all');

    expect(store.read(), throwsA(isA<FormatException>()));
  });

  test(
    'reading an unsupported schema version surfaces a FormatException',
    () async {
      final payload = document().toJson()..['schema_version'] = 99;
      await store.file.writeAsString(jsonEncode(payload));

      expect(store.read(), throwsA(isA<FormatException>()));
    },
  );

  test(
    'reading a document without a token surfaces a FormatException',
    () async {
      final payload = document().toJson()..remove('token');
      await store.file.writeAsString(jsonEncode(payload));

      expect(store.read(), throwsA(isA<FormatException>()));
    },
  );

  test('delete removes the file and tolerates a missing one', () async {
    await store.write(document());
    expect(store.file.existsSync(), isTrue);

    await store.delete();
    expect(store.file.existsSync(), isFalse);

    await store.delete();
    expect(store.file.existsSync(), isFalse);
  });
}
