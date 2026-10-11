import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_dock_provider.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_workspace_row.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/right_panel.dart';

const _historyCollapse = ValueKey('generation-history-collapse');
const _chatCollapse = ValueKey('agent-chat-collapse');
const _splitDivider = ValueKey('agent-dock-split-divider');
const _rightPanel = ValueKey('generation-right-panel');

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('right_panel_dock_test_');
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

  Future<ProviderContainer> pumpWorkspace(
    WidgetTester tester, {
    required _MemoryLocalStorage storage,
    required double width,
    double height = 900,
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
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
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(body: _DockWorkspace()),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(_DockWorkspace)),
    );
  }

  void expectNoOverflowAndMainProtected(WidgetTester tester, String reason) {
    expect(tester.takeException(), isNull, reason: reason);
    expect(
      tester.getSize(find.byKey(const ValueKey('dock-test-main'))).width,
      greaterThanOrEqualTo(GenerationWorkspaceRow.minimumMainWorkspaceWidth),
      reason: reason,
    );
  }

  void expectBothPanesOperable(WidgetTester tester, String reason) {
    final panelRect = tester.getRect(find.byKey(_rightPanel));
    final historyRect = tester.getRect(find.byType(HistoryPanel));
    final chatRect = tester.getRect(find.byType(AgentChatPanel));
    for (final rect in [historyRect, chatRect]) {
      expect(rect.left, greaterThanOrEqualTo(panelRect.left), reason: reason);
      expect(
        rect.right,
        lessThanOrEqualTo(panelRect.right + 0.01),
        reason: reason,
      );
      expect(rect.height, greaterThan(0), reason: reason);
    }
    expect(historyRect.overlaps(chatRect), isFalse, reason: reason);
    expect(find.byKey(_historyCollapse).hitTestable(), findsOneWidget);
    expect(find.byKey(_chatCollapse).hitTestable(), findsOneWidget);
  }

  testWidgets('独占模式在各宽度保持现状：只显示历史，折叠入口可切到聊天', (tester) async {
    for (final width in const [840.0, 1180.0, 1600.0]) {
      await pumpWorkspace(tester, storage: _MemoryLocalStorage(), width: width);
      expectNoOverflowAndMainProtected(tester, 'exclusive width=$width');
      expect(find.byType(HistoryPanel), findsOneWidget);
      expect(find.byType(AgentChatPanel), findsNothing);
    }

    await tester.tap(find.byKey(_historyCollapse));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-dock-rail-chat')));
    await tester.pump();
    expect(find.byType(AgentChatPanel), findsOneWidget);
    expect(find.byType(HistoryPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧版 right_panel_tab=0 仍打开聊天页', (tester) async {
    await pumpWorkspace(
      tester,
      storage: _MemoryLocalStorage({StorageKeys.rightPanelTab: 0}),
      width: 1180,
    );
    expect(find.byType(AgentChatPanel), findsOneWidget);
    expect(find.byType(HistoryPanel), findsNothing);
  });

  testWidgets('上下分栏在各宽度同时显示历史与聊天且可操作', (tester) async {
    for (final width in const [840.0, 1180.0, 1600.0]) {
      await pumpWorkspace(
        tester,
        storage: _MemoryLocalStorage({
          StorageKeys.agentChatDockMode: AgentChatDockMode.stacked.storageValue,
        }),
        width: width,
      );
      final reason = 'stacked width=$width';
      expectNoOverflowAndMainProtected(tester, reason);
      expectBothPanesOperable(tester, reason);
      expect(
        tester.getRect(find.byType(HistoryPanel)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(AgentChatPanel)).top),
        reason: reason,
      );
    }
  });

  testWidgets('左右分栏放得下时并排，宽度不足时确定退回上下分栏', (tester) async {
    for (final (width, sideBySide) in const [
      (840.0, false),
      (1180.0, true),
      (1600.0, true),
    ]) {
      await pumpWorkspace(
        tester,
        storage: _MemoryLocalStorage({
          StorageKeys.agentChatDockMode:
              AgentChatDockMode.sideBySide.storageValue,
        }),
        width: width,
      );
      final reason = 'sideBySide width=$width';
      expectNoOverflowAndMainProtected(tester, reason);
      expectBothPanesOperable(tester, reason);
      final historyRect = tester.getRect(find.byType(HistoryPanel));
      final chatRect = tester.getRect(find.byType(AgentChatPanel));
      if (sideBySide) {
        expect(historyRect.right, lessThanOrEqualTo(chatRect.left));
        expect(historyRect.top, chatRect.top, reason: reason);
      } else {
        expect(historyRect.bottom, lessThanOrEqualTo(chatRect.top));
        expect(historyRect.width, chatRect.width, reason: reason);
      }
    }
  });

  testWidgets('上下分栏拖动只在松手时持久化比例，拖动期间面板状态不重建', (tester) async {
    final storage = _MemoryLocalStorage({
      StorageKeys.agentChatDockMode: AgentChatDockMode.stacked.storageValue,
    });
    final container = await pumpWorkspace(
      tester,
      storage: storage,
      width: 1180,
    );
    final historyState = tester.state(find.byType(HistoryPanel));
    final chatState = tester.state(find.byType(AgentChatPanel));
    final chatTopBefore = tester.getRect(find.byType(AgentChatPanel)).top;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_splitDivider)),
    );
    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
    }
    expect(
      storage.values.containsKey(StorageKeys.agentChatDockStackedChatFraction),
      isFalse,
      reason: '拖动过程中不得写入存储',
    );
    await gesture.up();
    await tester.pump();

    final saved =
        storage.values[StorageKeys.agentChatDockStackedChatFraction]! as double;
    expect(saved, greaterThan(0.5));
    expect(container.read(agentChatDockProvider).stackedChatFraction, saved);
    expect(
      tester.getRect(find.byType(AgentChatPanel)).top,
      lessThan(chatTopBefore),
    );
    expect(tester.state(find.byType(HistoryPanel)), same(historyState));
    expect(tester.state(find.byType(AgentChatPanel)), same(chatState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('左右分栏拖动中间分隔线在两列间让宽度并同步回写', (tester) async {
    final storage = _MemoryLocalStorage({
      StorageKeys.agentChatDockMode: AgentChatDockMode.sideBySide.storageValue,
    });
    final container = await pumpWorkspace(
      tester,
      storage: storage,
      width: 1600,
    );
    final panelWidthBefore = tester.getSize(find.byKey(_rightPanel)).width;
    final chatWidthBefore = tester.getSize(find.byType(AgentChatPanel)).width;

    await tester.drag(find.byKey(_splitDivider), const Offset(-60, 0));
    await tester.pump();

    final chatWidth =
        storage.values[StorageKeys.agentChatDockSideBySideChatWidth]! as double;
    expect(chatWidth, greaterThan(chatWidthBefore));
    expect(
      container.read(layoutStateNotifierProvider).rightPanelWidth +
          chatWidth +
          8,
      closeTo(panelWidthBefore, 0.5),
    );
    expect(
      tester.getSize(find.byKey(_rightPanel)).width,
      closeTo(panelWidthBefore, 0.5),
      reason: '中间分隔线只在两列间让宽度，右栏总宽不变',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('每格收起只折叠自身；剩下一格再收起才收起整栏；入口可恢复', (tester) async {
    final storage = _MemoryLocalStorage({
      StorageKeys.agentChatDockMode: AgentChatDockMode.stacked.storageValue,
    });
    final container = await pumpWorkspace(
      tester,
      storage: storage,
      width: 1180,
    );
    final historyState = tester.state(find.byType(HistoryPanel));

    await tester.tap(find.byKey(_chatCollapse));
    await tester.pump();
    expect(find.byType(AgentChatPanel), findsNothing);
    expect(tester.state(find.byType(HistoryPanel)), same(historyState));
    final restore = find.byKey(const ValueKey('agent-dock-restore-chat'));
    expect(restore.hitTestable(), findsOneWidget);
    expect(
      container.read(layoutStateNotifierProvider).rightPanelExpanded,
      isTrue,
    );

    await tester.tap(restore);
    await tester.pump();
    expect(find.byType(AgentChatPanel), findsOneWidget);
    expect(find.byType(HistoryPanel), findsOneWidget);

    await tester.tap(find.byKey(_historyCollapse));
    await tester.pump();
    expect(find.byType(HistoryPanel), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-dock-restore-history')).hitTestable(),
      findsOneWidget,
    );

    await tester.tap(find.byKey(_chatCollapse));
    await tester.pump();
    expect(
      container.read(layoutStateNotifierProvider).rightPanelExpanded,
      isFalse,
    );
    expect(find.byKey(const ValueKey('agent-dock-rail-chat')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-dock-rail-history')));
    await tester.pump();
    expect(find.byType(HistoryPanel), findsOneWidget);
    expect(find.byType(AgentChatPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('浮窗模式下右栏只显示历史，不重复渲染聊天', (tester) async {
    await pumpWorkspace(
      tester,
      storage: _MemoryLocalStorage({
        StorageKeys.agentChatDockMode:
            AgentChatDockMode.sideBySide.storageValue,
        StorageKeys.agentChatFloatingEnabled: true,
      }),
      width: 1600,
    );
    expect(find.byType(HistoryPanel), findsOneWidget);
    expect(find.byType(AgentChatPanel), findsNothing);
    expect(tester.getSize(find.byKey(_rightPanel)).width, lessThan(600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换分栏方向保留两块面板状态', (tester) async {
    final container = await pumpWorkspace(
      tester,
      storage: _MemoryLocalStorage({
        StorageKeys.agentChatDockMode: AgentChatDockMode.stacked.storageValue,
      }),
      width: 1600,
    );
    final historyState = tester.state(find.byType(HistoryPanel));
    final chatState = tester.state(find.byType(AgentChatPanel));
    await container
        .read(agentChatDockProvider.notifier)
        .setMode(AgentChatDockMode.sideBySide);
    await tester.pump();
    expect(
      tester.getRect(find.byType(HistoryPanel)).right,
      lessThanOrEqualTo(tester.getRect(find.byType(AgentChatPanel)).left),
    );
    expect(tester.state(find.byType(HistoryPanel)), same(historyState));
    expect(tester.state(find.byType(AgentChatPanel)), same(chatState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('3 倍文字下分栏、恢复条与折叠入口仍可达且无溢出', (tester) async {
    final storage = _MemoryLocalStorage({
      StorageKeys.agentChatDockMode: AgentChatDockMode.stacked.storageValue,
    });
    final container = await pumpWorkspace(
      tester,
      storage: storage,
      width: 1180,
      textScale: 3,
    );
    expect(tester.takeException(), isNull);
    expectBothPanesOperable(tester, '3x stacked');

    await container
        .read(agentChatDockProvider.notifier)
        .setFoldedPane(AgentChatDockPane.chat);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('agent-dock-restore-chat')).hitTestable(),
      findsOneWidget,
    );

    await container
        .read(layoutStateNotifierProvider.notifier)
        .setRightPanelExpanded(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final key in const [
      'agent-dock-rail-chat',
      'agent-dock-rail-history',
    ]) {
      expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
    }
  });
}

class _DockWorkspace extends ConsumerWidget {
  const _DockWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutStateNotifierProvider);
    final chatWidth = ref.watch(
      agentChatDockProvider.select((dock) => dock.sideBySideChatWidthDemand),
    );
    return GenerationWorkspaceRow(
      leading: const [SizedBox(width: 300), SizedBox(width: 8)],
      occupiedLeadingWidth: 308,
      main: const ColoredBox(
        key: ValueKey('dock-test-main'),
        color: Colors.blueGrey,
      ),
      rightPanelExpanded: layout.rightPanelExpanded,
      preferredRightPanelWidth: layout.rightPanelWidth,
      sideBySideChatWidth: chatWidth,
      rightHandle: const SizedBox(width: 8),
      rightPanelBuilder: (allocation) => RightPanel(allocation: allocation),
    );
  }
}

class _MemoryLocalStorage extends LocalStorageService {
  _MemoryLocalStorage([Map<String, Object?>? values]) : values = values ?? {};

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
