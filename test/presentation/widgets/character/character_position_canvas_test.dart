import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/character_position_canvas.dart';

/// 惰性生成状态：真实 Notifier 内部有持续性任务会阻止测试进程退出
class _IdleImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveCharacterChipDisplay', () {
    CharacterPrompt buildCharacter({
      String name = 'Character 1',
      String prompt = '',
    }) {
      return CharacterPrompt(id: 'id', name: name, prompt: prompt);
    }

    test('首 tag 为 girl 时显示女性符号且名称取第二个 tag', () {
      final display = resolveCharacterChipDisplay(
        buildCharacter(prompt: 'girl, hahaha, qw'),
      );
      expect(display.genderIcon, Icons.female);
      expect(display.label, 'hahaha');
    });

    test('首 tag 为 1boy 时显示男性符号', () {
      final display = resolveCharacterChipDisplay(
        buildCharacter(prompt: '1boy, 1231'),
      );
      expect(display.genderIcon, Icons.male);
      expect(display.label, '1231');
    });

    test('首 tag 非性别时无符号且名称取首 tag', () {
      final display = resolveCharacterChipDisplay(
        buildCharacter(prompt: 'silver hair, maid'),
      );
      expect(display.genderIcon, isNull);
      expect(display.label, 'silver hair');
    });

    test('只有性别 tag 时无名称', () {
      final display = resolveCharacterChipDisplay(
        buildCharacter(prompt: 'girl,'),
      );
      expect(display.genderIcon, Icons.female);
      expect(display.label, isNull);
    });

    test('空提示词无符号无名称', () {
      final display = resolveCharacterChipDisplay(buildCharacter());
      expect(display.genderIcon, isNull);
      expect(display.label, isNull);
    });

    test('自定义名称优先于提示词提取', () {
      final display = resolveCharacterChipDisplay(
        buildCharacter(name: '爱丽丝', prompt: 'girl, hahaha'),
      );
      expect(display.genderIcon, Icons.female);
      expect(display.label, '爱丽丝');
    });
  });

  group('CharacterPrompt.effectiveGender', () {
    CharacterPrompt buildCharacter(String prompt) {
      return CharacterPrompt(id: 'id', name: 'n', prompt: prompt);
    }

    test('提示词首 tag 决定有效性别', () {
      expect(buildCharacter('girl, x').effectiveGender, CharacterGender.female);
      expect(buildCharacter('1BOY, y').effectiveGender, CharacterGender.male);
      // gender 字段是 male，但提示词首 tag 是 girl → 显示为女
      expect(
        const CharacterPrompt(
          id: 'id',
          name: 'n',
          gender: CharacterGender.male,
          prompt: 'girl, x',
        ).effectiveGender,
        CharacterGender.female,
      );
    });

    test('首 tag 非性别或空提示词时为其他', () {
      expect(
        buildCharacter('silver hair, girl').effectiveGender,
        CharacterGender.other,
      );
      expect(buildCharacter('').effectiveGender, CharacterGender.other);
    });
  });

  group('CharacterPromptConfig 默认位置', () {
    test('addCharacter 产生的默认位置均为 0-1 百分比', () {
      var config = const CharacterPromptConfig();
      for (var i = 0; i < 6; i++) {
        config = config.addCharacter(gender: CharacterGender.female);
      }
      for (final character in config.characters) {
        final position = character.customPosition;
        expect(position, isNotNull);
        expect(position!.row, inInclusiveRange(0.0, 1.0));
        expect(position.column, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('CharacterPositionCanvasView', () {
    late Directory hiveTempDir;

    setUpAll(() async {
      hiveTempDir = await Directory.systemTemp.createTemp(
        'nai_launcher_position_canvas_hive_',
      );
      Hive.init(hiveTempDir.path);
      await Hive.openBox(StorageKeys.settingsBox);
    });

    tearDownAll(() async {
      // 不调用 Hive.close()：widget 测试的 fake async 环境可能给 box
      // 留下悬置的写锁，close 会永远等待；进程退出时锁自然释放。
      try {
        await hiveTempDir.delete(recursive: true);
      } catch (_) {
        // Windows 下文件占用时删除失败可容忍，系统临时目录会被清理
      }
    });

    setUp(() async {
      await Hive.box(StorageKeys.settingsBox).clear();
    });

    Widget buildTestApp() {
      return ProviderScope(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(
            _IdleImageGenerationNotifier.new,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CharacterPositionCanvasView()),
        ),
      );
    }

    testWidgets('自定义模式显示锚点，AI 选择模式隐藏锚点', (tester) async {
      await tester.pumpWidget(buildTestApp());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CharacterPositionCanvasView)),
      );
      final notifier = container.read(characterPromptNotifierProvider.notifier);
      notifier.addCharacter(CharacterGender.female, name: 'Alice');
      notifier.addCharacter(CharacterGender.male, name: 'Bob');
      notifier.setGlobalAiChoice(false);
      // 预览区 provider 链可能存在持续性 timer，用固定帧替代 pumpAndSettle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Alice'), findsOneWidget);
      expect(find.byTooltip('Bob'), findsOneWidget);

      // 切到 AI 选择：锚点隐藏，位置数据保留
      notifier.setGlobalAiChoice(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Alice'), findsNothing);
      expect(
        container
            .read(characterPromptNotifierProvider)
            .characters
            .first
            .customPosition,
        isNotNull,
      );
    });
  });
}
