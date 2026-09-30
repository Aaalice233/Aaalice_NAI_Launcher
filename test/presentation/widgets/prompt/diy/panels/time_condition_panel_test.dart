import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/time_condition_panel.dart';

import '../../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('节日模板按钮的悬停与按压反馈画在按钮底色之上，点击套用模板', (tester) async {
    TimeCondition? changed;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimeConditionPanel(
              condition: TimeCondition.christmas(),
              onConditionChanged: (condition) => changed = condition,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final preset = find.ancestor(
      of: find.text('Halloween'),
      matching: find.byType(SurfaceInkWell),
    );
    final theme = Theme.of(tester.element(preset));
    final fill = theme.colorScheme.surfaceContainerHighest;

    await hoverOver(tester, preset);
    expectInkOnTop(tester, preset, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, preset);
    expectInkOnTop(tester, preset, ink: theme.highlightColor, below: fill);
    await press.up();
    await tester.pump();
    expect(changed?.startMonth, 10);
    expect(changed?.endMonth, 10);
  });

  testWidgets('只读时模板按钮不响应悬停与点击', (tester) async {
    TimeCondition? changed;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimeConditionPanel(
              condition: TimeCondition.christmas(),
              readOnly: true,
              onConditionChanged: (condition) => changed = condition,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final preset = find.ancestor(
      of: find.text('Halloween'),
      matching: find.byType(SurfaceInkWell),
    );
    final theme = Theme.of(tester.element(preset));
    await hoverOver(tester, preset);
    expect(tester.renderObject(preset), isNot(inkOnTop(ink: theme.hoverColor)));
    await tester.tap(preset);
    await tester.pump();
    expect(changed, isNull);
  });
  testWidgets('只有一个启用开关：停用的旧条件显示为关闭，打开后沿用原日期', (tester) async {
    final emitted = <TimeCondition?>[];
    await tester.pumpWidget(
      _panelApp(
        condition: TimeCondition.halloween().copyWith(enabled: false),
        onChanged: emitted.add,
      ),
    );
    await tester.pump();

    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(emitted.single?.enabled, isTrue);
    expect(emitted.single?.startMonth, 10);
    expect(find.text(_l10n.common_enabled), findsNothing);
    expect(find.byType(Switch), findsNWidgets(2));

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(emitted, hasLength(2));
    expect(emitted.last, isNull);
  });

  testWidgets('关闭每年重复后出现年份，默认今年并可改选', (tester) async {
    final emitted = <TimeCondition?>[];
    final thisYear = DateTime.now().year;
    await tester.pumpWidget(
      _panelApp(condition: TimeCondition.christmas(), onChanged: emitted.add),
    );
    await tester.pump();
    expect(find.text(_l10n.diy_year), findsNothing);

    await tester.ensureVisible(find.byType(Switch).last);
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    expect(emitted.last?.recurring, isFalse);
    expect(emitted.last?.specificYear, thisYear);
    expect(find.text(_l10n.diy_repeatOnceHint), findsOneWidget);

    final yearField = find.widgetWithText(
      DropdownButtonFormField<int>,
      _l10n.diy_year,
    );
    await tester.ensureVisible(yearField);
    await tester.tap(yearField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${thisYear + 1}').last);
    await tester.pumpAndSettle();
    expect(emitted.last?.specificYear, thisYear + 1);
    expect(emitted.last?.isActive(DateTime(thisYear, 12, 25)), isFalse);
    expect(emitted.last?.isActive(DateTime(thisYear + 1, 12, 25)), isTrue);
  });

  testWidgets('未选年份的旧数据如实提示每年生效', (tester) async {
    await tester.pumpWidget(
      _panelApp(
        condition: TimeCondition.christmas().copyWith(recurring: false),
        onChanged: (_) {},
      ),
    );
    await tester.pump();

    expect(find.text(_l10n.diy_yearUnsetHint), findsOneWidget);
  });

  testWidgets('年份字段在 320–1600 宽度与 3 倍文字下完整可达', (tester) async {
    addTearDown(tester.view.reset);
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      for (final textScale in [1.0, 3.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _panelApp(
            condition: TimeCondition.christmas().copyWith(
              recurring: false,
              specificYear: 2026,
            ),
            onChanged: (_) {},
            textScale: textScale,
          ),
        );
        await tester.pump();
        final reason = 'width=$width scale=$textScale';
        expect(tester.takeException(), isNull, reason: reason);

        final yearField = find.widgetWithText(
          DropdownButtonFormField<int>,
          _l10n.diy_year,
        );
        await tester.ensureVisible(yearField);
        await tester.pump();
        final rect = tester.getRect(yearField);
        expect(rect.left, greaterThanOrEqualTo(0), reason: reason);
        expect(rect.right, lessThanOrEqualTo(width), reason: reason);
      }
    }
  });
}

final _l10n = lookupAppLocalizations(const Locale('en'));

Widget _panelApp({
  required TimeCondition condition,
  required ValueChanged<TimeCondition?> onChanged,
  double textScale = 1,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: TimeConditionPanel(
          condition: condition,
          onConditionChanged: onChanged,
        ),
      ),
    ),
  );
}
