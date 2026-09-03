import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tag_entry_tile.dart';

void main() {
  testWidgets('桌面禁用态保留原阴影和文字独立弱化样式', (tester) async {
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
    expect(decoration.boxShadow, hasLength(1));
    expect(
      decoration.boxShadow!.single,
      BoxShadow(
        color: theme.colorScheme.shadow.withValues(alpha: 0.05),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    );

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
            isDark: false,
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
