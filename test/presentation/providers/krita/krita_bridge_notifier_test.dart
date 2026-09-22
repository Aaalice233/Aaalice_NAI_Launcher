import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/krita/krita_bridge_models.dart';
import 'package:nai_launcher/core/krita/krita_bridge_server.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_notifier.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_service.dart';

class RecordingKritaBridgeService implements KritaBridgeMessageService {
  final messages = <KritaBridgeMessage>[];
  final _controller = StreamController<KritaBridgeMessage>.broadcast();
  KritaBridgeActiveRequestReporter? _activeRequestReporter;
  var disconnectedCalls = 0;

  Stream<KritaBridgeMessage> get stream => _controller.stream;

  @override
  Future<void> handle(KritaBridgeMessage message) async {
    messages.add(message);
    _controller.add(message);
  }

  @override
  void handleClientDisconnected() {
    disconnectedCalls += 1;
  }

  @override
  void setActiveRequestReporter(KritaBridgeActiveRequestReporter reporter) {
    _activeRequestReporter = reporter;
  }

  void reportActiveRequest(String? requestId) {
    _activeRequestReporter?.call(requestId);
  }

  Future<void> close() => _controller.close();
}

void main() {
  late Directory tempDir;
  late KritaBridgeNotifier notifier;
  late RecordingKritaBridgeService bridgeService;
  late List<bool> persistedEnabledValues;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('krita_bridge_notifier_test_');
    bridgeService = RecordingKritaBridgeService();
    persistedEnabledValues = [];
    notifier = KritaBridgeNotifier(
      serverFactory: () => KritaBridgeServer(
        discoveryDirectory: tempDir,
        pidProvider: () => 12345,
        secretGenerator: () => 'notifier-secret',
        clock: () => DateTime.utc(2026, 5, 7, 10, 30),
      ),
      serviceFactory: (_) => bridgeService,
      persistEnabled: persistedEnabledValues.add,
    );
  });

  tearDown(() async {
    await notifier.close();
    await bridgeService.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('starts disabled by default', () {
    expect(notifier.state.enabled, isFalse);
    expect(notifier.state.status, KritaBridgeStatus.disabled);
    expect(notifier.state.port, isNull);
    expect(notifier.state.secret, isNull);
  });

  test('enable starts server and exposes listening session state', () async {
    await notifier.enable();

    final state = notifier.state;
    expect(state.enabled, isTrue);
    expect(state.status, KritaBridgeStatus.listening);
    expect(state.port, isNotNull);
    expect(state.secret, 'notifier-secret');
    expect(state.discoveryFilePath, endsWith('krita-bridge.json'));
    expect(await File(state.discoveryFilePath!).exists(), isTrue);
  });

  test('a failed enable keeps the discovery file of another instance',
      () async {
    const foreignContent = '{"port":4711,"pid":777,"version":1,'
        '"secret":"other-instance","started_at":"2026-05-07T09:00:00.000Z"}';
    final foreign =
        File('${tempDir.path}${Platform.pathSeparator}krita-bridge.json');
    await foreign.writeAsString(foreignContent);

    final failing = KritaBridgeNotifier(
      serverFactory: () => KritaBridgeServer(
        discoveryDirectory: tempDir,
        pidProvider: () => throw StateError('pid unavailable'),
        secretGenerator: () => 'failing-secret',
        clock: () => DateTime.utc(2026, 5, 7, 10, 30),
      ),
      serviceFactory: (_) => bridgeService,
      persistEnabled: persistedEnabledValues.add,
    );
    addTearDown(failing.close);

    await failing.enable();

    expect(failing.state.enabled, isFalse);
    expect(failing.state.status, KritaBridgeStatus.error);
    expect(failing.state.port, isNull);
    expect(persistedEnabledValues, isEmpty);
    expect(await foreign.exists(), isTrue);
    expect(await foreign.readAsString(), foreignContent);
  });

  test('disable stops server and clears session state', () async {
    await notifier.enable();
    final discoveryFilePath = notifier.state.discoveryFilePath!;

    await notifier.disable();

    final state = notifier.state;
    expect(state.enabled, isFalse);
    expect(state.status, KritaBridgeStatus.disabled);
    expect(state.port, isNull);
    expect(state.secret, isNull);
    expect(await File(discoveryFilePath).exists(), isFalse);
  });

  test('disable cancels active bridge request before clearing service',
      () async {
    await notifier.enable();
    bridgeService.reportActiveRequest('img-active');

    await notifier.disable();

    expect(bridgeService.disconnectedCalls, 1);
    expect(notifier.state.activeRequestId, isNull);
  });

  test('persists explicit enable and disable but not session regeneration',
      () async {
    await notifier.enable();
    await notifier.regenerateSession();
    await notifier.disable();

    expect(persistedEnabledValues, [true, false]);
  });

  test('regenerateSession invalidates the authenticated client', () async {
    await notifier.enable();
    final socket =
        await WebSocket.connect('ws://127.0.0.1:${notifier.state.port}/krita');
    final iterator = StreamIterator<dynamic>(socket);

    socket.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'notifier-secret',
      }),
    );
    await iterator.moveNext().timeout(const Duration(seconds: 2));
    expect(notifier.state.status, KritaBridgeStatus.connected);

    await notifier.regenerateSession();

    expect(notifier.state.status, KritaBridgeStatus.listening);
    expect(
      await iterator.moveNext().timeout(const Duration(seconds: 2)),
      isFalse,
    );
    expect(
      notifier.sendImageToKrita(
        Uint8List.fromList([1, 2, 3]),
        name: 'old-client.png',
      ),
      isFalse,
    );
  });

  test('forwards authenticated WebSocket messages to bridge service', () async {
    await notifier.enable();
    final socket =
        await WebSocket.connect('ws://127.0.0.1:${notifier.state.port}/krita');

    socket.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'notifier-secret',
      }),
    );
    await socket.first;
    expect(notifier.state.status, KritaBridgeStatus.connected);
    expect(notifier.state.connectedClientLabel, contains('127.0.0.1'));

    final nextMessage = bridgeService.stream.first;
    socket.add(jsonEncode({'type': 'get_params', 'id': 'params-1'}));

    final message = await nextMessage.timeout(const Duration(seconds: 2));
    expect(message, isA<KritaGetParamsMessage>());
    expect(message.id, 'params-1');

    await socket.close();
  });

  test('sendImageToKrita pushes image to authenticated Krita connection',
      () async {
    await notifier.enable();
    final socket =
        await WebSocket.connect('ws://127.0.0.1:${notifier.state.port}/krita');
    final iterator = StreamIterator<dynamic>(socket);

    socket.add(
      jsonEncode({
        'type': 'ping',
        'version': 1,
        'secret': 'notifier-secret',
      }),
    );
    await iterator.moveNext().timeout(const Duration(seconds: 2));

    final sent = notifier.sendImageToKrita(
      Uint8List.fromList([1, 2, 3]),
      name: 'from_launcher.png',
    );

    expect(sent, isTrue);
    await iterator.moveNext().timeout(const Duration(seconds: 2));
    final message =
        jsonDecode(iterator.current as String) as Map<String, dynamic>;
    expect(message['type'], 'push_image');
    expect(message['name'], 'from_launcher.png');
    expect(base64Decode(message['image'] as String), [1, 2, 3]);

    await iterator.cancel();
    await socket.close();
  });

  test('reflects active Krita request in bridge state', () async {
    await notifier.enable();

    bridgeService.reportActiveRequest('img-active');

    expect(notifier.state.activeRequestId, 'img-active');
    expect(notifier.state.isBridgeGenerating, isTrue);

    bridgeService.reportActiveRequest(null);

    expect(notifier.state.activeRequestId, isNull);
    expect(notifier.state.isBridgeGenerating, isFalse);
  });
}
