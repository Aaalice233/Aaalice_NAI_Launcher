import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/branch_conditions_editor.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/conditional_branch_panel.dart';

import '../../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('删除编辑中分支之前的分支后，编辑区仍指向原分支且不越界', (tester) async {
    ConditionalBranchConfig? changed;
    await tester.pumpWidget(
      _app(
        ConditionalBranchPanel(
          config: const ConditionalBranchConfig(
            id: 'outfit',
            name: 'Outfit',
            branches: [
              ConditionalBranch(name: 'Uniform', probability: 60),
              ConditionalBranch(name: 'Casual', probability: 40),
            ],
          ),
          onConfigChanged: (config) => changed = config,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Casual').last);
    await tester.pump();
    expect(find.text('Edit: Casual'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete branch').first);
    await tester.pump();

    expect(changed?.branches.map((branch) => branch.name), ['Casual']);
    expect(find.text('Edit: Casual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增分支后直接展开编辑；父级更新配置时保留仍在范围内的选中分支', (tester) async {
    var config = const ConditionalBranchConfig(
      id: 'outfit',
      name: 'Outfit',
      branches: [ConditionalBranch(name: 'Uniform', probability: 60)],
    );
    late StateSetter setParent;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            setParent = setState;
            return ConditionalBranchPanel(
              config: config,
              onConfigChanged: (next) => config = next!,
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add Branch'));
    await tester.pump();
    expect(config.branches, hasLength(2));
    expect(find.text('Edit: Branch 2'), findsOneWidget);

    setParent(() => config = config.copyWith(name: 'Renamed'));
    await tester.pump();
    expect(find.text('Edit: Branch 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('概率条分段与分支概率徽标的字号取自主题 labelSmall', (tester) async {
    const fontSize = 17.0;
    final base = ThemeData();
    final theme = base.copyWith(
      textTheme: base.textTheme.copyWith(
        labelSmall: base.textTheme.labelSmall!.copyWith(fontSize: fontSize),
      ),
    );
    tester.view.physicalSize = const Size(1180, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        ConditionalBranchPanel(
          config: const ConditionalBranchConfig(
            id: 'outfit',
            name: 'Outfit',
            branches: [
              ConditionalBranch(name: 'Uniform', probability: 60),
              ConditionalBranch(name: 'Casual', probability: 40),
            ],
          ),
          onConfigChanged: (_) {},
        ),
        theme: theme,
      ),
    );
    await tester.pump();

    final segments = find.byType(SurfaceInkWell);
    final segmentTexts = [
      for (final (index, name) in ['Uniform', 'Casual'].indexed) ...[
        find.descendant(of: segments.at(index), matching: find.text(name)),
        find.descendant(
          of: segments.at(index),
          matching: find.text(index == 0 ? '60%' : '40%'),
        ),
      ],
    ];
    final badges = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(r'^\d+%$').hasMatch(widget.data ?? '') &&
          segmentTexts.every(
            (segmentText) => !segmentText.evaluate().any(
              (element) => element.widget == widget,
            ),
          ),
    );
    expect(badges, findsNWidgets(2), reason: '分支列表里每个分支一个概率徽标');
    for (final text in [...segmentTexts, badges.at(0), badges.at(1)]) {
      expect(text, findsOne);
      expect(
        tester.renderObject<RenderParagraph>(text).text.style?.fontSize,
        fontSize,
        reason: text.describeMatch(Plurality.one),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('概率条分段的悬停与按压反馈画在分段渐变之上，选中后依旧可见', (tester) async {
    await tester.pumpWidget(
      _app(
        ConditionalBranchPanel(
          config: const ConditionalBranchConfig(
            id: 'outfit',
            name: 'Outfit',
            branches: [
              ConditionalBranch(name: 'Uniform', probability: 60),
              ConditionalBranch(name: 'Casual', probability: 40),
            ],
          ),
          onConfigChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    final segment = find.byType(SurfaceInkWell).first;
    final theme = Theme.of(tester.element(segment));
    Color leadingStop() =>
        tester.widget<SurfaceInkWell>(segment).gradient!.colors.first;
    expect(leadingStop(), theme.colorScheme.primary.withValues(alpha: 0.6));

    await hoverOver(tester, segment);
    expectInkOnTop(tester, segment, ink: theme.hoverColor, belowGradient: true);

    final press = await pressAndHold(tester, segment);
    expectInkOnTop(
      tester,
      segment,
      ink: theme.highlightColor,
      belowGradient: true,
    );
    await press.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(leadingStop(), theme.colorScheme.primary);

    final again = await pressAndHold(tester, segment);
    expectInkOnTop(
      tester,
      segment,
      ink: theme.highlightColor,
      belowGradient: true,
    );
    await again.up();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('打开时直接编辑指定分支；多个条件可切换全部或任一满足并可删除', (tester) async {
    tester.view.physicalSize = const Size(1180, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ConditionalBranchConfig? changed;
    await tester.pumpWidget(
      _app(
        ConditionalBranchPanel(
          config: const ConditionalBranchConfig(
            id: 'outfit',
            name: 'Outfit',
            branches: [
              ConditionalBranch(name: 'Uniform', probability: 60),
              ConditionalBranch(
                name: 'Casual',
                probability: 40,
                conditions: {'cat-mood': 'smile', 'gender': 'girl'},
              ),
            ],
          ),
          conditionSources: const [
            BranchConditionSource(
              id: 'cat-mood',
              label: 'Mood',
              kind: BranchConditionSourceKind.category,
            ),
            BranchConditionSource(
              id: 'gender',
              label: 'Gender',
              kind: BranchConditionSourceKind.characterGender,
            ),
          ],
          initialSelectedIndex: 1,
          onConfigChanged: (config) => changed = config,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Edit: Casual'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.text('Add condition'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Add condition'),
              matching: find.byWidgetPredicate((w) => w is TextButton),
            ),
          )
          .onPressed,
      isNull,
      reason: 'every source is already used',
    );

    await tester.tap(find.text('Match any'));
    await tester.pump();
    expect(changed?.branches[1].logicType, LogicType.or);

    await tester.tap(find.byTooltip('Delete condition').first);
    await tester.pump();
    expect(changed?.branches[1].conditions, {'gender': 'girl'});
    expect(find.byType(ChoiceChip), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget panel, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: panel)),
  );
}
