import 'agent_window_protocol.dart';

class AgentWindowVisibleArea {
  const AgentWindowVisibleArea({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

AgentWindowBounds ensureAgentWindowIsVisible({
  required AgentWindowBounds bounds,
  required List<AgentWindowVisibleArea> visibleAreas,
  double minimumWidth = 420,
  double minimumHeight = 520,
  double visibleEdge = 64,
}) {
  if (visibleAreas.isEmpty) {
    return AgentWindowBounds(
      x: bounds.x,
      y: bounds.y,
      width: bounds.width < minimumWidth ? minimumWidth : bounds.width,
      height: bounds.height < minimumHeight ? minimumHeight : bounds.height,
    );
  }

  bool intersects(AgentWindowVisibleArea area) {
    final horizontalEdge = visibleEdge.clamp(0, area.width);
    final verticalEdge = visibleEdge.clamp(0, area.height);
    return bounds.x + bounds.width >= area.x + horizontalEdge &&
        bounds.x <= area.x + area.width - horizontalEdge &&
        bounds.y + bounds.height >= area.y + verticalEdge &&
        bounds.y <= area.y + area.height - verticalEdge;
  }

  final area = visibleAreas.firstWhere(
    intersects,
    orElse: () => visibleAreas.first,
  );
  final availableWidth = area.width > 0 ? area.width : minimumWidth;
  final availableHeight = area.height > 0 ? area.height : minimumHeight;
  final width = bounds.width
      .clamp(minimumWidth.clamp(0, availableWidth), availableWidth)
      .toDouble();
  final height = bounds.height
      .clamp(minimumHeight.clamp(0, availableHeight), availableHeight)
      .toDouble();
  final wasVisible = intersects(area);
  final preferredX = wasVisible ? bounds.x : area.x + (area.width - width) / 2;
  final preferredY = wasVisible
      ? bounds.y
      : area.y + (area.height - height) / 2;
  final horizontalEdge = visibleEdge.clamp(0, area.width);
  final verticalEdge = visibleEdge.clamp(0, area.height);
  final maxX = area.x + area.width - horizontalEdge;
  final maxY = area.y + area.height - verticalEdge;

  return AgentWindowBounds(
    x: preferredX.clamp(area.x - width + horizontalEdge, maxX),
    y: preferredY.clamp(area.y, maxY),
    width: width,
    height: height,
  );
}
