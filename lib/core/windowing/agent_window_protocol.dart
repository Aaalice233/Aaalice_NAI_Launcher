import 'dart:convert';

const agentWindowProtocolVersion = 2;
const agentWindowBusinessId = 'agent';
const agentWindowBridgeChannelName = 'nai_launcher/agent_window/v2';
const agentWindowMaxImageAssetBytes = 16 * 1024 * 1024;
const agentWindowMaxImageAssetsPerSnapshot = 64;
const agentWindowMaxImageAssetBytesPerSnapshot = 32 * 1024 * 1024;
const agentWindowMaxCachedImageAssets = 256;
const agentWindowMaxCachedImageAssetBytes = 256 * 1024 * 1024;
const agentWindowMaxTimelineTurns = 64;
const agentWindowMaxTimelineItems = 500;
const agentWindowMaxTranscriptMessages = 400;
const agentWindowMaxSessionSummaries = 100;
const agentWindowMaxEnvelopeBytes = 48 * 1024 * 1024;

enum AgentWindowLifecycle { opening, open, closing, docked, error }

enum AgentWindowEntrypointKind {
  primary,
  compatibleSecondary,
  incompatibleSecondary,
}

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

/// Routes every recognized Agent secondary away from the primary bootstrap.
///
/// A secondary can outlive a protocol change during hot restart. Treating its
/// now-incompatible arguments as a primary entrypoint would initialize a
/// second application runtime and contend for the primary process's Hive
/// locks before the window can complete its ready handshake.
AgentWindowEntrypointKind classifyAgentWindowEntrypoint(List<String> args) {
  if (AgentWindowLaunchArguments.tryParseEntrypointArgs(args) != null) {
    return AgentWindowEntrypointKind.compatibleSecondary;
  }
  if (identifiesAgentWindowEntrypointArgs(args)) {
    return AgentWindowEntrypointKind.incompatibleSecondary;
  }
  return AgentWindowEntrypointKind.primary;
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
    final int encodedLength;
    try {
      encodedLength = utf8.encode(jsonEncode(value)).length;
    } on Object {
      throw const FormatException('Envelope is not JSON encodable');
    }
    if (encodedLength > agentWindowMaxEnvelopeBytes) {
      throw const FormatException('Agent window envelope is too large');
    }
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
    if (revision is! int || revision < 0 || payload is! Map) {
      throw const FormatException('Malformed agent window snapshot');
    }
    final snapshot = AgentWindowSnapshot(
      revision: revision,
      payload: Map<String, Object?>.from(payload),
    );
    validateAgentWindowSnapshotAssets(snapshot);
    validateAgentWindowTimeline(snapshot.payload);
    return snapshot;
  }
}

/// Timeline is optional for legacy v2 whole-read snapshots. Once present it
/// must use stable entry/turn identities and bounded collections.
void validateAgentWindowTimeline(Map<String, Object?> payload) {
  final messages = payload['messages'];
  final sessions = payload['sessions'];
  if (messages is List && messages.length > agentWindowMaxTranscriptMessages) {
    throw const FormatException('Agent window transcript is too large');
  }
  if (sessions is List && sessions.length > agentWindowMaxSessionSummaries) {
    throw const FormatException('Agent window session list is too large');
  }
  final timeline = payload['timeline'];
  if (timeline == null) return;
  if (timeline is! List || timeline.length > agentWindowMaxTimelineTurns) {
    throw const FormatException('Malformed agent window timeline');
  }
  var itemCount = 0;
  final turnIds = <String>{};
  if (messages is List) {
    for (final messageValue in messages) {
      if (messageValue is! Map) {
        throw const FormatException('Malformed agent window message');
      }
      if (messageValue['live'] == true) continue;
      if (messageValue['turnId'] is! String ||
          (messageValue['turnId'] as String).isEmpty ||
          messageValue['entryId'] is! String ||
          (messageValue['entryId'] as String).isEmpty ||
          messageValue['seq'] is! int ||
          (messageValue['seq'] as int) < 0 ||
          (messageValue['parentEntryId'] != null &&
              messageValue['parentEntryId'] is! String)) {
        throw const FormatException('Malformed agent window message identity');
      }
    }
  }
  for (final value in timeline) {
    if (value is! Map) {
      throw const FormatException('Malformed agent window turn');
    }
    final turn = Map<Object?, Object?>.from(value);
    final id = turn['id'];
    final status = turn['status'];
    final firstSeq = turn['firstSeq'];
    final lastSeq = turn['lastSeq'];
    final items = turn['items'];
    if (id is! String ||
        id.isEmpty ||
        status is! String ||
        !const {
          'running',
          'completed',
          'failed',
          'aborted',
          'interrupted',
        }.contains(status) ||
        firstSeq is! int ||
        firstSeq < 0 ||
        lastSeq is! int ||
        lastSeq < firstSeq ||
        items is! List) {
      throw const FormatException('Malformed agent window turn');
    }
    if (!turnIds.add(id)) {
      throw const FormatException('Duplicate agent window turn');
    }
    final startedAt = turn['startedAt'];
    final completedAt = turn['completedAt'];
    final durationMs = turn['durationMs'];
    final error = turn['error'];
    if ((startedAt != null && (startedAt is! int || startedAt <= 0)) ||
        (completedAt != null && (completedAt is! int || completedAt <= 0)) ||
        (durationMs != null &&
            (durationMs is! int ||
                durationMs < 0 ||
                startedAt is! int ||
                completedAt is! int ||
                durationMs != completedAt - startedAt))) {
      throw const FormatException('Malformed agent window turn duration');
    }
    if (error != null && (error is! String || error.length > 20000)) {
      throw const FormatException('Malformed agent window turn error');
    }
    itemCount += items.length;
    if (itemCount > agentWindowMaxTimelineItems) {
      throw const FormatException('Agent window timeline is too large');
    }
    for (final itemValue in items) {
      if (itemValue is! Map) {
        throw const FormatException('Malformed agent window timeline item');
      }
      final item = Map<Object?, Object?>.from(itemValue);
      if (item['id'] is! String ||
          (item['id'] as String).isEmpty ||
          item['entryId'] is! String ||
          (item['entryId'] as String).isEmpty ||
          item['seq'] is! int ||
          (item['seq'] as int) < 0 ||
          (item['parentEntryId'] != null && item['parentEntryId'] is! String) ||
          item['kind'] is! String) {
        throw const FormatException('Malformed agent window timeline item');
      }
      if ((item['kind'] == 'toolCall' || item['kind'] == 'toolResult') &&
          (item['toolCallId'] is! String ||
              (item['toolCallId'] as String).isEmpty)) {
        throw const FormatException('Malformed agent window tool identity');
      }
    }
  }
  if (messages is List) {
    for (final messageValue in messages.whereType<Map>()) {
      final turnId = messageValue['turnId'];
      if (messageValue['live'] != true &&
          (turnId is! String || !turnIds.contains(turnId))) {
        throw const FormatException('Unknown agent window message turn');
      }
    }
  }
  final activities = payload['activities'];
  if (activities is List) {
    for (final activityValue in activities.whereType<Map>()) {
      final turnId = activityValue['turnId'];
      if (turnId != null && (turnId is! String || !turnIds.contains(turnId))) {
        throw const FormatException('Unknown agent window activity turn');
      }
    }
  }
  final history = payload['history'];
  if (history != null && history is! Map) {
    throw const FormatException('Malformed agent window history cursor');
  }
  if (history is Map) {
    if ((history['hasEarlier'] != null && history['hasEarlier'] is! bool) ||
        (history['hasNewer'] != null && history['hasNewer'] is! bool)) {
      throw const FormatException('Malformed agent window history state');
    }
    final cursorValue = history['cursor'];
    if (cursorValue != null) {
      if (cursorValue is! Map ||
          cursorValue['beforeSeq'] is! int ||
          (cursorValue['beforeSeq'] as int) < 0 ||
          (cursorValue['parentEntryId'] != null &&
              cursorValue['parentEntryId'] is! String)) {
        throw const FormatException('Malformed agent window history cursor');
      }
    }
  }
}

/// Validates the bounded, one-shot image asset delta carried by a snapshot.
void validateAgentWindowSnapshotAssets(AgentWindowSnapshot snapshot) {
  final assetsValue = snapshot.payload['imageAssets'];
  final referencesValue = snapshot.payload['referencedImageAssets'];
  if (assetsValue == null && referencesValue == null) return;
  if (assetsValue is! Map || referencesValue is! List) {
    throw const FormatException('Malformed agent window image asset delta');
  }
  final mode = snapshot.payload['imageAssetMode'];
  if (mode != null && mode != 'full') {
    throw const FormatException('Unsupported agent window image asset mode');
  }
  final fullCache = mode == 'full';
  final maxAssetCount = fullCache
      ? agentWindowMaxCachedImageAssets
      : agentWindowMaxImageAssetsPerSnapshot;
  final maxTotalBytes = fullCache
      ? agentWindowMaxCachedImageAssetBytes
      : agentWindowMaxImageAssetBytesPerSnapshot;
  if (assetsValue.length > maxAssetCount) {
    throw const FormatException('Agent window image asset count is too large');
  }
  var totalBytes = 0;
  for (final entry in assetsValue.entries) {
    if (entry.key is! String || (entry.key as String).isEmpty) {
      throw const FormatException('Agent window image asset ID is invalid');
    }
    final asset = entry.value;
    if (asset is! Map || asset['base64'] is! String) {
      throw const FormatException('Agent window image asset is malformed');
    }
    final mimeType = asset['mimeType'];
    if (mimeType != null &&
        !const {
          'image/png',
          'image/jpeg',
          'image/webp',
          'image/gif',
        }.contains(mimeType)) {
      throw const FormatException('Agent window image asset MIME is invalid');
    }
    final String encoded = asset['base64'] as String;
    if (encoded.length > ((agentWindowMaxImageAssetBytes + 2) ~/ 3) * 4) {
      throw const FormatException('Agent window image asset is too large');
    }
    final List<int> bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      throw const FormatException('Agent window image asset is invalid');
    }
    if (bytes.length > agentWindowMaxImageAssetBytes) {
      throw const FormatException('Agent window image asset is too large');
    }
    totalBytes += bytes.length;
    if (totalBytes > maxTotalBytes) {
      throw const FormatException(
        'Agent window image asset snapshot is too large',
      );
    }
  }
  if (referencesValue.any((value) => value is! String || value.isEmpty)) {
    throw const FormatException(
      'Agent window image asset reference is invalid',
    );
  }
  final references = referencesValue.cast<String>();
  if (references.length > agentWindowMaxCachedImageAssets ||
      references.toSet().length != references.length) {
    throw const FormatException(
      'Agent window image asset references are malformed',
    );
  }
}

/// Identifies an Agent secondary even when its protocol is incompatible, so
/// the current runtime can retire it instead of opening a duplicate window.
bool identifiesAgentWindowEntrypointArgs(List<String> args) {
  if (args.length < 3 || args.first != 'multi_window') return false;
  try {
    final decoded = jsonDecode(args[2]);
    return decoded is Map && decoded['businessId'] == agentWindowBusinessId;
  } on FormatException {
    return false;
  }
}

/// Applies an incremental snapshot's image assets to an engine-local cache.
/// Snapshot transport only carries newly published assets; each engine retains
/// referenced assets until the primary omits their IDs from the reference set.
AgentWindowSnapshot mergeAgentWindowSnapshotAssets(
  AgentWindowSnapshot previous,
  AgentWindowSnapshot next,
) {
  if (next.revision < previous.revision) {
    throw FormatException(
      'Out-of-order agent window snapshot revision: '
      '${next.revision} < ${previous.revision}',
    );
  }
  validateAgentWindowSnapshotAssets(previous);
  validateAgentWindowSnapshotAssets(next);
  final previousAssets = previous.payload['imageAssets'];
  final nextAssets = next.payload['imageAssets'];
  final referencedAssets = next.payload['referencedImageAssets'];
  final mergedAssets = <Object?, Object?>{
    if (previousAssets is Map) ...previousAssets,
    if (nextAssets is Map) ...nextAssets,
  };
  if (referencedAssets is List) {
    final referenced = referencedAssets.whereType<String>().toSet();
    mergedAssets.removeWhere((key, _) => !referenced.contains(key));
    final missing = referenced.difference(
      mergedAssets.keys.whereType<String>().toSet(),
    );
    if (missing.isNotEmpty) {
      throw FormatException(
        'Agent window snapshot references unavailable image assets: '
        '${missing.join(', ')}',
      );
    }
  }
  return AgentWindowSnapshot(
    revision: next.revision,
    payload: {
      ...next.payload,
      'imageAssetMode': 'full',
      'imageAssets': mergedAssets,
    },
  );
}
