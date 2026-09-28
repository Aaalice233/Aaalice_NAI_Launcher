import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_binding_editor.dart';

class _EmptyShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => const ShortcutConfig();
}

class _DefaultShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

typedef _Key = (LogicalKeyboardKey, PhysicalKeyboardKey);

const _ctrl = (LogicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlLeft);

/// 物理键显式给出，logical key 反推不出来。
/// quoteSingle 不在此列：raw keyCode 表只收了 LogicalKeyboardKey.quote，
/// 模拟器发不出它，反查由 shortcut_key_mapping_test 覆盖。
const _symbolKeys = <(_Key, String)>[
  ((LogicalKeyboardKey.comma, PhysicalKeyboardKey.comma), 'comma'),
  ((LogicalKeyboardKey.period, PhysicalKeyboardKey.period), 'period'),
  ((LogicalKeyboardKey.slash, PhysicalKeyboardKey.slash), 'slash'),
  ((LogicalKeyboardKey.semicolon, PhysicalKeyboardKey.semicolon), 'semicolon'),
  (
    (LogicalKeyboardKey.bracketLeft, PhysicalKeyboardKey.bracketLeft),
    'bracketleft',
  ),
  (
    (LogicalKeyboardKey.bracketRight, PhysicalKeyboardKey.bracketRight),
    'bracketright',
  ),
  ((LogicalKeyboardKey.backslash, PhysicalKeyboardKey.backslash), 'backslash'),
  ((LogicalKeyboardKey.minus, PhysicalKeyboardKey.minus), 'minus'),
  ((LogicalKeyboardKey.equal, PhysicalKeyboardKey.equal), 'equal'),
  ((LogicalKeyboardKey.backquote, PhysicalKeyboardKey.backquote), 'backquote'),
];

const _binding = ShortcutBinding(
  id: 'test_binding',
  actionKey: 'test_action',
  defaultShortcut: 'ctrl+k',
);

void main() {
  late List<ShortcutBinding> saved;

  setUp(() => saved = []);

  Future<void> pumpEditor(
    WidgetTester tester, {
    ShortcutConfigNotifier Function()? notifierFactory,
  }) async {
    // 重新 pump 同类型 widget 会复用 State，换 key 才能拿到干净的录制起点
    final editorKey = UniqueKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            notifierFactory ?? _EmptyShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // 与设置面板一致：先 watch 出配置，编辑器才拿得到冲突检测数据
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                child: Consumer(
                  builder: (context, ref, _) {
                    ref.watch(shortcutConfigNotifierProvider);
                    return ShortcutBindingEditor(
                      key: editorKey,
                      binding: _binding,
                      onSave: saved.add,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 录制开始后按下主键即可成串，抬起时结束录制
  Future<void> record(WidgetTester tester, List<_Key> keys) async {
    await tester.tap(find.text('Ctrl+K'));
    await tester.pump();

    // android 的 raw keyCode 表没有 quoteSingle 这类符号键
    for (final (logical, physical) in keys) {
      await tester.sendKeyDownEvent(
        logical,
        physicalKey: physical,
        platform: 'windows',
      );
    }
    for (final (logical, physical) in keys.reversed) {
      await tester.sendKeyUpEvent(
        logical,
        physicalKey: physical,
        platform: 'windows',
      );
    }
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  testWidgets('可以录制 ctrl+comma', (tester) async {
    await pumpEditor(tester);

    await record(tester, [
      _ctrl,
      (LogicalKeyboardKey.comma, PhysicalKeyboardKey.comma),
    ]);

    expect(find.text('Ctrl+,'), findsOneWidget);

    await save(tester);

    expect(saved.single.customShortcut, 'ctrl+comma');
    expect(tester.takeException(), isNull);
  });

  testWidgets('可以录制无修饰键的 equal 与 minus', (tester) async {
    for (final scenario in const [
      ((LogicalKeyboardKey.equal, PhysicalKeyboardKey.equal), 'equal', '='),
      ((LogicalKeyboardKey.minus, PhysicalKeyboardKey.minus), 'minus', '-'),
    ]) {
      saved = [];
      await pumpEditor(tester);

      await record(tester, [scenario.$1]);

      expect(find.text(scenario.$3), findsOneWidget, reason: scenario.$2);

      await save(tester);

      expect(saved.single.customShortcut, scenario.$2, reason: scenario.$2);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('全部符号键都能录进去', (tester) async {
    for (final (key, name) in _symbolKeys) {
      saved = [];
      await pumpEditor(tester);

      await record(tester, [_ctrl, key]);
      await save(tester);

      expect(saved.single.customShortcut, 'ctrl+$name', reason: name);
    }
  });

  testWidgets('无修饰键的普通字母仍然不成串', (tester) async {
    await pumpEditor(tester);

    await record(tester, [(LogicalKeyboardKey.keyA, PhysicalKeyboardKey.keyA)]);

    expect(find.text('Ctrl+K'), findsOneWidget);
    expect(saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ctrl+comma 与设置页默认值冲突时禁止保存', (tester) async {
    await pumpEditor(
      tester,
      notifierFactory: _DefaultShortcutConfigNotifier.new,
    );

    await record(tester, [
      _ctrl,
      (LogicalKeyboardKey.comma, PhysicalKeyboardKey.comma),
    ]);

    expect(find.textContaining(ShortcutIds.navigateToSettings), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
