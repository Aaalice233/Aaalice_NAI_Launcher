import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/common/labeled_control_rows.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_slider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/algorithm_config_card.dart';

import '../../../../helpers/ink_expectations.dart';
import '../../../../helpers/labeled_rows_expectations.dart';
import '../../../../helpers/random_preset_test_harness.dart';
import '../../../../helpers/text_layout_expectations.dart';

const _minTouchExtent = 44.0;
const _landscape = Size(740, 360);
const _landscapePadding = FakeViewPadding(left: 32, right: 32, bottom: 16);
const _keyboardInset = 160.0;

// flutter_test 字体每个字形 1em，英文宽度约为真实两倍，作为最窄的压力场景
final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('标题与季节词库开关的按压反馈画在卡片底色之上', (tester) async {
    tester.view.physicalSize = const Size(840, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            TestRandomPresetNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: AlgorithmConfigCard()),
          ),
        ),
      ),
    );

    final card = find.byKey(const ValueKey('random-manager-algorithm-card'));
    final theme = Theme.of(tester.element(card));
    final cardFill = sectionSurfaceColor(theme.colorScheme);
    final header = find.byIcon(Icons.tune_rounded);

    final headerPress = await pressAndHold(tester, header);
    expectInkOnTop(tester, card, ink: theme.highlightColor, below: cardFill);
    await headerPress.up();
    await tester.pumpAndSettle();

    final seasonal = find.byType(SwitchListTile);
    await tester.ensureVisible(seasonal);
    await tester.pumpAndSettle();
    final switchPress = await pressAndHold(tester, seasonal);
    expectInkOnTop(tester, card, ink: theme.highlightColor, below: cardFill);
    await switchPress.cancel();
    await tester.pumpAndSettle();
  });

  for (final locale in const ['zh', 'ja', 'en']) {
    for (final width in labeledRowWidths) {
      for (final scale in labeledRowTextScales) {
        final scenario = '$locale ${width.toInt()} ${scale}x';
        testWidgets('$scenario 下权重滑块标签完整、读数单行且可达', (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                randomPresetNotifierProvider.overrideWith(
                  TestRandomPresetNotifier.new,
                ),
              ],
              child: MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(child: AlgorithmConfigCard()),
                ),
              ),
            ),
          );
          await tester.tap(find.byIcon(Icons.tune_rounded));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: scenario);

          final sliders = tester
              .widgetList<NamedSlider>(
                find.descendant(
                  of: find.byType(LabeledControlRows),
                  matching: find.byType(NamedSlider),
                ),
              )
              .toList();
          expect(sliders.length, greaterThanOrEqualTo(4), reason: scenario);
          await expectLabeledSliderRows(
            tester,
            labels: [for (final slider in sliders) slider.label],
            labelsSingleLine: locale != 'en',
            readouts: {
              for (final slider in sliders) slider.valueText(slider.value),
            },
            reason: scenario,
          );
          expect(tester.takeException(), isNull, reason: scenario);
        });
      }
    }
  }

  for (final textScale in labeledRowTextScales) {
    testWidgets('320–1600 宽度、${textScale}x 文字下折叠与展开均不溢出，小节标题与摘要完整、操作可达', (
      tester,
    ) async {
      for (final width in labeledRowWidths) {
        await _pumpLayoutCard(
          tester,
          size: Size(width, 900),
          textScale: textScale,
        );
        await _expectCardUsable(
          tester,
          reason: 'width=$width scale=$textScale',
        );
      }
    });
  }

  testWidgets('短横屏、安全区与软键盘下折叠与展开的卡片内容全部可滚到并点中', (tester) async {
    for (final textScale in labeledRowTextScales) {
      await _pumpLayoutCard(
        tester,
        size: _landscape,
        textScale: textScale,
        padding: _landscapePadding,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardInset);
      await tester.pumpAndSettle();
      final card = tester.getRect(_card());
      expect(card.left, greaterThanOrEqualTo(_landscapePadding.left));
      expect(
        card.right,
        lessThanOrEqualTo(_landscape.width - _landscapePadding.right),
      );
      await _expectCardUsable(
        tester,
        reason: 'landscape keyboard scale=$textScale',
      );
    }
  });
}

Finder _card() => find.byKey(const ValueKey('random-manager-algorithm-card'));

Finder _pageScrollable() =>
    find.ancestor(of: _card(), matching: find.byType(Scrollable)).first;

Finder _header() => find
    .ancestor(
      of: find.text(_l10n.randomManager_algorithmConfig),
      matching: find.byType(InkWell),
    )
    .first;

Finder _globalSettings() => find
    .ancestor(
      of: find.text(_l10n.randomManager_globalPeopleSettings),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    )
    .first;

Future<void> _pumpLayoutCard(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);

  // 同一用例内逐个尺寸重建，展开状态不能沿用上一个尺寸
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomPresetNotifierProvider.overrideWith(TestRandomPresetNotifier.new),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => InteractionPolicyScope(
          initialPolicy: InteractionPolicy.touchFirst,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [AlgorithmConfigCard(onGlobalSettings: () {})],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectCardUsable(
  WidgetTester tester, {
  required String reason,
}) async {
  expect(tester.takeException(), isNull, reason: 'collapsed $reason');
  final summary = find.descendant(
    of: find.byKey(const ValueKey('random-manager-algorithm-summary')),
    matching: find.byType(Text),
  );
  expect(summary, findsWidgets, reason: reason);
  for (var i = 0; i < summary.evaluate().length; i++) {
    await _expectTextComplete(tester, summary.at(i), reason: 'summary $reason');
  }
  await _expectControlReachable(tester, _header(), reason: 'header $reason');
  await _expectControlReachable(
    tester,
    _globalSettings(),
    reason: 'global settings $reason',
  );

  await tester.ensureVisible(_header());
  await tester.pumpAndSettle();
  await tester.tap(_header());
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'expanded $reason');

  for (final label in [
    _l10n.randomManager_characterCountWeight,
    _l10n.randomManager_genderWeight,
  ]) {
    await _expectTextComplete(
      tester,
      find.text(label),
      reason: 'section $label $reason',
    );
  }
  await _expectControlReachable(
    tester,
    find.byType(SwitchListTile),
    reason: 'seasonal $reason',
  );
  await _expectControlReachable(
    tester,
    labeledRowSlider(_l10n.randomManager_globalEmphasisProbability),
    touchTarget: false,
    reason: 'global emphasis $reason',
  );
  expect(tester.takeException(), isNull, reason: reason);
}

Future<void> _expectTextComplete(
  WidgetTester tester,
  Finder text, {
  required String reason,
}) async {
  await tester.ensureVisible(text);
  await tester.pumpAndSettle();
  expectFullyVisible(tester, text, reason: reason);
  _expectInsideCard(tester, text, reason: reason);
}

void _expectInsideCard(WidgetTester tester, Finder part, {String? reason}) {
  final card = tester.getRect(_card());
  final rect = tester.getRect(part);
  expect(rect.left, greaterThanOrEqualTo(card.left - 0.5), reason: reason);
  expect(rect.right, lessThanOrEqualTo(card.right + 0.5), reason: reason);
}

/// 滚到控件后断言它在卡片左右边界内，露出的部分能被点中，按钮类命中区达标
Future<void> _expectControlReachable(
  WidgetTester tester,
  Finder control, {
  required String reason,
  bool touchTarget = true,
}) async {
  expect(control, findsOneWidget, reason: reason);
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  _expectInsideCard(tester, control, reason: reason);

  final rect = tester.getRect(control);
  final visible = rect.intersect(tester.getRect(_pageScrollable()));
  expect(visible.width > 0 && visible.height > 0, isTrue, reason: reason);
  final target = tester.renderObject(control);
  expect(
    tester
        .hitTestOnBinding(visible.center)
        .path
        .any((entry) => entry.target == target),
    isTrue,
    reason: '可点中 $reason',
  );
  if (touchTarget) {
    expect(
      rect.shortestSide,
      greaterThanOrEqualTo(_minTouchExtent),
      reason: '命中区 $reason',
    );
  }
}
