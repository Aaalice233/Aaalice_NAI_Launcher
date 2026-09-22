import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import '../../../core/agent/audit/jsonl_audit_sink.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/mcp/mcp_discovery_file.dart';
import '../../../core/mcp/mcp_image_http_endpoint.dart';
import '../../../core/mcp/mcp_server_constants.dart';
import '../../../core/mcp/mcp_server_host.dart';
import '../../../core/mcp/mcp_session_registry.dart';
import '../../../core/mcp/mcp_token_generator.dart';
import '../../../core/mcp/mcp_tool_executor.dart';
import '../../../core/services/desktop_app_shutdown_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../agent_chat/services/agent_image_observation_ledger.dart';
import '../../agent_chat/services/agent_prepared_anlas_estimator.dart';
import '../../agent_chat/services/agent_prepared_file_targets.dart';
import '../../agent_chat/services/agent_tool_registry_builder.dart';
import '../../agent_chat/services/agent_workspace_directory.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../providers/notification_settings_provider.dart';
import '../../providers/share_image_settings_provider.dart';
import '../services/mcp_approval_coordinator.dart';
import '../services/mcp_external_tool_registry_factory.dart';
import '../services/mcp_tool_call_pipeline.dart';

const String _logTag = 'McpServer';

typedef McpServerHostFactory =
    McpServerHost Function(McpToolExecutor executor, String appVersion);

enum McpServerStatus { disabled, starting, listening, error }

/// 设备本地的 MCP 服务器设置。
abstract interface class McpServerSettingsStore {
  bool get enabled;
  int get port;
  AgentPermissionMode get permissionMode;

  Future<void> writeEnabled(bool value);
  Future<void> writePort(int value);
  Future<void> writePermissionMode(AgentPermissionMode value);
}

/// 长期有效的接入令牌。
abstract interface class McpServerTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class LocalStorageMcpServerSettingsStore implements McpServerSettingsStore {
  const LocalStorageMcpServerSettingsStore(this._storage);

  final LocalStorageService _storage;

  @override
  bool get enabled =>
      _storage.getSetting<bool>(
        StorageKeys.mcpServerEnabled,
        defaultValue: false,
      ) ??
      false;

  @override
  int get port {
    final stored = _storage.getSetting<int>(StorageKeys.mcpServerPort);
    return stored != null && _isValidPort(stored)
        ? stored
        : McpServerDefaults.port;
  }

  @override
  AgentPermissionMode get permissionMode => AgentPermissionMode.fromName(
    _storage.getSetting<String>(StorageKeys.mcpServerPermissionMode),
  );

  @override
  Future<void> writeEnabled(bool value) =>
      _storage.setSetting(StorageKeys.mcpServerEnabled, value);

  @override
  Future<void> writePort(int value) =>
      _storage.setSetting(StorageKeys.mcpServerPort, value);

  @override
  Future<void> writePermissionMode(AgentPermissionMode value) =>
      _storage.setSetting(StorageKeys.mcpServerPermissionMode, value.name);
}

class SecureMcpServerTokenStore implements McpServerTokenStore {
  const SecureMcpServerTokenStore(this._storage);

  final SecureStorageService _storage;

  @override
  Future<String?> read() => _storage.getMcpServerToken();

  @override
  Future<void> write(String token) => _storage.saveMcpServerToken(token);

  @override
  Future<void> delete() => _storage.deleteMcpServerToken();
}

class McpServerState {
  const McpServerState({
    this.enabled = false,
    this.status = McpServerStatus.disabled,
    this.configuredPort = McpServerDefaults.port,
    this.port,
    this.endpoint,
    this.discoveryFilePath,
    this.permissionMode = AgentPermissionMode.askBeforeSensitiveActions,
    this.sessions = const [],
    this.pendingApproval,
    this.errorCode,
    this.errorMessage,
  });

  final bool enabled;
  final McpServerStatus status;
  final int configuredPort;
  final int? port;
  final Uri? endpoint;
  final String? discoveryFilePath;
  final AgentPermissionMode permissionMode;
  final List<McpSessionSummary> sessions;
  final McpApprovalRequest? pendingApproval;
  final String? errorCode;
  final String? errorMessage;

  bool get isListening => status == McpServerStatus.listening;

  McpServerState copyWith({
    bool? enabled,
    McpServerStatus? status,
    int? configuredPort,
    int? port,
    Uri? endpoint,
    String? discoveryFilePath,
    AgentPermissionMode? permissionMode,
    List<McpSessionSummary>? sessions,
    McpApprovalRequest? pendingApproval,
    String? errorCode,
    String? errorMessage,
    bool clearSession = false,
    bool clearApproval = false,
    bool clearError = false,
  }) {
    return McpServerState(
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      configuredPort: configuredPort ?? this.configuredPort,
      port: clearSession ? null : (port ?? this.port),
      endpoint: clearSession ? null : (endpoint ?? this.endpoint),
      discoveryFilePath: clearSession
          ? null
          : (discoveryFilePath ?? this.discoveryFilePath),
      permissionMode: permissionMode ?? this.permissionMode,
      sessions: clearSession ? const [] : (sessions ?? this.sessions),
      pendingApproval: clearApproval
          ? null
          : (pendingApproval ?? this.pendingApproval),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// MCP 服务器生命周期：开关、端口、权限模式与待授权请求都收敛在这里，
/// 服务器本体只在启用期间存在。
class McpServerNotifier extends StateNotifier<McpServerState> {
  McpServerNotifier(
    this._ref, {
    McpServerHostFactory? hostFactory,
    McpDiscoveryFileStore? discovery,
    McpServerTokenStore? tokenStore,
    McpServerSettingsStore? settingsStore,
    Directory? supportDirectory,
    AgentImageObservationLedger? observationLedger,
    Future<void> Function()? notifyApprovalRequested,
  }) : _hostFactory = hostFactory,
       _discovery = discovery ?? McpDiscoveryFileStore(),
       _tokenStore =
           tokenStore ??
           SecureMcpServerTokenStore(_ref.read(secureStorageServiceProvider)),
       _settings =
           settingsStore ??
           LocalStorageMcpServerSettingsStore(
             _ref.read(localStorageServiceProvider),
           ),
       _providedSupportDirectory = supportDirectory,
       _observationLedger = observationLedger ?? AgentImageObservationLedger(),
       _notifyApprovalRequested = notifyApprovalRequested,
       super(const McpServerState()) {
    state = McpServerState(
      enabled: _settings.enabled,
      configuredPort: _settings.port,
      permissionMode: _settings.permissionMode,
    );
  }

  final Ref _ref;
  final McpServerHostFactory? _hostFactory;
  final McpDiscoveryFileStore _discovery;
  final McpServerTokenStore _tokenStore;
  final McpServerSettingsStore _settings;
  final Directory? _providedSupportDirectory;

  /// 按传输会话记录模型真正看过的图，会话归这里管，台账就归这里管。
  final AgentImageObservationLedger _observationLedger;
  final Future<void> Function()? _notifyApprovalRequested;

  McpServerHost? _host;
  McpExternalToolRegistryFactory? _factory;
  McpApprovalCoordinator? _approvals;
  AgentToolRegistry? _registry;
  StreamSubscription<List<McpSessionSummary>>? _sessionSubscription;
  StreamSubscription<McpApprovalRequest?>? _approvalSubscription;
  Future<void> _transition = Future<void>.value();
  final Lock _tokenLock = Lock();

  Future<void> setEnabled(bool enabled) => enabled ? enable() : disable();

  Future<void> enable({bool persist = true}) =>
      _serialize(() => _enable(persist: persist));

  Future<void> disable({bool persist = true}) =>
      _serialize(() => _disable(persist: persist));

  Future<void> setPort(int port) {
    if (!_isValidPort(port)) {
      throw ArgumentError.value(
        port,
        'port',
        'Must be between ${McpServerDefaults.minPort} and '
            '${McpServerDefaults.maxPort}',
      );
    }
    return _serialize(() async {
      if (port == state.configuredPort) return;
      await _settings.writePort(port);
      if (!mounted) return;
      state = state.copyWith(configuredPort: port);
      if (!state.enabled) return;
      await _disable(persist: false);
      await _enable(persist: false);
    });
  }

  Future<void> setPermissionMode(AgentPermissionMode mode) {
    return _serialize(() async {
      if (mode == state.permissionMode) return;
      await _settings.writePermissionMode(mode);
      if (!mounted) return;
      state = state.copyWith(permissionMode: mode);
      _rebuildRegistry(mode);
    });
  }

  /// 换发令牌会作废所有已连接会话，因此必须重启监听。
  Future<void> regenerateToken() {
    return _serialize(() async {
      await _tokenLock.synchronized(
        () => _tokenStore.write(generateMcpServerToken()),
      );
      if (!mounted || !state.enabled) return;
      await _disable(persist: false);
      await _enable(persist: false);
    });
  }

  /// 令牌长期有效；首次读取时补发，并串行化避免并发读写生成两份。
  Future<String> readToken() => _tokenLock.synchronized(() async {
    final existing = await _tokenStore.read();
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = generateMcpServerToken();
    await _tokenStore.write(generated);
    return generated;
  });

  bool resolveApproval(String toolCallId, bool approved) =>
      _approvals?.resolve(toolCallId, approved) ?? false;

  Future<void> close() => _serialize(() => _disable(persist: false));

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _transition.then((_) => action());
    _transition = next.catchError((_) {});
    return next;
  }

  Future<void> _enable({required bool persist}) async {
    if (state.status == McpServerStatus.listening ||
        state.status == McpServerStatus.starting) {
      return;
    }
    state = state.copyWith(
      enabled: true,
      status: McpServerStatus.starting,
      clearSession: true,
      clearError: true,
    );

    try {
      final supportDir = await _resolveSupportDirectory();
      final workspaceDir = await resolveAgentWorkspaceDirectory(supportDir);
      final auditSink = JsonlAgentAuditSink(
        File(
          '${supportDir.path}${Platform.pathSeparator}agent'
          '${Platform.pathSeparator}mcp-audit-v1.jsonl',
        ),
      );
      final factory = McpExternalToolRegistryFactory(
        ref: _ref,
        supportDir: supportDir,
        workspaceDir: workspaceDir.path,
        isHostAlive: () => mounted && state.enabled,
        observationLedger: _observationLedger,
        publishDisplayImage:
            (bytes, {required mimeType, required metadataStripped}) =>
                _host?.imageEndpoint.publish(
                  bytes,
                  mimeType: mimeType,
                  metadataStripped: metadataStripped,
                ),
      );
      final approvals = McpApprovalCoordinator(
        auditSink: auditSink,
        estimateAnlas: (toolName, args) => estimatePreparedAnlas(
          toolName,
          args,
          generationRuntime: factory.generationRuntime,
          queueRuntime: factory.queueRuntime,
          manualInpaintToolbox: factory.manualInpaintToolbox,
        ),
        describeFileTargets: (toolName, args) => preparedFileTargets(
          toolName,
          args,
          generationRuntime: factory.generationRuntime,
        ),
        isMounted: () => mounted,
        notifyRequested: _notifyApprovalRequested ?? _playApprovalSound,
      );
      _factory = factory;
      _approvals = approvals;
      _registry = factory.build(state.permissionMode);
      approvals.configure(_registry!);
      _approvalSubscription = approvals.changes.listen(_handleApprovalChanged);

      final host = (_hostFactory ?? _defaultHostFactory)(
        LauncherMcpToolExecutor(
          registry: () => _registry!,
          approvals: approvals,
          auditSink: auditSink,
          imageResponses: factory.imageResponses,
          observeResult: _observationLedger.recordToolResult,
        ),
        _appVersion(),
      );
      await host.start(port: state.configuredPort, token: await readToken());
      _host = host;
      _sessionSubscription = host.sessionChanges.listen(_handleSessionsChanged);
      if (!mounted) {
        await _disable(persist: false);
        return;
      }
      state = state.copyWith(
        enabled: true,
        status: McpServerStatus.listening,
        port: host.port,
        endpoint: host.endpoint,
        discoveryFilePath: _discovery.file.path,
        sessions: host.sessions,
        clearError: true,
      );
      AppLogger.i('MCP server listening on port ${host.port}', _logTag);
      if (persist) await _settings.writeEnabled(true);
    } on McpHostBindException catch (error) {
      await _teardown();
      AppLogger.e(
        'MCP server port ${error.port} unavailable',
        error,
        null,
        _logTag,
      );
      if (!mounted) return;
      state = state.copyWith(
        enabled: false,
        status: McpServerStatus.error,
        clearSession: true,
        errorCode: 'port_in_use',
        errorMessage: '${error.cause}',
      );
    } catch (error, stackTrace) {
      await _teardown();
      AppLogger.e('Failed to enable MCP server', error, stackTrace, _logTag);
      if (!mounted) return;
      state = state.copyWith(
        enabled: false,
        status: McpServerStatus.error,
        clearSession: true,
        errorCode: 'start_failed',
        errorMessage: '$error',
      );
    }
  }

  Future<void> _disable({required bool persist}) async {
    await _teardown();
    if (mounted) {
      state = state.copyWith(
        enabled: false,
        status: McpServerStatus.disabled,
        clearSession: true,
        clearApproval: true,
        clearError: true,
      );
    }
    if (persist) await _settings.writeEnabled(false);
  }

  Future<void> _teardown() async {
    await _sessionSubscription?.cancel();
    await _approvalSubscription?.cancel();
    _sessionSubscription = null;
    _approvalSubscription = null;
    _approvals?.dispose();
    _approvals = null;
    _factory = null;
    _registry = null;
    _observationLedger.clear();
    final host = _host;
    _host = null;
    if (host != null) await host.stop();
  }

  void _rebuildRegistry(AgentPermissionMode mode) {
    final factory = _factory;
    final approvals = _approvals;
    if (factory == null || approvals == null) return;
    _registry = factory.build(mode);
    approvals.configure(_registry!);
  }

  void _handleSessionsChanged(List<McpSessionSummary> sessions) {
    // 断开、被淘汰或空闲清扫掉的会话不能再替后来的客户端放行坐标敏感操作。
    _observationLedger.retainSessions(
      sessions.map((session) => session.id).toList(growable: false),
    );
    if (!mounted || !state.enabled) return;
    state = state.copyWith(sessions: sessions);
  }

  void _handleApprovalChanged(McpApprovalRequest? request) {
    if (!mounted) return;
    state = request == null
        ? state.copyWith(clearApproval: true)
        : state.copyWith(pendingApproval: request);
  }

  Future<Directory> _resolveSupportDirectory() async {
    final provided = _providedSupportDirectory;
    if (provided != null) return provided;
    return getApplicationSupportDirectory();
  }

  Future<void> _playApprovalSound() async {
    if (!mounted) return;
    final settings = _ref.read(notificationSettingsNotifierProvider);
    await NotificationService.instance.notifyGenerationComplete(
      playSound: settings.soundEnabled,
      customSoundPath: settings.customSoundPath,
    );
  }

  /// 打包信息在纯 Dart 测试环境不可用，缺失时不阻断服务器启动。
  String _appVersion() {
    try {
      return AppVersion.versionName;
    } catch (_) {
      return 'unknown';
    }
  }

  McpServerHost _defaultHostFactory(
    McpToolExecutor executor,
    String appVersion,
  ) => McpServerHost(
    executor: executor,
    discovery: _discovery,
    appVersion: appVersion,
    imageEndpoint: McpImageHttpEndpoint(
      requiresStrippedMetadata: () =>
          !mounted ||
          _ref
              .read(shareImageSettingsProvider)
              .effectiveStripMetadataForCopyAndDrag,
    ),
  );
}

bool _isValidPort(int port) =>
    port >= McpServerDefaults.minPort && port <= McpServerDefaults.maxPort;

final mcpServerNotifierProvider =
    StateNotifierProvider<McpServerNotifier, McpServerState>((ref) {
      final settings = LocalStorageMcpServerSettingsStore(
        ref.read(localStorageServiceProvider),
      );
      final notifier = McpServerNotifier(ref, settingsStore: settings);
      if (settings.enabled) {
        unawaited(notifier.enable(persist: false));
      }
      final removeCleanupHandler = DesktopAppShutdownService.addCleanupHandler(
        notifier.close,
      );
      ref.onDispose(() {
        removeCleanupHandler();
        unawaited(notifier.close());
      });
      return notifier;
    });
