import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/cli/mcp_client_config_printer.dart';
import 'package:nai_launcher/core/mcp/mcp_cli_path.dart';
import 'package:nai_launcher/core/mcp/mcp_discovery_file.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';
import 'package:nai_launcher/core/mcp/mcp_session_registry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/mcp/providers/mcp_server_notifier.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_approval_coordinator.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/mcp_server_settings_section.dart';

const _enableSwitch = ValueKey<String>('mcp-server-enable-switch');
const _statusRow = ValueKey<String>('mcp-server-status');
const _endpointValue = ValueKey<String>('mcp-server-endpoint');
const _copyEndpoint = ValueKey<String>('mcp-server-copy-endpoint');
const _portField = ValueKey<String>('mcp-server-port-field');
const _portError = ValueKey<String>('mcp-server-port-error');
const _portInUseHint = ValueKey<String>('mcp-server-port-in-use-hint');
const _discoveryFile = ValueKey<String>('mcp-server-discovery-file');
const _tokenValue = ValueKey<String>('mcp-server-token');
const _tokenReveal = ValueKey<String>('mcp-server-token-reveal');
const _tokenCopy = ValueKey<String>('mcp-server-token-copy');
const _tokenRegenerate = ValueKey<String>('mcp-server-token-regenerate');
const _sessionsEmpty = ValueKey<String>('mcp-server-sessions-empty');
const _pendingApproval = ValueKey<String>('mcp-server-pending-approval');
const _configUnavailable = ValueKey<String>('mcp-server-config-unavailable');
const _claudeCodePanel = ValueKey<String>(
  'mcp-server-client-config-claude-code',
);
const _copyClaudeCode = ValueKey<String>('mcp-server-copy-config-claude-code');

const _fakeToken = 'token-abcdef123456';
final _endpoint = Uri.parse(
  'http://${McpServerDefaults.loopbackHost}:${McpServerDefaults.port}'
  '${McpServerDefaults.endpointPath}',
);

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mcp_settings_section_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  McpServerState listeningState({
    List<McpSessionSummary> sessions = const [],
    McpApprovalRequest? pendingApproval,
    int? configuredPort,
  }) {
    return McpServerState(
      enabled: true,
      status: McpServerStatus.listening,
      configuredPort: configuredPort ?? McpServerDefaults.port,
      port: McpServerDefaults.port,
      endpoint: _endpoint,
      discoveryFilePath: '${root.path}/${McpServerDefaults.discoveryFileName}',
      sessions: sessions,
      pendingApproval: pendingApproval,
    );
  }

  Future<_FakeMcpServerNotifier> pumpSection(
    WidgetTester tester, {
    McpServerState? initialState,
    double width = 1180,
    double height = 2400,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    late _FakeMcpServerNotifier notifier;
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcpServerNotifierProvider.overrideWith((ref) {
            notifier = _FakeMcpServerNotifier(
              ref,
              discovery: McpDiscoveryFileStore(directory: root),
              settingsStore: _MemorySettingsStore(),
              tokenStore: _MemoryTokenStore(),
              supportDirectory: root,
            );
            if (initialState != null) notifier.seed(initialState);
            return notifier;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: true,
              textScaler: textScaler,
              size: Size(width, height),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(child: McpServerSettingsSection()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  List<String> mockClipboard(WidgetTester tester) {
    final written = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          written.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return written;
  }

  // Toast 自动关闭定时器是 3 秒，不冲掉会留下未完成 timer。
  Future<void> settleToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('关闭状态只显示开关与说明', (tester) async {
    await pumpSection(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(find.byKey(_enableSwitch), findsOneWidget);
    expect(find.text(l10n.settings_mcpServerDisabledText), findsOneWidget);
    expect(find.byKey(_statusRow, skipOffstage: false), findsNothing);
    expect(find.byKey(_endpointValue, skipOffstage: false), findsNothing);
    expect(find.byKey(_portField, skipOffstage: false), findsNothing);
    expect(find.byKey(_discoveryFile, skipOffstage: false), findsNothing);
    expect(find.byKey(_tokenValue, skipOffstage: false), findsNothing);
    expect(find.byKey(_configUnavailable), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('开关交给 notifier 处理，启动中禁用', (tester) async {
    final notifier = await pumpSection(tester);
    await tester.tap(find.byKey(_enableSwitch));
    await tester.pumpAndSettle();
    expect(notifier.enabledCalls, [isTrue]);

    notifier.seed(
      const McpServerState(enabled: true, status: McpServerStatus.starting),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byKey(_enableSwitch)).onChanged,
      isNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('监听状态展示端点、发现文件与令牌行', (tester) async {
    await pumpSection(tester, initialState: listeningState());
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(find.byKey(_statusRow), findsOneWidget);
    expect(find.text(l10n.settings_mcpServerListening), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byKey(_endpointValue)).data,
      '$_endpoint',
    );
    expect(find.byKey(_copyEndpoint), findsOneWidget);
    expect(find.byKey(_portField), findsOneWidget);
    expect(find.byKey(_discoveryFile), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byKey(_tokenValue)).data,
      '••••••••',
    );
    expect(find.byKey(_tokenRegenerate), findsOneWidget);
    expect(find.byKey(_portInUseHint, skipOffstage: false), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('端口占用错误展示原因和改端口提示', (tester) async {
    await pumpSection(
      tester,
      initialState: const McpServerState(
        status: McpServerStatus.error,
        errorCode: 'port_in_use',
        errorMessage: 'SocketException: address already in use',
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(find.text(l10n.settings_mcpServerError), findsOneWidget);
    expect(
      find.text('SocketException: address already in use'),
      findsOneWidget,
    );
    expect(find.byKey(_portInUseHint), findsOneWidget);
    // 错误态必须保留端口输入，否则用户无法自行恢复。
    expect(find.byKey(_portField), findsOneWidget);
    expect(find.byKey(_endpointValue, skipOffstage: false), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('端口校验拒绝越界值并接受合法端口', (tester) async {
    final notifier = await pumpSection(
      tester,
      initialState: listeningState(configuredPort: McpServerDefaults.minPort),
    );

    Future<void> submit(String value) async {
      await tester.enterText(find.byKey(_portField), value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    await submit('80');
    expect(find.byKey(_portError), findsOneWidget);
    expect(notifier.ports, isEmpty);

    await submit('70000');
    expect(find.byKey(_portError), findsOneWidget);
    expect(notifier.ports, isEmpty);

    await submit('${McpServerDefaults.port}');
    expect(find.byKey(_portError, skipOffstage: false), findsNothing);
    expect(notifier.ports, [McpServerDefaults.port]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('显示按钮在掩码与真实令牌之间切换', (tester) async {
    final notifier = await pumpSection(tester, initialState: listeningState());

    await tester.tap(find.byKey(_tokenReveal));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectableText>(find.byKey(_tokenValue)).data,
      _fakeToken,
    );
    expect(notifier.readTokenCount, 1);

    await tester.tap(find.byKey(_tokenReveal));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectableText>(find.byKey(_tokenValue)).data,
      '••••••••',
    );
    expect(notifier.readTokenCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('复制端点与令牌写入剪贴板', (tester) async {
    final written = mockClipboard(tester);
    final notifier = await pumpSection(tester, initialState: listeningState());

    await tester.tap(find.byKey(_copyEndpoint));
    await tester.pumpAndSettle();
    expect(written, ['$_endpoint']);
    await settleToast(tester);

    await tester.tap(find.byKey(_tokenCopy));
    await tester.pumpAndSettle();
    expect(written, ['$_endpoint', _fakeToken]);
    expect(notifier.readTokenCount, 1);
    await settleToast(tester);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('权限选项写回 notifier', (tester) async {
    final notifier = await pumpSection(tester, initialState: listeningState());
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(find.text(l10n.settings_mcpServerAnlasNotice), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('mcp-server-permission-fullAccess')),
    );
    await tester.pumpAndSettle();
    expect(notifier.permissionModes, [AgentPermissionMode.fullAccess]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('重新生成令牌先确认再执行', (tester) async {
    final notifier = await pumpSection(tester, initialState: listeningState());
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    await tester.tap(find.byKey(_tokenRegenerate));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.settings_mcpServerRegenerateTokenTitle),
      findsOneWidget,
    );
    expect(
      find.text(l10n.settings_mcpServerRegenerateTokenMessage),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.common_cancel));
    await tester.pumpAndSettle();
    expect(notifier.regenerateCount, 0);

    await tester.tap(find.byKey(_tokenRegenerate));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(l10n.settings_mcpServerRegenerateToken),
      ),
    );
    await tester.pumpAndSettle();
    expect(notifier.regenerateCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('会话列表展示客户端并在空列表时给出空状态', (tester) async {
    await pumpSection(tester, initialState: listeningState());
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.byKey(_sessionsEmpty), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());

    await pumpSection(
      tester,
      initialState: listeningState(
        sessions: [
          _session(id: 's1', clientName: 'codex', clientVersion: '1.2.3'),
          _session(id: 's2'),
        ],
      ),
    );

    expect(find.byKey(_sessionsEmpty, skipOffstage: false), findsNothing);
    expect(find.text('codex 1.2.3'), findsOneWidget);
    expect(find.text(l10n.mcpApproval_unknownClient), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('待处理授权提示指向全局横幅', (tester) async {
    await pumpSection(
      tester,
      initialState: listeningState(pendingApproval: _approval()),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(find.byKey(_pendingApproval), findsOneWidget);
    expect(
      find.text(
        l10n.settings_mcpServerPendingApproval('codex 1.0.0', 'generate_image'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(l10n.settings_mcpServerPendingApprovalHint),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('客户端配置预览打码，复制时写入真实令牌', (tester) async {
    final written = mockClipboard(tester);
    final notifier = await pumpSection(tester, initialState: listeningState());
    final cliPath = resolveBundledMcpCliPath();
    final masked = renderMcpClientConfig(
      McpClientKind.claudeCode,
      endpoint: _endpoint,
      token: '••••',
      cliPath: cliPath,
    );

    expect(find.byKey(_claudeCodePanel), findsOneWidget);
    await tester.tap(find.text('Claude Code'));
    await tester.pumpAndSettle();
    expect(find.text(masked), findsOneWidget);

    await tester.tap(find.byKey(_copyClaudeCode));
    await tester.pumpAndSettle();
    expect(notifier.readTokenCount, 1);
    expect(written, [
      renderMcpClientConfig(
        McpClientKind.claudeCode,
        endpoint: _endpoint,
        token: _fakeToken,
        cliPath: cliPath,
      ),
    ]);
    await settleToast(tester);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('开发环境缺少随包 CLI 时给出提示', (tester) async {
    await pumpSection(tester, initialState: listeningState());
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    await tester.tap(find.text('Claude Desktop'));
    await tester.pumpAndSettle();

    // 测试进程旁边不会有随包代理，提示必须出现且带上预期路径。
    expect(
      find.text(l10n.settings_mcpServerCliMissing(resolveBundledMcpCliPath())),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('各宽度与 3 倍文本下分组完整且无溢出', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    for (final width in const [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      for (final textScaler in const [
        TextScaler.noScaling,
        TextScaler.linear(3.0),
      ]) {
        final reason = 'width=$width scaler=$textScaler';
        await pumpSection(
          tester,
          initialState: listeningState(
            sessions: [
              _session(id: 's1', clientName: 'codex', clientVersion: '1.2.3'),
            ],
            pendingApproval: _approval(),
          ),
          width: width,
          height: 4000,
          textScaler: textScaler,
        );

        expect(tester.takeException(), isNull, reason: reason);
        expect(
          find.text(l10n.settings_integrationConnectionSection),
          findsOneWidget,
          reason: reason,
        );
        expect(
          find.text(l10n.settings_mcpServerPermissionSection),
          findsOneWidget,
          reason: reason,
        );
        expect(
          find.text(l10n.settings_mcpServerClientsSection),
          findsOneWidget,
          reason: reason,
        );
        expect(find.byKey(_portField), findsOneWidget, reason: reason);
        expect(find.byKey(_tokenRegenerate), findsOneWidget, reason: reason);
        expect(find.byKey(_pendingApproval), findsOneWidget, reason: reason);
        expect(find.byKey(_claudeCodePanel), findsOneWidget, reason: reason);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}

McpSessionSummary _session({
  required String id,
  String? clientName,
  String? clientVersion,
}) {
  final now = DateTime(2026, 9, 13, 10, 30, 15);
  return McpSessionSummary(
    id: id,
    clientName: clientName,
    clientVersion: clientVersion,
    connectedAt: now,
    lastActivity: now.add(const Duration(minutes: 2)),
  );
}

McpApprovalRequest _approval() {
  return McpApprovalRequest(
    request: const AgentToolApprovalRequest(
      toolCallId: 'call-1',
      toolName: 'generate_image',
      args: {'preparation_id': 'prep-1'},
      estimatedAnlas: 24,
    ),
    clientLabel: 'codex 1.0.0',
    expiresAt: DateTime(2026, 9, 13, 10, 35),
  );
}

class _FakeMcpServerNotifier extends McpServerNotifier {
  _FakeMcpServerNotifier(
    super.ref, {
    super.discovery,
    super.settingsStore,
    super.tokenStore,
    super.supportDirectory,
  });

  final List<bool> enabledCalls = [];
  final List<int> ports = [];
  final List<AgentPermissionMode> permissionModes = [];
  int regenerateCount = 0;
  int readTokenCount = 0;

  void seed(McpServerState next) => state = next;

  @override
  Future<void> setEnabled(bool enabled) async => enabledCalls.add(enabled);

  @override
  Future<void> setPort(int port) async => ports.add(port);

  @override
  Future<void> setPermissionMode(AgentPermissionMode mode) async =>
      permissionModes.add(mode);

  @override
  Future<void> regenerateToken() async => regenerateCount++;

  @override
  Future<String> readToken() async {
    readTokenCount++;
    return _fakeToken;
  }

  @override
  Future<void> close() async {}
}

class _MemorySettingsStore implements McpServerSettingsStore {
  @override
  bool enabled = false;
  @override
  int port = McpServerDefaults.port;
  @override
  AgentPermissionMode permissionMode =
      AgentPermissionMode.askBeforeSensitiveActions;

  @override
  Future<void> writeEnabled(bool value) async => enabled = value;

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
