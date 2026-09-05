import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_recording_policy.dart';

void main() {
  group('出厂默认必须可录制', () {
    test('每个默认快捷键都通过录制策略', () {
      for (final entry in DefaultShortcuts.all.entries) {
        final parsed = ShortcutParser.parse(entry.value);
        expect(parsed, isNotNull, reason: '${entry.key} = ${entry.value}');
        expect(
          ShortcutRecordingPolicy.allows(parsed!.modifiers, parsed.key),
          isTrue,
          reason: '${entry.key} = ${entry.value}',
        );
      }
    });

    test('裸用的默认主键从默认表推导，不是手写白名单', () {
      expect(
        ShortcutRecordingPolicy.modifierlessDefaultKeys,
        containsAll(const [
          ShortcutKey.equal,
          ShortcutKey.minus,
          ShortcutKey.digit0,
          ShortcutKey.pageup,
          ShortcutKey.pagedown,
          ShortcutKey.keyF,
        ]),
      );
      expect(
        ShortcutRecordingPolicy.modifierlessDefaultKeys,
        isNot(contains(ShortcutKey.space)),
      );
    });
  });

  group('无修饰键', () {
    test('导航与编辑键始终放行', () {
      for (final key in const [
        ShortcutKey.escape,
        ShortcutKey.delete,
        ShortcutKey.space,
        ShortcutKey.enter,
        ShortcutKey.arrowup,
        ShortcutKey.arrowdown,
        ShortcutKey.arrowleft,
        ShortcutKey.arrowright,
      ]) {
        expect(
          ShortcutRecordingPolicy.allowsModifierless(key),
          isTrue,
          reason: key.name,
        );
      }
    });

    test('功能键不依赖默认表，f3/f7/f12 同样放行', () {
      for (final key in const [
        ShortcutKey.f3,
        ShortcutKey.f7,
        ShortcutKey.f12,
      ]) {
        expect(
          ShortcutRecordingPolicy.allowsModifierless(key),
          isTrue,
          reason: key.name,
        );
      }
    });

    test('字母键只放行默认用过的 f，其余拦截', () {
      expect(
        ShortcutRecordingPolicy.allowsModifierless(ShortcutKey.keyF),
        isTrue,
      );
      expect(
        ShortcutRecordingPolicy.allowsModifierless(ShortcutKey.keyG),
        isFalse,
      );
      expect(
        ShortcutRecordingPolicy.allowsModifierless(ShortcutKey.keyA),
        isFalse,
      );
    });

    test('数字与符号键只放行默认用过的', () {
      expect(
        ShortcutRecordingPolicy.allowsModifierless(ShortcutKey.digit0),
        isTrue,
      );
      expect(
        ShortcutRecordingPolicy.allowsModifierless(ShortcutKey.digit5),
        isFalse,
      );
      expect(
        ShortcutRecordingPolicy.allowsModifierless(ShortcutKey.equal),
        isTrue,
      );
      expect(
        ShortcutRecordingPolicy.allowsModifierless(ShortcutKey.comma),
        isFalse,
      );
    });
  });

  test('带修饰键时任意主键都放行', () {
    for (final key in ShortcutKey.values) {
      expect(
        ShortcutRecordingPolicy.allows({ShortcutModifier.control}, key),
        isTrue,
        reason: key.name,
      );
    }
  });
}
