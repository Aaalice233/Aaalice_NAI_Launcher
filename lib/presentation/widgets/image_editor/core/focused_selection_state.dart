import 'dart:ui';

/// Focused Inpaint 选区状态
///
/// 与普通 selectionPath 分离，避免 focused 选区与编辑器通用选区互相污染。
class FocusedSelectionState {
  FocusedSelectionState({required Size canvasSize, Rect? initialRect})
    : _canvasSize = canvasSize,
      _committedRect = _normalizeRect(initialRect, canvasSize);

  Size _canvasSize;
  Rect? _committedRect;

  Rect? get committedRect => _committedRect;

  set canvasSize(Size size) {
    _canvasSize = size;
    _committedRect = _normalizeRect(_committedRect, size);
  }

  bool get hasCommittedRect => _committedRect != null;

  void load(Rect? rect) {
    _committedRect = _normalizeRect(rect, _canvasSize);
  }

  bool captureSelection(Path? selectionPath) {
    final rect = rectFromPath(selectionPath, _canvasSize);
    if (rect == null) {
      return false;
    }
    _committedRect = rect;
    return true;
  }

  Rect? resolveActiveRect({Path? previewPath}) {
    return rectFromPath(previewPath, _canvasSize) ?? _committedRect;
  }

  bool shouldSuppressSelectionOverlay({
    required bool focusedEnabled,
    required String? currentToolId,
    Path? previewPath,
  }) {
    if (!focusedEnabled) {
      return false;
    }
    if (currentToolId != 'rect_selection') {
      return false;
    }
    return previewPath != null || _committedRect != null;
  }

  void clear() {
    _committedRect = null;
  }

  static Rect? rectFromPath(Path? path, Size canvasSize) {
    if (path == null) {
      return null;
    }
    return _normalizeRect(path.getBounds(), canvasSize);
  }

  static Rect? _normalizeRect(Rect? rect, Size canvasSize) {
    if (rect == null) {
      return null;
    }

    final left = rect.left.clamp(0.0, canvasSize.width);
    final top = rect.top.clamp(0.0, canvasSize.height);
    final right = rect.right.clamp(left, canvasSize.width);
    final bottom = rect.bottom.clamp(top, canvasSize.height);
    if (right - left <= 2 || bottom - top <= 2) {
      return null;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }
}
