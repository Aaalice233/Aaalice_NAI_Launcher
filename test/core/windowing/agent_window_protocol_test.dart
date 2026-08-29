import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_window_protocol.dart';

void main() {
  test('secondary launch arguments round-trip through entrypoint args', () {
    const arguments = AgentWindowLaunchArguments(
      bounds: AgentWindowBounds(x: 12, y: 24, width: 560, height: 760),
      alwaysOnTop: true,
      handshakeToken: 'handshake-token',
    );

    final decoded = AgentWindowLaunchArguments.tryParseEntrypointArgs([
      'multi_window',
      'window-id',
      arguments.encode(),
    ]);

    expect(decoded, isNotNull);
    expect(decoded!.bounds.toJson(), arguments.bounds.toJson());
    expect(decoded.alwaysOnTop, isTrue);
    expect(decoded.handshakeToken, 'handshake-token');
  });

  test(
    'main and malformed arguments are not treated as a secondary engine',
    () {
      expect(
        AgentWindowLaunchArguments.tryParseEntrypointArgs(const []),
        isNull,
      );
      expect(
        AgentWindowLaunchArguments.tryParseEntrypointArgs(const [
          'multi_window',
          'id',
          '{"protocolVersion":999}',
        ]),
        isNull,
      );
    },
  );

  test('versioned envelope rejects incompatible peers', () {
    expect(
      () => AgentWindowEnvelope.fromJson({
        'protocolVersion': 99,
        'kind': 'event',
        'name': 'ready',
        'sequence': 0,
        'payload': <String, Object?>{},
      }),
      throwsFormatException,
    );
  });

  test('incompatible Agent entrypoints remain identifiable for retirement', () {
    const args = [
      'multi_window',
      'old-window',
      '{"protocolVersion":1,"businessId":"agent"}',
    ];

    expect(AgentWindowLaunchArguments.tryParseEntrypointArgs(args), isNull);
    expect(identifiesAgentWindowEntrypointArgs(args), isTrue);
    expect(
      classifyAgentWindowEntrypoint(args),
      AgentWindowEntrypointKind.incompatibleSecondary,
    );
    expect(
      classifyAgentWindowEntrypoint(const []),
      AgentWindowEntrypointKind.primary,
    );
    expect(
      identifiesAgentWindowEntrypointArgs(const [
        'multi_window',
        'other',
        '{"protocolVersion":1,"businessId":"other"}',
      ]),
      isFalse,
    );
  });

  test('current Agent entrypoint is routed to the IPC-only secondary', () {
    const arguments = AgentWindowLaunchArguments(
      bounds: AgentWindowBounds(x: 0, y: 0, width: 560, height: 760),
      alwaysOnTop: false,
      handshakeToken: 'current-token',
    );

    expect(
      classifyAgentWindowEntrypoint([
        'multi_window',
        'current-window',
        arguments.encode(),
      ]),
      AgentWindowEntrypointKind.compatibleSecondary,
    );
  });

  test('window envelopes preserve and require the authenticated token', () {
    const envelope = AgentWindowEnvelope(
      kind: 'command',
      name: 'send',
      sequence: 3,
      sessionToken: 'window-session',
    );

    final decoded = AgentWindowEnvelope.fromJson(envelope.toJson());

    expect(decoded.sessionToken, 'window-session');
    expect(
      () => AgentWindowEnvelope.fromJson({
        ...envelope.toJson(),
        'sessionToken': '',
      }),
      throwsFormatException,
    );
  });

  test('legacy snapshots remain valid while timeline duration is strict', () {
    expect(
      AgentWindowSnapshot.fromJson({
        'revision': 1,
        'payload': {'messages': <Object?>[], 'sessions': <Object?>[]},
      }).revision,
      1,
    );
    expect(
      () => AgentWindowSnapshot.fromJson({
        'revision': 2,
        'payload': {
          'messages': <Object?>[],
          'sessions': <Object?>[],
          'timeline': [
            {
              'id': 'turn-1',
              'status': 'completed',
              'firstSeq': 1,
              'lastSeq': 1,
              'startedAt': 100,
              'durationMs': 20,
              'items': <Object?>[],
            },
          ],
        },
      }),
      throwsFormatException,
    );
  });

  test('snapshot transcript and session collections are bounded', () {
    expect(
      () => AgentWindowSnapshot.fromJson({
        'revision': 1,
        'payload': {
          'messages': List<Object?>.filled(
            agentWindowMaxTranscriptMessages + 1,
            const {},
          ),
        },
      }),
      throwsFormatException,
    );
    expect(
      () => AgentWindowSnapshot.fromJson({
        'revision': 1,
        'payload': {
          'sessions': List<Object?>.filled(
            agentWindowMaxSessionSummaries + 1,
            const {},
          ),
        },
      }),
      throwsFormatException,
    );
  });
}
