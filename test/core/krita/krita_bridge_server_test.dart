import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/krita/krita_bridge_models.dart';
import 'package:nai_launcher/core/krita/krita_bridge_server.dart';

// Far beyond loopback buffering, so close() cannot flush without a reader.
const _stalledPayloadBytes = 16 * 1024 * 1024;

// A paused WebSocket client still drains on Windows; a raw socket does not.
Future<Socket> _connectNonReadingPeer(
  int port, {
  required String secret,
}) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  final ping = utf8.encode(
    jsonEncode({'type': 'ping', 'version': 1, 'secret': secret}),
  );
  expect(ping.length, lessThan(126));
  socket.add(
    ascii.encode(
      'GET /krita HTTP/1.1\r\n'
      'Host: 127.0.0.1:$port\r\n'
      'Upgrade: websocket\r\n'
      'Connection: Upgrade\r\n'
      'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
      'Sec-WebSocket-Version: 13\r\n'
      '\r\n',
    ),
  );
  // Masked text frame; an all-zero masking key leaves the payload unchanged.
  socket.add([0x81, 0x80 | ping.length, 0, 0, 0, 0, ...ping]);
  await socket.flush();
  return socket;
}

class _LateFrameDrops {
  final _firstDrop = Completer<void>();
  var connectionCount = 0;

  void record() {
    connectionCount++;
    if (!_firstDrop.isCompleted) {
      _firstDrop.complete();
    }
  }

  Future<void> get first =>
      _firstDrop.future.timeout(const Duration(seconds: 2));
}

class RecordingPermissionGuard {
  RecordingPermissionGuard({this.refusedMode});

  final String? refusedMode;
  final modes = <String>[];
  final paths = <String>[];
  int? sizeWhenRestricted;

  Future<void> call(String path, String mode) async {
    modes.add(mode);
    paths.add(path);
    final candidate = File(path);
    if (mode == '600') {
      sizeWhenRestricted = await candidate.length();
    }
    if (mode == refusedMode) {
      throw const FileSystemException('permission change refused');
    }
  }
}

void main() {
  late Directory tempDir;
  late KritaBridgeServer server;
  late _LateFrameDrops lateFrameDrops;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('krita_bridge_server_test_');
    lateFrameDrops = _LateFrameDrops();
    server = KritaBridgeServer(
      discoveryDirectory: tempDir,
      pidProvider: () => 12345,
      secretGenerator: () => 'server-secret',
      clock: () => DateTime.utc(2026, 5, 7, 10, 30),
      onLateFramesDropped: lateFrameDrops.record,
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

  test('start restricts the directory and temp file before writing the secret',
      () async {
    final guard = RecordingPermissionGuard();
    final guarded = KritaBridgeServer(
      discoveryDirectory: tempDir,
      pidProvider: () => 12345,
      secretGenerator: () => 'guarded-secret',
      clock: () => DateTime.utc(2026, 5, 7, 10, 30),
      restrictToOwner: guard.call,
    );
    addTearDown(guarded.stop);

    await guarded.start(preferredPort: 0);

    expect(guard.modes, ['700', '600']);
    expect(guard.paths.first, tempDir.path);
    expect(guard.paths.last, endsWith('.tmp'));
    // The secret must not reach the disk before the file is owner-only.
    expect(guard.sizeWhenRestricted, 0);

    final file =
        File('${tempDir.path}${Platform.pathSeparator}krita-bridge.json');
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(data['secret'], 'guarded-secret');
  });

  test('a refused permission change rolls back and keeps the published file',
      () async {
    const foreignContent = '{"port":4711,"pid":777,"version":1,'
        '"secret":"other-instance","started_at":"2026-05-07T09:00:00.000Z"}';
    final foreign =
        File('${tempDir.path}${Platform.pathSeparator}krita-bridge.json');
    await foreign.writeAsString(foreignContent);

    final guard = RecordingPermissionGuard(refusedMode: '600');
    int? boundPort;
    late final KritaBridgeServer failing;
    failing = KritaBridgeServer(
      discoveryDirectory: tempDir,
      pidProvider: () {
        boundPort = failing.port;
        return 12345;
      },
      secretGenerator: () => 'failing-secret',
      clock: () => DateTime.utc(2026, 5, 7, 10, 30),
      restrictToOwner: guard.call,
    );
    addTearDown(failing.stop);

    await expectLater(
      failing.start(preferredPort: 0),
      throwsA(isA<FileSystemException>()),
    );

    expect(guard.sizeWhenRestricted, 0);
    expect(
      await tempDir.list().map((entity) => entity.path).toList(),
      [foreign.path],
    );
    expect(await foreign.readAsString(), foreignContent);
    expect(failing.isListening, isFalse);
    expect(failing.port, isNull);

    final rebound =
        await HttpServer.bind(InternetAddress.loopbackIPv4, boundPort!);
    await rebound.close(force: true);
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
    addTearDown(subscription.cancel);

    final first =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    addTearDown(first.close);
    final firstIterator = StreamIterator(first);
    addTearDown(firstIterator.cancel);
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
    addTearDown(second.close);
    final secondIterator = StreamIterator(second);
    addTearDown(secondIterator.cancel);
    second.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'server-secret',
      }),
    );
    expect(await secondIterator.moveNext(), isTrue);

    // The paused iterator has not read the close frame, so this still sends.
    first.add(jsonEncode({'type': 'get_params', 'id': 'from-old'}));
    await lateFrameDrops.first;

    final currentMessage = server.messages.first;
    second.add(jsonEncode({'type': 'get_params', 'id': 'from-current'}));
    final forwarded = await currentMessage.timeout(const Duration(seconds: 2));

    expect(forwarded, isA<KritaGetParamsMessage>());
    expect(forwarded.id, 'from-current');
    expect(
      messages.whereType<KritaGetParamsMessage>().map((message) => message.id),
      isNot(contains('from-old')),
    );
    expect(lateFrameDrops.connectionCount, 1);
  });

  test('stop closes connections that never authenticated', () async {
    await server.start(preferredPort: 0);
    final authentications = <bool>[];
    final authSubscription =
        server.authenticationChanges.listen(authentications.add);
    addTearDown(authSubscription.cancel);
    final socket =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    addTearDown(socket.close);
    final frames = StreamIterator(socket);
    addTearDown(frames.cancel);

    socket.add(jsonEncode({'type': 'ping', 'version': 1, 'secret': 'wrong'}));
    expect(await frames.moveNext(), isTrue);

    await server.stop();
    socket.add(jsonEncode({'type': 'ping', 'version': 1, 'secret': ''}));

    await expectLater(
      frames.moveNext().timeout(const Duration(seconds: 2)),
      completion(isFalse),
    );
    expect(authentications, isNot(contains(true)));
    expect(server.isClientAuthenticated, isFalse);
  });

  test('frames arriving after stop closes a socket are dropped', () async {
    await server.start(preferredPort: 0);
    final socket =
        await WebSocket.connect('ws://127.0.0.1:${server.port}/krita');
    addTearDown(socket.close);
    final frames = StreamIterator(socket);
    addTearDown(frames.cancel);
    socket.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'server-secret',
      }),
    );
    expect(await frames.moveNext(), isTrue);

    await server.stop();
    // The paused iterator has not read the close frame, so this still sends.
    socket.add('not json');

    await lateFrameDrops.first;
    await expectLater(
      frames.moveNext().timeout(const Duration(seconds: 2)),
      completion(isFalse),
    );
    expect(lateFrameDrops.connectionCount, 1);
  });

  test('stop does not wait for a peer that stops reading', () async {
    final stalled = KritaBridgeServer(
      discoveryDirectory: tempDir,
      pidProvider: () => 12345,
      secretGenerator: () => 'server-secret',
      clock: () => DateTime.utc(2026, 5, 7, 10, 30),
      closeGracePeriod: const Duration(milliseconds: 100),
    );
    addTearDown(stalled.stop);
    await stalled.start(preferredPort: 0);
    final authenticated = stalled.authenticationChanges.firstWhere(
      (isAuthenticated) => isAuthenticated,
    );
    final peer = await _connectNonReadingPeer(
      stalled.port!,
      secret: 'server-secret',
    );
    addTearDown(peer.destroy);
    await authenticated.timeout(const Duration(seconds: 2));

    stalled.sendBinary(Uint8List(_stalledPayloadBytes));
    await stalled.stop().timeout(const Duration(seconds: 2));

    expect(stalled.isListening, isFalse);
    expect(await stalled.discoveryFile.exists(), isFalse);
  });

  test('restart closes old connections and only accepts the new secret',
      () async {
    final secrets = ['first-secret', 'second-secret'].iterator;
    final restarting = KritaBridgeServer(
      discoveryDirectory: tempDir,
      pidProvider: () => 12345,
      secretGenerator: () => (secrets..moveNext()).current,
      clock: () => DateTime.utc(2026, 5, 7, 10, 30),
    );
    addTearDown(restarting.stop);

    await restarting.start(preferredPort: 0);
    final stale =
        await WebSocket.connect('ws://127.0.0.1:${restarting.port}/krita');
    addTearDown(stale.close);
    final staleFrames = StreamIterator(stale);
    addTearDown(staleFrames.cancel);
    stale.add(jsonEncode({'type': 'ping', 'version': 1, 'secret': 'wrong'}));
    expect(await staleFrames.moveNext(), isTrue);

    await restarting.start(preferredPort: 0);
    await expectLater(
      staleFrames.moveNext().timeout(const Duration(seconds: 2)),
      completion(isFalse),
    );

    Future<Map<String, dynamic>> pingWith(String secret) async {
      final socket =
          await WebSocket.connect('ws://127.0.0.1:${restarting.port}/krita');
      final reply = socket.first;
      socket.add(jsonEncode({'type': 'ping', 'version': 1, 'secret': secret}));
      final decoded =
          jsonDecode(await reply.timeout(const Duration(seconds: 2)) as String)
              as Map<String, dynamic>;
      await socket.close();
      return decoded;
    }

    final oldSecretReply = await pingWith('first-secret');
    expect(oldSecretReply['code'], KritaBridgeErrorCode.authFailed.value);
    final newSecretReply = await pingWith('second-secret');
    expect(newSecretReply['type'], 'pong');
  });
}
