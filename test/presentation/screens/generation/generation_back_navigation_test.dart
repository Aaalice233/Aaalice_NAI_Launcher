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
import 'package:nai_launcher/presentation/providers/generation/image_card_selection_provider.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_maximize_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/desktop_layout.dart';
import 'package:nai_launcher/presentation/screens/generation/generation_screen.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_layout.dart';
import 'package:nai_launcher/presentation/screens/generation/web_style_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'generation-back-navigation-',
    );
    Hive.init(hiveDirectory.path);
    // 内存后端：落盘写一旦从 widget test 的 FakeAsync 时钟发起就不会完成，会锁死 box
    await Hive.openBox<dynamic>(StorageKeys.settingsBox, bytes: Uint8List(0));
    await Hive.openBox<dynamic>(StorageKeys.historyBox, bytes: Uint8List(0));
  });

  tearDownAll(() async {
    PlatformCapabilities.debugOverride = null;
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  testWidgets('手机返回键先退出预览多选，再交还路由', (tester) async {
    final container = await _pumpGeneration(tester, const Size(360, 760));
    expect(find.byType(MobileGenerationLayout), findsOneWidget);

    container.read(generationImageCardSelectionProvider.notifier).enter();
    await tester.pump();

    expect(await _systemBack(tester), isTrue);
    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isFalse,
    );

    expect(await _systemBack(tester), isFalse);
    await _disposeGeneration(tester);
  });

  testWidgets('手机返回键依次关闭提示词编辑器与多选', (tester) async {
    final container = await _pumpGeneration(tester, const Size(360, 760));
    container.read(generationImageCardSelectionProvider.notifier).enter();
    await container
        .read(promptMaximizeNotifierProvider.notifier)
        .setMaximized(true);
    await tester.pump();

    expect(await _systemBack(tester), isTrue);
    expect(container.read(promptMaximizeNotifierProvider), isFalse);
    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isTrue,
    );

    expect(await _systemBack(tester), isTrue);
    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isFalse,
    );
    await _disposeGeneration(tester);
  });

  testWidgets('历史抽屉内多选时返回键先退出多选，再关闭抽屉', (tester) async {
    final container = await _pumpGeneration(tester, const Size(360, 760));
    await tester.tap(
      find.byKey(const ValueKey('generation-history-drawer-action')),
    );
    await tester.pumpAndSettle();
    final drawer = find.byKey(const ValueKey('generation-history-drawer'));
    expect(drawer, findsOneWidget);

    container.read(generationImageCardSelectionProvider.notifier).enter();
    await tester.pump();

    expect(await _systemBack(tester), isTrue);
    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isFalse,
    );
    expect(drawer, findsOneWidget);

    expect(await _systemBack(tester), isTrue);
    expect(drawer, findsNothing);
    await _disposeGeneration(tester);
  });

  testWidgets('参数抽屉遮住预览多选时返回键先关闭抽屉', (tester) async {
    final container = await _pumpGeneration(tester, const Size(360, 760));
    container.read(generationImageCardSelectionProvider.notifier).enter();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('generation-parameters-drawer-action')),
    );
    await tester.pumpAndSettle();
    final drawer = find.byKey(const ValueKey('generation-parameters-drawer'));
    expect(drawer, findsOneWidget);

    expect(await _systemBack(tester), isTrue);
    expect(drawer, findsNothing);
    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isTrue,
    );

    expect(await _systemBack(tester), isTrue);
    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isFalse,
    );
    await _disposeGeneration(tester);
  });

  testWidgets('手机固定词浮层盖住编辑器时返回键只关闭浮层', (tester) async {
    final container = await _pumpGeneration(tester, const Size(360, 760));
    container.read(generationImageCardSelectionProvider.notifier).enter();
    await container
        .read(promptMaximizeNotifierProvider.notifier)
        .setMaximized(true);
    await container
        .read(layoutStateNotifierProvider.notifier)
        .setFixedTagsSidebarExpanded(true);
    await tester.pump();
    final overlay = find.byKey(const Key('generation-fixed-tags-overlay'));
    expect(overlay, findsOneWidget);

    expect(await _systemBack(tester), isTrue);
    expect(overlay, findsNothing);
    expect(container.read(promptMaximizeNotifierProvider), isTrue);
    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isTrue,
    );

    expect(await _systemBack(tester), isTrue);
    expect(container.read(promptMaximizeNotifierProvider), isFalse);
    expect(await _systemBack(tester), isTrue);
    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isFalse,
    );
    expect(await _systemBack(tester), isFalse);
    await _disposeGeneration(tester);
  });

  testWidgets('平板宽度的生成页返回键同样先退出多选', (tester) async {
    final container = await _pumpGeneration(tester, const Size(1180, 820));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DesktopGenerationLayout ||
            widget is WebStyleGenerationLayout,
      ),
      findsOneWidget,
    );

    container.read(generationImageCardSelectionProvider.notifier).enter();
    await tester.pump();

    expect(await _systemBack(tester), isTrue);
    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isFalse,
    );

    expect(await _systemBack(tester), isFalse);
    await _disposeGeneration(tester);
  });
}

Future<ProviderContainer> _pumpGeneration(
  WidgetTester tester,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      shortcutConfigNotifierProvider.overrideWith(
        _FakeShortcutConfigNotifier.new,
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  return container;
}

// 返回值即路由是否消费了这次返回；false 表示交还给系统。
Future<bool> _systemBack(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return handled;
}

Future<void> _disposeGeneration(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  // Token 计数有 400ms 防抖，先走完计时器再释放 container。
  await tester.pump(const Duration(milliseconds: 400));
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
