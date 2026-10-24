import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_options.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/director/director_emotion.dart';
import 'package:nai_launcher/data/models/director/director_prompt_params.dart';
import 'package:nai_launcher/data/models/director/director_tool_output.dart';
import 'package:nai_launcher/data/models/director/director_tool_type.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/director_tools_notifier.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

final Uint8List _resultBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

final PixelSnapOutput _pixelSnapOutput = PixelSnapOutput(
  pngBytes: _resultBytes,
  snappedWidth: 64,
  snappedHeight: 48,
  outputWidth: 64,
  outputHeight: 48,
  pitchX: 8,
  pitchY: 8,
  paletteSize: 12,
  downscaledForAnalysis: false,
);

/// 直接带着"已经跑出结果"的状态开局，免得为了造结果去真跑一遍引擎。
class _SeededDirectorToolsNotifier extends DirectorToolsNotifier {
  @override
  DirectorToolsState build() {
    return DirectorToolsState(
      selectedTool: DirectorToolType.pixelSnap,
      sourceImage: _resultBytes,
      results: <DirectorToolImage>[DirectorToolImage(_resultBytes)],
      pixelSnapResult: _pixelSnapOutput,
      imageWidth: 512,
      imageHeight: 512,
    );
  }
}

DirectorToolsNotifier _seededNotifier(ProviderContainer container) =>
    container.read(directorToolsNotifierProvider.notifier);

void main() {
  group('DirectorToolsState.estimatedAnlasCost', () {
    test('本地工具恒为 0', () {
      const DirectorToolsState state = DirectorToolsState(
        selectedTool: DirectorToolType.pixelSnap,
        imageWidth: 1024,
        imageHeight: 1024,
      );
      expect(state.estimatedAnlasCost(), 0);
      expect(state.estimatedAnlasCost(isOpus: true), 0);
    });

    test('同尺寸下走 API 的工具仍然计费', () {
      const DirectorToolsState state = DirectorToolsState(
        selectedTool: DirectorToolType.declutter,
        imageWidth: 1024,
        imageHeight: 1024,
      );
      expect(state.estimatedAnlasCost(), greaterThan(0));
    });
  });

  group('DirectorToolType', () {
    test('只有 Pixel Snap 是本地工具且产出像素画', () {
      for (final DirectorToolType tool in DirectorToolType.values) {
        final bool isPixelSnap = tool == DirectorToolType.pixelSnap;
        expect(tool.runsLocally, isPixelSnap, reason: '$tool');
        expect(tool.producesPixelArt, isPixelSnap, reason: '$tool');
      }
    });

    test('Pixel Snap 不需要提示词也没有 defry', () {
      expect(
        const DirectorToolsState(
          selectedTool: DirectorToolType.pixelSnap,
        ).activePromptParams,
        isNull,
      );
    });
  });

  group('PixelSnapOptions.copyWith', () {
    test('逐字段覆盖且不误伤其它字段', () {
      const PixelSnapOptions base = PixelSnapOptions();
      expect(base.paletteMode, PixelSnapPaletteMode.auto);
      expect(base.colors, PixelSnapOptions.defaultColors);

      final PixelSnapOptions custom = base.copyWith(
        paletteMode: PixelSnapPaletteMode.custom,
        colors: 32,
      );
      expect(custom.paletteMode, PixelSnapPaletteMode.custom);
      expect(custom.colors, 32);
      expect(custom.avoidOverRefining, base.avoidOverRefining);
      expect(custom.upscale, base.upscale);
      expect(custom == base, isFalse);
      expect(base.copyWith() == base, isTrue);
    });
  });

  group('DirectorToolsNotifier 结果保留', () {
    ProviderContainer buildContainer() {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          directorToolsNotifierProvider.overrideWith(
            _SeededDirectorToolsNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('改 Pixel Snap 参数不会清掉已生成的结果', () {
      final ProviderContainer container = buildContainer();
      _seededNotifier(container).updatePixelSnapOptions(
        const PixelSnapOptions(paletteMode: PixelSnapPaletteMode.custom),
      );

      final DirectorToolsState state = container.read(
        directorToolsNotifierProvider,
      );
      expect(state.result, isNotNull);
      expect(state.pixelSnapResult, isNotNull);
      expect(state.pixelSnap.paletteMode, PixelSnapPaletteMode.custom);
    });

    test('切换工具才清结果', () {
      final ProviderContainer container = buildContainer();
      _seededNotifier(container).selectTool(DirectorToolType.declutter);

      final DirectorToolsState state = container.read(
        directorToolsNotifierProvider,
      );
      expect(state.result, isNull);
      expect(state.pixelSnapResult, isNull);
    });
  });

  group('表情情绪', () {
    const List<String> officialEmotionOrder = <String>[
      'neutral',
      'happy',
      'sad',
      'angry',
      'scared',
      'surprised',
      'tired',
      'excited',
      'nervous',
      'thinking',
      'confused',
      'shy',
      'disgusted',
      'smug',
      'bored',
      'laughing',
      'irritated',
      'aroused',
      'embarrassed',
      'worried',
      'love',
      'determined',
      'hurt',
      'playful',
    ];

    test('与官网 24 种情绪同序', () {
      expect(
        DirectorEmotion.values
            .map((DirectorEmotion emotion) => emotion.mood)
            .toList(),
        officialEmotionOrder,
      );
    });

    test('强度标题与英日文同为中性的“等级”，不暗示数值越大越强', () {
      expect(
        lookupAppLocalizations(const Locale('zh')).img2img_directorEmotionLevel,
        '表情等级',
      );
      expect(
        lookupAppLocalizations(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ).img2img_directorEmotionLevel,
        '表情等級',
      );
    });

    test('情绪选择区标题与官网同为“情绪”', () {
      const Map<String, String> expected = <String, String>{
        'zh': '情绪',
        'zh_Hant': '情緒',
        'en': 'Emotion',
        'ja': '感情',
      };
      for (final Locale locale in _directorLocales) {
        expect(
          lookupAppLocalizations(locale).img2img_directorEmotionMood,
          expected[locale.toLanguageTag().replaceAll('-', '_')],
          reason: '$locale',
        );
      }
    });

    test('日文情绪名与官网措辞一致', () {
      final AppLocalizations ja = lookupAppLocalizations(const Locale('ja'));
      expect(DirectorEmotion.neutral.label(ja), '普通');
      expect(DirectorEmotion.aroused.label(ja), '興奮');
      expect(DirectorEmotion.hurt.label(ja), '傷つく');
    });

    test('四语名称齐全且互不重复', () {
      for (final Locale locale in _directorLocales) {
        final AppLocalizations l10n = lookupAppLocalizations(locale);
        final List<String> labels = <String>[
          for (final DirectorEmotion emotion in DirectorEmotion.values)
            emotion.label(l10n),
        ];
        expect(labels.every((String label) => label.isNotEmpty), isTrue);
        expect(labels.toSet(), hasLength(labels.length), reason: '$locale');
      }
    });

    test('强度说明与官网同义：数值越大表情越弱', () {
      const Map<String, String> expected = <String, String>{
        'zh': '数值越大，表情越弱（0 = 正常，5 = 最弱）',
        'zh_Hant': '數值越大，表情越弱（0 = 正常，5 = 最弱）',
        'en': 'Higher values make the emotion weaker (0 = normal, 5 = weakest)',
        'ja': '値が大きいほど感情が弱くなります (0 = 通常、5 = 最も弱い)',
      };
      for (final Locale locale in _directorLocales) {
        expect(
          lookupAppLocalizations(locale).img2img_directorEmotionLevelHint,
          expected[locale.toLanguageTag().replaceAll('-', '_')],
          reason: '$locale',
        );
      }
    });

    test('新增情绪按官网格式拼进请求，强度原样发送', () async {
      final _PromptRecordingService service = _PromptRecordingService();
      final DirectorToolsNotifier notifier = await _initPromptNotifier(
        _promptContainer(service),
      );
      notifier
        ..selectTool(DirectorToolType.fixEmotion)
        ..selectEmotion(DirectorEmotion.scared)
        ..updateDefry(4);

      await notifier.runTool();

      expect(service.emotionPrompts, <String>['scared;;']);
      expect(service.emotionDefries, <int>[4]);
    });

    test('先写附加提示词再换几种情绪，提示词原样保留并拼在情绪之后', () async {
      final _PromptRecordingService service = _PromptRecordingService();
      final ProviderContainer container = _promptContainer(service);
      final DirectorToolsNotifier notifier = await _initPromptNotifier(
        container,
      );
      notifier
        ..selectTool(DirectorToolType.fixEmotion)
        ..updatePrompt('tears, looking at viewer');

      for (final DirectorEmotion emotion in <DirectorEmotion>[
        DirectorEmotion.happy,
        DirectorEmotion.sad,
        DirectorEmotion.shy,
        DirectorEmotion.neutral,
        DirectorEmotion.playful,
      ]) {
        notifier.selectEmotion(emotion);
        final DirectorToolsState state = container.read(
          directorToolsNotifierProvider,
        );
        expect(state.selectedEmotion, emotion);
        expect(
          state.emotionParams.prompt,
          'tears, looking at viewer',
          reason: emotion.mood,
        );
        expect(
          state.emotionRequestPrompt,
          '${emotion.mood};;tears, looking at viewer',
        );
      }

      await notifier.runTool();

      expect(service.emotionPrompts, <String>[
        'playful;;tears, looking at viewer',
      ]);
    });

    test('刚打开时选中 neutral，空附加提示词发送 neutral;;', () async {
      final _PromptRecordingService service = _PromptRecordingService();
      final ProviderContainer container = _promptContainer(service);
      final DirectorToolsNotifier notifier = await _initPromptNotifier(
        container,
      );
      notifier.selectTool(DirectorToolType.fixEmotion);

      final DirectorToolsState state = container.read(
        directorToolsNotifierProvider,
      );
      expect(state.selectedEmotion, DirectorEmotion.neutral);
      expect(state.emotionRequestPrompt, 'neutral;;');

      await notifier.runTool();

      expect(service.emotionPrompts, <String>['neutral;;']);
      expect(service.emotionDefries, <int>[0]);
    });
  });

  group('上色与表情参数互相独立', () {
    test('切换工具后各自保留提示词与 defry，请求只用自己的那份', () async {
      final _PromptRecordingService service = _PromptRecordingService();
      final ProviderContainer container = _promptContainer(service);
      final DirectorToolsNotifier notifier = await _initPromptNotifier(
        container,
      );
      DirectorToolsState read() =>
          container.read(directorToolsNotifierProvider);

      notifier
        ..selectTool(DirectorToolType.colorize)
        ..updatePrompt('red hair')
        ..updateDefry(2)
        ..selectTool(DirectorToolType.fixEmotion);
      expect(read().activePromptParams, const DirectorPromptParams());

      notifier
        ..updatePrompt('tears')
        ..updateDefry(5)
        ..selectEmotion(DirectorEmotion.angry);
      expect(
        read().activePromptParams,
        const DirectorPromptParams(prompt: 'tears', defry: 5),
      );
      await notifier.runTool();

      notifier.selectTool(DirectorToolType.colorize);
      expect(
        read().activePromptParams,
        const DirectorPromptParams(prompt: 'red hair', defry: 2),
      );
      await notifier.runTool();

      notifier.selectTool(DirectorToolType.fixEmotion);
      expect(
        read().activePromptParams,
        const DirectorPromptParams(prompt: 'tears', defry: 5),
      );
      expect(read().selectedEmotion, DirectorEmotion.angry);

      expect(service.emotionPrompts, <String>['angry;;tears']);
      expect(service.emotionDefries, <int>[5]);
      expect(service.colorizePrompts, <String?>['red hair']);
      expect(service.colorizeDefries, <int>[2]);
    });

    test('不收提示词的工具上改参数不会写进上色或表情', () async {
      final ProviderContainer container = _promptContainer(
        _PromptRecordingService(),
      );
      final DirectorToolsNotifier notifier = await _initPromptNotifier(
        container,
      );

      notifier
        ..updatePrompt('ignored')
        ..updateDefry(3);

      final DirectorToolsState state = container.read(
        directorToolsNotifierProvider,
      );
      expect(state.activePromptParams, isNull);
      expect(state.colorizeParams, const DirectorPromptParams());
      expect(state.emotionParams, const DirectorPromptParams());
    });

    test('只有上色与改表情有自己的参数，读写落在同一份上', () {
      const DirectorPromptParams edited = DirectorPromptParams(
        prompt: 'edited',
        defry: 3,
      );
      const Set<DirectorToolType> promptTools = <DirectorToolType>{
        DirectorToolType.colorize,
        DirectorToolType.fixEmotion,
      };
      for (final DirectorToolType tool in DirectorToolType.values) {
        final DirectorToolsState state = DirectorToolsState(selectedTool: tool);
        final DirectorToolsState written = state.withActivePromptParams(edited);
        if (promptTools.contains(tool)) {
          expect(state.activePromptParams, const DirectorPromptParams());
          expect(written.activePromptParams, edited, reason: '$tool');
        } else {
          expect(state.activePromptParams, isNull, reason: '$tool');
          expect(written, same(state), reason: '$tool');
        }
      }
      expect(
        const DirectorToolsState(
          selectedTool: DirectorToolType.colorize,
        ).withActivePromptParams(edited).emotionParams,
        const DirectorPromptParams(),
      );
      expect(
        const DirectorToolsState(
          selectedTool: DirectorToolType.fixEmotion,
        ).withActivePromptParams(edited).colorizeParams,
        const DirectorPromptParams(),
      );
    });

    test('defry 夹在 0 到 5 之间', () async {
      final ProviderContainer container = _promptContainer(
        _PromptRecordingService(),
      );
      final DirectorToolsNotifier notifier = await _initPromptNotifier(
        container,
      );
      int colorizeDefry() =>
          container.read(directorToolsNotifierProvider).colorizeParams.defry;

      notifier
        ..selectTool(DirectorToolType.colorize)
        ..updateDefry(9);
      expect(colorizeDefry(), 5);
      notifier.updateDefry(-2);
      expect(colorizeDefry(), 0);
    });

    test('直接构造越界的 defry 会被断言拦下', () {
      for (final int defry in <int>[
        DirectorPromptParams.minDefry - 1,
        DirectorPromptParams.maxDefry + 1,
      ]) {
        expect(
          () => DirectorPromptParams(defry: defry),
          throwsAssertionError,
          reason: '$defry',
        );
      }
    });

    test('重新打开会把情绪、两份提示词与 defry 全部恢复默认', () async {
      final ProviderContainer container = _promptContainer(
        _PromptRecordingService(),
      );
      final DirectorToolsNotifier notifier = await _initPromptNotifier(
        container,
      );
      notifier
        ..selectTool(DirectorToolType.colorize)
        ..updatePrompt('red hair')
        ..updateDefry(2)
        ..selectTool(DirectorToolType.fixEmotion)
        ..updatePrompt('tears')
        ..updateDefry(4)
        ..selectEmotion(DirectorEmotion.love);

      await notifier.init(_resultBytes);

      final DirectorToolsState state = container.read(
        directorToolsNotifierProvider,
      );
      expect(state.selectedEmotion, DirectorEmotion.neutral);
      expect(state.colorizeParams, const DirectorPromptParams());
      expect(state.emotionParams, const DirectorPromptParams());
      expect(state.selectedTool, DirectorToolType.removeBackground);
      notifier.selectTool(DirectorToolType.fixEmotion);
      expect(
        container.read(directorToolsNotifierProvider).emotionRequestPrompt,
        'neutral;;',
      );
    });
  });

  group('登记结果时的提示词', () {
    test('保存的提示词取当前工具自己的附加提示词', () async {
      final _Registrar registrar = _Registrar();
      final ProviderContainer container = _promptContainer(
        _PromptRecordingService(),
        registrar: registrar,
      );
      final DirectorToolsNotifier notifier = await _initPromptNotifier(
        container,
      );
      final String basePrompt = container
          .read(generationParamsNotifierProvider)
          .prompt;

      notifier
        ..selectTool(DirectorToolType.colorize)
        ..updatePrompt('red hair')
        ..selectTool(DirectorToolType.fixEmotion)
        ..updatePrompt('tears')
        ..selectEmotion(DirectorEmotion.sad);
      await notifier.runTool();
      await notifier.registerResult();

      notifier.selectTool(DirectorToolType.colorize);
      await notifier.runTool();
      await notifier.registerResult();

      notifier
        ..selectTool(DirectorToolType.fixEmotion)
        ..updatePrompt('');
      await notifier.runTool();
      await notifier.registerResult();

      expect(
        registrar.registrations.map((_Registration r) => r.prompt).toList(),
        <String>['tears', 'red hair', basePrompt],
      );
    });
  });

  group('背景移除多结果', () {
    Future<DirectorToolsNotifier> runBackgroundRemoval(
      ProviderContainer container,
    ) async {
      final DirectorToolsNotifier notifier = container.read(
        directorToolsNotifierProvider.notifier,
      );
      await notifier.init(_resultBytes);
      await notifier.runTool();
      return notifier;
    }

    DirectorToolsState read(ProviderContainer container) =>
        container.read(directorToolsNotifierProvider);

    test('保留三张结果并默认选中 Masked', () async {
      final ProviderContainer container = _backgroundRemovalContainer(
        _Registrar(),
      );
      await runBackgroundRemoval(container);

      final DirectorToolsState state = read(container);
      expect(
        state.results.map((DirectorToolImage image) => image.bytes).toList(),
        <Uint8List>[_maskedBytes, _generatedBytes, _blendBytes],
      );
      expect(state.selectedResultIndex, 0);
      expect(state.result, same(_maskedBytes));
      expect(state.selectedResult?.variant, DirectorResultVariant.masked);
    });

    test('切换后回填源图用当前选中的那张', () async {
      final ProviderContainer container = _backgroundRemovalContainer(
        _Registrar(),
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      notifier.selectResult(2);
      expect(read(container).result, same(_blendBytes));
      notifier.selectResult(5);
      expect(read(container).selectedResultIndex, 2);

      notifier.applyResultAsSource();
      final DirectorToolsState state = read(container);
      expect(state.sourceImage, same(_blendBytes));
      expect(state.results, isEmpty);
      expect(state.selectedResultIndex, 0);
    });

    test('切换工具与重新运行都会清掉选择', () async {
      final ProviderContainer container = _backgroundRemovalContainer(
        _Registrar(),
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      notifier.selectResult(1);
      await notifier.runTool();
      expect(read(container).selectedResultIndex, 0);
      expect(read(container).results, hasLength(3));

      notifier
        ..selectResult(1)
        ..selectTool(DirectorToolType.extractLineArt);
      expect(read(container).results, isEmpty);
      expect(read(container).selectedResultIndex, 0);

      await notifier.runTool();
      expect(read(container).results, hasLength(1));
      expect(read(container).result, same(_lineArtBytes));
    });

    test('三张都带后缀进历史和图库，只有选中的那张顶替当前展示', () async {
      final _Registrar registrar = _Registrar();
      final ProviderContainer container = _backgroundRemovalContainer(
        registrar,
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      await notifier.registerResult();

      expect(
        registrar.registrations.map((_Registration r) => r.bytes).toList(),
        <Uint8List>[_blendBytes, _generatedBytes, _maskedBytes],
      );
      expect(
        registrar.registrations
            .map((_Registration r) => r.fileNameSuffix)
            .toList(),
        <String>['_blend', '_generated', '_masked'],
      );
      expect(
        registrar.registrations
            .map((_Registration r) => r.replaceCurrentDisplay)
            .toList(),
        <bool>[false, false, true],
      );
      expect(
        registrar.registrations.every(
          (_Registration r) => r.saveToLocal && !r.addToDisplay,
        ),
        isTrue,
      );
    });

    test('同一次处理的三张共用同一个创建时间', () async {
      final _Registrar registrar = _Registrar();
      final ProviderContainer container = _backgroundRemovalContainer(
        registrar,
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      await notifier.registerResult();

      final Set<DateTime?> createdAts = registrar.registrations
          .map((_Registration r) => r.createdAt)
          .toSet();
      expect(registrar.registrations, hasLength(3));
      expect(createdAts, hasLength(1));
      expect(createdAts.single, isNotNull);
    });

    test('选中第 1 张后登记，只有那张顶替当前展示', () async {
      final _Registrar registrar = _Registrar();
      final ProviderContainer container = _backgroundRemovalContainer(
        registrar,
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      notifier.selectResult(1);
      await notifier.registerResult();

      expect(
        registrar.registrations
            .where((_Registration r) => r.replaceCurrentDisplay)
            .map((_Registration r) => r.bytes)
            .toList(),
        <Uint8List>[_generatedBytes],
      );
      expect(registrar.registrations, hasLength(3));
    });

    test('三张全部登记成功时报告成功', () async {
      final ProviderContainer container = _backgroundRemovalContainer(
        _Registrar(),
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      final DirectorResultRegistration registration = await notifier
          .registerResult();

      expect(registration.total, 3);
      expect(registration.succeeded, isTrue);
      expect(registration.failedCount, 0);
      expect(registration.allFailed, isFalse);
      expect(registration.selectedFailed, isFalse);
    });

    test('某张登记失败不影响其余几张，也不向外抛出，并报告失败序号', () async {
      final _Registrar registrar = _Registrar(
        failing: <Uint8List>{_blendBytes},
      );
      final ProviderContainer container = _backgroundRemovalContainer(
        registrar,
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      final DirectorResultRegistration registration = await notifier
          .registerResult();

      expect(
        registrar.registrations.map((_Registration r) => r.bytes).toList(),
        <Uint8List>[_generatedBytes, _maskedBytes],
      );
      expect(registrar.registrations.last.replaceCurrentDisplay, isTrue);
      expect(registration.failedIndices, <int>{2});
      expect(registration.succeeded, isFalse);
      expect(registration.allFailed, isFalse);
      expect(registration.selectedFailed, isFalse);
    });

    test('已进历史但没写进图库也算失败', () async {
      final ProviderContainer container = _backgroundRemovalContainer(
        _Registrar(unsaved: <Uint8List>{_generatedBytes}),
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      final DirectorResultRegistration registration = await notifier
          .registerResult();

      expect(registration.failedIndices, <int>{1});
      expect(registration.selectedFailed, isFalse);
    });

    test('选中的那张失败时报告选中失败', () async {
      final ProviderContainer container = _backgroundRemovalContainer(
        _Registrar(failing: <Uint8List>{_generatedBytes}),
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      notifier.selectResult(1);
      final DirectorResultRegistration registration = await notifier
          .registerResult();

      expect(registration.failedIndices, <int>{1});
      expect(registration.selectedFailed, isTrue);
      expect(registration.allFailed, isFalse);
    });

    test('三张全部失败时报告全部失败', () async {
      final ProviderContainer container = _backgroundRemovalContainer(
        _Registrar(
          failing: <Uint8List>{_maskedBytes, _blendBytes},
          unsaved: <Uint8List>{_generatedBytes},
        ),
      );
      final DirectorToolsNotifier notifier = await runBackgroundRemoval(
        container,
      );

      final DirectorResultRegistration registration = await notifier
          .registerResult();

      expect(registration.failedIndices, <int>{0, 1, 2});
      expect(registration.allFailed, isTrue);
      expect(registration.selectedFailed, isTrue);
    });
  });

  group('DirectorToolsNotifier.registerResult', () {
    // 只进历史不进当前区，结果会排在仍占着当前区的原图下面，
    // 与 DLSS 增强、NovelAI 超分的做法不一致。
    test('加工结果顶替当前展示图，且不走 addToDisplay', () async {
      final _Registrar registrar = _Registrar();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          directorToolsNotifierProvider.overrideWith(
            _SeededDirectorToolsNotifier.new,
          ),
          imageGenerationNotifierProvider.overrideWith(() => registrar),
        ],
      );
      addTearDown(container.dispose);

      final DirectorResultRegistration outcome = await _seededNotifier(
        container,
      ).registerResult();

      final _Registration registration = registrar.registrations.single;
      expect(registration.bytes, same(_resultBytes));
      expect(registration.replaceCurrentDisplay, isTrue);
      expect(registration.addToDisplay, isFalse);
      expect(registration.saveToLocal, isTrue);
      expect(registration.fileNameSuffix, isEmpty);
      expect(outcome.succeeded, isTrue);
    });

    test('单图工具登记失败时报告全部失败', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          directorToolsNotifierProvider.overrideWith(
            _SeededDirectorToolsNotifier.new,
          ),
          imageGenerationNotifierProvider.overrideWith(
            () => _Registrar(failing: <Uint8List>{_resultBytes}),
          ),
        ],
      );
      addTearDown(container.dispose);

      final DirectorResultRegistration outcome = await _seededNotifier(
        container,
      ).registerResult();

      expect(outcome.total, 1);
      expect(outcome.allFailed, isTrue);
      expect(outcome.selectedFailed, isTrue);
    });

    test('没有结果时不注册', () async {
      final _Registrar registrar = _Registrar();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          imageGenerationNotifierProvider.overrideWith(() => registrar),
        ],
      );
      addTearDown(container.dispose);

      final DirectorResultRegistration outcome = await container
          .read(directorToolsNotifierProvider.notifier)
          .registerResult();

      expect(registrar.registrations, isEmpty);
      expect(outcome.total, 0);
      expect(outcome.succeeded, isTrue);
      expect(outcome.allFailed, isFalse);
    });
  });
}

const List<Locale> _directorLocales = <Locale>[
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale('en'),
  Locale('ja'),
];

class _AuthenticatedNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _SilentSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionState.initial();

  @override
  void schedulePostBillingRefresh({
    Duration delay = SubscriptionNotifier.postBillingRefreshDelay,
  }) {}
}

class _PromptRecordingService extends NAIImageEnhancementApiService {
  _PromptRecordingService() : super(Dio());

  final List<String> emotionPrompts = <String>[];
  final List<int> emotionDefries = <int>[];
  final List<String?> colorizePrompts = <String?>[];
  final List<int> colorizeDefries = <int>[];

  @override
  Future<DirectorToolOutput> fixEmotion(
    Uint8List image, {
    required String prompt,
    int defry = 0,
  }) async {
    emotionPrompts.add(prompt);
    emotionDefries.add(defry);
    return DirectorToolOutput.single(_resultBytes);
  }

  @override
  Future<DirectorToolOutput> colorize(
    Uint8List image, {
    String? prompt,
    int defry = 0,
  }) async {
    colorizePrompts.add(prompt);
    colorizeDefries.add(defry);
    return DirectorToolOutput.single(_resultBytes);
  }
}

ProviderContainer _promptContainer(
  _PromptRecordingService service, {
  _Registrar? registrar,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      authNotifierProvider.overrideWith(_AuthenticatedNotifier.new),
      naiImageEnhancementApiServiceProvider.overrideWithValue(service),
      subscriptionNotifierProvider.overrideWith(
        _SilentSubscriptionNotifier.new,
      ),
      if (registrar != null)
        imageGenerationNotifierProvider.overrideWith(() => registrar),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<DirectorToolsNotifier> _initPromptNotifier(
  ProviderContainer container,
) async {
  final DirectorToolsNotifier notifier = container.read(
    directorToolsNotifierProvider.notifier,
  );
  await notifier.init(_resultBytes);
  return notifier;
}

final Uint8List _maskedBytes = Uint8List.fromList(<int>[10]);
final Uint8List _generatedBytes = Uint8List.fromList(<int>[20]);
final Uint8List _blendBytes = Uint8List.fromList(<int>[30]);
final Uint8List _lineArtBytes = Uint8List.fromList(<int>[40]);

class _BackgroundRemovalService extends NAIImageEnhancementApiService {
  _BackgroundRemovalService() : super(Dio());

  @override
  Future<DirectorToolOutput> removeBackground(Uint8List image) async =>
      DirectorToolOutput.labelled(<Uint8List>[
        _maskedBytes,
        _generatedBytes,
        _blendBytes,
      ], variants: DirectorResultVariant.values);

  @override
  Future<DirectorToolOutput> extractLineArt(Uint8List image) async =>
      DirectorToolOutput.single(_lineArtBytes);
}

ProviderContainer _backgroundRemovalContainer(_Registrar registrar) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      authNotifierProvider.overrideWith(_AuthenticatedNotifier.new),
      naiImageEnhancementApiServiceProvider.overrideWithValue(
        _BackgroundRemovalService(),
      ),
      subscriptionNotifierProvider.overrideWith(
        _SilentSubscriptionNotifier.new,
      ),
      imageGenerationNotifierProvider.overrideWith(() => registrar),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _Registration {
  const _Registration({
    required this.bytes,
    required this.prompt,
    required this.saveToLocal,
    required this.addToDisplay,
    required this.replaceCurrentDisplay,
    required this.fileNameSuffix,
    required this.createdAt,
  });

  final Uint8List bytes;
  final String prompt;
  final bool saveToLocal;
  final bool addToDisplay;
  final bool replaceCurrentDisplay;
  final String fileNameSuffix;
  final DateTime? createdAt;
}

class _Registrar extends ImageGenerationNotifier {
  _Registrar({
    this.failing = const <Uint8List>{},
    this.unsaved = const <Uint8List>{},
  });

  /// 登记这些字节时抛错，模拟准备阶段失败。
  final Set<Uint8List> failing;

  /// 这些字节进了历史却没拿到文件路径，模拟落盘失败。
  final Set<Uint8List> unsaved;
  final List<_Registration> registrations = <_Registration>[];

  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<String?> registerExternalImage(
    Uint8List imageBytes, {
    required ImageParams params,
    int? width,
    int? height,
    Uint8List? comparisonSourceImage,
    bool saveToLocal = false,
    String? saveDirectoryPath,
    bool syncToGalleryIndex = true,
    bool addToDisplay = false,
    bool replaceCurrentDisplay = false,
    bool embedNaiMetadata = true,
    String fileNameSuffix = '',
    DateTime? createdAt,
  }) async {
    if (failing.contains(imageBytes)) {
      throw StateError('register failed');
    }
    registrations.add(
      _Registration(
        bytes: imageBytes,
        prompt: params.prompt,
        saveToLocal: saveToLocal,
        addToDisplay: addToDisplay,
        replaceCurrentDisplay: replaceCurrentDisplay,
        fileNameSuffix: fileNameSuffix,
        createdAt: createdAt,
      ),
    );
    if (unsaved.contains(imageBytes)) return null;
    return 'gallery/result${registrations.length}$fileNameSuffix.png';
  }
}
