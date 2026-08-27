import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_card.dart';

void main() {
  late Directory hiveTempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_inline_character_hive_',
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
    // 关闭自动补全，避免编辑器挂载时初始化标签数据库（测试环境不可用）
    await Hive.box(
      StorageKeys.settingsBox,
    ).put(StorageKeys.enableAutocomplete, false);
  });

  const character = CharacterPrompt(
    id: 'char-1',
    name: 'Alice',
    prompt: 'girl, silver hair, maid dress',
  );

  Widget buildTestApp({CharacterPrompt target = character}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: InlineCharacterCard(character: target, index: 0, total: 1),
            ),
          ),
        ),
      ),
    );
  }

  group('InlineCharacterCard', () {
    testWidgets('未选中时显示名字与提示词只读预览', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byKey(const Key('character-gender-female')), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('girl, silver hair, maid dress'), findsOneWidget);
      // 未选中时不显示正/负切换标签
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('点击预览区选中角色进入编辑态', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  capturedRef = ref;
                  return const SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                      child: InlineCharacterCard(
                        character: character,
                        index: 0,
                        total: 1,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('girl, silver hair, maid dress'));
      // 编辑态输入框光标闪烁动画不会停，避免 pumpAndSettle 超时
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(capturedRef.read(selectedCharacterIdProvider), equals('char-1'));
      // 编辑态显示输入框
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('禁用的角色整卡半透明', (tester) async {
      await tester.pumpWidget(
        buildTestApp(target: character.copyWith(enabled: false)),
      );
      await tester.pumpAndSettle();

      final opacityWidget = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(opacityWidget.opacity, closeTo(0.48, 0.001));
    });

    testWidgets('窄屏三点菜单完整显示所有操作且不 overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('character-actions-menu')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(InlineCharacterCard)),
      )!;
      expect(find.text(l10n.characterEditor_moveUp), findsOneWidget);
      expect(find.text(l10n.characterEditor_moveDown), findsOneWidget);
      expect(find.text(l10n.tagLibrary_addToLibrary), findsOneWidget);
      expect(find.text(l10n.common_delete), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
