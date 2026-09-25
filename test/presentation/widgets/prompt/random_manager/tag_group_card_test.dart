import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/tag_group_card.dart';

const _group = RandomTagGroup(
  id: 'group',
  name: '包含全部复杂配置的超长词组名称',
  conditionalBranchConfig: ConditionalBranchConfig(
    id: 'conditional',
    name: 'conditional',
  ),
  dependencyConfig: DependencyConfig(sourceCategoryId: 'source'),
  visibilityRules: [
    VisibilityRule(
      id: 'visibility',
      name: 'visibility',
      targetCategoryId: 'category',
      sourceCategoryId: 'source',
      conditionValue: 'portrait',
    ),
  ],
  timeCondition: TimeCondition(
    id: 'time',
    name: 'time',
    startMonth: 1,
    startDay: 1,
    endMonth: 12,
    endDay: 31,
  ),
  postProcessRules: [PostProcessRule(id: 'post', name: 'post')],
  emphasisProbability: 0.1,
);

const _category = RandomCategory(
  id: 'category',
  name: 'Category',
  key: 'category',
  groups: [_group],
);

class _FixedRandomPresetNotifier extends RandomPresetNotifier {
  @override
  RandomPresetState build() => const RandomPresetState(
    presets: [
      RandomPreset(id: 'preset', name: 'Preset', categories: [_category]),
    ],
    selectedPresetId: 'preset',
  );
}

void main() {
  testWidgets('全部 DIY 配置在最窄屏、放大文字和键盘组合下均走自适应表单', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _FixedRandomPresetNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewInsets: const EdgeInsets.only(bottom: 160),
              textScaler: const TextScaler.linear(3),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: TagGroupCard(
              tagGroup: _group,
              categoryId: 'category',
              categoryKey: 'category',
              presetId: 'preset',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('包含全部复杂配置的超长词组名称'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    final diyTab = find.byIcon(Icons.account_tree_outlined);
    await tester.ensureVisible(diyTab);
    await tester.pumpAndSettle();
    await tester.tap(diyTab);
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsNWidgets(5));
    expect(tester.takeException(), isNull);

    final firstEdit = find.byKey(const ValueKey('tag-group-diy-action-条件分支'));
    await tester.ensureVisible(firstEdit);
    await tester.pumpAndSettle();
    expect(
      firstEdit.hitTestable(),
      findsOneWidget,
      reason:
          'action=${tester.getRect(firstEdit)} scroll=${tester.getRect(find.byType(SingleChildScrollView).last)}',
    );
    await tester.tap(firstEdit);
    await tester.pumpAndSettle();

    expect(find.text('条件分支'), findsWidgets);
    expect(
      find.byKey(const ValueKey('adaptive-bottom-sheet')),
      findsNWidgets(2),
    );
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('概率滑块以字段名朗读，读数与界面一致且按四舍五入显示', (tester) async {
    // 0.1 分 10 格的第 7 格插值结果，截断取整会显示成 6%
    const group = RandomTagGroup(
      id: 'rounding',
      name: '取整词组',
      probability: 0.35,
      emphasisProbability: 0.06999999999999999,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _FixedRandomPresetNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TagGroupCard(
              tagGroup: group,
              categoryId: 'category',
              categoryKey: 'category',
              presetId: 'preset',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('取整词组'));
    await tester.pumpAndSettle();
    expect(_sliderNode('概率').value, '35%');
    expect(find.text('35%'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_tree_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('7%'));
    await tester.pumpAndSettle();

    final emphasis = _sliderNode('强调概率');
    expect(emphasis.value, '7%');
    expect(emphasis.increasedValue, '8%');
    expect(find.text('6%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

SemanticsNode _sliderNode(String label) {
  final slider = find.semantics.byPredicate(
    (node) => node.flagsCollection.isSlider && node.label == label,
  );
  expect(slider, findsOne, reason: label);
  return slider.evaluate().single;
}
