import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/account_manager_provider.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_dock_provider.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_surface_registry.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/router/app_branch.dart';
import 'package:nai_launcher/presentation/router/desktop_shell.dart';
import 'package:nai_launcher/presentation/router/shell_panels_overlay.dart';
import 'package:nai_launcher/presentation/widgets/navigation/main_nav_rail.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _agentNav = Key('agent-nav-item');

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'NAI Launcher',
      packageName: 'nai_launcher',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppVersion.initialize();
    hiveDir = Directory.systemTemp.createTempSync('desktop_shell_dock_test_');
    Hive.init(hiveDir.path);
    // 内存后端：落盘写一旦从 widget test 的 FakeAsync 时钟发起就不会完成，会锁死 box
    await Hive.openBox(StorageKeys.settingsBox, bytes: Uint8List(0));
  });

  tearDownAll(() async {
    await Hive.box(
      StorageKeys.settingsBox,
    ).close().timeout(const Duration(seconds: 10));
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  Future<_ShellHarness> pumpShell(
    WidgetTester tester, {
    required Map<String, Object?> settings,
    AppBranch branch = AppBranch.generation,
    bool? dockFits,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    final navigationShell = ValueNotifier<StatefulNavigationShell>(
      _shellAt(branch),
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _MemoryLocalStorage(Map.of(settings)),
          ),
          updateStateNotifierProvider.overrideWith(_FakeUpdateNotifier.new),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _FakeAccountManagerNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _FakeQueueExecutionNotifier.new,
          ),
          replicationQueueNotifierProvider.overrideWith(
            _FakeReplicationQueueNotifier.new,
          ),
          agentChatNotifierProvider.overrideWith(
            (ref) => AgentChatNotifier(
              ref,
              supportDir: hiveDir,
              workspaceDir: Directory('${hiveDir.path}/agent-workspace'),
              presetSkills: const [],
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<StatefulNavigationShell>(
            valueListenable: navigationShell,
            builder: (context, shell, _) => DesktopShell(
              navigationShell: shell,
              content: const SizedBox.expand(key: ValueKey('page-content')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DesktopShell)),
    );
    if (dockFits != null) {
      container
          .read(agentChatSurfaceRegistryProvider)
          .attachDockHost(_FakeDockHost(dockFits));
    }
    return _ShellHarness(container, navigationShell);
  }

  Future<void> tapAgentNav(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(_agentNav));
    await tester.pump();
    // 收起的导航栏只露出图标列，按行中心点击会落在裁切区外。
    await tester.tap(
      find.descendant(of: find.byKey(_agentNav), matching: find.byType(Icon)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  bool agentNavSelected(WidgetTester tester) =>
      tester.widget<MainNavRail>(find.byType(MainNavRail)).isAgentVisible;

  testWidgets('生成页共存模式：导航智能体展开右栏并聚焦停靠聊天，不开侧边浮层', (tester) async {
    final harness = await pumpShell(
      tester,
      settings: {
        StorageKeys.agentChatDockMode: AgentChatDockMode.stacked.storageValue,
        StorageKeys.agentChatDockFoldedPane: AgentChatDockPane.chat.name,
        StorageKeys.rightPanelExpanded: false,
      },
      dockFits: true,
    );

    await tapAgentNav(tester);

    expect(harness.read(shellPanelProvider), isNull);
    expect(
      harness.read(layoutStateNotifierProvider).rightPanelExpanded,
      isTrue,
    );
    expect(harness.read(agentChatDockProvider).foldedPane, isNull);
    expect(
      harness.read(agentChatSurfaceRegistryProvider).dockedFocus.pending,
      isTrue,
    );
    expect(find.byType(AgentChatPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('独占模式：显示历史时仍打开侧边浮层，已显示聊天时改为聚焦停靠聊天', (tester) async {
    final history = await pumpShell(tester, settings: const {}, dockFits: true);
    await tapAgentNav(tester);
    expect(history.read(shellPanelProvider), ShellPanel.agent);
    expect(agentNavSelected(tester), isTrue);
    await tapAgentNav(tester);
    expect(history.read(shellPanelProvider), isNull);

    final chat = await pumpShell(
      tester,
      settings: {StorageKeys.rightPanelTab: 0},
      dockFits: true,
    );
    await tapAgentNav(tester);
    expect(chat.read(shellPanelProvider), isNull);
    expect(
      chat.read(agentChatSurfaceRegistryProvider).dockedFocus.pending,
      isTrue,
    );
  });

  testWidgets('其他页面或右栏放不下时，共存模式仍回落到侧边浮层', (tester) async {
    final otherPage = await pumpShell(
      tester,
      settings: {
        StorageKeys.agentChatDockMode:
            AgentChatDockMode.sideBySide.storageValue,
      },
      branch: AppBranch.localGallery,
      dockFits: true,
    );
    await tapAgentNav(tester);
    expect(otherPage.read(shellPanelProvider), ShellPanel.agent);

    final narrow = await pumpShell(
      tester,
      settings: {
        StorageKeys.agentChatDockMode: AgentChatDockMode.stacked.storageValue,
      },
      dockFits: false,
    );
    await tapAgentNav(tester);
    expect(narrow.read(shellPanelProvider), ShellPanel.agent);

    final unmounted = await pumpShell(
      tester,
      settings: {
        StorageKeys.agentChatDockMode: AgentChatDockMode.stacked.storageValue,
      },
    );
    await tapAgentNav(tester);
    expect(unmounted.read(shellPanelProvider), ShellPanel.agent);
  });

  testWidgets('浮窗模式：导航切换浮窗显隐并同步选中态，从不打开侧边浮层', (tester) async {
    final harness = await pumpShell(
      tester,
      settings: {StorageKeys.agentChatFloatingEnabled: true},
      branch: AppBranch.settings,
    );
    expect(find.byType(AgentChatPanel), findsOneWidget);
    expect(agentNavSelected(tester), isTrue);

    await tapAgentNav(tester);
    expect(harness.read(agentChatDockProvider).floatingVisible, isFalse);
    expect(harness.read(shellPanelProvider), isNull);
    expect(agentNavSelected(tester), isFalse);
    expect(find.byType(AgentChatPanel), findsNothing);
    expect(
      find.byType(AgentChatPanel, skipOffstage: false),
      findsOneWidget,
      reason: '隐藏后保持挂载',
    );

    await tapAgentNav(tester);
    expect(harness.read(agentChatDockProvider).floatingVisible, isTrue);
    expect(agentNavSelected(tester), isTrue);
    expect(find.byType(AgentChatPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('浮窗层位于侧边面板之上、MCP 审批之下', (tester) async {
    await pumpShell(tester, settings: const {});
    final stack = tester.widget<Stack>(
      find.byKey(const Key('desktop-workspace-stack')),
    );
    final keys = [for (final child in stack.children) child.key];
    expect(keys.sublist(keys.length - 3), const [
      ValueKey('desktop-panel-overlay-layer'),
      ValueKey('desktop-floating-agent-layer'),
      ValueKey('desktop-approval-overlay-layer'),
    ]);
  });

  testWidgets('侧边浮层弹出为浮窗后关闭浮层，浮窗停靠回生成页右栏', (tester) async {
    final harness = await pumpShell(
      tester,
      settings: const {},
      branch: AppBranch.localGallery,
      dockFits: true,
    );
    await tapAgentNav(tester);
    expect(harness.read(shellPanelProvider), ShellPanel.agent);

    await tester.tap(find.byKey(const ValueKey('agent-chat-pop-out')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(harness.read(shellPanelProvider), isNull);
    expect(harness.read(agentChatDockProvider).floatingEnabled, isTrue);
    expect(find.byKey(const ValueKey('agent-floating-window')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-chat-dock')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(harness.read(agentChatDockProvider).floatingEnabled, isFalse);
    expect(
      harness.read(shellPanelProvider),
      ShellPanel.agent,
      reason: '非生成页停靠回当前页面的侧边面板',
    );

    harness.navigateTo(AppBranch.generation);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-chat-pop-out')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('agent-chat-dock')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(harness.read(shellPanelProvider), isNull);
    expect(
      harness.read(agentChatDockProvider).exclusivePane,
      AgentChatDockPane.chat,
      reason: '生成页停靠回右栏时独占模式切到聊天页',
    );
    expect(
      harness.read(layoutStateNotifierProvider).rightPanelExpanded,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('打开侧边浮层后切到共存模式的生成页，聊天交给停靠右栏避免叠加', (tester) async {
    final harness = await pumpShell(
      tester,
      settings: {
        StorageKeys.agentChatDockMode: AgentChatDockMode.stacked.storageValue,
      },
      branch: AppBranch.localGallery,
      dockFits: true,
    );
    await tapAgentNav(tester);
    expect(harness.read(shellPanelProvider), ShellPanel.agent);

    harness.navigateTo(AppBranch.generation);
    await tester.pump();
    await tester.pump();
    expect(harness.read(shellPanelProvider), isNull);
    expect(
      harness.read(agentChatSurfaceRegistryProvider).dockedFocus.pending,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

StatefulNavigationShell _shellAt(AppBranch branch) {
  final shell = _MockNavigationShell();
  when(() => shell.currentIndex).thenReturn(branch.index);
  return shell;
}

class _ShellHarness {
  _ShellHarness(this._container, this._navigationShell);

  final ProviderContainer _container;
  final ValueNotifier<StatefulNavigationShell> _navigationShell;

  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  void navigateTo(AppBranch branch) =>
      _navigationShell.value = _shellAt(branch);
}

class _FakeDockHost implements AgentChatDockHost {
  _FakeDockHost(this.fitsExpanded);

  @override
  final bool fitsExpanded;
}

class _MockNavigationShell extends Mock implements StatefulNavigationShell {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockNavigationShell';
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeUpdateNotifier extends UpdateStateNotifier {
  @override
  UpdateState build() => const UpdateState();
}

class _FakeAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}

class _FakeQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _FakeReplicationQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();
}

class _MemoryLocalStorage extends LocalStorageService {
  _MemoryLocalStorage(this.values);

  final Map<String, Object?> values;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = values[key];
    return value == null ? defaultValue : value as T;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
