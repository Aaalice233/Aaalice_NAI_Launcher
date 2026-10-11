import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/mcp/mcp_discovery_file.dart';
import 'package:nai_launcher/core/mcp/mcp_image_http_endpoint.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';
import 'package:nai_launcher/core/mcp/mcp_server_host.dart';
import 'package:nai_launcher/core/mcp/mcp_session_registry.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_executor.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_image_observation_ledger.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/mcp/providers/mcp_server_notifier.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late ProviderContainer container;
  late _MemorySettingsStore settings;
  late _MemoryTokenStore tokens;
  late List<_FakeMcpServerHost> hosts;
  late List<McpToolExecutor> executors;

  McpServerNotifier build({
    int? bindFailurePort,
    McpDiscoveryFileStore? discovery,
    AgentImageObservationLedger? observationLedger,
  }) {
    final store = discovery ?? McpDiscoveryFileStore(directory: root);
    return McpServerNotifier(
      container.read(_refProvider),
      observationLedger: observationLedger,
      hostFactory: (executor, appVersion) {
        final host = _FakeMcpServerHost(
          appVersion: appVersion,
          discovery: store,
          bindFailurePort: bindFailurePort,
        );
        hosts.add(host);
        executors.add(executor);
        return host;
      },
      discovery: store,
      settingsStore: settings,
      tokenStore: tokens,
      supportDirectory: root,
      notifyApprovalRequested: () async {},
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mcp_server_notifier_');
    settings = _MemorySettingsStore();
    tokens = _MemoryTokenStore();
    hosts = [];
    executors = [];
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: root,
            workspaceDirectory: root,
            environment: const {},
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('starts from persisted settings without touching the host', () {
    settings
      ..enabled = true
      ..port = 15000
      ..permissionMode = AgentPermissionMode.safe;

    final notifier = build();
    addTearDown(notifier.dispose);

    expect(notifier.state.enabled, isTrue);
    expect(notifier.state.status, McpServerStatus.disabled);
    expect(notifier.state.configuredPort, 15000);
    expect(notifier.state.permissionMode, AgentPermissionMode.safe);
    expect(hosts, isEmpty);
  });

  test('enable starts the host and publishes the endpoint', () async {
    final notifier = build();
    addTearDown(notifier.dispose);

    await notifier.enable();

    expect(notifier.state.status, McpServerStatus.listening);
    expect(notifier.state.enabled, isTrue);
    expect(notifier.state.port, McpServerDefaults.port);
    expect(notifier.state.endpoint?.path, McpServerDefaults.endpointPath);
    expect(
      notifier.state.discoveryFilePath,
      endsWith(McpServerDefaults.discoveryFileName),
    );
    expect(settings.enabled, isTrue);
    expect(hosts.single.startedToken, isNotEmpty);
    expect(await tokens.read(), hosts.single.startedToken);
  });

  test('disable stops the host and clears the session state', () async {
    final notifier = build();
    addTearDown(notifier.dispose);
    await notifier.enable();

    await notifier.disable();

    expect(notifier.state.status, McpServerStatus.disabled);
    expect(notifier.state.enabled, isFalse);
    expect(notifier.state.port, isNull);
    expect(notifier.state.endpoint, isNull);
    expect(notifier.state.sessions, isEmpty);
    expect(hosts.single.stopCalls, greaterThanOrEqualTo(1));
    expect(settings.enabled, isFalse);
  });

  test('session updates flow into the state', () async {
    final notifier = build();
    addTearDown(notifier.dispose);
    await notifier.enable();

    hosts.single.emitSessions([
      McpSessionSummary(
        id: 'session-1',
        clientName: 'codex',
        clientVersion: '1.0.0',
        connectedAt: DateTime.utc(2026, 1, 1),
        lastActivity: DateTime.utc(2026, 1, 1),
      ),
    ]);
    await pumpEventQueue();

    expect(notifier.state.sessions.single.clientName, 'codex');
  });

  test('a disconnected session loses its observation evidence', () async {
    final ledger = AgentImageObservationLedger();
    final notifier = build(observationLedger: ledger);
    addTearDown(notifier.dispose);
    await notifier.enable();
    ledger.recordToolResult('session-1', _observedImage(r'C:\work\a.png'));
    ledger.recordToolResult('session-2', _observedImage(r'C:\work\b.png'));

    hosts.single.emitSessions([_summary('session-2')]);
    await pumpEventQueue();

    expect(_observed(ledger, 'session-1', r'C:\work\a.png'), isFalse);
    expect(_observed(ledger, 'session-2', r'C:\work\b.png'), isTrue);

    await notifier.disable();

    expect(
      _observed(ledger, 'session-2', r'C:\work\b.png'),
      isFalse,
      reason: 'a restart hands out fresh session ids, so evidence cannot carry',
    );
  });

  test('setPort rejects ports outside the allowed range', () async {
    final notifier = build();
    addTearDown(notifier.dispose);

    expect(
      () => notifier.setPort(McpServerDefaults.minPort - 1),
      throwsArgumentError,
    );
    expect(
      () => notifier.setPort(McpServerDefaults.maxPort + 1),
      throwsArgumentError,
    );
    expect(settings.port, McpServerDefaults.port);
  });

  test('setPort persists and restarts the listening host', () async {
    final notifier = build();
    addTearDown(notifier.dispose);
    await notifier.enable();

    await notifier.setPort(15500);

    expect(settings.port, 15500);
    expect(notifier.state.configuredPort, 15500);
    expect(notifier.state.port, 15500);
    expect(hosts, hasLength(2));
    expect(hosts.last.startedPort, 15500);
    expect(settings.enabledWrites, [true]);
  });

  test('setPort only persists while the server is disabled', () async {
    final notifier = build();
    addTearDown(notifier.dispose);

    await notifier.setPort(15500);

    expect(settings.port, 15500);
    expect(hosts, isEmpty);
    expect(notifier.state.status, McpServerStatus.disabled);
  });

  test('regenerateToken restarts with a fresh token', () async {
    final notifier = build();
    addTearDown(notifier.dispose);
    await notifier.enable();
    final firstToken = hosts.single.startedToken;

    await notifier.regenerateToken();

    expect(hosts, hasLength(2));
    expect(hosts.last.startedToken, isNot(firstToken));
    expect(await tokens.read(), hosts.last.startedToken);
    expect(settings.enabledWrites, [true]);
  });

  test('a bound port reports port_in_use instead of listening', () async {
    final notifier = build(bindFailurePort: McpServerDefaults.port);
    addTearDown(notifier.dispose);

    await notifier.enable();

    expect(notifier.state.status, McpServerStatus.error);
    expect(notifier.state.errorCode, 'port_in_use');
    expect(notifier.state.errorMessage, isNotNull);
    expect(notifier.state.enabled, isFalse);
    expect(settings.enabledWrites, isEmpty);
  });

  test('a failed discovery write reports start_failed and retries', () async {
    final discovery = _FailingDiscoveryStore(root);
    final notifier = build(discovery: discovery);
    addTearDown(notifier.dispose);

    await notifier.enable();

    expect(notifier.state.status, McpServerStatus.error);
    expect(notifier.state.errorCode, 'start_failed');
    expect(notifier.state.errorMessage, isNotNull);
    expect(notifier.state.enabled, isFalse);
    expect(notifier.state.port, isNull);
    expect(hosts.single.isListening, isFalse);
    expect(settings.enabledWrites, isEmpty);

    await notifier.disable();
    expect(notifier.state.status, McpServerStatus.disabled);

    discovery.failWrites = false;
    await notifier.enable();

    expect(notifier.state.status, McpServerStatus.listening);
    expect(notifier.state.port, McpServerDefaults.port);
    expect(hosts.last.startedPort, McpServerDefaults.port);
    expect(hosts.last.isListening, isTrue);
  });

  test('permission mode is persisted and narrows the exposed tools', () async {
    final notifier = build();
    addTearDown(notifier.dispose);
    await notifier.enable();
    final fullTools = _toolNames(executors.single);

    await notifier.setPermissionMode(AgentPermissionMode.safe);

    expect(settings.permissionMode, AgentPermissionMode.safe);
    expect(notifier.state.permissionMode, AgentPermissionMode.safe);
    expect(notifier.state.status, McpServerStatus.listening);
    final safeTools = _toolNames(executors.single);
    expect(safeTools, isNotEmpty);
    expect(safeTools.length, lessThan(fullTools.length));
    expect(fullTools.toSet(), containsAll(safeTools));
  });

  test('close stops the host without persisting a disabled flag', () async {
    final notifier = build();
    addTearDown(notifier.dispose);
    await notifier.enable();

    await notifier.close();

    expect(notifier.state.status, McpServerStatus.disabled);
    expect(settings.enabledWrites, [true]);
  });
}

final _refProvider = Provider<Ref>((ref) => ref);

List<String> _toolNames(McpToolExecutor executor) =>
    executor.tools.map((tool) => tool.name).toList();

McpSessionSummary _summary(String id) => McpSessionSummary(
  id: id,
  connectedAt: DateTime.utc(2026, 1, 1),
  lastActivity: DateTime.utc(2026, 1, 1),
);

AgentToolResult _observedImage(String path) => AgentToolResult(
  content: [
    ToolResultImageContent(
      ImageContent(
        source: ImageSource.base64(
          mimeType: 'image/png',
          base64Data: base64Encode(
            img.encodePng(img.Image(width: 512, height: 512)),
          ),
        ),
      ),
    ),
  ],
  details: <String, dynamic>{
    'files': [path],
  },
);

bool _observed(
  AgentImageObservationLedger ledger,
  String session,
  String path,
) => ledger.hasObserved(session, paths: [path], sourceLongSide: 512);

class _FakeMcpServerHost implements McpServerHost {
  _FakeMcpServerHost({
    required this.appVersion,
    required this.discovery,
    this.bindFailurePort,
  });

  final String appVersion;
  final McpDiscoveryFileStore discovery;
  @override
  final imageEndpoint = McpImageHttpEndpoint();
  final int? bindFailurePort;
  final StreamController<List<McpSessionSummary>> _sessions =
      StreamController<List<McpSessionSummary>>.broadcast();

  int? startedPort;
  String startedToken = '';
  int stopCalls = 0;
  List<McpSessionSummary> _summaries = const [];

  @override
  bool get isListening => startedPort != null;

  @override
  int? get port => startedPort;

  @override
  Uri? get endpoint => startedPort == null
      ? null
      : Uri(
          scheme: 'http',
          host: McpServerDefaults.loopbackHost,
          port: startedPort,
          path: McpServerDefaults.endpointPath,
        );

  @override
  List<McpSessionSummary> get sessions => _summaries;

  @override
  Stream<List<McpSessionSummary>> get sessionChanges => _sessions.stream;

  @override
  Future<void> start({required int port, required String token}) async {
    if (bindFailurePort == port) {
      throw McpHostBindException(
        port,
        const SocketException('address already in use'),
      );
    }
    startedPort = port;
    startedToken = token;
    imageEndpoint.start(endpoint!);
    try {
      await discovery.write(
        McpDiscoveryDocument(
          port: port,
          pid: 4242,
          startedAt: DateTime.utc(2026, 5, 7, 10, 30),
          token: token,
          protocolVersions: const ['2025-11-25'],
          appVersion: appVersion,
        ),
      );
    } catch (_) {
      _release();
      rethrow;
    }
  }

  // dispose() stops the host unawaited, so deleting here would race tearDown.
  @override
  Future<void> stop() async {
    stopCalls += 1;
    _release();
  }

  void emitSessions(List<McpSessionSummary> summaries) {
    _summaries = summaries;
    _sessions.add(summaries);
  }

  void _release() {
    imageEndpoint.stop();
    startedPort = null;
  }
}

class _FailingDiscoveryStore extends McpDiscoveryFileStore {
  _FailingDiscoveryStore(Directory directory) : super(directory: directory);

  bool failWrites = true;

  @override
  Future<void> write(McpDiscoveryDocument document) async {
    if (failWrites) {
      throw const FileSystemException('discovery directory is not writable');
    }
    return super.write(document);
  }
}

class _MemorySettingsStore implements McpServerSettingsStore {
  @override
  bool enabled = false;
  @override
  int port = McpServerDefaults.port;
  @override
  AgentPermissionMode permissionMode =
      AgentPermissionMode.askBeforeSensitiveActions;
  final List<bool> enabledWrites = [];

  @override
  Future<void> writeEnabled(bool value) async {
    enabled = value;
    enabledWrites.add(value);
  }

  @override
  Future<void> writePort(int value) async => port = value;

  @override
  Future<void> writePermissionMode(AgentPermissionMode value) async =>
      permissionMode = value;
}

class _MemoryTokenStore implements McpServerTokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> delete() async => _token = null;
}

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    return value == null ? defaultValue : value as T;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }
}
