import 'dart:convert';

const agentWindowProtocolVersion = 1;
const agentWindowBusinessId = 'agent';
const agentWindowBridgeChannelName = 'nai_launcher/agent_window/v1';

enum AgentWindowLifecycle { opening, open, closing, docked, error }

class AgentWindowBounds {
  const AgentWindowBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory AgentWindowBounds.fromJson(Map<Object?, Object?> json) {
    double number(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite) {
        throw FormatException('Invalid agent window bounds field: $key');
      }
      return value.toDouble();
    }

    return AgentWindowBounds(
      x: number('x'),
      y: number('y'),
      width: number('width'),
      height: number('height'),
    );
  }
}

class AgentWindowLaunchArguments {
  const AgentWindowLaunchArguments({
    required this.bounds,
    required this.alwaysOnTop,
    required this.handshakeToken,
  });

  final AgentWindowBounds bounds;
  final bool alwaysOnTop;
  final String handshakeToken;

  String encode() => jsonEncode({
    'protocolVersion': agentWindowProtocolVersion,
    'businessId': agentWindowBusinessId,
    'bounds': bounds.toJson(),
    'alwaysOnTop': alwaysOnTop,
    'handshakeToken': handshakeToken,
  });

  static AgentWindowLaunchArguments? tryParseEntrypointArgs(List<String> args) {
    if (args.length < 3 || args.first != 'multi_window') return null;
    try {
      final decoded = jsonDecode(args[2]);
      if (decoded is! Map) return null;
      final json = Map<Object?, Object?>.from(decoded);
      if (json['protocolVersion'] != agentWindowProtocolVersion ||
          json['businessId'] != agentWindowBusinessId ||
          json['alwaysOnTop'] is! bool ||
          json['handshakeToken'] is! String ||
          (json['handshakeToken'] as String).isEmpty ||
          json['bounds'] is! Map) {
        return null;
      }
      return AgentWindowLaunchArguments(
        bounds: AgentWindowBounds.fromJson(
          Map<Object?, Object?>.from(json['bounds'] as Map),
        ),
        alwaysOnTop: json['alwaysOnTop'] as bool,
        handshakeToken: json['handshakeToken'] as String,
      );
    } on FormatException {
      return null;
    }
  }
}

class AgentWindowEnvelope {
  const AgentWindowEnvelope({
    required this.kind,
    required this.name,
    required this.sequence,
    required this.sessionToken,
    this.payload = const {},
  });

  final String kind;
  final String name;
  final int sequence;
  final String sessionToken;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'protocolVersion': agentWindowProtocolVersion,
    'kind': kind,
    'name': name,
    'sequence': sequence,
    'sessionToken': sessionToken,
    'payload': payload,
  };

  factory AgentWindowEnvelope.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Envelope must be a map');
    final json = Map<Object?, Object?>.from(value);
    if (json['protocolVersion'] != agentWindowProtocolVersion) {
      throw const FormatException('Unsupported agent window protocol');
    }
    final kind = json['kind'];
    final name = json['name'];
    final sequence = json['sequence'];
    final sessionToken = json['sessionToken'];
    final payload = json['payload'];
    if (kind is! String ||
        name is! String ||
        sequence is! int ||
        sessionToken is! String ||
        sessionToken.isEmpty ||
        payload is! Map) {
      throw const FormatException('Malformed agent window envelope');
    }
    return AgentWindowEnvelope(
      kind: kind,
      name: name,
      sequence: sequence,
      sessionToken: sessionToken,
      payload: Map<String, Object?>.from(payload),
    );
  }
}

class AgentWindowSnapshot {
  const AgentWindowSnapshot({required this.revision, required this.payload});

  final int revision;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {'revision': revision, 'payload': payload};

  factory AgentWindowSnapshot.fromJson(Map<Object?, Object?> json) {
    final revision = json['revision'];
    final payload = json['payload'];
    if (revision is! int || payload is! Map) {
      throw const FormatException('Malformed agent window snapshot');
    }
    return AgentWindowSnapshot(
      revision: revision,
      payload: Map<String, Object?>.from(payload),
    );
  }
}
