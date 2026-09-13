import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_discovery_file.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/mcp/providers/mcp_server_notifier.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_approval_coordinator.dart';
import 'package:nai_launcher/presentation/mcp/widgets/mcp_approval_banner.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mcp_approval_banner_');
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
  });

  tearDown(() async {
    PlatformCapabilities.debugOverride = null;
    if (await root.exists()) await root.delete(recursive: true);
  });

  _RecordingMcpServerNotifier buildNotifier(Ref ref) {
    return _RecordingMcpServerNotifier(
      ref,
      discovery: McpDiscoveryFileStore(directory: root),
      settingsStore: _MemorySettingsStore(),
      tokenStore: _MemoryTokenStore(),
      supportDirectory: root,
    );
  }

  Future<_RecordingMcpServerNotifier> pumpBanner(
    WidgetTester tester, {
    McpApprovalRequest? pending,
    double width = 1180,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    late _RecordingMcpServerNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcpServerNotifierProvider.overrideWith((ref) {
            notifier = buildNotifier(ref);
            if (pending != null) notifier.showApproval(pending);
            return notifier;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: true,
              textScaler: textScaler,
              size: Size(width, 900),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(width: width, child: const McpApprovalBanner()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return notifier;
  }

  testWidgets('renders nothing without a pending approval', (tester) async {
    await pumpBanner(tester);

    expect(find.byKey(const ValueKey('mcp-approval-banner')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows the client, the tool and the estimated cost', (
    tester,
  ) async {
    await pumpBanner(tester, pending: _request());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byKey(const ValueKey('mcp-approval-banner')), findsOneWidget);
    expect(find.text(l10n.mcpApproval_title('codex 1.0.0')), findsOneWidget);
    expect(
      find.text(l10n.agentChat_approvalEstimatedAnlas(24)),
      findsOneWidget,
    );
    expect(find.text(l10n.agentChat_approvalAllow), findsOneWidget);
    expect(find.text(l10n.agentChat_approvalDeny), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('falls back to an unknown client label', (tester) async {
    await pumpBanner(tester, pending: _request(clientLabel: '  '));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(
      find.text(l10n.mcpApproval_title(l10n.mcpApproval_unknownClient)),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('allow and deny report back to the notifier', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    final allowNotifier = await pumpBanner(tester, pending: _request());
    await tester.tap(find.text(l10n.agentChat_approvalAllow));
    await tester.pump();
    expect(allowNotifier.resolutions, [('call-1', true)]);
    await tester.pumpWidget(const SizedBox.shrink());

    final denyNotifier = await pumpBanner(tester, pending: _request());
    await tester.tap(find.text(l10n.agentChat_approvalDeny));
    await tester.pump();
    expect(denyNotifier.resolutions, [('call-1', false)]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stays overflow-free across widths and 3x text', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    for (final width in const [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      for (final scaler in const [
        TextScaler.noScaling,
        TextScaler.linear(3.0),
      ]) {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pumpBanner(
          tester,
          pending: _request(),
          width: width,
          textScaler: scaler,
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'width=$width scaler=$scaler',
        );
        expect(
          find.byKey(const ValueKey('mcp-approval-banner')),
          findsOneWidget,
          reason: 'width=$width scaler=$scaler',
        );
        expect(
          find.text(l10n.agentChat_approvalAllow),
          findsOneWidget,
          reason: 'width=$width scaler=$scaler',
        );
        expect(
          find.text(l10n.agentChat_approvalDeny),
          findsOneWidget,
          reason: 'width=$width scaler=$scaler',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('the countdown timer stops with the banner', (tester) async {
    await pumpBanner(tester, pending: _request());
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  group('McpApprovalOverlay', () {
    const underlyingButtonKey = ValueKey('underlying-button');
    const underlyingContentKey = ValueKey('underlying-content');

    Future<_RecordingMcpServerNotifier> pumpOverlay(
      WidgetTester tester, {
      McpApprovalRequest? pending,
      required VoidCallback onUnderlyingTap,
    }) async {
      late _RecordingMcpServerNotifier notifier;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mcpServerNotifierProvider.overrideWith((ref) {
              notifier = buildNotifier(ref);
              if (pending != null) notifier.showApproval(pending);
              return notifier;
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Stack(
                  children: [
                    Column(
                      children: [
                        SizedBox(
                          height: 48,
                          child: TextButton(
                            key: underlyingButtonKey,
                            onPressed: onUnderlyingTap,
                            child: const Text('underlying'),
                          ),
                        ),
                        const Expanded(
                          child: SizedBox.expand(key: underlyingContentKey),
                        ),
                      ],
                    ),
                    const McpApprovalOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return notifier;
    }

    testWidgets('lets pointer events through while idle', (tester) async {
      var taps = 0;
      await pumpOverlay(tester, onUnderlyingTap: () => taps++);

      await tester.tap(find.byKey(underlyingButtonKey));
      expect(taps, 1);
      expect(find.byKey(const ValueKey('mcp-approval-banner')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('floats over the page instead of pushing it down', (
      tester,
    ) async {
      await pumpOverlay(tester, onUnderlyingTap: () {});
      final idleContent = tester.getRect(find.byKey(underlyingContentKey));
      await tester.pumpWidget(const SizedBox.shrink());

      final notifier = await pumpOverlay(
        tester,
        pending: _request(),
        onUnderlyingTap: () {},
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final banner = find.byKey(const ValueKey('mcp-approval-banner'));

      expect(banner, findsOneWidget);
      expect(tester.getRect(find.byKey(underlyingContentKey)), idleContent);
      expect(tester.getRect(banner).top, lessThan(idleContent.top));
      expect(
        tester.getRect(banner).bottom,
        greaterThan(idleContent.top),
        reason: 'the card overlaps the page rather than reserving space',
      );

      await tester.tap(find.text(l10n.agentChat_approvalAllow));
      await tester.pump();
      expect(notifier.resolutions, [('call-1', true)]);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

McpApprovalRequest _request({String clientLabel = 'codex 1.0.0'}) {
  return McpApprovalRequest(
    request: const AgentToolApprovalRequest(
      toolCallId: 'call-1',
      toolName: 'generate_image',
      args: {'preparation_id': 'prep-1'},
      estimatedAnlas: 24,
    ),
    clientLabel: clientLabel,
    expiresAt: DateTime.now().add(McpServerDefaults.approvalTimeout),
  );
}

class _RecordingMcpServerNotifier extends McpServerNotifier {
  _RecordingMcpServerNotifier(
    super.ref, {
    super.discovery,
    super.settingsStore,
    super.tokenStore,
    super.supportDirectory,
  });

  final List<(String, bool)> resolutions = [];

  void showApproval(McpApprovalRequest request) {
    state = state.copyWith(pendingApproval: request);
  }

  @override
  bool resolveApproval(String toolCallId, bool approved) {
    resolutions.add((toolCallId, approved));
    return true;
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
