import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/generation_screen.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/quick_tools_drawer.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_number_input.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_scaffold.dart';

import '../../../helpers/flutter_error_collector.dart';

/// 生成页移动端的抽屉槽位分工与底栏批量计数。
///
/// 上游 v4.2.1 是 drawer=参数面板 / endDrawer=历史，我们是
/// drawer=快捷工具 / endDrawer=参数面板 / 历史走底部面板。这几条断言存在的
/// 唯一目的，就是让下一轮跟上游时「照搬上游槽位」立刻失败。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('generation-drawer-');
    Hive.init(hiveDirectory.path);
    // 与上游 generation_screen_responsive_test（aa743762）同一修法：内存后端。
    // 落盘写一旦从 widget test 的 FakeAsync 时钟发起就不会完成，会锁死 box，
    // tearDownAll 的 Hive.close() 随之永久挂起。
    await Hive.openBox<dynamic>(StorageKeys.settingsBox, bytes: Uint8List(0));
    await Hive.openBox<dynamic>(StorageKeys.historyBox, bytes: Uint8List(0));
  });

  tearDownAll(() async {
    PlatformCapabilities.debugOverride = null;
    // 有界等待：box 被锁死时快速失败，而不是拖到看门狗超时
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  testWidgets('移动端左抽屉是快捷工具、参数面板在右抽屉、历史不占抽屉槽位', (tester) async {
    final flutterErrors = FlutterErrorCollector.install(tester);
    addTearDown(flutterErrors.restoreAndAssertNoErrors);
    await _pumpMobileGeneration(tester);

    final scaffold = tester.widget<ThemedScaffold>(find.byType(ThemedScaffold));
    expect(scaffold.drawer, isA<GenerationQuickToolsDrawer>());
    expect(
      (scaffold.endDrawer! as Drawer).key,
      const ValueKey('generation-parameters-drawer'),
    );
    expect(
      find.byKey(const ValueKey('generation-quick-tools-drawer-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('generation-history-panel-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('generation-import-metadata-action')),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('顶栏一击打开快捷工具抽屉并可切到角色页', (tester) async {
    final flutterErrors = FlutterErrorCollector.install(tester);
    addTearDown(flutterErrors.restoreAndAssertNoErrors);
    await _pumpMobileGeneration(tester);

    await tester.tap(
      find.byKey(const ValueKey('generation-quick-tools-drawer-action')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GenerationQuickToolsDrawer), findsOneWidget);
    expect(
      find.byKey(const ValueKey('generation-quick-tools-manage-fixed-tags')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('generation-quick-tools-tabs')),
        matching: find.byIcon(Icons.people_outline),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('generation-quick-tools-manage-characters')),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('移动端底栏带回 ×N 批量计数', (tester) async {
    final flutterErrors = FlutterErrorCollector.install(tester);
    addTearDown(flutterErrors.restoreAndAssertNoErrors);
    await _pumpMobileGeneration(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('generation-mobile-queue-actions')),
        matching: find.byType(DraggableNumberInput),
      ),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _pumpMobileGeneration(WidgetTester tester) async {
  PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
    TargetPlatform.android,
  );
  await tester.binding.setSurfaceSize(const Size(390, 760));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          _FakeShortcutConfigNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: GenerationScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
