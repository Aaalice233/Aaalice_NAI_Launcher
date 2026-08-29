import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/cloud_sync/content_selection.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/cloud_sync/cloud_sync_agent_content_section.dart';

void main() {
  testWidgets(
    'Skill backup starts off and enables explicit searchable selection',
    (tester) async {
      var selection = const CloudSyncContentSelection();
      late StateSetter rebuild;
      final skills = SkillCatalogSnapshot(
        entries: [
          _skill('shared', SkillSource.workspace, 'Workspace skill'),
          _skill('shared', SkillSource.piUser, 'User skill'),
          _skill('other', SkillSource.piUser, 'Other skill'),
        ],
        diagnostics: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SingleChildScrollView(
                  child: CloudSyncAgentContentSection(
                    selection: selection,
                    skills: skills,
                    onChanged: (value) {
                      rebuild(() => selection = value);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(selection.includeAgentSystemPrompt, isTrue);
      expect(selection.includeSkills, isFalse);
      expect(find.text('智能体自定义系统提示词'), findsOneWidget);
      expect(find.text('搜索 Skill'), findsNothing);

      await tester.tap(find.widgetWithText(SwitchListTile, '备份 Skill'));
      await tester.pumpAndSettle();
      expect(selection.includeSkills, isTrue);
      expect(selection.selectedSkillIds, isEmpty);
      expect(find.text('已选择 0 个 Skill'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '搜索 Skill'),
        'Workspace',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Workspace skill'), findsOneWidget);
      expect(find.textContaining('User skill'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('cloud-sync-skill-workspace:shared')),
      );
      await tester.pumpAndSettle();
      expect(selection.selectedSkillIds, {'workspace:shared'});
      expect(find.text('已选择 1 个 Skill'), findsOneWidget);

      rebuild(
        () => selection = selection.copyWith(
          selectedSkillIds: {
            ...selection.selectedSkillIds,
            'commonUser:missing-skill',
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('其中 1 个当前不可用'), findsOneWidget);
      await tester.tap(find.text('移除不可用项'));
      await tester.pumpAndSettle();
      expect(selection.selectedSkillIds, {'workspace:shared'});
      expect(find.text('已选择 1 个 Skill'), findsOneWidget);
    },
  );
}

SkillCatalogEntry _skill(String name, SkillSource source, String description) =>
    SkillCatalogEntry(
      id: name,
      skill: HarnessSkill(
        name: name,
        description: description,
        content: description,
        filePath: '/skills/$name/SKILL.md',
      ),
      source: source,
      safePath: '${source.name}:/$name/SKILL.md',
      enabled: true,
    );
