import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Uses Command on macOS and Control everywhere else.
bool isPrimarySelectionModifierPressed({
  HardwareKeyboard? keyboard,
  TargetPlatform? platform,
}) {
  final resolvedKeyboard = keyboard ?? HardwareKeyboard.instance;
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  return resolvedPlatform == TargetPlatform.macOS
      ? resolvedKeyboard.isMetaPressed
      : resolvedKeyboard.isControlPressed;
}
