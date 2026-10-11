// KeyEventManager 与 RawKeyboard 已弃用，但仍是 Engine 按键进入框架的真实通路。
// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/windows_clipboard_history_key_fix.dart';

const int _injectedPhysical = 0x1600000000;
const int _controlLeftPhysical = 0x700e0;
const int _controlLeftLogical = 0x200000100;
const int _keyVPhysical = 0x70019;
const int _keyVLogical = 0x76;

void main() {
  group('WindowsClipboardHistoryKeyEventNormalizer', () {
    test('restores the captured Win+V sequence as Ctrl+V', () {
      final normalizer = _normalizer();

      final normalized = _capturedSequence.map(normalizer.normalize).toList();

      expect(normalized, [
        [_matchesKey(KeyEventType.down, _controlLeftPhysical, false)],
        isEmpty,
        [_matchesKey(KeyEventType.down, _keyVPhysical, false)],
        [_matchesKey(KeyEventType.up, _keyVPhysical, false)],
        isEmpty,
        [_matchesKey(KeyEventType.up, _controlLeftPhysical, true)],
      ]);
      expect(normalizer.isNormalizing, isFalse);
    });

    test('passes transit mode probes through without breaking a sequence', () {
      final normalizer = _normalizer();
      final probe = _keyData(KeyEventType.down, physical: 0, logical: 0);

      normalizer.normalize(_capturedSequence[0]);
      final probeResult = normalizer.normalize(probe);
      final remaining = _capturedSequence
          .skip(1)
          .map(normalizer.normalize)
          .toList();

      expect(probeResult, [same(probe)]);
      expect(remaining.last, [
        _matchesKey(KeyEventType.up, _controlLeftPhysical, true),
      ]);
    });

    test('leaves unrelated events unchanged', () {
      final normalizer = _normalizer();
      final event = _keyData(
        KeyEventType.down,
        physical: 0x70004,
        logical: 0x61,
      );

      expect(normalizer.normalize(event), [same(event)]);
      expect(normalizer.isNormalizing, isFalse);
    });

    test('releases injected keys before an interrupting event', () {
      final normalizer = _normalizer();
      _capturedSequence.take(3).forEach(normalizer.normalize);
      final interruption = _keyData(
        KeyEventType.down,
        physical: 0x70004,
        logical: 0x61,
      );

      expect(normalizer.normalize(interruption), [
        _matchesKey(KeyEventType.up, _keyVPhysical, true),
        _matchesKey(KeyEventType.up, _controlLeftPhysical, true),
        same(interruption),
      ]);
      expect(normalizer.isNormalizing, isFalse);
    });

    test('restarts when a new sequence interrupts the current one', () {
      final normalizer = _normalizer();
      normalizer.normalize(_capturedSequence[0]);

      expect(normalizer.normalize(_capturedSequence[0]), [
        _matchesKey(KeyEventType.up, _controlLeftPhysical, true),
        _matchesKey(KeyEventType.down, _controlLeftPhysical, false),
      ]);
      expect(normalizer.isNormalizing, isTrue);
    });

    test('abandon releases held keys once and resets', () {
      final normalizer = _normalizer();
      _capturedSequence.take(2).forEach(normalizer.normalize);

      expect(normalizer.abandon(), [
        _matchesKey(KeyEventType.up, _controlLeftPhysical, true),
      ]);
      expect(normalizer.abandon(), isEmpty);
      expect(normalizer.isNormalizing, isFalse);
    });

    test('does not inject Control when the user already holds it', () {
      final normalizer = _normalizer(pressed: const {_controlLeftPhysical});

      final normalized = _capturedSequence.map(normalizer.normalize).toList();

      expect(normalized, [
        isEmpty,
        isEmpty,
        [_matchesKey(KeyEventType.down, _keyVPhysical, false)],
        [_matchesKey(KeyEventType.up, _keyVPhysical, false)],
        isEmpty,
        isEmpty,
      ]);
    });
  });

  group('KeyEventManager pipeline with captured Win+V messages', () {
    tearDown(RawKeyboard.instance.clearKeysPressed);

    test('Control is held when V is pressed', () async {
      final keyboard = HardwareKeyboard();
      final normalizer = WindowsClipboardHistoryKeyEventNormalizer(
        isPhysicalKeyPressed: (physical) => keyboard.physicalKeysPressed
            .contains(PhysicalKeyboardKey(physical)),
      );

      final result = await _replayCapturedMessages(
        keyboard,
        normalizer.normalize,
      );

      expect(result.controlHeldOnKeyV, isTrue);
      expect(keyboard.physicalKeysPressed, isEmpty);
    });

    test('without normalization Control is released before V', () async {
      final keyboard = HardwareKeyboard();

      final result = await _replayCapturedMessages(keyboard, (data) => [data]);

      expect(result.controlHeldOnKeyV, isFalse);
    });
  });
}

// Flutter 3.47.5 / Windows 11 实测：鼠标点选与方向键回车选中产生相同序列。
final List<KeyData> _capturedSequence = [
  _keyData(KeyEventType.down, logical: _controlLeftLogical),
  _keyData(KeyEventType.up, logical: _controlLeftLogical, synthesized: true),
  _keyData(KeyEventType.down, logical: _keyVLogical),
  _keyData(KeyEventType.up, logical: _keyVLogical),
  _keyData(KeyEventType.down, logical: _controlLeftLogical, synthesized: true),
  _keyData(KeyEventType.up, logical: _controlLeftLogical, synthesized: true),
];

class _ReplayResult {
  bool? controlHeldOnKeyV;
}

Future<_ReplayResult> _replayCapturedMessages(
  HardwareKeyboard keyboard,
  List<KeyData> Function(KeyData data) normalize,
) async {
  final result = _ReplayResult();
  keyboard.addHandler((event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyV) {
      result.controlHeldOnKeyV = keyboard.isControlPressed;
    }
    return false;
  });
  final manager = KeyEventManager(keyboard, RawKeyboard.instance);

  void keyData(KeyData data) {
    for (final event in normalize(data)) {
      manager.handleKeyData(event);
    }
  }

  Future<void> raw(String type, int keyCode, int scanCode, int modifiers) {
    return manager.handleRawKeyMessage(<String, dynamic>{
      'keymap': 'windows',
      'type': type,
      'keyCode': keyCode,
      'scanCode': scanCode,
      'characterCodePoint': 0,
      'modifiers': modifiers,
    });
  }

  keyData(_keyData(KeyEventType.down, physical: 0, logical: 0));
  await raw('keyup', 0x56, 47, 0);
  keyData(_capturedSequence[0]);
  await raw('keydown', 0xa2, 0, 24);
  keyData(_capturedSequence[1]);
  keyData(_capturedSequence[2]);
  await raw('keydown', 0x56, 0, 24);
  keyData(_capturedSequence[3]);
  keyData(_capturedSequence[4]);
  await raw('keyup', 0x56, 0, 24);
  keyData(_capturedSequence[5]);
  await raw('keyup', 0xa2, 0, 0);
  return result;
}

KeyData _keyData(
  KeyEventType type, {
  int physical = _injectedPhysical,
  required int logical,
  bool synthesized = false,
}) {
  return KeyData(
    timeStamp: const Duration(milliseconds: 1),
    type: type,
    physical: physical,
    logical: logical,
    character: null,
    synthesized: synthesized,
  );
}

WindowsClipboardHistoryKeyEventNormalizer _normalizer({
  Set<int> pressed = const {},
}) {
  return WindowsClipboardHistoryKeyEventNormalizer(
    isPhysicalKeyPressed: pressed.contains,
  );
}

Matcher _matchesKey(KeyEventType type, int physical, bool synthesized) {
  final logical = physical == _controlLeftPhysical
      ? _controlLeftLogical
      : _keyVLogical;
  return isA<KeyData>()
      .having((event) => event.type, 'type', type)
      .having((event) => event.physical, 'physical', physical)
      .having((event) => event.logical, 'logical', logical)
      .having((event) => event.synthesized, 'synthesized', synthesized);
}
