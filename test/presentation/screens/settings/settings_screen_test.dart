import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/account_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/appearance_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/integrations_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/prompt_assistant_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_screen.dart';

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
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('settings_screen_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('设置页导航为 9 个分类', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations.length, 9);

    final labels = rail.destinations
        .map((destination) => (destination.label as Text).data)
        .toList();
    expect(labels, const [
      '账户',
      '外观',
      '生成',
      '数据与存储',
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
      Icons.storage_outlined,
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
      Icons.storage,
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
      find.descendant(of: promptAssistantSection, matching: find.text('提示词助手')),
      findsOneWidget,
    );
    expect(segmentLabels, const ['提示词助手', 'ComfyUI', 'Krita']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('新增服务商弹窗在移动端完整适配窄屏', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

    await tester.tap(find.text('集成'));
    await tester.pumpAndSettle();

    final addProvider = find.byKey(
      const ValueKey('prompt-assistant-add-provider'),
    );
    await tester.scrollUntilVisible(addProvider, 200);
    await tester.tap(addProvider);
    await tester.pumpAndSettle();

    final dialog = find.byKey(
      const ValueKey('prompt-assistant-provider-dialog'),
    );
    expect(dialog, findsOneWidget);
    expect(find.text('OpenAI Chat Completions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final selectedProtocolRect = tester.getRect(
      find.text('OpenAI Chat Completions'),
    );
    expect(selectedProtocolRect.left, greaterThanOrEqualTo(36));
    expect(selectedProtocolRect.right, lessThanOrEqualTo(330));

    await tester.tap(find.text('保存'));
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
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();

    expect(find.byType(AppearanceSettingsSection), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.bySemanticsLabel('外观'), findsWidgets);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountSettingsSection), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AccountSettingsSection), findsNothing);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);

    await tester.tap(find.text('集成'));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    expect(find.byType(IntegrationsSettingsSection), findsNothing);
    expect(find.text('集成'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
