import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/windowing/agent_chat_dock_contract.dart';
import '../../../core/windowing/floating_panel_geometry.dart';
import '../../providers/layout_state_provider.dart';
import 'agent_chat_dock_state.dart';
import 'agent_chat_surface_registry.dart';

export 'agent_chat_dock_state.dart';

/// Device-local presentation of Agent chat: right panel docking and the
/// in-app floating window. None of these keys join cloud sync.
final agentChatDockProvider =
    NotifierProvider<AgentChatDockNotifier, AgentChatDockState>(
      AgentChatDockNotifier.new,
    );

class AgentChatDockNotifier extends Notifier<AgentChatDockState> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  AgentChatSurfaceRegistry get _surfaces =>
      ref.read(agentChatSurfaceRegistryProvider);

  @override
  AgentChatDockState build() {
    final storage = ref.read(localStorageServiceProvider);
    Object? read(String key) => storage.getSetting<Object?>(key);
    return AgentChatDockState(
      mode: AgentChatDockMode.fromStorageValue(
        read(StorageKeys.agentChatDockMode),
      ),
      exclusivePane: AgentChatDockPane.fromLegacyTabIndex(
        read(StorageKeys.rightPanelTab),
      ),
      foldedPane: AgentChatDockPane.fromStorageValue(
        read(StorageKeys.agentChatDockFoldedPane),
      ),
      stackedChatFraction: AgentChatDockContract.normalizeStackedChatFraction(
        _asDouble(read(StorageKeys.agentChatDockStackedChatFraction)),
      ),
      sideBySideChatWidth: AgentChatDockContract.normalizeSideBySideChatWidth(
        _asDouble(read(StorageKeys.agentChatDockSideBySideChatWidth)),
      ),
      floatingEnabled: read(StorageKeys.agentChatFloatingEnabled) == true,
      floatingVisible: read(StorageKeys.agentChatFloatingVisible) != false,
      floatingRect: _decodeRect(read(StorageKeys.agentChatFloatingRect)),
    );
  }

  Future<void> setMode(AgentChatDockMode mode) {
    if (state.mode == mode && state.foldedPane == null) return Future.value();
    state = state.copyWith(mode: mode, foldedPane: () => null);
    return Future.wait([
      _storage.setSetting(StorageKeys.agentChatDockMode, mode.storageValue),
      _storage.setSetting<String?>(StorageKeys.agentChatDockFoldedPane, null),
    ]);
  }

  Future<void> showExclusivePane(AgentChatDockPane pane) {
    if (state.exclusivePane == pane) return Future.value();
    state = state.copyWith(exclusivePane: pane);
    return _storage.setSetting(StorageKeys.rightPanelTab, pane.legacyTabIndex);
  }

  Future<void> setFoldedPane(AgentChatDockPane? pane) {
    if (state.foldedPane == pane) return Future.value();
    state = state.copyWith(foldedPane: () => pane);
    return _storage.setSetting<String?>(
      StorageKeys.agentChatDockFoldedPane,
      pane?.name,
    );
  }

  /// A coexisting pane folds alone while its sibling stays visible; otherwise
  /// the whole right panel collapses.
  Future<void> collapsePane(AgentChatDockPane pane) {
    if (state.coexists && state.foldedPane == null) {
      return setFoldedPane(pane);
    }
    return ref
        .read(layoutStateNotifierProvider.notifier)
        .setRightPanelExpanded(false);
  }

  /// Expands the right panel with [pane] visible; chat also takes focus.
  Future<void> revealDockedPane(AgentChatDockPane pane) {
    final showPane = state.mode.coexists
        ? state.foldedPane == pane
              ? setFoldedPane(null)
              : Future<void>.value()
        : showExclusivePane(pane);
    final expand = ref.read(layoutStateNotifierProvider).rightPanelExpanded
        ? Future<void>.value()
        : ref
              .read(layoutStateNotifierProvider.notifier)
              .setRightPanelExpanded(true);
    if (pane == AgentChatDockPane.chat) _surfaces.dockedFocus.request();
    return Future.wait([showPane, expand]);
  }

  Future<void> setStackedChatFraction(double fraction) {
    final normalized = AgentChatDockContract.normalizeStackedChatFraction(
      fraction,
    );
    if (state.stackedChatFraction == normalized) return Future.value();
    state = state.copyWith(stackedChatFraction: normalized);
    return _storage.setSetting(
      StorageKeys.agentChatDockStackedChatFraction,
      normalized,
    );
  }

  Future<void> setSideBySideChatWidth(double width) {
    final normalized = AgentChatDockContract.normalizeSideBySideChatWidth(
      width,
    );
    if (state.sideBySideChatWidth == normalized) return Future.value();
    state = state.copyWith(sideBySideChatWidth: normalized);
    return _storage.setSetting(
      StorageKeys.agentChatDockSideBySideChatWidth,
      normalized,
    );
  }

  Future<void> setFloatingEnabled(bool enabled) {
    if (state.floatingEnabled == enabled &&
        (!enabled || state.floatingVisible)) {
      return Future.value();
    }
    state = state.copyWith(
      floatingEnabled: enabled,
      floatingVisible: enabled ? true : null,
    );
    return Future.wait([
      _storage.setSetting(StorageKeys.agentChatFloatingEnabled, enabled),
      if (enabled)
        _storage.setSetting(StorageKeys.agentChatFloatingVisible, true),
    ]);
  }

  Future<void> popOut() {
    final write = setFloatingEnabled(true);
    _surfaces.floatingFocus.request();
    return write;
  }

  Future<void> setFloatingVisible(bool visible) {
    if (visible) _surfaces.floatingFocus.request();
    if (state.floatingVisible == visible) return Future.value();
    state = state.copyWith(floatingVisible: visible);
    return _storage.setSetting(StorageKeys.agentChatFloatingVisible, visible);
  }

  Future<void> setFloatingRect(Rect rect) {
    if (!FloatingPanelGeometry.isUsable(rect) || state.floatingRect == rect) {
      return Future.value();
    }
    state = state.copyWith(floatingRect: () => rect);
    return _storage.setSetting<List<double>>(
      StorageKeys.agentChatFloatingRect,
      [rect.left, rect.top, rect.width, rect.height],
    );
  }

  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  static Rect? _decodeRect(Object? value) {
    if (value is! List || value.length != 4) return null;
    final numbers = <double>[];
    for (final item in value) {
      if (item is! num) return null;
      numbers.add(item.toDouble());
    }
    final rect = Rect.fromLTWH(numbers[0], numbers[1], numbers[2], numbers[3]);
    return FloatingPanelGeometry.isUsable(rect) ? rect : null;
  }
}
