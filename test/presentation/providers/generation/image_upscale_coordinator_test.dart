import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/comfyui/comfyui_models.dart';
import 'package:nai_launcher/core/comfyui/seedvr2_support.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/comfyui/comfyui_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_upscale_coordinator.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/generation/novel_ai_upscale_task_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';

const _coordinatorPath =
    'lib/presentation/providers/generation/image_upscale_coordinator.dart';

const _regularModel = '4x-UltraSharp.pth';
const _legacySeedvr2Model = 'seedvr2_ema_3b_fp8_e4m3fn.safetensors';

const _legacyCapabilities = ComfySeedvr2Capabilities(
  legacyNodesAvailable: true,
  legacyModels: [_legacySeedvr2Model],
);

void main() {
  final png = _png(320, 200);
  final jpeg = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 320, height: 200)),
  );
  final webp = _losslessWebp(320, 200);
  final unreadable = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);

  group('ImageUpscaleCoordinator source sizing', () {
    test('every comfy module reads the same size from one source', () async {
      final sizes = <ComfyUpscaleModule, (int?, int?)>{};
      for (final module in ComfyUpscaleModule.values) {
        final harness = _Harness(
          source: png,
          module: module,
          scale: 1.0,
          results: [unreadable],
        );
        addTearDown(harness.dispose);

        final result = await harness.run();

        expect(result, isA<ImageUpscaleSuccess>(), reason: module.name);
        sizes[module] = (harness.registeredWidth, harness.registeredHeight);
      }

      expect(sizes.values.toSet(), equals({(320, 200)}));
    });

    test('reads png, jpeg and webp headers without decoding pixels', () async {
      for (final source in <String, Uint8List>{
        'png': png,
        'jpeg': jpeg,
        'webp': webp,
      }.entries) {
        final harness = _Harness(
          source: source.value,
          module: ComfyUpscaleModule.regular,
          scale: 1.0,
          results: [unreadable],
        );
        addTearDown(harness.dispose);

        await harness.run();

        expect(harness.paramValues?['target_width'], 320, reason: source.key);
        expect(harness.paramValues?['target_height'], 200, reason: source.key);
        expect(harness.registeredWidth, 320, reason: source.key);
        expect(harness.registeredHeight, 200, reason: source.key);
      }
    });

    test('regular upscale targets the EXIF-oriented size', () async {
      // ComfyUI 的 LoadImage 会先按 EXIF 方向转正再交给放大模型
      final rotated = img.Image(width: 320, height: 200)
        ..exif.imageIfd.orientation = 6;
      final harness = _Harness(
        source: Uint8List.fromList(img.encodeJpg(rotated)),
        module: ComfyUpscaleModule.regular,
        scale: 1.0,
        results: [unreadable],
      );
      addTearDown(harness.dispose);

      await harness.run();

      expect(harness.paramValues?['target_width'], 200);
      expect(harness.paramValues?['target_height'], 320);
      expect((harness.registeredWidth, harness.registeredHeight), (200, 320));
    });

    test(
      'seedvr2 target resolution follows the source shortest side',
      () async {
        final harness = _Harness(
          source: png,
          module: ComfyUpscaleModule.seedvr2,
          scale: 1.5,
          results: [unreadable],
        );
        addTearDown(harness.dispose);

        await harness.run();

        expect(harness.paramValues?['target_resolution'], 300);
      },
    );

    test('rejects a source whose header cannot be parsed', () async {
      for (final module in ComfyUpscaleModule.values) {
        final harness = _Harness(
          source: unreadable,
          module: module,
          scale: 1.5,
          results: [png],
        );
        addTearDown(harness.dispose);

        final result = await harness.run();

        expect(
          result,
          isA<ImageUpscaleRejected>().having(
            (rejected) => rejected.reason,
            'reason',
            ImageUpscaleFailure.sourceDecodeFailed,
          ),
          reason: module.name,
        );
        expect(harness.registeredWidth, isNull, reason: module.name);
      }
    });
  });

  group('ImageUpscaleCoordinator output sizing', () {
    test('reports no result for empty and missing backend output', () async {
      for (final results in <List<Uint8List>?>[null, const []]) {
        for (final module in ComfyUpscaleModule.values) {
          final harness = _Harness(
            source: png,
            module: module,
            scale: 1.5,
            results: results,
          );
          addTearDown(harness.dispose);

          final result = await harness.run();

          expect(
            result,
            isA<ImageUpscaleRejected>().having(
              (rejected) => rejected.reason,
              'reason',
              ImageUpscaleFailure.noResult,
            ),
            reason: module.name,
          );
        }
      }
    });

    test('uses the output header when it is readable', () async {
      for (final module in ComfyUpscaleModule.values) {
        final harness = _Harness(
          source: png,
          module: module,
          scale: 1.5,
          results: [_png(640, 400)],
        );
        addTearDown(harness.dispose);

        final result = await harness.run();

        expect(
          result,
          isA<ImageUpscaleSuccess>()
              .having((success) => success.width, 'width', 640)
              .having((success) => success.height, 'height', 400),
          reason: module.name,
        );
        expect(harness.registeredWidth, 640, reason: module.name);
        expect(harness.registeredHeight, 400, reason: module.name);
      }
    });

    test('falls back to per-module scaling for unreadable output', () async {
      const expected = {
        ComfyUpscaleModule.seedvr2: (480, 300),
        ComfyUpscaleModule.regular: (480, 300),
        ComfyUpscaleModule.rtx: (480, 304),
      };

      for (final module in ComfyUpscaleModule.values) {
        final harness = _Harness(
          source: png,
          module: module,
          scale: 1.5,
          results: [unreadable],
        );
        addTearDown(harness.dispose);

        await harness.run();

        expect(
          (harness.registeredWidth, harness.registeredHeight),
          expected[module],
          reason: module.name,
        );
      }
    });
  });

  group('ImageUpscaleCoordinator NovelAI outcomes', () {
    Future<(ImageUpscaleResult, _Harness)> runNovelAi(
      NovelAiUpscaleOutcome outcome,
    ) async {
      final harness = _Harness(
        source: png,
        module: ComfyUpscaleModule.regular,
        scale: 1.0,
        results: null,
        backend: UpscaleBackend.novelai,
        novelAiOutcome: outcome,
      );
      addTearDown(harness.dispose);
      return (await harness.run(), harness);
    }

    test('a completed upscale reports and registers the output size', () async {
      final (result, harness) = await runNovelAi(
        const NovelAiUpscaleCompleted(),
      );

      expect(
        result,
        isA<ImageUpscaleSuccess>()
            .having((success) => success.kind, 'kind', ImageUpscaleKind.novelAi)
            .having((success) => success.width, 'width', 640)
            .having((success) => success.height, 'height', 400),
      );
      expect(harness.registeredWidth, 640);
      expect(harness.registeredHeight, 400);
    });

    test(
      'requests that never ran or failed are not reported as success',
      () async {
        const expectations = {
          NovelAiUpscaleSkipped(NovelAiUpscaleSkipReason.busy):
              ImageUpscaleFailure.busy,
          NovelAiUpscaleSkipped(NovelAiUpscaleSkipReason.unauthenticated):
              ImageUpscaleFailure.authenticationRequired,
          NovelAiUpscaleFailed('图像放大失败: 服务器返回错误: 402'):
              ImageUpscaleFailure.requestFailed,
        };
        for (final MapEntry(key: outcome, value: reason)
            in expectations.entries) {
          final (result, harness) = await runNovelAi(outcome);

          expect(
            result,
            isA<ImageUpscaleRejected>().having(
              (rejected) => rejected.reason,
              'reason',
              reason,
            ),
            reason: '$outcome',
          );
          expect(harness.registrarEvents, isEmpty, reason: '$outcome');
        }
        final (failed, _) = await runNovelAi(
          const NovelAiUpscaleFailed('图像放大失败: 服务器返回错误: 402'),
        );
        expect((failed as ImageUpscaleRejected).detail, '图像放大失败: 服务器返回错误: 402');
      },
    );
  });

  test(
    'the generation page registers with its params, auto-save and source',
    () async {
      final novelAi = _Harness(
        source: png,
        module: ComfyUpscaleModule.regular,
        scale: 1.0,
        results: null,
        backend: UpscaleBackend.novelai,
        novelAiOutcome: const NovelAiUpscaleCompleted(),
      );
      final seedVr2 = _Harness(
        source: png,
        module: ComfyUpscaleModule.seedvr2,
        scale: 1.5,
        results: [_png(480, 300)],
      );
      addTearDown(novelAi.dispose);
      addTearDown(seedVr2.dispose);

      await novelAi.run();
      await seedVr2.run();

      final registration = novelAi.registrar;
      expect(registration.params?.sourceImage, same(png));
      expect(registration.comparisonSourceImage, same(png));
      expect(registration.saveToLocal, isFalse);
      expect(registration.replaceCurrentDisplay, isTrue);
      expect(registration.embedNaiMetadata, isTrue);
      // SeedVR2 遵循面板上的"嵌入 NAI 元数据"开关，默认关闭。
      expect(seedVr2.registrar.embedNaiMetadata, isFalse);
    },
  );

  test('the generation page restores history before registering', () async {
    for (final module in ComfyUpscaleModule.values) {
      final harness = _Harness(
        source: png,
        module: module,
        scale: 1.5,
        results: [_png(480, 300)],
      );
      addTearDown(harness.dispose);

      await harness.run();

      expect(harness.registrarEvents, [
        'restore',
        'register',
      ], reason: '$module');
    }
  });

  test('a failed comfy task reports its error code as detail', () async {
    final harness = _Harness(
      source: png,
      module: ComfyUpscaleModule.regular,
      scale: 1.5,
      results: null,
      comfyErrorCode: ComfyUITaskErrorCode.connectionFailed,
    );
    addTearDown(harness.dispose);

    final result = await harness.run();

    expect(
      result,
      isA<ImageUpscaleRejected>()
          .having(
            (rejected) => rejected.reason,
            'reason',
            ImageUpscaleFailure.noResult,
          )
          .having((rejected) => rejected.detail, 'detail', 'connectionFailed'),
    );
  });

  test('upscale coordinator never decodes full frames', () {
    final source = File(_coordinatorPath).readAsStringSync();

    expect(source, isNot(contains('decodeImage(')));
    expect(source, isNot(contains('package:image/image.dart')));
    expect(source, contains('NaiResolutionAdapter.readImageSize'));
  });
}

final class _Harness {
  _Harness({
    required Uint8List source,
    required ComfyUpscaleModule module,
    required double scale,
    required List<Uint8List>? results,
    UpscaleBackend backend = UpscaleBackend.comfyui,
    NovelAiUpscaleOutcome? novelAiOutcome,
    ComfyUITaskErrorCode? comfyErrorCode,
  }) : _task = _StubComfyTask(results, comfyErrorCode),
       _novelAi = _StubNovelAiUpscaleTask(novelAiOutcome),
       _registrar = _RecordingImageGenerationNotifier() {
    final settings = UpscaleWorkflowSettings(
      backend: backend,
      comfyModule: module,
      comfyScale: scale,
      comfyRegularModel: _regularModel,
      comfySeedvr2LegacyModel: _legacySeedvr2Model,
      seedvr2Engine: ComfySeedvr2Engine.legacy,
    );
    _container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          () => _StubGenerationParams(ImageParams(sourceImage: source)),
        ),
        imageWorkflowControllerProvider.overrideWith(
          () => _StubWorkflowController(
            ImageWorkflowState(
              mode: ImageWorkflowMode.upscale,
              upscale: settings,
            ),
          ),
        ),
        comfyUISeedvr2ModelsProvider.overrideWith(
          () => _StubSeedvr2Models(const [
            _regularModel,
            _legacySeedvr2Model,
          ], _legacyCapabilities),
        ),
        comfyUITaskProvider.overrideWith(() => _task),
        novelAiUpscaleTaskProvider.overrideWith(() => _novelAi),
        imageGenerationNotifierProvider.overrideWith(() => _registrar),
        imageSaveSettingsNotifierProvider.overrideWith(
          _StubImageSaveSettings.new,
        ),
      ],
    );
    // 两个 ComfyUI provider 是 autoDispose，订阅住才能保证桩 Notifier 只挂载一次。
    _subscriptions = [
      _container.listen(comfyUITaskProvider, (_, _) {}),
      _container.listen(comfyUISeedvr2ModelsProvider, (_, _) {}),
    ];
  }

  final _StubComfyTask _task;
  final _StubNovelAiUpscaleTask _novelAi;
  final _RecordingImageGenerationNotifier _registrar;
  late final ProviderContainer _container;
  late final List<ProviderSubscription<Object?>> _subscriptions;

  Map<String, dynamic>? get paramValues => _task.paramValues;
  int? get registeredWidth => _registrar.width;
  int? get registeredHeight => _registrar.height;
  List<String> get registrarEvents => _registrar.events;
  _RecordingImageGenerationNotifier get registrar => _registrar;

  Future<ImageUpscaleResult> run() =>
      _container.read(imageUpscaleCoordinatorProvider).runFromGenerationPage();

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    _container.dispose();
  }
}

final class _StubGenerationParams extends GenerationParamsNotifier {
  _StubGenerationParams(this._params);

  final ImageParams _params;

  @override
  ImageParams build() => _params;
}

final class _StubWorkflowController extends ImageWorkflowController {
  _StubWorkflowController(this._state);

  final ImageWorkflowState _state;

  @override
  ImageWorkflowState build() => _state;
}

final class _StubSeedvr2Models extends ComfyUISeedvr2Models {
  _StubSeedvr2Models(this._models, this._capabilities);

  final List<String> _models;
  final ComfySeedvr2Capabilities _capabilities;

  @override
  ComfySeedvr2Capabilities get capabilities => _capabilities;

  @override
  List<String> build() => _models;
}

final class _StubComfyTask extends ComfyUITask {
  _StubComfyTask(this._results, this._errorCode);

  final List<Uint8List>? _results;
  final ComfyUITaskErrorCode? _errorCode;
  Map<String, dynamic>? paramValues;

  @override
  ComfyUITaskState build() => const ComfyUITaskState();

  @override
  Future<List<Uint8List>?> execute({
    required String templateId,
    Map<String, Uint8List> inputImages = const {},
    Map<String, dynamic> paramValues = const {},
  }) async {
    this.paramValues = paramValues;
    if (_errorCode case final code?) {
      state = state.copyWith(status: ComfyUITaskStatus.failed, errorCode: code);
    }
    return _results;
  }
}

final class _StubNovelAiUpscaleTask extends NovelAiUpscaleTaskNotifier {
  _StubNovelAiUpscaleTask(this._outcome);

  final NovelAiUpscaleOutcome? _outcome;

  @override
  Future<NovelAiUpscaleOutcome> execute({
    required Uint8List sourceImage,
    required Future<void> Function(Uint8List result) adopt,
  }) async {
    final outcome = _outcome!;
    if (outcome is NovelAiUpscaleCompleted) await adopt(_novelAiUpscaled);
    return outcome;
  }
}

final class _RecordingImageGenerationNotifier extends ImageGenerationNotifier {
  int? width;
  int? height;
  ImageParams? params;
  Uint8List? comparisonSourceImage;
  bool? saveToLocal;
  bool? replaceCurrentDisplay;
  bool? embedNaiMetadata;
  final events = <String>[];

  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<void> ensureGenerationHistoryRestored() async {
    events.add('restore');
  }

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
    events.add('register');
    this.width = width;
    this.height = height;
    this.params = params;
    this.comparisonSourceImage = comparisonSourceImage;
    this.saveToLocal = saveToLocal;
    this.replaceCurrentDisplay = replaceCurrentDisplay;
    this.embedNaiMetadata = embedNaiMetadata;
    return null;
  }
}

final class _StubImageSaveSettings extends ImageSaveSettingsNotifier {
  @override
  ImageSaveSettings build() => const ImageSaveSettings();
}

final _novelAiUpscaled = _png(640, 400);

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

/// 最小 VP8L 无损 WebP：1 字节签名后紧跟 14 位宽、14 位高、1 位 alpha、3 位版本。
Uint8List _losslessWebp(int width, int height) {
  const payloadSize = 16;
  final builder = BytesBuilder()
    ..add(ascii.encode('RIFF'))
    ..add(_uint32Le(4 + 8 + payloadSize))
    ..add(ascii.encode('WEBP'))
    ..add(ascii.encode('VP8L'))
    ..add(_uint32Le(payloadSize))
    ..addByte(0x2f)
    ..add(_uint32Le((width - 1) | ((height - 1) << 14)))
    ..add(Uint8List(payloadSize - 5));
  return builder.toBytes();
}

Uint8List _uint32Le(int value) {
  final bytes = Uint8List(4);
  ByteData.view(bytes.buffer).setUint32(0, value, Endian.little);
  return bytes;
}
