import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/windowing/desktop_window_controller.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_prompt_draft_provider.dart';
import 'package:nai_launcher/presentation/screens/cloud_sync/cloud_sync_screen.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/account_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/appearance_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/integrations_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/prompt_assistant_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_screen.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_section.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/common/desktop_window_frame.dart';
import 'package:window_manager/window_manager.dart';

class _NoopDesktopWindowController implements DesktopWindowController {
  @override
  void addListener(WindowListener listener) {}

  @override
  void removeListener(WindowListener listener) {}

  @override
  Future<bool> isMaximized() async => false;

  @override
  Future<void> startDragging() async {}

  @override
  Future<void> minimize() async {}

  @override
  Future<void> maximize() async {}

  @override
  Future<void> unmaximize() async {}

  @override
  Future<void> close() async {}
}

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

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}

class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionStateInitial();
}

void main() {
  late _MemoryLocalStorage storage;

  setUp(() {
    storage = _MemoryLocalStorage();
  });

  testWidgets('设置页导航为 11 个稳定分类并包含备份与恢复', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: Directory.systemTemp,
              workspaceDirectory: Directory.systemTemp,
              environment: const {},
              skillCatalogService: const _EmptySkillCatalogService(),
            ),
          ),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _FakeAccountManagerNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _FakeSubscriptionNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectSettingsLayeredChrome(tester, hasNavigation: true);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations.length, 11);

    final sectionScrollView = find.byKey(
      const ValueKey('settings-section-scroll-view'),
    );
    final pageLayout = find.byKey(const ValueKey('settings-page-layout'));
    expect(
      find.ancestor(of: sectionScrollView, matching: find.byType(SafeArea)),
      findsOneWidget,
    );
    for (final width in [700.0, 840.0, 1180.0, 1600.0, 3840.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpAndSettle();
      final scrollRect = tester.getRect(sectionScrollView);
      final pageRect = tester.getRect(pageLayout);
      final availableWidth = scrollRect.width - 48;
      final expectedWidth = availableWidth.clamp(0, 960).toDouble();
      final expectedLeft =
          scrollRect.left + 24 + (availableWidth - expectedWidth) / 2;
      expect(pageRect.width, moreOrLessEquals(expectedWidth));
      expect(pageRect.left, moreOrLessEquals(expectedLeft));
      expect(pageRect.top, moreOrLessEquals(scrollRect.top + 24));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpAndSettle();

    final labels = rail.destinations
        .map((destination) => (destination.label as Text).data)
        .toList();
    expect(labels, const [
      '账户',
      '外观',
      '生成',
      '智能体',
      '数据与存储',
      '备份与恢复',
      '安全与分享',
      '网络',
      '快捷键',
      '集成',
      '关于',
    ]);

    final icons = rail.destinations
        .map((destination) => (destination.icon as Icon).icon)
        .toList();
    expect(icons, const [
      Icons.person_outline,
      Icons.palette_outlined,
      Icons.tune_outlined,
      Icons.smart_toy_outlined,
      Icons.storage_outlined,
      Icons.cloud_sync_outlined,
      Icons.shield_outlined,
      Icons.network_check_outlined,
      Icons.keyboard_outlined,
      Icons.extension_outlined,
      Icons.info_outlined,
    ]);

    final selectedIcons = rail.destinations
        .map((destination) => (destination.selectedIcon as Icon).icon)
        .toList();
    expect(selectedIcons, const [
      Icons.person,
      Icons.palette,
      Icons.tune,
      Icons.smart_toy,
      Icons.storage,
      Icons.cloud_sync,
      Icons.shield,
      Icons.network_check,
      Icons.keyboard,
      Icons.extension,
      Icons.info,
    ]);

    // 撤销的分类不再出现
    expect(find.text('队列'), findsNothing);
    expect(find.text('通知'), findsNothing);
    expect(find.text('数据源'), findsNothing);
    expect(find.text('ComfyUI'), findsNothing);

    await tester.tap(find.byIcon(Icons.cloud_sync_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(CloudSyncScreen), findsOneWidget);
    expect(find.text('尚未连接'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.extension_outlined));
    await tester.pumpAndSettle();

    final integrations = find.byType(IntegrationsSettingsSection);
    expect(integrations, findsOneWidget);

    final segmentedButton = find.descendant(
      of: integrations,
      matching: find.byType(SegmentedButton<int>),
    );
    expect(segmentedButton, findsOneWidget);

    final segments = tester
        .widget<SegmentedButton<int>>(segmentedButton)
        .segments;
    final segmentLabels = segments
        .map((segment) => (segment.label as Text).data)
        .toList();

    final promptAssistantSection = find.byType(PromptAssistantSettingsSection);
    expect(promptAssistantSection, findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('settings-page-title')))
          .data,
      '集成',
    );
    expect(segmentLabels, const ['提示词助手', 'ComfyUI', 'Krita']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('新增服务商弹窗在移动端完整适配窄屏', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: Directory.systemTemp,
              workspaceDirectory: Directory.systemTemp,
              environment: const {},
              skillCatalogService: const _EmptySkillCatalogService(),
            ),
          ),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _FakeAccountManagerNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _FakeSubscriptionNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('集成'));
    await tester.pumpAndSettle();

    final addProvider = find.byKey(
      const ValueKey('prompt-assistant-add-provider'),
    );
    final contentScrollable = find.descendant(
      of: find.byKey(const ValueKey('settings-section-scroll-view')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      addProvider,
      200,
      scrollable: contentScrollable,
    );
    await tester.tap(addProvider);
    await tester.pumpAndSettle();

    final dialog = find.byKey(
      const ValueKey('prompt-assistant-provider-dialog'),
    );
    expect(dialog, findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key == const ValueKey('adaptive-full-screen-form') ||
            widget.key == const ValueKey('adaptive-centered-form'),
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('OpenAI Chat Completions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final selectedProtocolRect = tester.getRect(
      find.text('OpenAI Chat Completions'),
    );
    expect(selectedProtocolRect.left, greaterThanOrEqualTo(16));
    expect(selectedProtocolRect.right, lessThanOrEqualTo(374));

    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);
    final dialogContext = tester.element(dialog);
    final visibleBottom =
        MediaQuery.sizeOf(dialogContext).height -
        MediaQuery.viewInsetsOf(dialogContext).bottom;
    expect(
      tester.getBottomRight(find.text('保存')).dy,
      lessThanOrEqualTo(visibleBottom),
    );
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'test-key');
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('prompt-assistant-provider-openai_chat')),
      findsOneWidget,
    );
    expect(find.text('连接配置'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('紧凑布局使用单页分类并由系统返回手势回到列表', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      return tester.binding.setSurfaceSize(null);
    });

    Future<void> pumpTransition() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _FakeAccountManagerNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _FakeSubscriptionNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await pumpTransition();

    _expectSettingsLayeredChrome(tester);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);

    await tester.tap(find.text('外观'));
    await pumpTransition();

    expect(find.byType(AppearanceSettingsSection), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.bySemanticsLabel('外观'), findsWidgets);

    await tester.binding.setSurfaceSize(const Size(390, 480));
    await tester.pump();

    final contentScrollable = find.descendant(
      of: find.byKey(const ValueKey('settings-section-scroll-view')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(
      tester.state<ScrollableState>(contentScrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.scrollUntilVisible(
      find.text('历史记录点击行为'),
      200,
      scrollable: contentScrollable,
    );
    expect(find.text('历史记录点击行为').hitTestable(), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(390, 820));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await pumpTransition();

    await tester.tap(find.text('账户'));
    await pumpTransition();

    expect(find.byType(AccountSettingsSection), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.binding.handlePopRoute();
    await pumpTransition();

    expect(find.byType(AccountSettingsSection), findsNothing);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);

    await tester.tap(find.text('集成'));
    await pumpTransition();

    final integrations = find.byType(IntegrationsSettingsSection);
    expect(integrations, findsOneWidget);
    final segmentedButton = tester.widget<SegmentedButton<int>>(
      find.descendant(
        of: integrations,
        matching: find.byType(SegmentedButton<int>),
      ),
    );
    expect(segmentedButton.segments.map((segment) => segment.enabled), [
      isTrue,
      isFalse,
    ]);
    expect(find.text('桌面浮层交互'), findsNothing);

    await tester.binding.handlePopRoute();
    await pumpTransition();
    expect(find.byType(IntegrationsSettingsSection), findsNothing);
    expect(find.text('集成'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('桌面端离开智能体设置前保护未保存的系统提示词', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      return tester.binding.setSurfaceSize(null);
    });

    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: Directory.systemTemp,
            workspaceDirectory: Directory.systemTemp,
            environment: const {},
            skillCatalogService: const _EmptySkillCatalogService(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(
                      initialSection: SettingsSection.agent,
                    ),
                  ),
                ),
                child: const Text('打开设置'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开设置'));
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find
          .byKey(const ValueKey('agent-custom-system-prompt'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.byKey(const ValueKey('agent-custom-system-prompt')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('agent-settings-open-integrations')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IntegrationsSettingsSection), findsOneWidget);
    await tester.tap(find.byIcon(Icons.smart_toy_outlined));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-custom-system-prompt')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-custom-system-prompt')),
      '尚未保存',
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('放弃未保存的系统提示词？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('打开设置'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('紧凑智能体草稿由 AppBar 取消并由系统返回确认且各提示一次', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      return tester.binding.setSurfaceSize(null);
    });

    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: Directory.systemTemp,
            workspaceDirectory: Directory.systemTemp,
            environment: const {},
            skillCatalogService: const _EmptySkillCatalogService(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
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
          home: SettingsScreen(initialSection: SettingsSection.agent),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor = find.byKey(const ValueKey('agent-custom-system-prompt'));
    await tester.enterText(editor, '移动端未保存草稿');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的系统提示词？'), findsOneWidget);

    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(editor, findsOneWidget);
    expect(container.read(agentPromptDraftProvider).dirty, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的系统提示词？'), findsOneWidget);

    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的系统提示词？'), findsNothing);
    expect(find.byKey(const ValueKey('settings-section-list')), findsOneWidget);
    expect(container.read(agentPromptDraftProvider).dirty, isFalse);
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('桌面与紧凑布局切换保持当前设置浏览位置', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1280, 700));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      return tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _FakeAccountManagerNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _FakeSubscriptionNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => DesktopWindowFrame(
            enabled: true,
            controller: _NoopDesktopWindowController(),
            child: child!,
          ),
          home: const SettingsScreen(
            initialSection: SettingsSection.integrations,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder contentScrollable() => find.descendant(
      of: find.byKey(const ValueKey('settings-section-scroll-view')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.drag(contentScrollable(), const Offset(0, -360));
    await tester.pumpAndSettle();
    final desktopOffset = tester
        .state<ScrollableState>(contentScrollable())
        .position
        .pixels;
    expect(desktopOffset, greaterThan(0));

    for (final minimizedSize in [Size.zero, const Size(144, 19)]) {
      await tester.binding.setSurfaceSize(minimizedSize);
      await tester.pump();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(IntegrationsSettingsSection), findsOneWidget);
      expect(
        tester.state<ScrollableState>(contentScrollable()).position.pixels,
        closeTo(desktopOffset, 1),
      );
      expect(tester.takeException(), isNull);
    }

    await tester.binding.setSurfaceSize(const Size(1280, 700));
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(IntegrationsSettingsSection), findsOneWidget);
    expect(
      tester.state<ScrollableState>(contentScrollable()).position.pixels,
      closeTo(desktopOffset, 1),
    );

    // A real manual resize still crosses the responsive breakpoint normally.
    await tester.binding.setSurfaceSize(const Size(390, 700));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(contentScrollable()).position.pixels,
      closeTo(desktopOffset, 1),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 700));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(contentScrollable()).position.pixels,
      closeTo(desktopOffset, 1),
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('取消外部 section 切换会恢复 URL 与智能体页面', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      return tester.binding.setSurfaceSize(null);
    });

    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: Directory.systemTemp,
            workspaceDirectory: Directory.systemTemp,
            environment: const {},
            skillCatalogService: const _EmptySkillCatalogService(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      container.read(agentSettingsProvider);
      for (var attempt = 0; attempt < 100; attempt++) {
        if (container.read(agentSettingsProvider).initialized) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('Agent settings did not initialize.');
    });
    final router = GoRouter(
      initialLocation: '/settings?section=agent',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => SettingsScreen(
            initialSection: SettingsSection.fromId(
              state.uri.queryParameters['section'],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('agent-custom-system-prompt')),
      '路由切换前未保存',
    );
    await tester.pump();

    router.go('/settings?section=appearance');
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的系统提示词？'), findsOneWidget);

    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.queryParameters['section'],
      'agent',
    );
    expect(
      find.byKey(const ValueKey('agent-custom-system-prompt')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });
}

void _expectSettingsLayeredChrome(
  WidgetTester tester, {
  bool hasNavigation = false,
}) {
  final appBarFinder = find.byType(AppBar);
  final appBar = tester.widget<AppBar>(appBarFinder);
  final theme = Theme.of(tester.element(appBarFinder));

  expect(appBar.shape, isNull);
  expect(appBar.backgroundColor, sectionSurfaceColor(theme.colorScheme));
  expect(
    find.descendant(
      of: appBarFinder,
      matching: find.byIcon(Icons.settings_outlined),
    ),
    findsOneWidget,
  );
  expect(find.byType(VerticalDivider), findsNothing);

  final navigationSurface = find.byKey(
    const ValueKey('settings-navigation-tonal-surface'),
  );
  if (!hasNavigation) {
    expect(navigationSurface, findsNothing);
    for (final element in find.byType(ListTile).evaluate()) {
      final tile = element.widget as ListTile;
      expect(tile.tileColor, sectionSurfaceColor(theme.colorScheme));
      expect(
        element.findAncestorWidgetOfExactType<Material>()?.type,
        MaterialType.transparency,
      );
    }
    return;
  }

  final decoration =
      tester.widget<Container>(navigationSurface).decoration! as BoxDecoration;
  expect(decoration.color, sectionSurfaceColor(theme.colorScheme));
  expect(decoration.border, isNull);
  expect(decoration.borderRadius, isNotNull);
}
