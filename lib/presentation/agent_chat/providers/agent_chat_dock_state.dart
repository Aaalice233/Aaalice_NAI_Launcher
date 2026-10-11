import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../core/windowing/agent_chat_dock_contract.dart';

/// How chat and history share the generation right panel on wide layouts.
enum AgentChatDockMode {
  exclusive('exclusive'),
  stacked('stacked'),
  sideBySide('side_by_side');

  const AgentChatDockMode(this.storageValue);

  final String storageValue;

  bool get coexists => this != AgentChatDockMode.exclusive;

  static AgentChatDockMode fromStorageValue(Object? value) {
    for (final mode in values) {
      if (mode.storageValue == value) return mode;
    }
    return AgentChatDockMode.exclusive;
  }
}

enum AgentChatDockPane {
  chat,
  history;

  AgentChatDockPane get other =>
      this == AgentChatDockPane.chat ? history : chat;

  // Legacy right panel tab values: 0 = chat, 1 = history.
  int get legacyTabIndex => this == AgentChatDockPane.chat ? 0 : 1;

  static AgentChatDockPane fromLegacyTabIndex(Object? value) =>
      value == 0 ? AgentChatDockPane.chat : AgentChatDockPane.history;

  static AgentChatDockPane? fromStorageValue(Object? value) {
    for (final pane in values) {
      if (pane.name == value) return pane;
    }
    return null;
  }
}

enum AgentChatSurfaceTarget { floating, dock, overlay }

/// Resolved right panel content after width fallback.
@immutable
class AgentChatDockLayout {
  const AgentChatDockLayout.single(
    AgentChatDockPane this.visiblePane, {
    this.foldedPane,
    this.axis = Axis.vertical,
  });

  const AgentChatDockLayout.split(this.axis)
    : visiblePane = null,
      foldedPane = null;

  /// The only pane shown, or null when both panes are split.
  final AgentChatDockPane? visiblePane;

  /// A coexisting pane the user folded into a restore strip.
  final AgentChatDockPane? foldedPane;

  /// Split direction, and the direction a restore strip is laid out in.
  final Axis axis;

  bool get isSplit => visiblePane == null;

  @override
  bool operator ==(Object other) =>
      other is AgentChatDockLayout &&
      other.visiblePane == visiblePane &&
      other.foldedPane == foldedPane &&
      other.axis == axis;

  @override
  int get hashCode => Object.hash(visiblePane, foldedPane, axis);
}

@immutable
class AgentChatDockState {
  const AgentChatDockState({
    this.mode = AgentChatDockMode.exclusive,
    this.exclusivePane = AgentChatDockPane.history,
    this.foldedPane,
    this.stackedChatFraction = AgentChatDockContract.defaultStackedChatFraction,
    this.sideBySideChatWidth = AgentChatDockContract.defaultSideBySideChatWidth,
    this.floatingEnabled = false,
    this.floatingVisible = true,
    this.floatingRect,
  });

  final AgentChatDockMode mode;

  /// Pane shown by [AgentChatDockMode.exclusive].
  final AgentChatDockPane exclusivePane;
  final AgentChatDockPane? foldedPane;
  final double stackedChatFraction;
  final double sideBySideChatWidth;
  final bool floatingEnabled;
  final bool floatingVisible;

  /// Saved floating geometry; null until the user first moves or resizes it.
  final Rect? floatingRect;

  /// Whether chat and history currently share the right panel; a floating
  /// chat leaves history alone there whatever [mode] says.
  bool get coexists => !floatingEnabled && mode.coexists;

  /// Whether the right panel presents chat when expanded.
  bool get dockShowsChat => coexists
      ? foldedPane != AgentChatDockPane.chat
      : !floatingEnabled && exclusivePane == AgentChatDockPane.chat;

  /// Chat column width requested by an unfolded side-by-side split.
  double? get sideBySideChatWidthDemand =>
      coexists && mode == AgentChatDockMode.sideBySide && foldedPane == null
      ? sideBySideChatWidth
      : null;

  bool chatVisibleAtStartup({required bool rightPanelExpanded}) =>
      floatingEnabled ? floatingVisible : rightPanelExpanded && dockShowsChat;

  AgentChatDockLayout dockLayout({required bool sideBySideFits}) {
    if (floatingEnabled) {
      return const AgentChatDockLayout.single(AgentChatDockPane.history);
    }
    if (!mode.coexists) return AgentChatDockLayout.single(exclusivePane);
    final axis = mode == AgentChatDockMode.sideBySide && sideBySideFits
        ? Axis.horizontal
        : Axis.vertical;
    final folded = foldedPane;
    if (folded == null) return AgentChatDockLayout.split(axis);
    return AgentChatDockLayout.single(
      folded.other,
      foldedPane: folded,
      axis: axis,
    );
  }

  AgentChatSurfaceTarget navigationTarget({required bool dockAvailable}) {
    if (floatingEnabled) return AgentChatSurfaceTarget.floating;
    if (dockAvailable &&
        (mode.coexists || exclusivePane == AgentChatDockPane.chat)) {
      return AgentChatSurfaceTarget.dock;
    }
    return AgentChatSurfaceTarget.overlay;
  }

  AgentChatDockState copyWith({
    AgentChatDockMode? mode,
    AgentChatDockPane? exclusivePane,
    ValueGetter<AgentChatDockPane?>? foldedPane,
    double? stackedChatFraction,
    double? sideBySideChatWidth,
    bool? floatingEnabled,
    bool? floatingVisible,
    ValueGetter<Rect?>? floatingRect,
  }) {
    return AgentChatDockState(
      mode: mode ?? this.mode,
      exclusivePane: exclusivePane ?? this.exclusivePane,
      foldedPane: foldedPane == null ? this.foldedPane : foldedPane(),
      stackedChatFraction: stackedChatFraction ?? this.stackedChatFraction,
      sideBySideChatWidth: sideBySideChatWidth ?? this.sideBySideChatWidth,
      floatingEnabled: floatingEnabled ?? this.floatingEnabled,
      floatingVisible: floatingVisible ?? this.floatingVisible,
      floatingRect: floatingRect == null ? this.floatingRect : floatingRect(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AgentChatDockState &&
      other.mode == mode &&
      other.exclusivePane == exclusivePane &&
      other.foldedPane == foldedPane &&
      other.stackedChatFraction == stackedChatFraction &&
      other.sideBySideChatWidth == sideBySideChatWidth &&
      other.floatingEnabled == floatingEnabled &&
      other.floatingVisible == floatingVisible &&
      other.floatingRect == floatingRect;

  @override
  int get hashCode => Object.hash(
    mode,
    exclusivePane,
    foldedPane,
    stackedChatFraction,
    sideBySideChatWidth,
    floatingEnabled,
    floatingVisible,
    floatingRect,
  );
}
