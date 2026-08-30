import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/repositories/character_prompt_repository.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/character_position_canvas.dart';
import 'package:nai_launcher/presentation/widgets/common/composition_guide.dart';
import 'package:nai_launcher/presentation/widgets/common/decoded_memory_image.dart';

/// 惰性生成状态：真实 Notifier 内部有持续性任务会阻止测试进程退出
class _IdleImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();
}

class _WidePreviewImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() {
    return ImageGenerationState(
      displayImages: [
        GeneratedImage(
          id: 'wide-preview',
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0l'
            'EQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          width: 1000,
          height: 10,
        ),
      ],
    );
  }
}

class _PortraitPreviewImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() {
    return ImageGenerationState(
      displayImages: [
        GeneratedImage(
          id: 'portrait-preview',
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0l'
            'EQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          width: 832,
          height: 1216,
        ),
      ],
    );
  }
}

/// 构图参考线设置走 Hive，测试里没开 box，写入会抛，用内存版顶掉
class _MemoryStorage extends LocalStorageService {
  String? guideMode;
  int guideColumns = CompositionGuide.defaultDivisions;
  int guideRows = CompositionGuide.defaultDivisions;

  @override
  String? getCompositionGuideMode() => guideMode;

  @override
  Future<void> setCompositionGuideMode(String value) async => guideMode = value;

  @override
  int getCompositionGuideColumns() => guideColumns;

  @override
  Future<void> setCompositionGuideColumns(int value) async =>
      guideColumns = value;

  @override
  int getCompositionGuideRows() => guideRows;

  @override
  Future<void> setCompositionGuideRows(int value) async => guideRows = value;
}

class _MemoryCharacterPromptRepository extends CharacterPromptRepository {
  CharacterPromptConfig config = const CharacterPromptConfig();

  @override
  CharacterPromptConfig load() => config;

  @override
  Future<bool> save(CharacterPromptConfig value) async {
    config = value;
    return true;
  }
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
    test('AI 布局新增角色不预填手动坐标', () {
      var config = const CharacterPromptConfig();
      for (var i = 0; i < 6; i++) {
        config = config.addCharacter(gender: CharacterGender.female);
      }
      for (final character in config.characters) {
        expect(character.positionMode, CharacterPositionMode.aiChoice);
        expect(character.customPosition, isNull);
      }
    });

    test('自定义布局新增角色会分配有效手动坐标', () {
      var config = const CharacterPromptConfig(globalAiChoice: false);
      for (var i = 0; i < 6; i++) {
        config = config.addCharacter(gender: CharacterGender.female);
      }
      for (final character in config.characters) {
        final position = character.customPosition;
        expect(character.positionMode, CharacterPositionMode.custom);
        expect(position, isNotNull);
        expect(position!.row, inInclusiveRange(0.0, 1.0));
        expect(position.column, inInclusiveRange(0.0, 1.0));
      }
    });

    test('六角色自定义布局会为每个角色生成稳定连续坐标', () {
      final characters = List<CharacterPrompt>.generate(
        6,
        (index) => CharacterPrompt(
          id: 'character-$index',
          name: 'Character ${index + 1}',
          prompt: 'character $index',
        ),
      );

      final config = CharacterPromptConfig(
        characters: characters,
        globalAiChoice: false,
      ).normalizeCustomPositions();

      expect(config.characters, hasLength(6));
      expect(
        config.characters.every(
          (character) =>
              character.positionMode == CharacterPositionMode.custom &&
              character.customPosition != null,
        ),
        isTrue,
      );
      expect(config.characters.last.customPosition?.column, 0.8);
      expect(config.characters.last.customPosition?.row, 0.75);
    });
  });

  group('CharacterPositionCanvasView', () {
    Widget buildTestApp() {
      return ProviderScope(
        overrides: [
          characterPromptRepositoryProvider.overrideWith(
            (ref) => _MemoryCharacterPromptRepository(),
          ),
          imageGenerationNotifierProvider.overrideWith(
            _IdleImageGenerationNotifier.new,
          ),
          localStorageServiceProvider.overrideWith((ref) => _MemoryStorage()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CharacterPositionCanvasView()),
        ),
      );
    }

    Widget buildWidePreviewTestApp() {
      return ProviderScope(
        overrides: [
          characterPromptRepositoryProvider.overrideWith(
            (ref) => _MemoryCharacterPromptRepository(),
          ),
          imageGenerationNotifierProvider.overrideWith(
            _WidePreviewImageGenerationNotifier.new,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CharacterPositionCanvasView()),
        ),
      );
    }

    Widget buildPortraitPreviewTestApp() {
      return ProviderScope(
        overrides: [
          characterPromptRepositoryProvider.overrideWith(
            (ref) => _MemoryCharacterPromptRepository(),
          ),
          imageGenerationNotifierProvider.overrideWith(
            _PortraitPreviewImageGenerationNotifier.new,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CharacterPositionCanvasView()),
        ),
      );
    }

    test('replaceAll 和重新启用会在自定义模式补齐全部坐标', () async {
      final container = ProviderContainer(
        overrides: [
          characterPromptRepositoryProvider.overrideWith(
            (ref) => _MemoryCharacterPromptRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(characterPromptNotifierProvider.notifier);
      notifier.setGlobalAiChoice(false);
      notifier.replaceAll(
        List<CharacterPrompt>.generate(
          6,
          (index) => CharacterPrompt(
            id: 'replace-$index',
            name: 'Character ${index + 1}',
            prompt: 'character $index',
          ),
        ),
      );

      var config = container.read(characterPromptNotifierProvider);
      expect(
        config.characters.every(
          (character) => character.customPosition != null,
        ),
        isTrue,
      );
      expect(config.characters.last.customPosition?.column, 0.8);
      expect(config.characters.last.customPosition?.row, 0.75);

      final last = config.characters.last;
      notifier.updateCharacter(
        last.copyWith(
          enabled: false,
          positionMode: CharacterPositionMode.aiChoice,
          customPosition: null,
        ),
      );
      notifier.toggleCharacterEnabled(last.id);

      config = container.read(characterPromptNotifierProvider);
      expect(config.characters.last.enabled, isTrue);
      expect(config.characters.last.customPosition, isNotNull);
      await Future<void>.delayed(Duration.zero);
    });

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

    testWidgets('构图参考线选档后叠到画布，且不吃锚点手势', (tester) async {
      await tester.pumpWidget(buildTestApp());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CharacterPositionCanvasView)),
      );
      final notifier = container.read(characterPromptNotifierProvider.notifier);
      notifier.addCharacter(CharacterGender.female, name: 'Alice');
      notifier.setGlobalAiChoice(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final guideLayer = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is CompositionGuidePainter,
      );
      expect(guideLayer, findsNothing);

      final characterId = container
          .read(characterPromptNotifierProvider)
          .characters
          .single
          .id;
      double columnOf() => container
          .read(characterPromptNotifierProvider)
          .characters
          .single
          .customPosition!
          .column;
      // 分多段推：单次位移要超过 kPanSlop 才会被识别成 pan
      Future<void> dragAnchor() async {
        final gesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(ValueKey<String>('canvas-anchor-$characterId')),
          ),
        );
        for (var step = 0; step < 3; step++) {
          await gesture.moveBy(const Offset(20, 20));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();
      }

      final origin = columnOf();
      await dragAnchor();
      final withoutGuide = columnOf();
      expect(withoutGuide, greaterThan(origin));

      await tester.tap(find.byTooltip('Composition Guide'));
      await tester.pump();
      await tester.tap(find.text('Thirds'));
      await tester.pump();

      expect(guideLayer, findsOneWidget);

      // 收起浮层回到画布：参考线盖在锚点之上，但不能截走拖动
      await tester.tap(find.byTooltip('Composition Guide'));
      await tester.pump();
      expect(find.text('Thirds'), findsNothing);

      await dragAnchor();
      expect(columnOf(), greaterThan(withoutGuide));
    });

    testWidgets('极矮画布真实拖动不抛异常并限制背景解码尺寸', (tester) async {
      await tester.pumpWidget(buildWidePreviewTestApp());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CharacterPositionCanvasView)),
      );
      container
          .read(generationParamsNotifierProvider.notifier)
          .updateSize(1000, 10, persist: false);
      final notifier = container.read(characterPromptNotifierProvider.notifier);
      notifier.addCharacter(CharacterGender.female, name: 'Alice');
      notifier.setGlobalAiChoice(false);
      await tester.pump();

      final character = container
          .read(characterPromptNotifierProvider)
          .characters
          .single;
      final anchor = find.byKey(
        ValueKey<String>('canvas-anchor-${character.id}'),
      );
      expect(anchor, findsOneWidget);
      expect(find.byType(DecodedMemoryImage), findsOneWidget);

      await tester.drag(
        anchor,
        const Offset(4, 1),
        touchSlopX: 0,
        touchSlopY: 0,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        container
            .read(characterPromptNotifierProvider)
            .characters
            .single
            .customPosition,
        isNotNull,
      );
    });

    testWidgets('已有纵向预览图时切换横向分辨率会更新画布宽高比', (tester) async {
      await tester.pumpWidget(buildPortraitPreviewTestApp());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CharacterPositionCanvasView)),
      );

      container
          .read(generationParamsNotifierProvider.notifier)
          .updateSize(1216, 832, persist: false);
      await tester.pump();

      final canvas = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(canvas.aspectRatio, closeTo(1216 / 832, 0.0001));
      expect(find.byType(DecodedMemoryImage), findsOneWidget);
    });
  });
}
