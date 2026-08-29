import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/agent/agent_profile_service.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/agent/agent_profile_actions.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/agent/skill_management_panel.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/agent_settings_section.dart';

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
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: AgentSettingsSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AgentSettingsSection), findsOneWidget);
      expect(find.text('导入配置'), findsOneWidget);
      expect(find.text('导出配置'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      final skillsTab = find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Skills'),
      );
      expect(skillsTab, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(skillsTab.first);
      await tester.tap(skillsTab.first);
      await tester.pumpAndSettle();
      expect(find.text('已启用 0/0'), findsOneWidget);
      expect(find.text('没有匹配的 Skill'), findsOneWidget);
      final promptTab = find.descendant(
        of: find.byType(TabBar),
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
      expect(find.textContaining('保留内置说明与 Skills 列表'), findsOneWidget);

      await tester.tap(find.text('覆盖'));
      await tester.pumpAndSettle();
      expect(find.textContaining('仅将下方内容作为系统提示词'), findsOneWidget);
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
      final skillsTab = find.descendant(
        of: find.byType(TabBar),
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

  testWidgets('配置导入预览在 360 和 400dp 内受约束且内容可滚动', (tester) async {
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
      for (final width in const [360.0, 400.0]) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: AgentProfileActions()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('导入配置'));
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        final dialogMaterial = find.descendant(
          of: dialog,
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.type == MaterialType.card,
          ),
        );
        expect(dialogMaterial, findsOneWidget);
        final rect = tester.getRect(dialogMaterial);
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(rect.right, lessThanOrEqualTo(width - 16));
        expect(
          find.descendant(
            of: dialog,
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
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
