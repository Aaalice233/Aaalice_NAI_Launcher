import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/windows_clipboard_history_key_fix.dart';

void main() {
  group('WindowsClipboardHistoryKeyEventNormalizer', () {
    test('restores the malformed Win+V sequence as Ctrl+V', () {
      final normalizer = WindowsClipboardHistoryKeyEventNormalizer();

      final normalized = <KeyData?>[
        normalizer.normalize(
          _keyData(
            type: KeyEventType.down,
            physical: 0x1600000000,
            logical: 0x200000100,
          ),
        ),
        normalizer.normalize(
          _keyData(type: KeyEventType.down, physical: 0, logical: 0),
        ),
        normalizer.normalize(
          _keyData(
            type: KeyEventType.up,
            physical: 0x1600000000,
            logical: 0x200000100,
          ),
        ),
        normalizer.normalize(
          _keyData(
            type: KeyEventType.down,
            physical: 0x1600000000,
            logical: 0x200000100,
            synthesized: true,
          ),
        ),
        normalizer.normalize(
          _keyData(
            type: KeyEventType.up,
            physical: 0x1600000000,
            logical: 0x200000100,
            synthesized: true,
          ),
        ),
      ];

      expect(
        normalized[0],
        _matchesKey(KeyEventType.down, 0x700e0, 0x200000100),
      );
      expect(normalized[1], isNull);
      expect(normalized[2], _matchesKey(KeyEventType.down, 0x70019, 0x76));
      expect(normalized[3], _matchesKey(KeyEventType.up, 0x70019, 0x76));
      expect(normalized[4], _matchesKey(KeyEventType.up, 0x700e0, 0x200000100));
    });

    test('leaves unrelated events unchanged', () {
      final normalizer = WindowsClipboardHistoryKeyEventNormalizer();
      final event = _keyData(
        type: KeyEventType.down,
        physical: 0x70004,
        logical: 0x61,
      );

      expect(normalizer.normalize(event), same(event));
    });

    test('abandons normalization when the sequence is interrupted', () {
      final normalizer = WindowsClipboardHistoryKeyEventNormalizer();
      normalizer.normalize(
        _keyData(
          type: KeyEventType.down,
          physical: 0x1600000000,
          logical: 0x200000100,
        ),
      );
      final interruption = _keyData(
        type: KeyEventType.down,
        physical: 0x70004,
        logical: 0x61,
      );
      final laterMalformedEvent = _keyData(
        type: KeyEventType.up,
        physical: 0x1600000000,
        logical: 0x200000100,
      );

      expect(normalizer.normalize(interruption), same(interruption));
      expect(
        normalizer.normalize(laterMalformedEvent),
        same(laterMalformedEvent),
      );
    });
  });
}

KeyData _keyData({
  required KeyEventType type,
  required int physical,
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

Matcher _matchesKey(KeyEventType type, int physical, int logical) {
  return isA<KeyData>()
      .having((event) => event.type, 'type', type)
      .having((event) => event.physical, 'physical', physical)
      .having((event) => event.logical, 'logical', logical)
      .having((event) => event.synthesized, 'synthesized', isFalse);
}
