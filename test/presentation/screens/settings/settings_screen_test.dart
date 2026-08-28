import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/screens/cloud_sync/cloud_sync_screen.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/account_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/appearance_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/integrations_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/prompt_assistant_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_screen.dart';

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

  testWidgets('设置页导航包含独立同步与备份分类', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations.length, 10);

    final labels = rail.destinations
        .map((destination) => (destination.label as Text).data)
        .toList();
    expect(labels, const [
      '账户',
      '外观',
      '生成',
      '数据与存储',
      '同步与备份',
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

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);

    await tester.tap(find.text('外观'));
    await pumpTransition();

    expect(find.byType(AppearanceSettingsSection), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.bySemanticsLabel('外观'), findsWidgets);

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
}
