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
}
