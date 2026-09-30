import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/diy_category_field.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/post_process_rule_panel.dart';

import '../../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('3x text stacks presets at 320px and keeps the wide row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(960, 3600);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    List<PostProcessRule>? changedRules;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostProcessRulePanel(
              rules: const [],
              onRulesChanged: (rules) => changedRules = rules,
              categoryOptions: _categoryOptions,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Finder preset(String label) => find.descendant(
      of: find.byType(SurfaceInkWell),
      matching: find.text(label),
    );
    final sleeping = preset('Sleeping Rule');
    final mermaid = preset('Mermaid Rule');
    expect(sleeping, findsOneWidget);
    expect(mermaid, findsOneWidget);
    expect(
      tester.getCenter(sleeping).dy,
      lessThan(tester.getCenter(mermaid).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(sleeping);
    await tester.pump();
    expect(changedRules, hasLength(1));
    expect(changedRules!.single.id, 'sleeping_rule');
    expect(changedRules!.single.targetCategoryIds, ['cat-eyes']);
    // 父级不重建时面板也要立即列出新规则
    expect(find.text('Sleeping Rule'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1800, 3600);
    await tester.pump();

    expect(
      tester.getCenter(sleeping).dy,
      closeTo(tester.getCenter(mermaid).dy, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('预设规则按钮的悬停与按压反馈画在底色之上，前景描边不改变尺寸', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostProcessRulePanel(
              rules: const [],
              onRulesChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final preset = find.ancestor(
      of: find.text('Sleeping Rule'),
      matching: find.byType(SurfaceInkWell),
    );
    final row = find.descendant(of: preset, matching: find.byType(Row)).first;
    // 12 内边距加 1 描边，上下各 13
    expect(
      tester.getSize(preset).height,
      moreOrLessEquals(tester.getSize(row).height + 26),
    );

    final theme = Theme.of(tester.element(preset));
    final fill = theme.colorScheme.surfaceContainerHighest;
    await hoverOver(tester, preset);
    expectInkOnTop(tester, preset, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, preset);
    expectInkOnTop(tester, preset, ink: theme.highlightColor, below: fill);
    await press.up();
    await tester.pump();
  });

  group('预设规则的目标类别', () {
    // 返回读取最新规则的函数，面板后续的编辑也能被断言
    Future<List<PostProcessRule> Function()> addPreset(
      WidgetTester tester,
      String label, {
      required List<DiyCategoryOption> options,
    }) async {
      tester.view.physicalSize = const Size(1180, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var changedRules = <PostProcessRule>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostProcessRulePanel(
                rules: const [],
                onRulesChanged: (rules) => changedRules = rules,
                categoryOptions: options,
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SurfaceInkWell),
          matching: find.text(label),
        ),
      );
      await tester.pump();
      return () => changedRules;
    }

    testWidgets('睡眠规则按键名指向本预设的瞳色类别，不出现已失效目标', (tester) async {
      final rules = await addPreset(
        tester,
        'Sleeping Rule',
        options: _categoryOptions,
      );

      expect(rules().single.targetCategoryIds, ['cat-eyes']);
      expect(find.text('Edit Rule'), findsNothing);
      expect(find.textContaining('Unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('预设里找不到对应类别时展开编辑，目标留空待用户选择', (tester) async {
      final rules = await addPreset(
        tester,
        'Sleeping Rule',
        options: const [
          DiyCategoryOption(id: 'cat-outfit', label: 'Outfit', key: 'clothing'),
        ],
      );

      expect(rules().single.targetCategoryIds, isEmpty);
      expect(find.text('Edit Rule'), findsOneWidget);
      expect(find.text('Target Categories'), findsOneWidget);
      expect(find.textContaining('Unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('美人鱼规则没有可整类移除的默认目标，添加后展开编辑由用户选择', (tester) async {
      final rules = await addPreset(
        tester,
        'Mermaid Rule',
        options: _categoryOptions,
      );

      final rule = rules().single;
      expect(rule.triggerTags, ['mermaid', 'centaur', 'lamia']);
      expect(rule.action, PostProcessAction.removeCategory);
      expect(rule.targetCategoryIds, isEmpty);
      expect(find.text('Edit Rule'), findsOneWidget);
      expect(find.textContaining('Unavailable'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Outfit'));
      await tester.pump();
      expect(rules().single.targetCategoryIds, ['cat-outfit']);
      expect(tester.takeException(), isNull);
    });
  });
}

const _categoryOptions = [
  DiyCategoryOption(id: 'cat-eyes', label: 'Eyes', key: 'eyeColor'),
  DiyCategoryOption(id: 'cat-outfit', label: 'Outfit', key: 'clothing'),
];
