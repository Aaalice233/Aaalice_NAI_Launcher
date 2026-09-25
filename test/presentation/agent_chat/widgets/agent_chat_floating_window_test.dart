import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/windowing/floating_panel_geometry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_dock_provider.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_surface_registry.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_floating_window.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';

const _window = ValueKey('agent-floating-window');
const _titleBar = ValueKey('agent-floating-title-bar');

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('agent_floating_test_');
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

  Future<(ProviderContainer, _Counters)> pumpLayer(
    WidgetTester tester, {
    required _MemoryLocalStorage storage,
    Size size = const Size(1200, 800),
    InteractionPolicy? policy,
  }) async {
    final counters = _Counters();
    await tester.binding.setSurfaceSize(size);
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
          home: InteractionPolicyScope(
            initialPolicy: policy,
            child: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('floating-test-page'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => counters.pageTaps++,
                    ),
                  ),
                  Positioned.fill(
                    child: AgentChatFloatingLayer(
                      onDock: () => counters.docks++,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AgentChatFloatingLayer)),
    );
    return (container, counters);
  }

  Rect windowRect(WidgetTester tester) => tester.getRect(find.byKey(_window));

  testWidgets('首次显示前不挂载聊天，弹出后出现在右下角并消费焦点请求', (tester) async {
    final (container, _) = await pumpLayer(
      tester,
      storage: _MemoryLocalStorage(),
    );
    expect(find.byType(AgentChatPanel, skipOffstage: false), findsNothing);

    await container.read(agentChatDockProvider.notifier).popOut();
    await tester.pump();
    await tester.pump();

    expect(find.byType(AgentChatPanel), findsOneWidget);
    final expected = FloatingPanelGeometry.defaultRect(const Size(1200, 800));
    expect(windowRect(tester), expected);
    expect(
      container.read(agentChatSurfaceRegistryProvider).floatingFocus.pending,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动标题栏移动浮窗，松手才保存位置并始终夹在工作区内', (tester) async {
    final storage = _MemoryLocalStorage({
      StorageKeys.agentChatFloatingEnabled: true,
    });
    await pumpLayer(tester, storage: storage);
    final before = windowRect(tester);
    final chatState = tester.state(find.byType(AgentChatPanel));

    final titleBar = tester.getRect(find.byKey(_titleBar));
    final gesture = await tester.startGesture(
      titleBar.topLeft + const Offset(58, 28),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-40, -40));
    await tester.pump();
    await gesture.moveBy(const Offset(-5000, -5000));
    await tester.pump();
    expect(
      storage.values.containsKey(StorageKeys.agentChatFloatingRect),
      isFalse,
    );
    expect(windowRect(tester).topLeft, Offset.zero);
    await gesture.up();
    await tester.pump();

    expect(windowRect(tester).size, before.size);
    expect(storage.values[StorageKeys.agentChatFloatingRect], [
      0.0,
      0.0,
      before.width,
      before.height,
    ]);
    expect(tester.state(find.byType(AgentChatPanel)), same(chatState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动边角调整大小遵守最小尺寸，窗口外沿的抓手可命中', (tester) async {
    final storage = _MemoryLocalStorage({
      StorageKeys.agentChatFloatingEnabled: true,
      StorageKeys.agentChatFloatingRect: [300.0, 100.0, 420.0, 500.0],
    });
    await pumpLayer(tester, storage: storage);
    expect(windowRect(tester), const Rect.fromLTWH(300, 100, 420, 500));

    await tester.dragFrom(
      windowRect(tester).bottomRight + const Offset(4, 4),
      const Offset(80, 60),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    final grown = windowRect(tester);
    expect(grown.topLeft, const Offset(300, 100));
    expect(grown.width, greaterThan(420));
    expect(grown.height, greaterThan(500));

    await tester.dragFrom(
      windowRect(tester).centerLeft + const Offset(-4, 0),
      const Offset(600, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(windowRect(tester).width, FloatingPanelGeometry.minimumSize.width);
    expect(windowRect(tester).right, grown.right);
    expect(tester.takeException(), isNull);
  });

  testWidgets('触屏下角抓手外沿不少于 44 像素并可拖动调整', (tester) async {
    await pumpLayer(
      tester,
      storage: _MemoryLocalStorage({
        StorageKeys.agentChatFloatingEnabled: true,
        StorageKeys.agentChatFloatingRect: [300.0, 100.0, 420.0, 500.0],
      }),
      policy: InteractionPolicy.touchFirst,
    );
    final grip = tester.getRect(
      find.byKey(const ValueKey('agent-floating-resize-bottomRight')),
    );
    expect(grip.width, greaterThanOrEqualTo(44));
    expect(grip.height, greaterThanOrEqualTo(44));
    expect(grip.right - windowRect(tester).right, greaterThanOrEqualTo(22));

    await tester.dragFrom(
      windowRect(tester).bottomRight + const Offset(16, 16),
      const Offset(60, 60),
    );
    await tester.pump();
    expect(windowRect(tester).width, greaterThan(420));
    expect(tester.takeException(), isNull);
  });

  testWidgets('工作区变小时浮窗夹回可见范围，保存的偏好不被覆盖', (tester) async {
    final storage = _MemoryLocalStorage({
      StorageKeys.agentChatFloatingEnabled: true,
      StorageKeys.agentChatFloatingRect: [700.0, 250.0, 420.0, 500.0],
    });
    await pumpLayer(tester, storage: storage);
    final chatState = tester.state(find.byType(AgentChatPanel));

    await tester.binding.setSurfaceSize(const Size(900, 600));
    await tester.pump();
    final clamped = windowRect(tester);
    expect(clamped.right, lessThanOrEqualTo(900));
    expect(clamped.bottom, lessThanOrEqualTo(600));
    expect(clamped.size, const Size(420, 500));
    expect(storage.values[StorageKeys.agentChatFloatingRect], [
      700.0,
      250.0,
      420.0,
      500.0,
    ]);

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pump();
    expect(windowRect(tester), const Rect.fromLTWH(700, 250, 420, 500));
    expect(tester.state(find.byType(AgentChatPanel)), same(chatState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏保持挂载并暂停动画，隐藏后点击穿透到页面，再显示复用同一状态', (tester) async {
    final (container, counters) = await pumpLayer(
      tester,
      storage: _MemoryLocalStorage({
        StorageKeys.agentChatFloatingEnabled: true,
      }),
    );
    final chatState = tester.state(find.byType(AgentChatPanel));
    final visibleRect = windowRect(tester);

    await tester.tap(find.byKey(const ValueKey('agent-chat-floating-hide')));
    await tester.pump();
    expect(container.read(agentChatDockProvider).floatingVisible, isFalse);
    expect(find.byType(AgentChatPanel), findsNothing);
    expect(
      tester.state(find.byType(AgentChatPanel, skipOffstage: false)),
      same(chatState),
    );
    final tickerMode = tester.widget<TickerMode>(
      find
          .ancestor(
            of: find.byType(AgentChatPanel, skipOffstage: false),
            matching: find.byType(TickerMode, skipOffstage: false),
          )
          .first,
    );
    expect(tickerMode.enabled, isFalse);

    await tester.tapAt(visibleRect.center);
    expect(counters.pageTaps, 1);

    await container
        .read(agentChatDockProvider.notifier)
        .setFloatingVisible(true);
    await tester.pump();
    expect(tester.state(find.byType(AgentChatPanel)), same(chatState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('停靠按钮交给宿主处理；关闭浮窗模式后释放聊天实例', (tester) async {
    final (container, counters) = await pumpLayer(
      tester,
      storage: _MemoryLocalStorage({
        StorageKeys.agentChatFloatingEnabled: true,
      }),
    );
    await tester.tap(find.byKey(const ValueKey('agent-chat-dock')));
    await tester.pump();
    expect(counters.docks, 1);

    await container
        .read(agentChatDockProvider.notifier)
        .setFloatingEnabled(false);
    await tester.pump();
    expect(find.byType(AgentChatPanel, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Counters {
  int pageTaps = 0;
  int docks = 0;
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
