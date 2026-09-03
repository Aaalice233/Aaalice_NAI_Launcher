import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/services/danbooru_tags_lazy_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/share_image_settings_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/privacy_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_card.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/blacklist_settings_panel.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('privacy_settings_hive_');
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

  Future<void> pumpSection(
    WidgetTester tester, {
    Size size = const Size(1000, 2000),
    double textScale = 1,
    double bottomInset = 0,
    EdgeInsets safePadding = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          danbooruTagsLazyServiceProvider.overrideWith(
            (ref) => Completer<DanbooruTagsLazyService>().future,
          ),
          shareImageSettingsProvider.overrideWith(
            _TestShareImageSettingsNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: safePadding,
              viewPadding: safePadding,
              viewInsets: EdgeInsets.only(bottom: bottomInset),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: PrivacySettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('包含保护模式、水印与在线画廊黑名单', (tester) async {
    await pumpSection(tester);

    expect(find.text('保护模式'), findsOneWidget);
    expect(find.text('保护功能'), findsOneWidget);
    expect(find.text('复制/拖拽时移除全部元数据'), findsOneWidget);
    expect(find.text('限制生图频率'), findsOneWidget);
    expect(find.text('生图间隔'), findsOneWidget);
    expect(find.text('水印'), findsOneWidget);
    expect(find.text('启用水印工具'), findsOneWidget);
    expect(find.text('水印副本保留元数据'), findsOneWidget);
    expect(find.byType(OnlineGalleryBlacklistSettingsPanel), findsOneWidget);
  });

  for (final width in [320.0, 600.0, 840.0, 1600.0]) {
    testWidgets('隐私设置在 ${width.toInt()} 宽度无布局异常', (tester) async {
      await pumpSection(
        tester,
        size: Size(width, width == 320 ? 520 : 1200),
        textScale: width == 320 ? 3 : 1,
      );

      expect(find.text('保护模式'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320 宽、3x 文本、IME 和 SafeArea 下数字编辑器仍可用', (tester) async {
    const safePadding = EdgeInsets.fromLTRB(8, 24, 8, 16);
    await pumpSection(
      tester,
      size: const Size(320, 568),
      textScale: 3,
      bottomInset: 160,
      safePadding: safePadding,
    );

    await tester.tap(find.text('保护模式'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Anlas 警告阈值'));
    await tester.tap(find.text('Anlas 警告阈值'));
    await tester.pumpAndSettle();

    final panel = find.byWidgetPredicate(
      (widget) =>
          widget.key == const ValueKey('adaptive-full-screen-form') ||
          widget.key == const ValueKey('adaptive-centered-form'),
    );
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: panel, matching: find.byType(TextField)),
      findsOne,
    );
    await tester.ensureVisible(find.text('保存'));
    expect(find.text('保存'), findsOneWidget);
    final panelRect = tester.getRect(panel);
    expect(panelRect.left, greaterThanOrEqualTo(safePadding.left));
    expect(panelRect.top, greaterThanOrEqualTo(safePadding.top));
    expect(panelRect.right, lessThanOrEqualTo(320 - safePadding.right));
    expect(panelRect.bottom, lessThanOrEqualTo(568 - 160 - safePadding.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('两个数字编辑器保留校验与保存返回语义', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('保护模式'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Anlas 警告阈值'));
    await tester.tap(find.text('Anlas 警告阈值'));
    await tester.pumpAndSettle();
    var panel = find.byWidgetPredicate(
      (widget) =>
          widget.key == const ValueKey('adaptive-centered-form') ||
          widget.key == const ValueKey('adaptive-side-sheet'),
    );
    var editor = find.descendant(of: panel, matching: find.byType(TextField));
    await tester.enterText(editor, '0');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    await tester.enterText(editor, '75');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('75 Anlas'), findsOneWidget);

    await tester.ensureVisible(find.text('限制生图频率'));
    await tester.tap(find.text('限制生图频率'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('生图间隔'));
    await tester.tap(find.text('生图间隔'));
    await tester.pumpAndSettle();
    panel = find.byWidgetPredicate(
      (widget) =>
          widget.key == const ValueKey('adaptive-centered-form') ||
          widget.key == const ValueKey('adaptive-side-sheet'),
    );
    editor = find.descendant(of: panel, matching: find.byType(TextField));
    await tester.enterText(editor, '3601');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    await tester.enterText(editor, '30');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('30 秒'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保护模式卡片保留整卡点击并控制子设置', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('保护模式'));
    await tester.pumpAndSettle();

    final protectionSwitch = tester.widget<Switch>(
      find.descendant(
        of: find.byType(SettingsCard).first,
        matching: find.byType(Switch),
      ),
    );
    expect(protectionSwitch.value, isTrue);

    final stripTile = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('复制/拖拽时移除全部元数据'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(stripTile.onChanged, isNotNull);
  });

  testWidgets('保护模式关闭时子开关不可用', (tester) async {
    await pumpSection(tester);

    final stripTile = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('复制/拖拽时移除全部元数据'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(stripTile.onChanged, isNull);

    final intervalSwitch = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('限制生图频率'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(intervalSwitch.onChanged, isNull);

    final intervalTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('生图间隔'), matching: find.byType(ListTile)),
    );
    expect(intervalTile.onTap, isNull);
  });

  testWidgets('在线画廊黑名单与全部主设置卡片宽度一致', (tester) async {
    await pumpSection(tester);

    final settingsCards = find.descendant(
      of: find.byType(SettingsCard),
      matching: find.byType(Card),
    );
    final blacklistPanel = find.byType(OnlineGalleryBlacklistSettingsPanel);
    final blacklistCard = find.ancestor(
      of: blacklistPanel,
      matching: find.byType(Card),
    );
    expect(settingsCards, findsNWidgets(4));
    expect(blacklistCard, findsOneWidget);
    expect(
      find.descendant(of: blacklistPanel, matching: find.byType(Card)),
      findsNothing,
    );

    final primaryRect = tester.getRect(settingsCards.first);
    final blacklistRect = tester.getRect(blacklistCard);

    for (var index = 1; index < 4; index++) {
      final sectionRect = tester.getRect(settingsCards.at(index));
      expect(sectionRect.left, primaryRect.left);
      expect(sectionRect.right, primaryRect.right);
      expect(sectionRect.width, primaryRect.width);
    }
    expect(blacklistRect.left, primaryRect.left);
    expect(blacklistRect.right, primaryRect.right);
    expect(blacklistRect.width, primaryRect.width);
  });
}

class _TestShareImageSettingsNotifier extends ShareImageSettingsNotifier {
  @override
  ShareImageSettings build() => const ShareImageSettings();

  @override
  Future<void> setProtectionMode(bool value) async {
    state = state.copyWith(protectionMode: value);
  }

  @override
  Future<void> setHighAnlasCostThreshold(int value) async {
    state = state.copyWith(highAnlasCostThreshold: value);
  }

  @override
  Future<void> setLimitGenerationInterval(bool value) async {
    state = state.copyWith(limitGenerationInterval: value);
  }

  @override
  Future<void> setGenerationIntervalSeconds(int value) async {
    state = state.copyWith(generationIntervalSeconds: value);
  }
}
