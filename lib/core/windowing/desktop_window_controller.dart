import 'package:window_manager/window_manager.dart';

/// Window operations used by the main Flutter caption.
///
/// Keeping this boundary small makes the caption testable and ensures its
/// close action follows window_manager's prevent-close event instead of
/// destroying a window directly.
abstract interface class DesktopWindowController {
  void addListener(WindowListener listener);

  void removeListener(WindowListener listener);

  Future<bool> isMaximized();

  Future<void> startDragging();

  Future<void> minimize();

  Future<void> maximize();

  Future<void> unmaximize();

  Future<void> close();
}

final class WindowManagerDesktopWindowController
    implements DesktopWindowController {
  const WindowManagerDesktopWindowController();

  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);

  @override
  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> unmaximize() => windowManager.unmaximize();

  @override
  Future<void> close() => windowManager.close();
}
