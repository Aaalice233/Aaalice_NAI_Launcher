import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/core/agent/skill_archive_service.dart';
import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/agent/agent_profile_service.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/agent/agent_profile_actions.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/agent/skill_management_panel.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/agent_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_card.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_page_layout.dart';

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> setSettings(Map<String, Object?> values) async {
    _values.addAll(values);
  }

  @override
  Future<void> deleteSetting(String key) async {
    _values.remove(key);
  }
}

class _MemorySecureStorage extends SecureStorageService {
  @override
  Future<String?> getAgentWebAccessExaApiKey() async => null;

  @override
  Future<String?> getPromptAssistantApiKey(String providerId) async => null;
}

class _EmptySkillCatalogService extends SkillCatalogService {
  const _EmptySkillCatalogService();

  @override
  Future<SkillCatalogSnapshot> scan({
    required List<SkillRoot> roots,
    Map<String, bool> skillEnabledOverrides = const {},
  }) async => const SkillCatalogSnapshot();
}

class _ManySkillCatalogService extends SkillCatalogService {
  const _ManySkillCatalogService();

  @override
  Future<SkillCatalogSnapshot> scan({
    required List<SkillRoot> roots,
    Map<String, bool> skillEnabledOverrides = const {},
  }) async => SkillCatalogSnapshot(
    entries: [
      for (var index = 0; index < 100; index++)
        SkillCatalogEntry(
          id: 'skill-$index',
          skill: HarnessSkill(
            name: 'skill-$index',
            description: 'Skill $index',
            content: 'Instructions $index',
            filePath: 'skill-$index/SKILL.md',
          ),
          source: SkillSource.workspace,
          safePath: 'workspace:/.../skill-$index/SKILL.md',
          enabled: skillEnabledOverrides['skill-$index'] ?? true,
        ),
    ],
  );
}

class _SourcedSkillCatalogService extends SkillCatalogService {
  const _SourcedSkillCatalogService();

  @override
  Future<SkillCatalogSnapshot> scan({
    required List<SkillRoot> roots,
    Map<String, bool> skillEnabledOverrides = const {},
  }) async => SkillCatalogSnapshot(
    entries: [
      for (final source in SkillSource.values)
        SkillCatalogEntry(
          id: '${source.name}-skill',
          skill: HarnessSkill(
            name: '${source.name}-skill',
            description: '${source.name} description',
            content: '${source.name} instructions',
            filePath: '${source.name}/SKILL.md',
          ),
          source: source,
          safePath: '${source.name}:/.../SKILL.md',
          enabled:
              skillEnabledOverrides['${source.name}-skill'] ??
              source.defaultEnabled,
        ),
    ],
  );
}

void main() {
  testWidgets('智能体设置在手机、横屏和桌面宽度无布局溢出', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(390, 820));
    final root = Directory('tool/.tmp/agent-settings-section-test')
      ..createSync(recursive: true);
    final storage = _MemoryLocalStorage();
    var openedIntegrations = false;
    await storage.setSetting(
      StorageKeys.promptAssistantConfigJson,
      PromptAssistantConfigState.defaults()
          .copyWith(
            providers: const [
              ProviderConfig(
                id: 'test-provider',
                name: 'Test Provider',
                baseUrl: 'https://example.test',
              ),
            ],
            models: const [
              ModelConfig(
                providerId: 'test-provider',
                name: 'test-chat-model',
                displayName: 'Test Chat Model',
                forTask: AssistantTaskType.chat,
              ),
            ],
          )
          .encode(),
    );
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: root,
            workspaceDirectory: root,
            environment: const {},
            skillCatalogService: const _EmptySkillCatalogService(),
          ),
        ),
      ],
    );

    try {
      await tester.runAsync(() async {
        container.read(agentSettingsProvider);
        for (var attempt = 0; attempt < 100; attempt++) {
          if (container.read(agentSettingsProvider).initialized) return;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('Agent settings did not initialize.');
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
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
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AgentSettingsSection(
                  onOpenIntegrations: () => openedIntegrations = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AgentSettingsSection), findsOneWidget);
      expect(find.byType(SettingsPageLayout), findsOneWidget);
      final pageLeft = tester.getTopLeft(find.byType(SettingsPageLayout)).dx;
      expect(tester.getTopLeft(find.byType(SettingsCard).first).dx, pageLeft);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('settings-page-title'))).dx,
        pageLeft,
      );
      expect(find.text('导入配置'), findsOneWidget);
      expect(find.text('导出配置'), findsOneWidget);
      final panelSelector = find.byKey(
        const ValueKey('agent-settings-panel-selector'),
      );
      expect(panelSelector, findsOneWidget);
      expect(
        find.ancestor(of: panelSelector, matching: find.byType(SettingsCard)),
        findsOneWidget,
      );
      expect(find.byType(TabBar), findsNothing);
      expect(tester.widget<SegmentedButton<int>>(panelSelector).selected, {0});

      final textScaleControl = find.byKey(
        const ValueKey('agent-reading-text-scale'),
      );
      final densityControl = find.byKey(const ValueKey('agent-chat-density'));
      expect(textScaleControl, findsOneWidget);
      expect(densityControl, findsOneWidget);
      expect(
        tester.widget<SegmentedButton<double>>(textScaleControl).selected,
        {1.0},
      );
      expect(
        tester
            .widget<SegmentedButton<AgentChatDensity>>(densityControl)
            .selected,
        {AgentChatDensity.comfortable},
      );
      tester
          .widget<SegmentedButton<double>>(textScaleControl)
          .onSelectionChanged!({1.15});
      await tester.pumpAndSettle();
      tester
          .widget<SegmentedButton<AgentChatDensity>>(densityControl)
          .onSelectionChanged!({AgentChatDensity.compact});
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 50; attempt++) {
          final chat = container.read(agentSettingsProvider).settings.chat;
          if (chat.readingTextScale == 1.15 &&
              chat.density == AgentChatDensity.compact) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(
        container.read(agentSettingsProvider).settings.chat.readingTextScale,
        1.15,
      );
      expect(
        container.read(agentSettingsProvider).settings.chat.density,
        AgentChatDensity.compact,
      );
      expect(tester.takeException(), isNull);

      final modelField = find.byKey(
        const ValueKey('agent-settings-model-field'),
      );
      await tester.ensureVisible(modelField);
      await tester.tap(modelField);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-settings-model-search')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-settings-model-results')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey('agent-settings-model-header-close')),
      );
      await tester.pumpAndSettle();

      final manageProviders = find.byKey(
        const ValueKey('agent-settings-open-integrations'),
      );
      await tester.ensureVisible(manageProviders);
      await tester.tap(manageProviders);
      expect(openedIntegrations, isTrue);

      final skillsTab = find.descendant(
        of: panelSelector,
        matching: find.text('Skills'),
      );
      expect(skillsTab, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(skillsTab.first);
      await tester.tap(skillsTab.first);
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<int>>(panelSelector).selected, {1});
      expect(find.text('已启用 0/0'), findsOneWidget);
      expect(find.text('没有匹配的 Skill'), findsOneWidget);
      final promptTab = find.descendant(
        of: panelSelector,
        matching: find.text('系统提示词'),
      );
      await tester.ensureVisible(promptTab.first);
      await tester.tap(promptTab.first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-custom-system-prompt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-system-prompt-mode')),
        findsOneWidget,
      );
      expect(find.text('追加'), findsOneWidget);
      expect(find.text('覆盖'), findsOneWidget);
      final promptMode = tester.widget<SegmentedButton<AgentSystemPromptMode>>(
        find.byKey(const ValueKey('agent-system-prompt-mode')),
      );
      expect(promptMode.selected, {AgentSystemPromptMode.override});
      final promptField = tester.widget<TextField>(
        find.byKey(const ValueKey('agent-custom-system-prompt')),
      );
      expect(
        promptField.controller!.text,
        startsWith('You are the AI agent inside Aaalice'),
      );
      expect(find.textContaining('仅将下方内容作为系统提示词'), findsOneWidget);

      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();
      expect(find.textContaining('保留内置说明与 Skills 列表'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('agent-custom-system-prompt')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);

      for (final size in const [
        Size(700, 430),
        Size(840, 700),
        Size(1180, 800),
        Size(1600, 900),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AgentSettingsSection), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
      root.deleteSync(recursive: true);
    }
  });

  test('配置导入预览只认可启用服务商的真实 Chat 模型', () {
    final config = PromptAssistantConfigState.defaults().copyWith(
      providers: const [
        ProviderConfig(
          id: 'enabled',
          name: 'Enabled',
          baseUrl: 'https://enabled.example',
        ),
        ProviderConfig(
          id: 'disabled',
          name: 'Disabled',
          baseUrl: 'https://disabled.example',
          enabled: false,
        ),
      ],
      models: const [
        ModelConfig(
          providerId: 'enabled',
          name: 'chat-model',
          displayName: 'Chat',
          forTask: AssistantTaskType.chat,
        ),
        ModelConfig(
          providerId: 'enabled',
          name: 'llm-model',
          displayName: 'LLM',
          forTask: AssistantTaskType.llm,
        ),
        ModelConfig(
          providerId: 'enabled',
          name: 'default-model',
          displayName: 'Placeholder',
          forTask: AssistantTaskType.chat,
        ),
        ModelConfig(
          providerId: 'disabled',
          name: 'disabled-chat',
          displayName: 'Disabled Chat',
          forTask: AssistantTaskType.chat,
        ),
      ],
    );

    expect(availableAgentModelReferences(config), {'enabled/chat-model'});
  });

  testWidgets('Skills 大列表使用有界惰性视口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    final root = Directory('tool/.tmp/agent-settings-skill-list-test')
      ..createSync(recursive: true);
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: root,
            workspaceDirectory: root,
            environment: const {},
            skillCatalogService: const _ManySkillCatalogService(),
          ),
        ),
      ],
    );
    try {
      await tester.runAsync(() async {
        container.read(agentSettingsProvider);
        for (var attempt = 0; attempt < 100; attempt++) {
          if (container.read(agentSettingsProvider).initialized) return;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('Agent settings did not initialize.');
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: AgentSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final panelSelector = find.byKey(
        const ValueKey('agent-settings-panel-selector'),
      );
      final skillsTab = find.descendant(
        of: panelSelector,
        matching: find.text('Skills'),
      );
      await tester.ensureVisible(skillsTab.first);
      await tester.tap(skillsTab.first);
      await tester.pumpAndSettle();

      expect(find.text('已启用 100/100'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsWidgets);
      expect(find.byType(SwitchListTile).evaluate().length, lessThan(100));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.binding.setSurfaceSize(null);
      root.deleteSync(recursive: true);
    }
  });

  testWidgets('Skills 清晰区分图片项目与用户来源及默认状态', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    final root = Directory('tool/.tmp/agent-settings-skill-source-test')
      ..createSync(recursive: true);
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: root,
            workspaceDirectory: root,
            environment: const {},
            skillCatalogService: const _SourcedSkillCatalogService(),
          ),
        ),
      ],
    );
    try {
      await tester.runAsync(() async {
        container.read(agentSettingsProvider);
        for (var attempt = 0; attempt < 100; attempt++) {
          if (container.read(agentSettingsProvider).initialized) return;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('Agent settings did not initialize.');
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: SkillManagementPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前图片项目'), findsOneWidget);
      expect(find.text('Pi 用户'), findsOneWidget);
      expect(find.text('用户全局'), findsOneWidget);
      expect(
        find.text('当前图片项目中的 Skill 会自动启用；Pi 用户与用户全局 Skill 仅在手动开启后使用。'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('agent-skill-workspace-skill')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('agent-skill-piUser-skill')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('agent-skill-commonUser-skill')),
            )
            .value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.binding.setSurfaceSize(null);
      root.deleteSync(recursive: true);
    }
  });

  testWidgets('Skill 导出表单在紧凑与宽屏保持选择和有界呈现', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    final root = Directory('tool/.tmp/agent-skill-export-form-test')
      ..createSync(recursive: true);
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: root,
            workspaceDirectory: root,
            environment: const {},
            skillCatalogService: const _ManySkillCatalogService(),
          ),
        ),
      ],
    );

    Future<void> openExport() async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('导出所选 Skills'));
      await tester.pumpAndSettle();
    }

    Widget buildApp(Size size) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: size, textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: SkillManagementPanel()),
        ),
      ),
    );

    try {
      await tester.runAsync(() async {
        container.read(agentSettingsProvider);
        for (var attempt = 0; attempt < 100; attempt++) {
          if (container.read(agentSettingsProvider).initialized) return;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('Agent settings did not initialize.');
      });
      await tester.pumpWidget(buildApp(const Size(360, 640)));
      await tester.pumpAndSettle();

      await openExport();
      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('skill-export-selection-list')),
        findsOneWidget,
      );
      var continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '继续导出'),
      );
      expect(continueButton.onPressed, isNull);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'skill-0'));
      await tester.pump();
      continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '继续导出'),
      );
      expect(continueButton.onPressed, isNotNull);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'skill-0'),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(1180, 760));
      await tester.pumpWidget(buildApp(const Size(1180, 760)));
      await tester.pumpAndSettle();
      await openExport();
      expect(
        find.byKey(const ValueKey('adaptive-centered-form')),
        findsOneWidget,
      );
      final panelRect = tester.getRect(
        find.byKey(const ValueKey('adaptive-centered-form')),
      );
      expect(panelRect.width, lessThanOrEqualTo(560));
      expect(panelRect.right, lessThanOrEqualTo(1180));
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.binding.setSurfaceSize(null);
      root.deleteSync(recursive: true);
    }
  });

  testWidgets('Skill 导入冲突表单在最坏文本与列表组合下可替换和取消', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    final root = Directory('tool/.tmp/agent-skill-import-form-test')
      ..createSync(recursive: true);
    final target = Directory('${root.path}/pi-user/skills');
    Directory('${target.path}/a-conflict').createSync(recursive: true);
    final archive = Archive();
    for (var index = 0; index < 30; index++) {
      final name = index == 0 ? 'a-conflict' : 'skill-import-$index';
      final manifest = Uint8List.fromList(
        ('---\nname: $name\n'
                'description: A deliberately long imported Skill description '
                'for adaptive conflict layout verification $index.\n---\n'
                'Instructions $index')
            .codeUnits,
      );
      archive.addFile(ArchiveFile('$name/SKILL.md', manifest.length, manifest));
    }
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final preview = (await tester.runAsync(
      () => const SkillArchiveService().previewImport(
        bytes: bytes,
        targetDirectory: target,
      ),
    ))!;
    expect(preview.items, hasLength(30));
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: root,
            workspaceDirectory: root,
            environment: const {},
            skillCatalogService: const _EmptySkillCatalogService(),
          ),
        ),
      ],
    );

    try {
      await tester.runAsync(() async {
        container.read(agentSettingsProvider);
        for (var attempt = 0; attempt < 100; attempt++) {
          if (container.read(agentSettingsProvider).initialized) return;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('Agent settings did not initialize.');
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: const Size(360, 640),
                textScaler: const TextScaler.linear(3),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      SkillImportConflictForm.show(context, preview),
                  child: const Text('打开冲突表单'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开冲突表单'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('skill-import-conflict-list')),
        findsOneWidget,
      );
      var installButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '安装'),
      );
      expect(installButton.onPressed, isNull);
      final conflictTile = find.widgetWithText(CheckboxListTile, 'a-conflict');
      await tester.ensureVisible(conflictTile);
      await tester.pumpAndSettle();
      await tester.tap(conflictTile);
      await tester.pump();
      installButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '安装'),
      );
      expect(installButton.onPressed, isNotNull);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'a-conflict'),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(target.listSync().single.path, endsWith('a-conflict'));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.binding.setSurfaceSize(null);
      root.deleteSync(recursive: true);
    }
  });

  testWidgets('配置导入审阅器在极端尺寸保留滚动内容和应用取消操作', (tester) async {
    FilePicker? originalFilePicker;
    try {
      originalFilePicker = FilePicker.platform;
    } catch (_) {
      originalFilePicker = null;
    }
    final profile = const AgentProfileService().exportProfile(
      const AgentSettings(),
    );
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult([
        PlatformFile(
          name: 'agent-profile.json',
          size: profile.length,
          bytes: Uint8List.fromList(profile.codeUnits),
        ),
      ]),
    );
    addTearDown(() {
      if (originalFilePicker != null) FilePicker.platform = originalFilePicker;
    });

    final root = Directory('tool/.tmp/agent-profile-dialog-test')
      ..createSync(recursive: true);
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: root,
            workspaceDirectory: root,
            environment: const {},
            skillCatalogService: const _EmptySkillCatalogService(),
          ),
        ),
      ],
    );

    try {
      await tester.runAsync(() async {
        container.read(agentSettingsProvider);
        for (var attempt = 0; attempt < 100; attempt++) {
          if (container.read(agentSettingsProvider).initialized) return;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('Agent settings did not initialize.');
      });
      for (final scenario in <({Size size, double scale, String surface})>[
        (
          size: const Size(360, 480),
          scale: 1,
          surface: 'adaptive-full-screen-form',
        ),
        (
          size: const Size(599.9, 700),
          scale: 1,
          surface: 'adaptive-full-screen-form',
        ),
        (
          size: const Size(600, 500),
          scale: 2,
          surface: 'adaptive-full-screen-form',
        ),
        (
          size: const Size(839.9, 700),
          scale: 1,
          surface: 'adaptive-centered-form',
        ),
        (
          size: const Size(840, 500),
          scale: 2,
          surface: 'adaptive-full-screen-form',
        ),
        (
          size: const Size(1600, 900),
          scale: 1,
          surface: 'adaptive-centered-form',
        ),
      ]) {
        await tester.binding.setSurfaceSize(scenario.size);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: scenario.size,
                  textScaler: TextScaler.linear(scenario.scale),
                ),
                child: child!,
              ),
              home: const Scaffold(body: AgentProfileActions()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final importButton = find.widgetWithText(OutlinedButton, '导入配置');
        expect(importButton.hitTestable(), findsOneWidget);
        await tester.tap(importButton);
        await tester.pumpAndSettle();

        expect(find.byKey(ValueKey(scenario.surface)), findsOneWidget);
        expect(
          find.byKey(const Key('agent-profile-import-review-list')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('agent-profile-import-actions-scroll')),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, '应用').hitTestable(), findsOne);
        expect(find.widgetWithText(TextButton, '取消').hitTestable(), findsOne);
        expect(tester.takeException(), isNull);

        if (scenario.size.width == 1600) {
          await tester.tap(find.widgetWithText(FilledButton, '应用'));
        } else {
          await tester.tap(find.widgetWithText(TextButton, '取消'));
        }
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(scenario.surface)), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.binding.setSurfaceSize(null);
      root.deleteSync(recursive: true);
    }
  });
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}
