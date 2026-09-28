import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/add_character_buttons.dart';

/// 到达官方角色上限后 addCharacter 只写日志就 return。上游没有在这个组件里
/// 做任何上限判断，触屏上只有 tooltip 等于没有提示，这里锁住"变灰 + 点击有
/// 可见反馈"两条行为。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_add_character_limit_hive_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  Future<ProviderContainer> pumpButtons(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: AddCharacterButtons(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('未到上限时添加入口可用且不挂禁用原因', (tester) async {
    final container = await pumpButtons(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(container.read(characterLimitReachedProvider), isFalse);
    expect(find.byType(Tooltip), findsNothing);

    await tester.tap(find.text(l10n.characterEditor_addFemale));
    await tester.pump();

    expect(
      container.read(characterPromptNotifierProvider).characters,
      hasLength(1),
    );
  });

  testWidgets('到达角色上限后四个入口禁用并在点击时给出提示', (tester) async {
    final container = await pumpButtons(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    final notifier = container.read(characterPromptNotifierProvider.notifier);
    final limit = notifier.characterLimit;
    for (var i = 0; i < limit; i++) {
      notifier.addCharacter(CharacterGender.female);
    }
    await tester.pump();

    expect(container.read(characterLimitReachedProvider), isTrue);

    final message = l10n.character_limitReached(limit.toString());
    // 女 / 男 / 其他 / 词库 四个入口全部进入禁用态并挂上同一句原因
    expect(find.byTooltip(message), findsNWidgets(4));

    await tester.tap(find.text(l10n.characterEditor_addFemale));
    await tester.pump();

    // 点击不再添加角色，而是弹出提示（触屏没有 hover，只给 tooltip 等于没提示）
    expect(
      container.read(characterPromptNotifierProvider).characters,
      hasLength(limit),
    );
    expect(find.text(message), findsOneWidget);

    // 放掉 toast 的自动消失定时器，避免遗留 pending timer
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
