import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/keyboard_modifier_utils.dart';

void main() {
  test('Windows selection uses Control and ignores Meta', () {
    final controlKeyboard = HardwareKeyboard();
    _press(
      controlKeyboard,
      physicalKey: PhysicalKeyboardKey.controlLeft,
      logicalKey: LogicalKeyboardKey.controlLeft,
    );
    expect(
      isPrimarySelectionModifierPressed(
        keyboard: controlKeyboard,
        platform: TargetPlatform.windows,
      ),
      isTrue,
    );

    final metaKeyboard = HardwareKeyboard();
    _press(
      metaKeyboard,
      physicalKey: PhysicalKeyboardKey.metaLeft,
      logicalKey: LogicalKeyboardKey.metaLeft,
    );
    expect(
      isPrimarySelectionModifierPressed(
        keyboard: metaKeyboard,
        platform: TargetPlatform.windows,
      ),
      isFalse,
    );
  });

  test('macOS selection uses Command and ignores Control', () {
    final metaKeyboard = HardwareKeyboard();
    _press(
      metaKeyboard,
      physicalKey: PhysicalKeyboardKey.metaLeft,
      logicalKey: LogicalKeyboardKey.metaLeft,
    );
    expect(
      isPrimarySelectionModifierPressed(
        keyboard: metaKeyboard,
        platform: TargetPlatform.macOS,
      ),
      isTrue,
    );

    final controlKeyboard = HardwareKeyboard();
    _press(
      controlKeyboard,
      physicalKey: PhysicalKeyboardKey.controlLeft,
      logicalKey: LogicalKeyboardKey.controlLeft,
    );
    expect(
      isPrimarySelectionModifierPressed(
        keyboard: controlKeyboard,
        platform: TargetPlatform.macOS,
      ),
      isFalse,
    );
  });
}

void _press(
  HardwareKeyboard keyboard, {
  required PhysicalKeyboardKey physicalKey,
  required LogicalKeyboardKey logicalKey,
}) {
  keyboard.handleKeyEvent(
    KeyDownEvent(
      physicalKey: physicalKey,
      logicalKey: logicalKey,
      timeStamp: Duration.zero,
    ),
  );
}
