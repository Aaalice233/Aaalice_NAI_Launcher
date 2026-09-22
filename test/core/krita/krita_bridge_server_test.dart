import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/krita/krita_bridge_models.dart';
import 'package:nai_launcher/core/krita/krita_bridge_server.dart';

void main() {
  late Directory tempDir;
  late KritaBridgeServer server;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('krita_bridge_server_test_');
    server = KritaBridgeServer(
      discoveryDirectory: tempDir,
      pidProvider: () => 12345,
      secretGenerator: () => 'server-secret',
      clock: () => DateTime.utc(2026, 5, 7, 10, 30),
    );
  });

  tearDown(() async {
    await server.stop();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('start writes discovery file and stop deletes it', () async {
    await server.start(preferredPort: 0);

    final file =
        File('${tempDir.path}${Platform.pathSeparator}krita-bridge.json');
    expect(await file.exists(), isTrue);

    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(data['port'], server.port);
    expect(data['pid'], 12345);
    expect(data['version'], 1);
    expect(data['secret'], 'server-secret');
    expect(data['started_at'], '2026-05-07T10:30:00.000Z');

    await server.stop();

    expect(await file.exists(), isFalse);
  });

  test('start replaces a stale discovery file without leaving temp files',
      () async {
    final file =
        File('${tempDir.path}${Platform.pathSeparator}krita-bridge.json');
    await file.writeAsString('{"port":4711,"pid":777,"version":1}');

    await server.start(preferredPort: 0);

    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(data['pid'], 12345);
    expect(data['secret'], 'server-secret');
    expect(
      await tempDir.list().map((entity) => entity.path).toList(),
      [file.path],
    );
  });

  test('a failed discovery write releases the bound port', () async {
    final blockedDirectory =
        Directory('${tempDir.path}${Platform.pathSeparator}blocked');
    await blockedDirectory.create();
    await Directory(
      '${blockedDirectory.path}${Platform.pathSeparator}krita-bridge.json',
    ).create();

    int? boundPort;
    late final KritaBridgeServer failing;
    failing = KritaBridgeServer(
      discoveryDirectory: blockedDirectory,
      pidProvider: () {
        boundPort = failing.port;
        return 12345;
      },
      secretGenerator: () => 'failing-secret',
      clock: () => DateTime.utc(2026, 5, 7, 10, 30),
    );
    addTearDown(failing.stop);

    await expectLater(
      failing.start(preferredPort: 0),
      throwsA(isA<FileSystemException>()),
    );

    final residue =
        await blockedDirectory.list().map((entity) => entity.path).toList();
    expect(residue.where((path) => path.endsWith('.tmp')), isEmpty);

    expect(failing.isListening, isFalse);
    expect(failing.port, isNull);
    expect(failing.secret, isNull);

    final rebound =
        await HttpServer.bind(InternetAddress.loopbackIPv4, boundPort!);
    await rebound.close(force: true);
  });

  test('a failed start keeps the discovery file of another instance', () async {
    const foreignContent = '{"port":4711,"pid":777,"version":1,'
        '"secret":"other-instance","started_at":"2026-05-07T09:00:00.000Z"}';
    final foreign =
        File('${tempDir.path}${Platform.pathSeparator}krita-bridge.json');
    await foreign.writeAsString(foreignContent);

    final failing = KritaBridgeServer(
      discoveryDirectory: tempDir,
      pidProvider: () => throw StateError('pid unavailable'),
      secretGenerator: () => 'failing-secret',
      clock: () => DateTime.utc(2026, 5, 7, 10, 30),
    );

    await expectLater(
      failing.start(preferredPort: 0),
      throwsA(isA<StateError>()),
    );

    expect(failing.isListening, isFalse);
    expect(await foreign.exists(), isTrue);
    expect(await foreign.readAsString(), foreignContent);
    expect(
      await tempDir.list().map((entity) => entity.path).toList(),
      [foreign.path],
    );
  });

  test('start succeeds again on the same port after a failed write', () async {
    var failWrites = true;
    int? boundPort;
    late final KritaBridgeServer flaky;
    flaky = KritaBridgeServer(
      discoveryDirectory: tempDir,
      pidProvider: () {
        boundPort = flaky.port;
        if (failWrites) {
          throw StateError('pid unavailable');
        }
        return 12345;
      },
      secretGenerator: () => 'flaky-secret',
      clock: () => DateTime.utc(2026, 5, 7, 10, 30),
    );
    addTearDown(flaky.stop);

    await expectLater(
      flaky.start(preferredPort: 0),
      throwsA(isA<StateError>()),
    );
    await flaky.stop();
    await flaky.stop();

    failWrites = false;
    await flaky.start(preferredPort: boundPort!);

    expect(flaky.isListening, isTrue);
    expect(flaky.port, boundPort);
    expect(flaky.secret, 'flaky-secret');
    expect(
      await File('${tempDir.path}${Platform.pathSeparator}krita-bridge.json')
          .exists(),
      isTrue,
    );
  });

  test('rejects unauthenticated messages and keeps them off message stream',
      () async {
    await server.start(preferredPort: 0);
    final socket =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    final messages = <KritaBridgeMessage>[];
    final subscription = server.messages.listen(messages.add);

    socket.add(jsonEncode({'type': 'get_params', 'id': 'req-1'}));

    final response =
        jsonDecode(await socket.first as String) as Map<String, dynamic>;
    expect(response['type'], 'error');
    expect(
      response['code'],
      KritaBridgeErrorCode.unauthorizedBridgeClient.value,
    );
    expect(messages, isEmpty);

    await subscription.cancel();
    await socket.close();
  });

  test('authenticates with ping and forwards later messages', () async {
    await server.start(preferredPort: 0);
    final socket =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    final nextMessage = server.messages.first;

    socket.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'server-secret',
      }),
    );
    final pong =
        jsonDecode(await socket.first as String) as Map<String, dynamic>;
    expect(pong['type'], 'pong');
    expect(pong['version'], 1);
    expect(server.isClientAuthenticated, isTrue);

    socket.add(jsonEncode({'type': 'get_params', 'id': 'req-2'}));
    final message = await nextMessage.timeout(const Duration(seconds: 2));

    expect(message, isA<KritaGetParamsMessage>());
    expect(message.id, 'req-2');

    await socket.close();
  });

  test('does not share authentication with a second unauthenticated client',
      () async {
    await server.start(preferredPort: 0);
    final first =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    final firstIterator = StreamIterator(first);
    final second =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    final messages = <KritaBridgeMessage>[];
    final subscription = server.messages.listen(messages.add);

    first.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'server-secret',
      }),
    );
    expect(await firstIterator.moveNext(), isTrue);
    expect(server.isClientAuthenticated, isTrue);

    second.add(jsonEncode({'type': 'get_params', 'id': 'req-second'}));

    final response =
        jsonDecode(await second.first as String) as Map<String, dynamic>;
    expect(response['type'], 'error');
    expect(
      response['code'],
      KritaBridgeErrorCode.unauthorizedBridgeClient.value,
    );
    await Future<void>.delayed(Duration.zero);
    expect(messages, isEmpty);

    await subscription.cancel();
    await firstIterator.cancel();
    await first.close();
    await second.close();
  });

  test('reports supported versions without authenticating mismatched ping',
      () async {
    await server.start(preferredPort: 0);
    final socket =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');

    socket.add(
      jsonEncode({
        'type': 'ping',
        'version': 999,
        'secret': 'server-secret',
      }),
    );

    final response =
        jsonDecode(await socket.first as String) as Map<String, dynamic>;
    expect(response['type'], 'pong');
    expect(response['version'], 1);
    expect(response['supported_versions'], [1]);
    expect(server.isClientAuthenticated, isFalse);

    await socket.close();
  });

  test('new authenticated client replaces the old authenticated client',
      () async {
    await server.start(preferredPort: 0);
    final first =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    final firstIterator = StreamIterator(first);
    first.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'server-secret',
      }),
    );
    expect(await firstIterator.moveNext(), isTrue);

    final second =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    final secondIterator = StreamIterator(second);
    second.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'server-secret',
      }),
    );
    expect(await secondIterator.moveNext(), isTrue);
    final pong =
        jsonDecode(secondIterator.current as String) as Map<String, dynamic>;

    expect(pong['type'], 'pong');
    await expectLater(
      firstIterator.moveNext().timeout(const Duration(seconds: 2)),
      completion(isFalse),
    );

    await firstIterator.cancel();
    await secondIterator.cancel();
    await second.close();
  });

  test('replaced authenticated client cannot forward messages', () async {
    await server.start(preferredPort: 0);
    final messages = <KritaBridgeMessage>[];
    final subscription = server.messages.listen(messages.add);

    final first =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    final firstIterator = StreamIterator(first);
    first.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'server-secret',
      }),
    );
    expect(await firstIterator.moveNext(), isTrue);

    final second =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    final secondIterator = StreamIterator(second);
    second.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'server-secret',
      }),
    );
    expect(await secondIterator.moveNext(), isTrue);

    first.add(jsonEncode({'type': 'get_params', 'id': 'from-old'}));
    second.add(jsonEncode({'type': 'get_params', 'id': 'from-current'}));

    final currentMessage =
        await server.messages.first.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(Duration.zero);

    expect(currentMessage, isA<KritaGetParamsMessage>());
    expect(currentMessage.id, 'from-current');
    expect(
      messages.whereType<KritaGetParamsMessage>().map((message) => message.id),
      isNot(contains('from-old')),
    );

    await subscription.cancel();
    await firstIterator.cancel();
    await secondIterator.cancel();
    await first.close();
    await second.close();
  });
}
