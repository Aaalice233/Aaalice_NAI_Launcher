import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/windowing/agent_chat_dock_contract.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_dock_provider.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_surface_registry.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';

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

ProviderContainer _container(_MemoryLocalStorage storage) {
  final container = ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('空存储的默认值等于现状：独占模式显示历史，不启用浮窗', () {
    final state = _container(_MemoryLocalStorage()).read(agentChatDockProvider);
    expect(state.mode, AgentChatDockMode.exclusive);
    expect(state.exclusivePane, AgentChatDockPane.history);
    expect(state.foldedPane, isNull);
    expect(state.floatingEnabled, isFalse);
    expect(state.floatingVisible, isTrue);
    expect(state.floatingRect, isNull);
    expect(
      state.stackedChatFraction,
      AgentChatDockContract.defaultStackedChatFraction,
    );
    expect(
      state.sideBySideChatWidth,
      AgentChatDockContract.defaultSideBySideChatWidth,
    );
  });

  test('兼容旧版 right_panel_tab：0 为聊天，其余值回落到历史', () {
    for (final (stored, expected) in <(Object?, AgentChatDockPane)>[
      (0, AgentChatDockPane.chat),
      (1, AgentChatDockPane.history),
      (7, AgentChatDockPane.history),
      ('chat', AgentChatDockPane.history),
    ]) {
      final storage = _MemoryLocalStorage({StorageKeys.rightPanelTab: stored});
      expect(
        _container(storage).read(agentChatDockProvider).exclusivePane,
        expected,
        reason: '$stored',
      );
    }
  });

  test('独占页签继续写回旧键，旧版本降级后仍能读懂', () async {
    final storage = _MemoryLocalStorage();
    final container = _container(storage);
    await container
        .read(agentChatDockProvider.notifier)
        .showExclusivePane(AgentChatDockPane.chat);
    expect(storage.values[StorageKeys.rightPanelTab], 0);
    await container
        .read(agentChatDockProvider.notifier)
        .showExclusivePane(AgentChatDockPane.history);
    expect(storage.values[StorageKeys.rightPanelTab], 1);
  });

  test('损坏的持久化值回落到默认值', () {
    final state = _container(
      _MemoryLocalStorage({
        StorageKeys.agentChatDockMode: 'unknown',
        StorageKeys.agentChatDockFoldedPane: 42,
        StorageKeys.agentChatDockStackedChatFraction: 'wide',
        StorageKeys.agentChatDockSideBySideChatWidth: -3,
        StorageKeys.agentChatFloatingEnabled: 'yes',
        StorageKeys.agentChatFloatingRect: [1, 2, 3],
      }),
    ).read(agentChatDockProvider);
    expect(state.mode, AgentChatDockMode.exclusive);
    expect(state.foldedPane, isNull);
    expect(
      state.stackedChatFraction,
      AgentChatDockContract.defaultStackedChatFraction,
    );
    expect(
      state.sideBySideChatWidth,
      AgentChatDockContract.defaultSideBySideChatWidth,
    );
    expect(state.floatingEnabled, isFalse);
    expect(state.floatingRect, isNull);
  });

  test('模式、分栏比例、聊天列宽与浮窗几何持久化后可恢复', () async {
    final storage = _MemoryLocalStorage();
    final container = _container(storage);
    final notifier = container.read(agentChatDockProvider.notifier);
    await notifier.setMode(AgentChatDockMode.stacked);
    await notifier.setFoldedPane(AgentChatDockPane.chat);
    await notifier.setMode(AgentChatDockMode.sideBySide);
    expect(container.read(agentChatDockProvider).foldedPane, isNull);
    await notifier.setStackedChatFraction(0.95);
    await notifier.setSideBySideChatWidth(512);
    await notifier.setFloatingRect(const Rect.fromLTWH(10, 20, 400, 500));
    await notifier.setFloatingRect(const Rect.fromLTWH(0, 0, 0, 0));

    final restored = _container(storage).read(agentChatDockProvider);
    expect(restored.mode, AgentChatDockMode.sideBySide);
    expect(restored.foldedPane, isNull);
    expect(
      restored.stackedChatFraction,
      AgentChatDockContract.maximumStackedChatFraction,
    );
    expect(restored.sideBySideChatWidth, 512);
    expect(restored.floatingRect, const Rect.fromLTWH(10, 20, 400, 500));
  });

  test('共存模式下收起一格只折叠该格，另一格再收起才收起整个右栏', () async {
    final storage = _MemoryLocalStorage();
    final container = _container(storage);
    final notifier = container.read(agentChatDockProvider.notifier);
    await notifier.setMode(AgentChatDockMode.stacked);

    await notifier.collapsePane(AgentChatDockPane.chat);
    expect(
      container.read(agentChatDockProvider).foldedPane,
      AgentChatDockPane.chat,
    );
    expect(
      container.read(layoutStateNotifierProvider).rightPanelExpanded,
      isTrue,
    );

    await notifier.collapsePane(AgentChatDockPane.history);
    expect(
      container.read(layoutStateNotifierProvider).rightPanelExpanded,
      isFalse,
    );

    await notifier.revealDockedPane(AgentChatDockPane.chat);
    expect(container.read(agentChatDockProvider).foldedPane, isNull);
    expect(
      container.read(layoutStateNotifierProvider).rightPanelExpanded,
      isTrue,
    );
    expect(
      container.read(agentChatSurfaceRegistryProvider).dockedFocus.pending,
      isTrue,
    );
  });

  test('独占模式与浮窗模式下收起按钮收起整个右栏', () async {
    final container = _container(_MemoryLocalStorage());
    final notifier = container.read(agentChatDockProvider.notifier);
    await notifier.collapsePane(AgentChatDockPane.history);
    expect(
      container.read(layoutStateNotifierProvider).rightPanelExpanded,
      isFalse,
    );

    await notifier.revealDockedPane(AgentChatDockPane.history);
    await notifier.setMode(AgentChatDockMode.sideBySide);
    await notifier.popOut();
    await notifier.collapsePane(AgentChatDockPane.history);
    expect(container.read(agentChatDockProvider).foldedPane, isNull);
    expect(
      container.read(layoutStateNotifierProvider).rightPanelExpanded,
      isFalse,
    );
  });

  test('独占模式展示聊天时切换页签并请求停靠聊天焦点', () async {
    final storage = _MemoryLocalStorage();
    final container = _container(storage);
    final registry = container.read(agentChatSurfaceRegistryProvider);
    await container
        .read(agentChatDockProvider.notifier)
        .revealDockedPane(AgentChatDockPane.chat);
    expect(
      container.read(agentChatDockProvider).exclusivePane,
      AgentChatDockPane.chat,
    );
    expect(storage.values[StorageKeys.rightPanelTab], 0);
    expect(registry.dockedFocus.consume(), isTrue);
    expect(registry.dockedFocus.consume(), isFalse);
  });

  test('弹出与显示浮窗会请求浮窗焦点，隐藏不会', () async {
    final storage = _MemoryLocalStorage();
    final container = _container(storage);
    final notifier = container.read(agentChatDockProvider.notifier);
    final focus = container
        .read(agentChatSurfaceRegistryProvider)
        .floatingFocus;

    await notifier.popOut();
    expect(container.read(agentChatDockProvider).floatingEnabled, isTrue);
    expect(container.read(agentChatDockProvider).floatingVisible, isTrue);
    expect(focus.consume(), isTrue);

    await notifier.setFloatingVisible(false);
    expect(focus.pending, isFalse);
    expect(storage.values[StorageKeys.agentChatFloatingVisible], isFalse);

    await notifier.setFloatingVisible(true);
    expect(focus.consume(), isTrue);

    await notifier.setFloatingVisible(false);
    await notifier.setFloatingEnabled(true);
    expect(
      container.read(agentChatDockProvider).floatingVisible,
      isTrue,
      reason: '重新开启浮窗时必须可见，否则用户看不到任何变化',
    );
    await notifier.setFloatingEnabled(false);
    expect(storage.values[StorageKeys.agentChatFloatingEnabled], isFalse);
  });

  group('派生布局与导航目标', () {
    test('右栏布局按模式、收起状态和左右宽度退化解析', () {
      const exclusive = AgentChatDockState();
      expect(
        exclusive.dockLayout(sideBySideFits: true),
        const AgentChatDockLayout.single(AgentChatDockPane.history),
      );
      expect(
        const AgentChatDockState(
          mode: AgentChatDockMode.sideBySide,
        ).dockLayout(sideBySideFits: true),
        const AgentChatDockLayout.split(Axis.horizontal),
      );
      expect(
        const AgentChatDockState(
          mode: AgentChatDockMode.sideBySide,
        ).dockLayout(sideBySideFits: false),
        const AgentChatDockLayout.split(Axis.vertical),
      );
      expect(
        const AgentChatDockState(
          mode: AgentChatDockMode.stacked,
          foldedPane: AgentChatDockPane.chat,
        ).dockLayout(sideBySideFits: true),
        const AgentChatDockLayout.single(
          AgentChatDockPane.history,
          foldedPane: AgentChatDockPane.chat,
        ),
      );
      expect(
        const AgentChatDockState(
          mode: AgentChatDockMode.stacked,
          floatingEnabled: true,
        ).dockLayout(sideBySideFits: true),
        const AgentChatDockLayout.single(AgentChatDockPane.history),
      );
    });

    test('左右分栏只在未收起、未浮窗时申请聊天列宽', () {
      expect(const AgentChatDockState().sideBySideChatWidthDemand, isNull);
      expect(
        const AgentChatDockState(
          mode: AgentChatDockMode.sideBySide,
          sideBySideChatWidth: 400,
        ).sideBySideChatWidthDemand,
        400,
      );
      expect(
        const AgentChatDockState(
          mode: AgentChatDockMode.sideBySide,
          foldedPane: AgentChatDockPane.history,
        ).sideBySideChatWidthDemand,
        isNull,
      );
      expect(
        const AgentChatDockState(
          mode: AgentChatDockMode.sideBySide,
          floatingEnabled: true,
        ).sideBySideChatWidthDemand,
        isNull,
      );
    });

    test('导航智能体：浮窗优先，其次共存或已显示聊天的停靠，最后侧边浮层', () {
      for (final (state, dockAvailable, expected)
          in <(AgentChatDockState, bool, AgentChatSurfaceTarget)>[
            (
              const AgentChatDockState(floatingEnabled: true),
              true,
              AgentChatSurfaceTarget.floating,
            ),
            (
              const AgentChatDockState(floatingEnabled: true),
              false,
              AgentChatSurfaceTarget.floating,
            ),
            (
              const AgentChatDockState(mode: AgentChatDockMode.stacked),
              true,
              AgentChatSurfaceTarget.dock,
            ),
            (
              const AgentChatDockState(mode: AgentChatDockMode.sideBySide),
              false,
              AgentChatSurfaceTarget.overlay,
            ),
            (const AgentChatDockState(), true, AgentChatSurfaceTarget.overlay),
            (
              const AgentChatDockState(exclusivePane: AgentChatDockPane.chat),
              true,
              AgentChatSurfaceTarget.dock,
            ),
          ]) {
        expect(
          state.navigationTarget(dockAvailable: dockAvailable),
          expected,
          reason: '$state dockAvailable=$dockAvailable',
        );
      }
    });

    test('启动预热只在聊天实际可见时触发', () {
      expect(
        const AgentChatDockState().chatVisibleAtStartup(
          rightPanelExpanded: true,
        ),
        isFalse,
      );
      expect(
        const AgentChatDockState(
          exclusivePane: AgentChatDockPane.chat,
        ).chatVisibleAtStartup(rightPanelExpanded: true),
        isTrue,
      );
      expect(
        const AgentChatDockState(
          exclusivePane: AgentChatDockPane.chat,
        ).chatVisibleAtStartup(rightPanelExpanded: false),
        isFalse,
      );
      expect(
        const AgentChatDockState(
          mode: AgentChatDockMode.stacked,
        ).chatVisibleAtStartup(rightPanelExpanded: true),
        isTrue,
      );
      expect(
        const AgentChatDockState(
          mode: AgentChatDockMode.stacked,
          foldedPane: AgentChatDockPane.chat,
        ).chatVisibleAtStartup(rightPanelExpanded: true),
        isFalse,
      );
      expect(
        const AgentChatDockState(
          floatingEnabled: true,
        ).chatVisibleAtStartup(rightPanelExpanded: false),
        isTrue,
      );
      expect(
        const AgentChatDockState(
          floatingEnabled: true,
          floatingVisible: false,
        ).chatVisibleAtStartup(rightPanelExpanded: true),
        isFalse,
      );
    });
  });
}
