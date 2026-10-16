import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/diy_category_field.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/conditional_branch_panel.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/dependency_config_panel.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/post_process_rule_panel.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/time_condition_panel.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/visibility_rule_panel.dart';

void main() {
  testWidgets('条件分支的分支名称带标签与图标并回显当前名称，切换分支后跟随', (tester) async {
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
          initialSelectedIndex: 1,
          onConfigChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    final name = _field(_l10n.diy_branchName);
    _expectIcon(name, Icons.label_outline_rounded);
    expect(_text(tester, name), 'Casual');

    await tester.tap(find.text('Uniform').last);
    await tester.pump();
    expect(_text(tester, _field(_l10n.diy_branchName)), 'Uniform');
    expect(tester.takeException(), isNull);
  });

  testWidgets('时间条件名称为空时显示提示与图标，套用模板后回显模板名称', (tester) async {
    await tester.pumpWidget(
      _app(
        TimeConditionPanel(
          condition: TimeCondition.christmas().copyWith(name: ''),
          onConditionChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    final name = _field(_l10n.diy_conditionNameHint);
    _expectIcon(name, Icons.edit_rounded);
    expect(_text(tester, name), isEmpty);

    await tester.tap(find.text(_l10n.diy_halloween));
    await tester.pump();
    final applied = find.descendant(
      of: find.byType(ThemedFormInput),
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(applied).controller.text,
      _l10n.diy_halloween,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('可见性规则编辑区的名称与条件值带标签与图标并回显已保存的值', (tester) async {
    await tester.pumpWidget(
      _app(
        VisibilityRulePanel(
          rules: const [
            VisibilityRule(
              id: 'rule',
              name: 'Portrait hides outfit',
              sourceCategoryId: 'cat-hair',
              targetCategoryId: 'cat-outfit',
              conditionValue: 'portrait',
            ),
          ],
          categoryOptions: _categoryOptions,
          onRulesChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Portrait hides outfit').first);
    await tester.pump();

    final name = _field(_l10n.diy_ruleName);
    _expectIcon(name, Icons.label_outline_rounded);
    expect(_text(tester, name), 'Portrait hides outfit');
    final value = _field(_l10n.diy_conditionValue);
    _expectIcon(value, Icons.text_fields_rounded);
    expect(_text(tester, value), 'portrait');
    expect(tester.takeException(), isNull);
  });

  testWidgets('后处理规则编辑区的名称、触发与目标标签带标签与图标并回显已保存的值', (tester) async {
    await tester.pumpWidget(
      _app(
        PostProcessRulePanel(
          rules: const [
            PostProcessRule(
              id: 'post',
              name: 'Sleeping',
              triggerTags: ['sleeping', 'closed eyes'],
              targetTags: ['open mouth'],
            ),
          ],
          categoryOptions: _categoryOptions,
          onRulesChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Sleeping'));
    await tester.pump();

    final name = _field(_l10n.diy_ruleName);
    _expectIcon(name, Icons.label_outline_rounded);
    expect(_text(tester, name), 'Sleeping');
    final trigger = _field(_l10n.diy_triggerTags);
    _expectIcon(trigger, Icons.play_circle_outline_rounded);
    expect(_text(tester, trigger), 'sleeping, closed eyes');
    final target = _field(_l10n.diy_targetTags);
    _expectIcon(target, Icons.label_outline_rounded);
    expect(_text(tester, target), 'open mouth');
    expect(tester.takeException(), isNull);
  });

  testWidgets('依赖默认值显示提示与图标并回显已保存的默认值', (tester) async {
    await tester.pumpWidget(
      _app(
        DependencyConfigPanel(
          config: const DependencyConfig(
            sourceCategoryId: 'cat-hair',
            defaultValue: '0-1',
          ),
          categoryOptions: _categoryOptions,
          onConfigChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    final field = find
        .ancestor(
          of: find.byIcon(Icons.edit_note_rounded),
          matching: find.byType(ThemedFormInput),
        )
        .first;
    expect(_text(tester, field), '0-1');
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          )
          .decoration
          ?.hintText,
      _l10n.diy_defaultValueHint,
    );
    expect(tester.takeException(), isNull);
  });
}

final _l10n = lookupAppLocalizations(const Locale('en'));

const _categoryOptions = [
  DiyCategoryOption(id: 'cat-hair', label: 'Hair'),
  DiyCategoryOption(id: 'cat-outfit', label: 'Outfit'),
];

Widget _app(Widget panel) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: panel)),
  );
}

Finder _field(String labelOrHint) => find.ancestor(
  of: find.text(labelOrHint),
  matching: find.byType(ThemedFormInput),
);

void _expectIcon(Finder field, IconData icon) {
  expect(
    find.descendant(of: field, matching: find.byIcon(icon)),
    findsOneWidget,
    reason: '$icon',
  );
}

String _text(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .controller
    .text;
