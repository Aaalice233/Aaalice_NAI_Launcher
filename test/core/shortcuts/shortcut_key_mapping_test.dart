import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_key_mapping.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_manager.dart';

void main() {
  group('ShortcutKey 键位映射', () {
    test('全部枚举值都有物理按键，没有刻意留空的键', () {
      final mapped = <ShortcutKey, LogicalKeyboardKey>{
        for (final key in ShortcutKey.values) key: key.logicalKeyboardKey,
      };

      expect(mapped, hasLength(ShortcutKey.values.length));
      for (final entry in mapped.entries) {
        expect(entry.value, isA<LogicalKeyboardKey>(), reason: '${entry.key}');
      }
    });

    test('不同枚举值不会落到同一个物理按键', () {
      final byLogicalKey = <LogicalKeyboardKey, List<ShortcutKey>>{};
      for (final key in ShortcutKey.values) {
        byLogicalKey.putIfAbsent(key.logicalKeyboardKey, () => []).add(key);
      }

      final collisions = byLogicalKey.entries
          .where((entry) => entry.value.length > 1)
          .map((entry) => '${entry.key.keyLabel}: ${entry.value}')
          .toList();

      expect(collisions, isEmpty);
    });

    test('修饰键映射到左右不敏感的合成键', () {
      expect(
        ShortcutModifier.control.logicalKeyboardKey,
        LogicalKeyboardKey.control,
      );
      expect(ShortcutModifier.alt.logicalKeyboardKey, LogicalKeyboardKey.alt);
      expect(
        ShortcutModifier.shift.logicalKeyboardKey,
        LogicalKeyboardKey.shift,
      );
      expect(ShortcutModifier.meta.logicalKeyboardKey, LogicalKeyboardKey.meta);
      expect(
        ShortcutModifier.values.map((m) => m.logicalKeyboardKey).toSet(),
        hasLength(ShortcutModifier.values.length),
      );
    });
  });

  group('LogicalKeyboardKey 反查 ShortcutKey', () {
    test('每个枚举值都能原样往返', () {
      for (final key in ShortcutKey.values) {
        expect(key.logicalKeyboardKey.shortcutKey, key, reason: key.name);
      }
    });

    test('符号键全部可反查，不再是录制盲区', () {
      final symbols = <LogicalKeyboardKey, ShortcutKey>{
        LogicalKeyboardKey.comma: ShortcutKey.comma,
        LogicalKeyboardKey.period: ShortcutKey.period,
        LogicalKeyboardKey.slash: ShortcutKey.slash,
        LogicalKeyboardKey.semicolon: ShortcutKey.semicolon,
        LogicalKeyboardKey.quoteSingle: ShortcutKey.quote,
        LogicalKeyboardKey.bracketLeft: ShortcutKey.bracketleft,
        LogicalKeyboardKey.bracketRight: ShortcutKey.bracketright,
        LogicalKeyboardKey.backslash: ShortcutKey.backslash,
        LogicalKeyboardKey.minus: ShortcutKey.minus,
        LogicalKeyboardKey.equal: ShortcutKey.equal,
        LogicalKeyboardKey.backquote: ShortcutKey.backquote,
      };

      symbols.forEach((logical, expected) {
        expect(logical.shortcutKey, expected, reason: logical.keyLabel);
      });
    });

    test('枚举没覆盖的物理按键返回 null', () {
      expect(LogicalKeyboardKey.controlLeft.shortcutKey, isNull);
      expect(LogicalKeyboardKey.numpadAdd.shortcutKey, isNull);
      expect(LogicalKeyboardKey.f13.shortcutKey, isNull);
    });
  });

  group('ParsedShortcut.logicalKeys', () {
    test('同时包含修饰键与主键', () {
      final parsed = ShortcutParser.parse('ctrl+shift+alt+meta+comma')!;

      expect(parsed.logicalKeys, {
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.alt,
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.comma,
      });
    });

    test('无修饰键时只有主键', () {
      expect(ShortcutParser.parse('f11')!.logicalKeys, {
        LogicalKeyboardKey.f11,
      });
    });
  });

  group('AppShortcutManager.parseActivator', () {
    test('对每个枚举键都产出与共享映射一致的 LogicalKeySet', () {
      for (final key in ShortcutKey.values) {
        final shortcut = 'ctrl+${key.logicalKey}';
        final activator = AppShortcutManager.parseActivator(shortcut);

        expect(activator, isA<LogicalKeySet>(), reason: shortcut);
        expect((activator! as LogicalKeySet).keys, {
          LogicalKeyboardKey.control,
          key.logicalKeyboardKey,
        }, reason: shortcut);
      }
    });

    test('空值与无法解析的字符串仍返回 null', () {
      expect(AppShortcutManager.parseActivator(null), isNull);
      expect(AppShortcutManager.parseActivator(''), isNull);
      expect(AppShortcutManager.parseActivator('ctrl'), isNull);
      expect(AppShortcutManager.parseActivator('ctrl+notakey'), isNull);
    });
  });
}
