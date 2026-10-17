import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Command is the primary shortcut modifier on macOS, Control everywhere else.
bool usesCommandAsPrimaryModifier({TargetPlatform? platform}) =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.macOS;

/// Uses Command on macOS and Control everywhere else.
bool isPrimarySelectionModifierPressed({
  HardwareKeyboard? keyboard,
  TargetPlatform? platform,
}) {
  final resolvedKeyboard = keyboard ?? HardwareKeyboard.instance;
  return usesCommandAsPrimaryModifier(platform: platform)
      ? resolvedKeyboard.isMetaPressed
      : resolvedKeyboard.isControlPressed;
}
