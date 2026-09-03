import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/themes/prompt_semantic_colors.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tag_entry_tile.dart';

void main() {
  testWidgets('桌面禁用态以色面和文字弱化表达层级且不添加边框', (tester) async {
    final entry = FixedTagEntry.create(
      name: '禁用固定词',
      content: '1girl, blue eyes',
      enabled: false,
    );

    await _pumpTile(tester, entry: entry);

    final theme = Theme.of(tester.element(find.byType(FixedTagEntryTile)));
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(
      decoration.color,
      Color.alphaBlend(
        theme.promptSemanticColors.positiveFixedTag.withValues(alpha: 0.07),
        controlSurfaceColor(theme.colorScheme),
      ),
    );
    expect(decoration.color, isNot(theme.colorScheme.surface));
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNull);
    expect(tester.getSize(find.byType(Switch)).width, greaterThanOrEqualTo(48));

    final nameStyle = tester.widget<Text>(find.text('禁用固定词')).style!;
    expect(nameStyle.color, theme.colorScheme.onSurface.withValues(alpha: 0.5));
    expect(nameStyle.decoration, TextDecoration.lineThrough);
    expect(
      nameStyle.decorationColor,
      theme.colorScheme.outline.withValues(alpha: 0.6),
    );
    expect(nameStyle.decorationThickness, 2);

    final contentStyle = tester
        .widget<Text>(find.text('1girl, blue eyes'))
        .style!;
    expect(
      contentStyle.color,
      theme.colorScheme.outline.withValues(alpha: 0.5),
    );
    expect(contentStyle.decoration, TextDecoration.lineThrough);
    expect(
      contentStyle.decorationColor,
      theme.colorScheme.outline.withValues(alpha: 0.4),
    );
  });

  testWidgets('桌面条目整行可点击并在 hover 时提升层级', (tester) async {
    var toggleCount = 0;
    final entry = FixedTagEntry.create(
      name: '悬浮固定词',
      content: 'masterpiece',
      enabled: false,
    );

    await _pumpTile(tester, entry: entry, onToggleEnabled: () => toggleCount++);

    final entrySurface = find.byKey(ValueKey('fixed-tag-entry-${entry.id}'));
    final animatedSurface = find.descendant(
      of: entrySurface,
      matching: find.byType(AnimatedContainer),
    );
    final before = tester.widget<AnimatedContainer>(animatedSurface);
    final beforeDecoration = before.decoration! as BoxDecoration;
    final inkWell = tester.widget<InkWell>(entrySurface);
    expect(inkWell.hoverColor, Colors.transparent);
    expect(inkWell.focusColor, Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(entrySurface));
    await tester.pumpAndSettle();

    final after = tester.widget<AnimatedContainer>(animatedSurface);
    final afterDecoration = after.decoration! as BoxDecoration;
    expect(afterDecoration.color, isNot(beforeDecoration.color));
    expect(afterDecoration.boxShadow, isNull);

    await tester.tapAt(tester.getTopLeft(entrySurface) + const Offset(4, 4));
    expect(toggleCount, 1);
  });

  testWidgets('正向与负向固定词使用各自的低对比语义色面', (tester) async {
    final positive = FixedTagEntry.create(
      name: '正向固定词',
      content: 'masterpiece',
    );
    final negative = FixedTagEntry.create(
      name: '负向固定词',
      content: 'lowres',
      promptType: FixedTagPromptType.negative,
    );

    Future<Color?> surfaceColor(FixedTagEntry entry) async {
      await _pumpTile(tester, entry: entry);
      return (tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration)
          .color;
    }

    final positiveColor = await surfaceColor(positive);
    final theme = Theme.of(tester.element(find.byType(FixedTagEntryTile)));
    final expectedPositive = Color.alphaBlend(
      theme.promptSemanticColors.positiveFixedTag.withValues(alpha: 0.12),
      controlSurfaceColor(theme.colorScheme),
    );
    expect(positiveColor, expectedPositive);

    final negativeColor = await surfaceColor(negative);
    final negativeTheme = Theme.of(
      tester.element(find.byType(FixedTagEntryTile)),
    );
    final expectedNegative = Color.alphaBlend(
      negativeTheme.promptSemanticColors.negativeFixedTag.withValues(
        alpha: 0.12,
      ),
      controlSurfaceColor(negativeTheme.colorScheme),
    );
    expect(negativeColor, expectedNegative);
    expect(negativeColor, isNot(positiveColor));
  });

  testWidgets('桌面文字点击区域使用点击光标并切换启用状态', (tester) async {
    var toggleCount = 0;
    final entry = FixedTagEntry.create(name: '可点击固定词', content: 'masterpiece');

    await _pumpTile(tester, entry: entry, onToggleEnabled: () => toggleCount++);

    final mouseRegions = tester.widgetList<MouseRegion>(
      find.ancestor(
        of: find.text('可点击固定词'),
        matching: find.byType(MouseRegion),
      ),
    );
    expect(
      mouseRegions.any((region) => region.cursor == SystemMouseCursors.click),
      isTrue,
    );

    await tester.tap(find.text('可点击固定词'));
    expect(toggleCount, 1);
  });

  testWidgets('Windows touch uses delayed drag and touch-safe actions', (
    tester,
  ) async {
    final entry = FixedTagEntry.create(name: '触控固定词', content: '1girl');
    await _pumpTile(
      tester,
      entry: entry,
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
    );

    expect(find.byType(ReorderableDelayedDragStartListener), findsOneWidget);
    expect(find.byType(ReorderableDragStartListener), findsNothing);
    expect(tester.getSize(find.byTooltip('编辑')), const Size(48, 48));
  });

  testWidgets('Android mouse uses precise-pointer drag and compact actions', (
    tester,
  ) async {
    final entry = FixedTagEntry.create(name: '鼠标固定词', content: '1girl');
    await _pumpTile(
      tester,
      entry: entry,
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      ),
    );

    expect(find.byType(ReorderableDragStartListener), findsOneWidget);
    expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
    expect(tester.getSize(find.byTooltip('编辑')), const Size(25, 25));
  });
}

Future<void> _pumpTile(
  WidgetTester tester, {
  required FixedTagEntry entry,
  VoidCallback? onToggleEnabled,
  InteractionPolicy? interactionPolicy,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: InteractionPolicyScope(
        initialPolicy:
            interactionPolicy ??
            const InteractionPolicy(
              modality: InteractionModality.pointer,
              touchAvailable: false,
              precisePointerAvailable: true,
            ),
        child: Scaffold(
          body: FixedTagEntryTile(
            entry: entry,
            index: 0,
            onToggleEnabled: onToggleEnabled ?? () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
