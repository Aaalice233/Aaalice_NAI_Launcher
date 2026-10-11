import 'workspace_side_panel_contract.dart';

/// Size policy for the generation right panel when chat and history share it.
abstract final class AgentChatDockContract {
  static const double splitHandleExtent = 8;
  static const double minimumHistoryPaneWidth = 200;
  static const double minimumChatPaneWidth = 240;
  static const double defaultSideBySideChatWidth = 360;
  static const double minimumHistoryPaneHeight = 160;
  static const double minimumChatPaneHeight = 280;
  static const double defaultStackedChatFraction = 0.5;
  static const double minimumStackedChatFraction = 0.2;
  static const double maximumStackedChatFraction = 0.8;

  static const double sideBySideMinimumWidth =
      minimumHistoryPaneWidth + splitHandleExtent + minimumChatPaneWidth;

  static double sideBySidePreferredWidth({
    required double historyWidth,
    required double chatWidth,
  }) => historyWidth + splitHandleExtent + chatWidth;

  // Each column keeps the single-panel reading ceiling.
  static double sideBySideMaximumFor(double workspaceWidth) =>
      WorkspaceSidePanelContract.maximumFor(workspaceWidth) * 2 +
      splitHandleExtent;

  /// Width left for a side-by-side split, or null when two minimum columns
  /// cannot fit beside a usable primary workspace.
  static double? sideBySideWidthFor({
    required double workspaceWidth,
    required double occupiedWidth,
    required double minimumPrimaryWidth,
    required double preferredWidth,
  }) {
    if (!workspaceWidth.isFinite || workspaceWidth <= 0) return null;
    final available = workspaceWidth - occupiedWidth - minimumPrimaryWidth;
    if (available < sideBySideMinimumWidth) return null;
    final maximum = sideBySideMaximumFor(
      workspaceWidth,
    ).clamp(sideBySideMinimumWidth, available).toDouble();
    return preferredWidth.clamp(sideBySideMinimumWidth, maximum).toDouble();
  }

  static double normalizeStackedChatFraction(double? value) {
    if (value == null || !value.isFinite) return defaultStackedChatFraction;
    return value
        .clamp(minimumStackedChatFraction, maximumStackedChatFraction)
        .toDouble();
  }

  static double normalizeSideBySideChatWidth(double? value) {
    if (value == null || !value.isFinite || value <= 0) {
      return defaultSideBySideChatWidth;
    }
    return value
        .clamp(minimumChatPaneWidth, WorkspaceSidePanelContract.maximumWidth)
        .toDouble();
  }
}
