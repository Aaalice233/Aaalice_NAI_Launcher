/// Shared width policy for desktop workspace side panels.
///
/// Standard desktop widths keep the established 520 logical-pixel ceiling.
/// Wider workspaces progressively expose more parallel content while preserving
/// the primary workspace, with an absolute ceiling suitable for readable text.
abstract final class WorkspaceSidePanelContract {
  static const double standardWidth = 520;
  static const double maximumWidth = 960;
  static const double wideWorkspaceFraction = 0.38;

  static double maximumFor(double workspaceWidth) {
    if (!workspaceWidth.isFinite || workspaceWidth <= 0) return 0;
    return (workspaceWidth * wideWorkspaceFraction)
        .clamp(
          standardWidth.clamp(0, workspaceWidth),
          maximumWidth.clamp(0, workspaceWidth),
        )
        .toDouble();
  }

  static double overlayWidth(double workspaceWidth) =>
      maximumFor(workspaceWidth);

  static double constrainedWorkspaceWidth({
    required double workspaceWidth,
    required double preferredWidth,
    double occupiedWidth = 0,
    double minimumPrimaryWidth = 0,
    double minimumWidth = 200,
  }) {
    if (!workspaceWidth.isFinite || workspaceWidth <= 0) return 0;
    final remainingForPanel =
        workspaceWidth - occupiedWidth - minimumPrimaryWidth;
    final maximum = maximumFor(
      workspaceWidth,
    ).clamp(0, remainingForPanel.clamp(0, workspaceWidth)).toDouble();
    if (maximum <= 0) return 0;
    return preferredWidth
        .clamp(minimumWidth.clamp(0, maximum), maximum)
        .toDouble();
  }
}
