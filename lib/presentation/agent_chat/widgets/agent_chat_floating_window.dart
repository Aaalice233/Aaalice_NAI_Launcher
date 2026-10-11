import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/windowing/floating_panel_geometry.dart';
import '../../adaptive/interaction_policy.dart';
import '../../themes/core/layered_surface_style.dart';
import '../../themes/theme_extension.dart';
import '../providers/agent_chat_dock_provider.dart';
import '../providers/agent_chat_surface_registry.dart';
import 'agent_chat_panel.dart';

/// In-app floating Agent chat that stays above every desktop page.
///
/// The chat mounts on first reveal and stays alive while hidden, so drafts,
/// scrolling and running turns survive; docking it back disposes it.
class AgentChatFloatingLayer extends ConsumerStatefulWidget {
  const AgentChatFloatingLayer({
    super.key,
    required this.onDock,
    this.onOpenSettings,
  });

  final VoidCallback onDock;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<AgentChatFloatingLayer> createState() =>
      _AgentChatFloatingLayerState();
}

class _AgentChatFloatingLayerState
    extends ConsumerState<AgentChatFloatingLayer> {
  final _focusScope = FocusScopeNode(debugLabel: 'agent-floating-window');
  final _geometry = ValueNotifier<Rect?>(null);
  late final AgentChatDockNotifier _dock;
  late final AgentChatSurfaceRegistry _surfaces;
  bool _hasMounted = false;
  bool _interacting = false;

  @override
  void initState() {
    super.initState();
    _dock = ref.read(agentChatDockProvider.notifier);
    _surfaces = ref.read(agentChatSurfaceRegistryProvider);
    _geometry.value = ref.read(agentChatDockProvider).floatingRect;
  }

  @override
  void dispose() {
    _focusScope.dispose();
    _geometry.dispose();
    super.dispose();
  }

  Size get _bounds {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : Size.zero;
  }

  Rect _currentRect() {
    final bounds = _bounds;
    return FloatingPanelGeometry.clamp(
      _geometry.value ?? FloatingPanelGeometry.defaultRect(bounds),
      bounds,
    );
  }

  void _beginInteraction() {
    _interacting = true;
    _geometry.value = _currentRect();
  }

  void _move(Offset delta) {
    _geometry.value = FloatingPanelGeometry.move(
      _currentRect(),
      delta,
      _bounds,
    );
  }

  void _resize(FloatingPanelEdge edge, Offset delta) {
    _geometry.value = FloatingPanelGeometry.resize(
      _currentRect(),
      edge,
      delta,
      _bounds,
    );
  }

  void _endInteraction() {
    if (!_interacting) return;
    _interacting = false;
    final rect = _geometry.value;
    if (rect != null) unawaited(_dock.setFloatingRect(rect));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Rect?>(
      agentChatDockProvider.select((dock) => dock.floatingRect),
      (_, rect) {
        if (!_interacting) _geometry.value = rect;
      },
    );
    final floating = ref.watch(
      agentChatDockProvider.select(
        (dock) =>
            (enabled: dock.floatingEnabled, visible: dock.floatingVisible),
      ),
    );
    final visible = floating.enabled && floating.visible;
    if (!floating.enabled) {
      _hasMounted = false;
    } else if (visible) {
      _hasMounted = true;
    }
    if (!_hasMounted) return const SizedBox.shrink();

    final reach = context.interactionPolicy.touchAvailable
        ? _FloatingWindowFrame.touchResizeReach
        : _FloatingWindowFrame.pointerResizeReach;
    final colors = Theme.of(context).colorScheme;
    return CustomSingleChildLayout(
      delegate: _FloatingWindowLayout(geometry: _geometry, reach: reach),
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: FocusScope(
            node: _focusScope,
            canRequestFocus: visible,
            descendantsAreFocusable: visible,
            child: _FloatingWindowFrame(
              reach: reach,
              onResizeStart: _beginInteraction,
              onResize: _resize,
              onResizeEnd: _endInteraction,
              child: AgentChatPanel(
                key: const ValueKey('agent-floating-chat-panel'),
                onClose: () => unawaited(_dock.setFloatingVisible(false)),
                onDock: widget.onDock,
                onOpenSettings: widget.onOpenSettings,
                focusRequest: _surfaces.floatingFocus,
                backgroundColor: overlaySurfaceColor(colors),
                headerWrapper: (header) => _PointerDragRegion(
                  key: const ValueKey('agent-floating-title-bar'),
                  cursor: SystemMouseCursors.move,
                  onStart: _beginInteraction,
                  onUpdate: _move,
                  onEnd: _endInteraction,
                  child: header,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingWindowLayout extends SingleChildLayoutDelegate {
  _FloatingWindowLayout({required this.geometry, required this.reach})
    : super(relayout: geometry);

  final ValueListenable<Rect?> geometry;
  final double reach;

  Rect _frame(Size bounds) => FloatingPanelGeometry.clamp(
    geometry.value ?? FloatingPanelGeometry.defaultRect(bounds),
    bounds,
  ).inflate(reach);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tight(_frame(constraints.biggest).size);

  @override
  Offset getPositionForChild(Size size, Size childSize) => _frame(size).topLeft;

  @override
  bool shouldRelayout(_FloatingWindowLayout oldDelegate) =>
      oldDelegate.geometry != geometry || oldDelegate.reach != reach;
}

/// Window surface plus resize grips that reach [reach] beyond its edges.
class _FloatingWindowFrame extends StatelessWidget {
  const _FloatingWindowFrame({
    required this.reach,
    required this.onResizeStart,
    required this.onResize,
    required this.onResizeEnd,
    required this.child,
  });

  static const double pointerResizeReach = 8;
  static const double touchResizeReach = 22;

  final double reach;
  final VoidCallback onResizeStart;
  final void Function(FloatingPanelEdge edge, Offset delta) onResize;
  final VoidCallback onResizeEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grip = reach * 2;
    return Stack(
      children: [
        // Grips sit under the window, which absorbs pointers inside its own
        // bounds, so only the outer half of each grip starts a resize.
        for (final edge in FloatingPanelEdge.values)
          Positioned(
            left: edge.movesRight ? null : 0,
            right: edge.movesLeft ? null : 0,
            top: edge.movesBottom ? null : 0,
            bottom: edge.movesTop ? null : 0,
            width: edge.movesLeft || edge.movesRight ? grip : null,
            height: edge.movesTop || edge.movesBottom ? grip : null,
            child: _edgeInset(
              edge,
              grip,
              _PointerDragRegion(
                key: ValueKey('agent-floating-resize-${edge.name}'),
                cursor: _cursorFor(edge),
                onStart: onResizeStart,
                onUpdate: (delta) => onResize(edge, delta),
                onEnd: onResizeEnd,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        Positioned.fill(
          left: reach,
          top: reach,
          right: reach,
          bottom: reach,
          child: Material(
            key: const ValueKey('agent-floating-window'),
            color: overlaySurfaceColor(theme.colorScheme),
            elevation: 16,
            shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.appTheme.dialogRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ],
    );
  }

  // Edge grips leave the corners to corner grips so no point resizes twice.
  Widget _edgeInset(FloatingPanelEdge edge, double grip, Widget child) {
    final isCorner =
        (edge.movesLeft || edge.movesRight) &&
        (edge.movesTop || edge.movesBottom);
    if (isCorner) return child;
    final vertical = edge.movesLeft || edge.movesRight;
    return Padding(
      padding: vertical
          ? EdgeInsets.symmetric(vertical: grip)
          : EdgeInsets.symmetric(horizontal: grip),
      child: child,
    );
  }

  MouseCursor _cursorFor(FloatingPanelEdge edge) => switch (edge) {
    FloatingPanelEdge.left ||
    FloatingPanelEdge.right => SystemMouseCursors.resizeLeftRight,
    FloatingPanelEdge.top ||
    FloatingPanelEdge.bottom => SystemMouseCursors.resizeUpDown,
    FloatingPanelEdge.topLeft ||
    FloatingPanelEdge.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
    FloatingPanelEdge.topRight ||
    FloatingPanelEdge.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
  };
}

/// Reports pointer travel in screen space, so a region that moves with the
/// window it drags does not feed its own movement back into the delta.
class _PointerDragRegion extends StatefulWidget {
  const _PointerDragRegion({
    super.key,
    required this.cursor,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
  });

  final MouseCursor cursor;
  final VoidCallback onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;
  final Widget child;

  @override
  State<_PointerDragRegion> createState() => _PointerDragRegionState();
}

class _PointerDragRegionState extends State<_PointerDragRegion> {
  Offset? _lastGlobal;

  void _end() {
    if (_lastGlobal == null) return;
    _lastGlobal = null;
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: (details) {
        _lastGlobal = details.globalPosition;
        widget.onStart();
      },
      onPanUpdate: (details) {
        final last = _lastGlobal;
        if (last == null) return;
        _lastGlobal = details.globalPosition;
        final delta = details.globalPosition - last;
        if (delta != Offset.zero) widget.onUpdate(delta);
      },
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: widget.child,
    ),
  );
}
