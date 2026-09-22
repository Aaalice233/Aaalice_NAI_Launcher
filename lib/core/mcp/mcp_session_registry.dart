import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:stream_channel/stream_channel.dart';

import '../agent/agent_types.dart';
import '../utils/portable_logger.dart';
import 'mcp_launcher_server.dart';
import 'mcp_server_constants.dart';

typedef McpLauncherServerFactory =
    McpLauncherServer Function(
      StreamChannel<String> channel,
      McpSession session,
    );

/// Every session slot is held by a session that is still running a tool call,
/// so no slot can be freed for a new client.
class McpSessionCapacityException implements Exception {
  const McpSessionCapacityException(this.maxSessions);

  final int maxSessions;

  @override
  String toString() => 'McpSessionCapacityException(maxSessions: $maxSessions)';
}

/// Immutable view of one connected client, for the settings UI.
class McpSessionSummary {
  const McpSessionSummary({
    required this.id,
    required this.connectedAt,
    required this.lastActivity,
    this.clientName,
    this.clientVersion,
  });

  final String id;
  final String? clientName;
  final String? clientVersion;
  final DateTime connectedAt;
  final DateTime lastActivity;

  McpSessionSummary copyWith({
    String? id,
    String? clientName,
    String? clientVersion,
    DateTime? connectedAt,
    DateTime? lastActivity,
  }) => McpSessionSummary(
    id: id ?? this.id,
    clientName: clientName ?? this.clientName,
    clientVersion: clientVersion ?? this.clientVersion,
    connectedAt: connectedAt ?? this.connectedAt,
    lastActivity: lastActivity ?? this.lastActivity,
  );

  @override
  bool operator ==(Object other) =>
      other is McpSessionSummary &&
      other.id == id &&
      other.clientName == clientName &&
      other.clientVersion == clientVersion &&
      other.connectedAt == connectedAt &&
      other.lastActivity == lastActivity;

  @override
  int get hashCode =>
      Object.hash(id, clientName, clientVersion, connectedAt, lastActivity);

  @override
  String toString() =>
      'McpSessionSummary($id, ${clientName ?? 'unknown'} '
      '${clientVersion ?? 'unknown'})';
}

/// One client connection: the in-memory channel feeding its
/// [McpLauncherServer], plus the abort handles of its running tool calls.
class McpSession {
  McpSession._({
    required this.id,
    required this.connectedAt,
    required DateTime lastActivity,
    required void Function() onChanged,
  }) : _lastActivity = lastActivity,
       _onChanged = onChanged {
    _subscription = _controller.local.stream.listen(
      _emit,
      onDone: _closeOutgoing,
    );
  }

  static const String _logTag = 'McpServer';

  final String id;
  final DateTime connectedAt;
  final void Function() _onChanged;
  final StreamChannelController<String> _controller =
      StreamChannelController<String>();
  final StreamController<Map<String, Object?>> _outgoing =
      StreamController<Map<String, Object?>>.broadcast();
  final Map<String, AbortController> _inFlight = <String, AbortController>{};

  late final StreamSubscription<String> _subscription;
  McpLauncherServer? _server;
  mcp.Implementation? _clientInfo;
  DateTime _lastActivity;
  bool _closed = false;

  /// The end of the channel the protocol server listens on.
  StreamChannel<String> get channel => _controller.foreign;

  /// Messages the protocol server emits. Broadcast, so anything sent while no
  /// HTTP response is waiting is dropped instead of replayed later.
  Stream<Map<String, Object?>> get outgoing => _outgoing.stream;

  DateTime get lastActivity => _lastActivity;

  /// A tool call can run for far longer than the idle timeout, so the registry
  /// asks before reclaiming a session.
  bool get hasInFlightCalls => _inFlight.isNotEmpty;

  McpLauncherServer get server => _server!;

  McpSessionSummary get summary => McpSessionSummary(
    id: id,
    clientName: _clientName,
    clientVersion: _clientVersion,
    connectedAt: connectedAt,
    lastActivity: _lastActivity,
  );

  void send(Map<String, Object?> message) {
    if (_closed) {
      return;
    }
    _controller.local.sink.add(jsonEncode(message));
  }

  /// Shared by the transport, which pre-registers a call before forwarding it,
  /// and by the protocol server, which asks for the signal while dispatching.
  AbortSignal signalFor(String callId) =>
      (_inFlight[callId] ??= AbortController()).signal;

  void abortCall(String callId, String reason) =>
      _inFlight[callId]?.abort(reason);

  void endCall(String callId) => _inFlight.remove(callId);

  void attachClientInfo(mcp.Implementation clientInfo) {
    _clientInfo = clientInfo;
    _onChanged();
  }

  String? get _clientName {
    final info = _clientInfo;
    if (info == null) {
      return null;
    }
    try {
      return info.name;
    } on ArgumentError {
      return null;
    }
  }

  String? get _clientVersion {
    final info = _clientInfo;
    if (info == null) {
      return null;
    }
    try {
      return info.version;
    } on ArgumentError {
      return null;
    }
  }

  void _emit(String raw) {
    if (_outgoing.isClosed) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        _outgoing.add(decoded);
      }
    } on FormatException catch (error) {
      PortableLogger.w('Dropped unparsable server message: $error', _logTag);
    }
  }

  void _closeOutgoing() {
    if (!_outgoing.isClosed) {
      unawaited(_outgoing.close());
    }
  }

  Future<void> _dispose(String reason) async {
    if (_closed) {
      return;
    }
    _closed = true;
    for (final controller in _inFlight.values) {
      controller.abort(reason);
    }
    _inFlight.clear();
    await _server?.shutdown();
    await _subscription.cancel();
    _closeOutgoing();
    await _controller.local.sink.close();
  }
}

/// Owns the live [McpSession]s. It holds no timer of its own: the host decides
/// when to call [sweepIdle].
class McpSessionRegistry {
  McpSessionRegistry({
    required this.createServer,
    this.idleTimeout = McpServerDefaults.sessionIdleTimeout,
    this.maxSessions = McpServerDefaults.maxSessions,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? generateMcpSessionId;

  final McpLauncherServerFactory createServer;
  final Duration idleTimeout;
  final int maxSessions;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final Map<String, McpSession> _sessions = <String, McpSession>{};
  final StreamController<List<McpSessionSummary>> _changes =
      StreamController<List<McpSessionSummary>>.broadcast();

  List<McpSessionSummary> get summaries => List<McpSessionSummary>.unmodifiable(
    _sessions.values.map((session) => session.summary),
  );

  /// Emits on connect, disconnect and client handshake. Activity timestamps
  /// alone do not push an event; read [summaries] for those.
  Stream<List<McpSessionSummary>> get changes => _changes.stream;

  int get length => _sessions.length;

  /// Throws [McpSessionCapacityException] when every slot is held by a session
  /// whose tool call is still running.
  McpSession create() {
    if (_sessions.length >= maxSessions) {
      _evictIdlest();
    }
    final now = _clock();
    final session = McpSession._(
      id: _nextId(),
      connectedAt: now,
      lastActivity: now,
      onChanged: _notifyChanged,
    );
    session._server = createServer(session.channel, session);
    _sessions[session.id] = session;
    _notifyChanged();
    return session;
  }

  McpSession? find(String id) => _sessions[id];

  void touch(McpSession session) => session._lastActivity = _clock();

  Future<void> close(String id) async {
    final session = _sessions.remove(id);
    if (session == null) {
      return;
    }
    _notifyChanged();
    await session._dispose('session closed');
  }

  Future<void> closeAll() async {
    final sessions = _sessions.values.toList(growable: false);
    if (sessions.isEmpty) {
      return;
    }
    _sessions.clear();
    _notifyChanged();
    await Future.wait(
      sessions.map((session) => session._dispose('server stopped')),
    );
  }

  int sweepIdle() {
    final now = _clock();
    final expired = _sessions.values
        .where(
          (session) =>
              !session.hasInFlightCalls &&
              now.difference(session.lastActivity) >= idleTimeout,
        )
        .toList(growable: false);
    if (expired.isEmpty) {
      return 0;
    }
    for (final session in expired) {
      _sessions.remove(session.id);
      unawaited(session._dispose('session idle'));
    }
    _notifyChanged();
    return expired.length;
  }

  Future<void> dispose() async {
    await closeAll();
    await _changes.close();
  }

  void _evictIdlest() {
    final reclaimable = _sessions.values.where(
      (session) => !session.hasInFlightCalls,
    );
    if (reclaimable.isEmpty) {
      throw McpSessionCapacityException(maxSessions);
    }
    final idlest = reclaimable.reduce(
      (a, b) => a.lastActivity.isAfter(b.lastActivity) ? b : a,
    );
    _sessions.remove(idlest.id);
    unawaited(idlest._dispose('session limit reached'));
  }

  String _nextId() {
    final base = _idGenerator();
    var id = base;
    var attempt = 1;
    while (_sessions.containsKey(id)) {
      id = '$base-${attempt++}';
    }
    return id;
  }

  void _notifyChanged() {
    if (!_changes.isClosed) {
      _changes.add(summaries);
    }
  }
}

final Random _sessionIdRandom = Random.secure();

/// Visible-ASCII session id, as required for the `Mcp-Session-Id` header.
String generateMcpSessionId() {
  final bytes = List<int>.generate(18, (_) => _sessionIdRandom.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
