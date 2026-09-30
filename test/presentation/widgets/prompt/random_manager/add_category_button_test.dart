import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/add_category_button.dart';

void main() {
  testWidgets('未接线的新增类别按钮默认弹窗创建类别', (tester) async {
    final notifier = _RecordingRandomPresetNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(() => notifier),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AddCategoryButton()),
        ),
      ),
    );

    await tester.tap(find.text('新增类别'));
    await tester.pumpAndSettle();

    // 默认行为：弹出输入对话框
    expect(find.text('创建新类别'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '发色');
    // 让 onChanged 的 setState 生效，确认按钮才会变为可点击
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(notifier.added, hasLength(1));
    expect(notifier.added.single.name, '发色');
    expect(notifier.added.single.key, isNotEmpty);
  });

  testWidgets('传入回调时优先使用自定义回调', (tester) async {
    var pressed = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _RecordingRandomPresetNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AddCategoryButton(onPressed: () => pressed++)),
        ),
      ),
    );

    await tester.tap(find.text('新增类别'));
    await tester.pumpAndSettle();

    expect(pressed, 1);
    expect(find.text('创建新类别'), findsNothing);
  });

  testWidgets('键盘可聚焦并用 Enter 或空格触发，读屏识别为可聚焦按钮', (tester) async {
    final semantics = tester.ensureSemantics();
    var pressed = 0;
    await _pumpButton(tester, onPressed: () => pressed++);

    final node = find.semantics.byPredicate(
      (node) => node.flagsCollection.isButton && node.label == '新增类别',
    );
    expect(node, findsOne);
    expect(
      node.evaluate().single.flagsCollection.isFocused,
      isNot(Tristate.none),
      reason: '可获得焦点的节点才会带 isFocused 状态',
    );
    expect(
      node.evaluate().single.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('新增类别'))).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pressed, 2);
    semantics.dispose();
  });

  testWidgets('标签字号取自主题的按钮文字 token，触屏命中区不小于 48', (tester) async {
    final base = ThemeData();
    final theme = base.copyWith(
      textTheme: base.textTheme.copyWith(
        labelLarge: base.textTheme.labelLarge!.copyWith(fontSize: 17),
      ),
    );
    await _pumpButton(tester, onPressed: () {}, theme: theme);

    final label = tester.renderObject<RenderParagraph>(find.text('新增类别'));
    expect(label.text.style?.fontSize, 17);
    final size = tester.getSize(find.byType(AddCategoryButton));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });
}

Future<void> _pumpButton(
  WidgetTester tester, {
  VoidCallback? onPressed,
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomPresetNotifierProvider.overrideWith(
          _RecordingRandomPresetNotifier.new,
        ),
      ],
      child: MaterialApp(
        theme: theme,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: AddCategoryButton(onPressed: onPressed)),
        ),
      ),
    ),
  );
}

class _RecordingRandomPresetNotifier extends RandomPresetNotifier {
  final List<RandomCategory> added = [];

  @override
  RandomPresetState build() {
    return const RandomPresetState(
      presets: [
        RandomPreset(id: 'custom', name: '测试预设'),
      ],
      selectedPresetId: 'custom',
    );
  }

  @override
  Future<void> addCategory(RandomCategory category) async {
    added.add(category);
  }
}
