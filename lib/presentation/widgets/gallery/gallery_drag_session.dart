import 'package:flutter/foundation.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Native dragging can outlive the pointer sequence and its source card.
class GalleryDragSessionState extends ValueNotifier<bool> {
  GalleryDragSessionState() : super(false);

  DragSession? _session;

  void track(DragSession session) {
    _detach();
    _session = session;
    session.dragging.addListener(_update);
    session.dragCompleted.addListener(_update);
    _update();
  }

  void _update() {
    final session = _session;
    if (session == null) return;
    if (session.dragCompleted.value != null) {
      _detach();
      value = false;
    } else {
      value = session.dragging.value;
    }
  }

  void _detach() {
    _session?.dragging.removeListener(_update);
    _session?.dragCompleted.removeListener(_update);
    _session = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }
}
