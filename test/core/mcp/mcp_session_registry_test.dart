import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_launcher_server.dart';
import 'package:nai_launcher/core/mcp/mcp_session_registry.dart';

import 'fake_mcp_tool_executor.dart';

void main() {
  late DateTime now;
  late FakeMcpToolExecutor executor;
  final registries = <McpSessionRegistry>[];

  McpSessionRegistry buildRegistry({
    Duration idleTimeout = const Duration(minutes: 30),
    int maxSessions = 16,
    List<String>? ids,
  }) {
    var index = 0;
    final registry = McpSessionRegistry(
      createServer: (channel, session) => McpLauncherServer.fromStreamChannel(
        channel,
        executor: executor,
        sessionId: session.id,
        appVersion: '1.0.0',
        signalFor: session.signalFor,
        onClientInfo: session.attachClientInfo,
      ),
      idleTimeout: idleTimeout,
      maxSessions: maxSessions,
      clock: () => now,
      idGenerator: ids == null ? null : () => ids[index++ % ids.length],
    );
    registries.add(registry);
    return registry;
  }

  Future<Map<String, Object?>> handshake(
    McpSession session, {
    String name = 'codex',
    String version = '0.9.1',
  }) async {
    final response = session.outgoing
        .firstWhere((message) => message['id'] == 1)
        .timeout(const Duration(seconds: 5));
    session.send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-11-25',
        'capabilities': <String, Object?>{},
        'clientInfo': {'name': name, 'version': version},
      },
    });
    return response;
  }

  setUp(() {
    now = DateTime.utc(2026, 5, 7, 10);
    executor = FakeMcpToolExecutor([
      FakeAgentTool(name: 'get_application_context', label: 'Context'),
    ]);
  });

  tearDown(() async {
    for (final registry in registries) {
      await registry.dispose();
    }
    registries.clear();
  });

  test('create returns a findable session with a live protocol server', () {
    final registry = buildRegistry();

    final session = registry.create();

    expect(registry.find(session.id), same(session));
    expect(registry.length, 1);
    expect(session.server.sessionId, session.id);
    expect(session.connectedAt, now);
    expect(session.lastActivity, now);
  });

  test('generated ids are unique visible ASCII', () {
    final registry = buildRegistry();

    final ids = {for (var i = 0; i < 8; i++) registry.create().id};

    expect(ids, hasLength(8));
    for (final id in ids) {
      expect(RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(id), isTrue, reason: id);
    }
  });

  test('a colliding id generator still yields distinct sessions', () {
    final registry = buildRegistry(ids: ['fixed']);

    final first = registry.create();
    final second = registry.create();

    expect(first.id, 'fixed');
    expect(second.id, 'fixed-1');
    expect(registry.length, 2);
  });

  test('the session channel drives its protocol server', () async {
    final registry = buildRegistry();
    final session = registry.create();

    final result = await handshake(session);

    expect(
      (result['result'] as Map)['serverInfo'],
      containsPair('version', '1.0.0'),
    );
  });

  test('summaries pick up the client after the handshake', () async {
    final registry = buildRegistry();
    final session = registry.create();

    expect(registry.summaries.single.clientName, isNull);
    await handshake(session, name: 'claude-desktop', version: '1.5.0');

    final summary = registry.summaries.single;
    expect(summary.id, session.id);
    expect(summary.clientName, 'claude-desktop');
    expect(summary.clientVersion, '1.5.0');
    expect(summary.connectedAt, now);
  });

  test('changes emits on connect, handshake and disconnect', () async {
    final registry = buildRegistry();
    final emitted = <List<McpSessionSummary>>[];
    final subscription = registry.changes.listen(emitted.add);

    final session = registry.create();
    await handshake(session);
    await registry.close(session.id);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(emitted, hasLength(3));
    expect(emitted[0].single.clientName, isNull);
    expect(emitted[1].single.clientName, 'codex');
    expect(emitted[2], isEmpty);
  });

  test('touch moves lastActivity to the current clock', () {
    final registry = buildRegistry();
    final session = registry.create();

    now = now.add(const Duration(minutes: 7));
    registry.touch(session);

    expect(session.lastActivity, DateTime.utc(2026, 5, 7, 10, 7));
    expect(registry.summaries.single.lastActivity, session.lastActivity);
  });

  test('close aborts the in-flight calls of that session', () async {
    final registry = buildRegistry();
    final session = registry.create();
    final signal = session.signalFor('call-1');

    await registry.close(session.id);

    expect(signal.aborted, isTrue);
    expect(signal.reason, 'session closed');
    expect(registry.find(session.id), isNull);
    expect(registry.summaries, isEmpty);
  });

  test('closing an unknown session is a no-op', () async {
    final registry = buildRegistry();
    registry.create();

    await registry.close('nope');

    expect(registry.length, 1);
  });

  test('signalFor is stable per call id and endCall forgets it', () {
    final registry = buildRegistry();
    final session = registry.create();

    final signal = session.signalFor('call-1');
    expect(session.signalFor('call-1'), same(signal));

    session.abortCall('call-1', 'cancelled by client');
    expect(signal.aborted, isTrue);
    expect(signal.reason, 'cancelled by client');

    session.endCall('call-1');
    expect(session.signalFor('call-1'), isNot(same(signal)));
  });

  test('sweepIdle closes only sessions past the idle timeout', () async {
    final registry = buildRegistry(idleTimeout: const Duration(minutes: 30));
    final stale = registry.create();
    now = now.add(const Duration(minutes: 20));
    final fresh = registry.create();
    now = now.add(const Duration(minutes: 11));

    expect(registry.sweepIdle(), 1);
    expect(registry.find(stale.id), isNull);
    expect(registry.find(fresh.id), same(fresh));
    expect(registry.sweepIdle(), 0);
  });

  test('sweepIdle stops the servers of the sessions it closes', () async {
    final registry = buildRegistry(idleTimeout: const Duration(minutes: 5));
    final session = registry.create();
    now = now.add(const Duration(minutes: 6));

    expect(registry.sweepIdle(), 1);
    await Future<void>.delayed(Duration.zero);
    expect(session.server.isActive, isFalse);
  });

  test('sweepIdle keeps a session whose call is still running', () async {
    final registry = buildRegistry(idleTimeout: const Duration(minutes: 5));
    final session = registry.create();
    final signal = session.signalFor('call-1');
    now = now.add(const Duration(minutes: 6));

    expect(registry.sweepIdle(), 0);
    expect(registry.find(session.id), same(session));
    expect(signal.aborted, isFalse);

    session.endCall('call-1');
    expect(registry.sweepIdle(), 1);
  });

  test('sweepIdle closes the idle neighbours of a busy session', () async {
    final registry = buildRegistry(idleTimeout: const Duration(minutes: 5));
    final busy = registry.create();
    busy.signalFor('call-1');
    final idle = registry.create();
    now = now.add(const Duration(minutes: 6));

    expect(registry.sweepIdle(), 1);
    expect(registry.find(busy.id), same(busy));
    expect(registry.find(idle.id), isNull);
  });

  test('reaching maxSessions evicts the idlest session', () async {
    final registry = buildRegistry(maxSessions: 2);
    final first = registry.create();
    now = now.add(const Duration(minutes: 1));
    final second = registry.create();
    now = now.add(const Duration(minutes: 1));
    registry.touch(first);

    final third = registry.create();

    expect(registry.length, 2);
    expect(registry.find(second.id), isNull);
    expect(registry.find(first.id), same(first));
    expect(registry.find(third.id), same(third));
  });

  test('a busy session is never the one evicted', () async {
    final registry = buildRegistry(maxSessions: 2);
    final busy = registry.create();
    final busySignal = busy.signalFor('call-1');
    now = now.add(const Duration(minutes: 1));
    final idle = registry.create();

    final third = registry.create();

    expect(registry.length, 2);
    expect(registry.find(idle.id), isNull);
    expect(registry.find(busy.id), same(busy));
    expect(registry.find(third.id), same(third));
    expect(busySignal.aborted, isFalse);
  });

  test('create is refused while every session is busy', () async {
    final registry = buildRegistry(maxSessions: 2);
    final first = registry.create();
    final firstSignal = first.signalFor('call-1');
    final second = registry.create();
    final secondSignal = second.signalFor('call-2');

    expect(
      () => registry.create(),
      throwsA(isA<McpSessionCapacityException>()),
    );
    expect(registry.length, 2);
    expect(registry.find(first.id), same(first));
    expect(registry.find(second.id), same(second));
    expect(firstSignal.aborted, isFalse);
    expect(secondSignal.aborted, isFalse);
  });

  test('closeAll empties the registry and stops every server', () async {
    final registry = buildRegistry();
    final first = registry.create();
    final second = registry.create();

    await registry.closeAll();

    expect(registry.length, 0);
    expect(registry.summaries, isEmpty);
    expect(first.server.isActive, isFalse);
    expect(second.server.isActive, isFalse);
  });

  test('summary compares by value and copies field by field', () {
    final base = McpSessionSummary(
      id: 'a',
      clientName: 'codex',
      clientVersion: '0.9.1',
      connectedAt: DateTime.utc(2026),
      lastActivity: DateTime.utc(2026),
    );

    expect(base, base.copyWith());
    expect(base.hashCode, base.copyWith().hashCode);
    expect(base, isNot(base.copyWith(clientVersion: '0.9.2')));
    expect(base.copyWith(id: 'b').id, 'b');
    expect(base.copyWith(id: 'b').clientName, 'codex');
  });
}
