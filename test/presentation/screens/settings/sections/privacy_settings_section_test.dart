import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/services/danbooru_tags_lazy_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
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

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          danbooruTagsLazyServiceProvider.overrideWith(
            (ref) => Completer<DanbooruTagsLazyService>().future,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: PrivacySettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('包含保护模式与在线画廊黑名单', (tester) async {
    await pumpSection(tester);

    expect(find.text('保护模式'), findsOneWidget);
    expect(find.text('保护功能'), findsOneWidget);
    expect(find.text('复制/拖拽时移除全部元数据'), findsOneWidget);
    expect(find.byType(OnlineGalleryBlacklistSettingsPanel), findsOneWidget);
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
  });

  testWidgets('在线画廊黑名单与主设置卡片宽度一致', (tester) async {
    await pumpSection(tester);

    final primaryCard = find.descendant(
      of: find.byType(SettingsCard),
      matching: find.byType(Card),
    );
    final blacklistCard = find.descendant(
      of: find.byType(OnlineGalleryBlacklistSettingsPanel),
      matching: find.byType(Card),
    );
    expect(primaryCard, findsOneWidget);
    expect(blacklistCard, findsOneWidget);

    final primaryRect = tester.getRect(primaryCard);
    final blacklistRect = tester.getRect(blacklistCard);

    expect(blacklistRect.left, primaryRect.left);
    expect(blacklistRect.right, primaryRect.right);
    expect(blacklistRect.width, primaryRect.width);
  });
}
