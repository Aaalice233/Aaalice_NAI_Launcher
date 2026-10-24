import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_options.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/director/director_emotion.dart';
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
      result: _resultBytes,
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
      expect(DirectorToolType.pixelSnap.needsPrompt, isFalse);
      expect(DirectorToolType.pixelSnap.supportsDefry, isFalse);
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

  group('表情预设', () {
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
        emotionPresets.map((EmotionPreset preset) => preset.mood).toList(),
        officialEmotionOrder,
      );
    });

    test('原有附加标签不变，新增情绪不带附加标签', () {
      const Map<String, String> legacyTags = <String, String>{
        'happy': 'smile',
        'laughing': 'open mouth',
        'sad': 'crying',
        'angry': 'furrowed brow',
        'surprised': 'open mouth, wide eyes',
        'shy': 'blush, embarrassed, looking away',
        'smug': 'half-closed eyes',
        'love': 'heart',
        'playful': 'wink',
      };
      for (final EmotionPreset preset in emotionPresets) {
        expect(
          preset.extraTags,
          legacyTags[preset.mood] ?? '',
          reason: preset.mood,
        );
      }
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
          for (final EmotionPreset preset in emotionPresets)
            preset.emotion.label(l10n),
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
      final _EmotionRecordingService service = _EmotionRecordingService();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          authNotifierProvider.overrideWith(_AuthenticatedNotifier.new),
          naiImageEnhancementApiServiceProvider.overrideWithValue(service),
          subscriptionNotifierProvider.overrideWith(
            _SilentSubscriptionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final DirectorToolsNotifier notifier = container.read(
        directorToolsNotifierProvider.notifier,
      );
      await notifier.init(_resultBytes);
      notifier
        ..selectTool(DirectorToolType.fixEmotion)
        ..applyEmotionPreset(
          emotionPresets.firstWhere(
            (EmotionPreset preset) => preset.mood == 'scared',
          ),
        )
        ..updateDefry(4);

      await notifier.runTool();

      expect(service.prompts, <String>['scared;;']);
      expect(service.defries, <int>[4]);
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

      await _seededNotifier(container).registerResult();

      final _Registration registration = registrar.registrations.single;
      expect(registration.bytes, same(_resultBytes));
      expect(registration.replaceCurrentDisplay, isTrue);
      expect(registration.addToDisplay, isFalse);
      expect(registration.saveToLocal, isTrue);
    });

    test('没有结果时不注册', () async {
      final _Registrar registrar = _Registrar();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          imageGenerationNotifierProvider.overrideWith(() => registrar),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(directorToolsNotifierProvider.notifier)
          .registerResult();

      expect(registrar.registrations, isEmpty);
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

class _EmotionRecordingService extends NAIImageEnhancementApiService {
  _EmotionRecordingService() : super(Dio());

  final List<String> prompts = <String>[];
  final List<int> defries = <int>[];

  @override
  Future<Uint8List> fixEmotion(
    Uint8List image, {
    required String prompt,
    int defry = 0,
  }) async {
    prompts.add(prompt);
    defries.add(defry);
    return _resultBytes;
  }
}

class _Registration {
  const _Registration({
    required this.bytes,
    required this.saveToLocal,
    required this.addToDisplay,
    required this.replaceCurrentDisplay,
  });

  final Uint8List bytes;
  final bool saveToLocal;
  final bool addToDisplay;
  final bool replaceCurrentDisplay;
}

class _Registrar extends ImageGenerationNotifier {
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
  }) async {
    registrations.add(
      _Registration(
        bytes: imageBytes,
        saveToLocal: saveToLocal,
        addToDisplay: addToDisplay,
        replaceCurrentDisplay: replaceCurrentDisplay,
      ),
    );
    return null;
  }
}
