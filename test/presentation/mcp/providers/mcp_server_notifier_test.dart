import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_discovery_file.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';
import 'package:nai_launcher/core/mcp/mcp_server_host.dart';
import 'package:nai_launcher/core/mcp/mcp_session_registry.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_executor.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/mcp/providers/mcp_server_notifier.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late ProviderContainer container;
  late _MemorySettingsStore settings;
  late _MemoryTokenStore tokens;
  late List<_FakeMcpServerHost> hosts;
  late List<McpToolExecutor> executors;

  McpServerNotifier build() {
    return McpServerNotifier(
      container.read(_refProvider),
      hostFactory: (executor, appVersion) {
        final host = _FakeMcpServerHost(appVersion: appVersion);
        hosts.add(host);
        executors.add(executor);
        return host;
      },
      discovery: McpDiscoveryFileStore(directory: root),
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
    final notifier = McpServerNotifier(
      container.read(_refProvider),
      hostFactory: (executor, appVersion) {
        final host = _FakeMcpServerHost(
          appVersion: appVersion,
          bindFailurePort: McpServerDefaults.port,
        );
        hosts.add(host);
        executors.add(executor);
        return host;
      },
      discovery: McpDiscoveryFileStore(directory: root),
      settingsStore: settings,
      tokenStore: tokens,
      supportDirectory: root,
      notifyApprovalRequested: () async {},
    );
    addTearDown(notifier.dispose);

    await notifier.enable();

    expect(notifier.state.status, McpServerStatus.error);
    expect(notifier.state.errorCode, 'port_in_use');
    expect(notifier.state.errorMessage, isNotNull);
    expect(notifier.state.enabled, isFalse);
    expect(settings.enabledWrites, isEmpty);
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

class _FakeMcpServerHost implements McpServerHost {
  _FakeMcpServerHost({required this.appVersion, this.bindFailurePort});

  final String appVersion;
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
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    startedPort = null;
  }

  void emitSessions(List<McpSessionSummary> summaries) {
    _summaries = summaries;
    _sessions.add(summaries);
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
