import 'package:flutter/gestures.dart';

/// Scroll events lack button state, so held buttons come from the pointer route.
abstract final class PointerPressTracker {
  static int _observers = 0;
  static final Set<int> _pressedDevices = {};

  static bool get mouseButtonHeld => _pressedDevices.isNotEmpty;

  static void observe() {
    if (_observers++ == 0) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_track);
    }
  }

  static void unobserve() {
    assert(_observers > 0);
    if (--_observers == 0) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_track);
      _pressedDevices.clear();
    }
  }

  static void _track(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if ((event is PointerDownEvent || event is PointerMoveEvent) &&
        event.buttons != 0) {
      _pressedDevices.add(event.device);
    } else if (event is PointerUpEvent ||
        event is PointerCancelEvent ||
        event is PointerRemovedEvent ||
        event is PointerMoveEvent ||
        event is PointerHoverEvent) {
      _pressedDevices.remove(event.device);
    }
  }
}
