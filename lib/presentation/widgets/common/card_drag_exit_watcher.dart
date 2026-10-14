import 'dart:ui';

import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Calls [onExit] once when a drag's cursor leaves the launcher view.
///
/// Windows reports drag locations as physical screen pixels, while the drag
/// started at a logical view location; the first report anchors the view on
/// screen without any window API.
class CardDragExitWatcher {
  CardDragExitWatcher({
    required this.session,
    required Offset startLocation,
    required double devicePixelRatio,
    required Size physicalSize,
    required this.onExit,
  }) : _start = startLocation * devicePixelRatio,
       _size = physicalSize {
    session.lastScreenLocation.addListener(_onMove);
    session.dragCompleted.addListener(_onCompleted);
    _onCompleted();
  }

  final DragSession session;
  final void Function() onExit;
  final Offset _start;
  final Size _size;
  Rect? _view;
  bool _closed = false;

  void _onMove() {
    final location = session.lastScreenLocation.value;
    if (_closed || location == null) return;
    final view = _view ??= (location - _start) & _size;
    if (view.contains(location)) return;
    close();
    onExit();
  }

  void _onCompleted() {
    if (session.dragCompleted.value != null) close();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    session.lastScreenLocation.removeListener(_onMove);
    session.dragCompleted.removeListener(_onCompleted);
  }
}
