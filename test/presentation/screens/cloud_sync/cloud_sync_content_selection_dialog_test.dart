import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/cloud_sync/content_selection.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/cloud_sync/cloud_sync_content_selection_dialog.dart';

void main() {
  for (final width in const [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('$width 宽度下内容清单保持可滚动且操作可达', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 760);
      tester.view.padding = const FakeViewPadding(top: 12, bottom: 16);
      tester.view.viewInsets = const FakeViewPadding(bottom: 120);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
        tester.view.resetViewInsets();
      });
      CloudSyncContentSelection? result;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await showCloudSyncContentSelectionDialog(
                    context: context,
                    initialSelection: const CloudSyncContentSelection(),
                    skills: const SkillCatalogSnapshot(),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey(
            width < 840 ? 'adaptive-bottom-sheet' : 'adaptive-centered-form',
          ),
        ),
        findsOneWidget,
      );
      if (find
          .byKey(const ValueKey('cloud-sync-content-settings'))
          .evaluate()
          .isEmpty) {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('cloud-sync-content-settings')),
          300,
          maxScrolls: 20,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('cloud-sync-content-selection-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const ValueKey('cloud-sync-content-settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cloud-sync-content-group-lightweight')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cloud-sync-content-save')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      if (find
          .byKey(const ValueKey('cloud-sync-content-save'))
          .hitTestable()
          .evaluate()
          .isEmpty) {
        await tester.drag(
          find.byKey(const ValueKey('cloud-sync-content-footer-scroll')),
          const Offset(-800, 0),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('cloud-sync-content-save')));
      await tester.pumpAndSettle();
      expect(result?.selectedItemCount, 8);
      expect(result?.includeAgentSystemPrompt, isTrue);
      expect(result?.includeSkills, isTrue);
      expect(result?.includeTagThumbnails, isTrue);
      expect(result?.includeVibes, isFalse);
    });
  }

  testWidgets('Skill 清单使用独立弹窗，不嵌套在内容清单滚动区', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 760);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showCloudSyncContentSelectionDialog(
                context: context,
                initialSelection: const CloudSyncContentSelection(),
                skills: SkillCatalogSnapshot(
                  entries: [
                    for (var index = 0; index < 12; index++) _skill(index),
                  ],
                  diagnostics: const [],
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    final contentList = find.byKey(
      const ValueKey('cloud-sync-content-selection-list'),
    );
    final skillEntry = find.byKey(
      const ValueKey('cloud-sync-skill-selection-entry'),
    );
    await tester.scrollUntilVisible(
      skillEntry,
      300,
      scrollable: find.descendant(
        of: contentList,
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(
      tester.element(skillEntry),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    expect(skillEntry.hitTestable(), findsOneWidget);
    await tester.tap(skillEntry);
    await tester.pumpAndSettle();

    final skillList = find.byKey(const ValueKey('cloud-sync-skill-list'));
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsNWidgets(2),
    );
    expect(skillList, findsOneWidget);
    expect(find.descendant(of: contentList, matching: skillList), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('cloud-sync-skill-workspace:skill-0')),
    );
    await tester.tap(find.byKey(const ValueKey('cloud-sync-skill-save')));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 个 Skill'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

SkillCatalogEntry _skill(int index) => SkillCatalogEntry(
  id: 'skill-$index',
  skill: HarnessSkill(
    name: 'skill-$index',
    description: 'Skill $index description',
    content: 'Skill $index',
    filePath: '/skills/skill-$index/SKILL.md',
  ),
  source: SkillSource.workspace,
  safePath: 'workspace:/skill-$index/SKILL.md',
  enabled: true,
);
