import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_image_source_loader.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generated_image_export_writer.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_read_contract.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_resource.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_save_path_exporter.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_save_path_validator.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_workspace_path_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_upscale_toolbox.dart';
import 'package:nai_launcher/presentation/providers/comfyui/comfyui_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_upscale_coordinator.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/generation/novel_ai_upscale_task_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

Map<String, dynamic> _json(AgentToolResult result) =>
    jsonDecode(result.content.whereType<ToolResultTextContent>().first.text)
        as Map<String, dynamic>;

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

final _sourceRef = AgentChatResourceReferenceCodec.encodeJsonMap(
  generationImageResourceReference('source'),
);

const _sourceComment = '{"prompt":"1girl, smile"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('upscale_image is a charged tool in the generation domain', () {
    final descriptor = describeAgentToolPermission('upscale_image');

    expect(descriptor.domain, AgentPermissionDomain.generation);
    expect(descriptor.operation, AgentPermissionOperation.update);
    expect(descriptor.mayConsumeAnlas, isTrue);
    expect(descriptor.deletesStoredData, isFalse);
  });

  test('NovelAI is estimated by source area and ComfyUI is free', () async {
    final payg = await _Harness.create(source: _png(832, 1216));
    final opusSmall = await _Harness.create(
      source: _png(640, 640),
      subscriptionTier: 3,
    );
    final oversized = await _Harness.create(source: _png(2048, 2048));
    addTearDown(payg.dispose);
    addTearDown(opusSmall.dispose);
    addTearDown(oversized.dispose);

    expect(await payg.estimate({'resource_ref': _sourceRef}), 1);
    expect(await opusSmall.estimate({'resource_ref': _sourceRef}), 0);
    expect(
      await oversized.estimate({'resource_ref': _sourceRef}),
      AnlasCalculator.invalidCost,
    );
    expect(
      await payg.estimate({'resource_ref': _sourceRef, 'backend': 'comfyui'}),
      0,
    );
    // 参数本身不成立的调用不会发出请求。
    expect(
      await payg.estimate({'resource_ref': _sourceRef, 'backend': 'other'}),
      0,
    );
  });

  test('a paid NovelAI upscale runs only at the approved price', () async {
    final harness = await _Harness.create(
      source: _png(832, 1216),
      pageBackend: UpscaleBackend.comfyui,
    );
    addTearDown(harness.dispose);
    final args = {'resource_ref': _sourceRef, 'backend': 'novelai'};

    final unapproved = await harness.upscale(args);
    expect(_json(unapproved)['code'], 'upscale_cost_changed');
    expect(harness.coordinator.requests, isEmpty);

    await harness.estimate(args);
    final result = await harness.upscale(args);

    expect(result.isError, isFalse, reason: '${_json(result)}');
    final payload = _json(result);
    expect(payload['backend'], 'novelai');
    expect(payload['upscaler'], 'novelai');
    expect(payload['source_size'], '832x1216');
    final image = (payload['images'] as List).single as Map;
    expect(image['resource_ref'], isA<Map>());
    expect(image['size'], '1664x2432');
    expect(
      harness.coordinator.requests.single.settings.backend,
      UpscaleBackend.novelai,
    );
    // 单次覆盖不写回生成页设置。
    expect(
      harness.container.read(imageWorkflowControllerProvider).upscale.backend,
      UpscaleBackend.comfyui,
    );
    final registered = harness.registrar.registrations.single;
    expect(registered.embedNaiMetadata, isFalse);
    expect(registered.saveToLocal, isTrue);
    expect(registered.replaceCurrentDisplay, isTrue);
    expect(
      UnifiedMetadataParser.extractPngTextData(registered.bytes)['Comment'],
      _sourceComment,
    );
    expect(harness.registrar.restoreCalls, 1);
  });

  test('an approved price survives reconfiguring the toolbox', () async {
    final harness = await _Harness.create(source: _png(832, 1216));
    addTearDown(harness.dispose);
    final args = {'resource_ref': _sourceRef};

    await harness.estimate(args);
    harness.reconfigure();
    final result = await harness.upscale(args);

    expect(result.isError, isFalse, reason: '${_json(result)}');
    expect(harness.coordinator.requests, hasLength(1));
  });

  test('an approval for another source does not authorize this one', () async {
    final harness = await _Harness.create(source: _png(832, 1216));
    addTearDown(harness.dispose);

    await harness.estimate({'image_path': 'other.png'});
    final result = await harness.upscale({'resource_ref': _sourceRef});

    expect(_json(result)['code'], 'upscale_cost_changed');
    expect(harness.coordinator.requests, isEmpty);
  });

  test(
    'ComfyUI needs to be enabled and scale only applies to this call',
    () async {
      final disabled = await _Harness.create(
        source: _png(832, 1216),
        pageBackend: UpscaleBackend.comfyui,
      );
      final enabled = await _Harness.create(
        source: _png(832, 1216),
        pageBackend: UpscaleBackend.comfyui,
        comfyEnabled: true,
      );
      addTearDown(disabled.dispose);
      addTearDown(enabled.dispose);

      final rejected = await disabled.upscale({'resource_ref': _sourceRef});
      final result = await enabled.upscale({
        'resource_ref': _sourceRef,
        'scale': 2.0,
      });

      expect(_json(rejected)['code'], 'comfyui_disabled');
      expect(disabled.coordinator.requests, isEmpty);
      expect(result.isError, isFalse, reason: '${_json(result)}');
      expect(enabled.coordinator.requests.single.settings.comfyScale, 2.0);
      expect(enabled.models.fetchCalls, 1);
      expect(
        enabled.container
            .read(imageWorkflowControllerProvider)
            .upscale
            .comfyScale,
        UpscaleWorkflowSettings.defaultComfyScale,
      );
    },
  );

  test('invalid arguments are rejected before any request', () async {
    final harness = await _Harness.create(source: _png(832, 1216));
    final oversized = await _Harness.create(source: _png(2048, 2048));
    addTearDown(harness.dispose);
    addTearDown(oversized.dispose);

    final cases = <String, Map<String, dynamic>>{
      'invalid_source': {'resource_ref': _sourceRef, 'image_path': 'a.png'},
      'invalid_backend': {'resource_ref': _sourceRef, 'backend': 'other'},
      'scale_unsupported': {'resource_ref': _sourceRef, 'scale': 1.5},
      'invalid_scale': {
        'resource_ref': _sourceRef,
        'backend': 'comfyui',
        'scale': 3,
      },
      'invalid_save_path': {
        'resource_ref': _sourceRef,
        'save_path': 'up-{seed}.png',
      },
    };
    for (final MapEntry(key: code, value: args) in cases.entries) {
      expect(_json(await harness.upscale(args))['code'], code, reason: code);
    }
    expect(
      _json(await oversized.upscale({'resource_ref': _sourceRef}))['code'],
      'upscale_source_too_large',
    );
    expect(harness.coordinator.requests, isEmpty);
    expect(oversized.coordinator.requests, isEmpty);
  });

  test('backend failures are reported with their cause', () async {
    final failed = await _Harness.create(
      source: _png(832, 1216),
      result: const ImageUpscaleRejected(
        ImageUpscaleFailure.requestFailed,
        detail: '服务器返回错误: 402',
      ),
    );
    final signedOut = await _Harness.create(
      source: _png(832, 1216),
      result: const ImageUpscaleRejected(
        ImageUpscaleFailure.authenticationRequired,
      ),
    );
    addTearDown(failed.dispose);
    addTearDown(signedOut.dispose);
    final args = {'resource_ref': _sourceRef};

    await failed.estimate(args);
    await signedOut.estimate(args);
    final failure = _json(await failed.upscale(args));
    final unauthenticated = _json(await signedOut.upscale(args));

    expect(failure['code'], 'upscale_failed');
    expect(failure['message'], contains('402'));
    expect(unauthenticated['code'], 'authentication_required');
  });

  test('save_path writes a copy of the upscaled image', () async {
    final harness = await _Harness.create(source: _png(832, 1216));
    addTearDown(harness.dispose);
    final args = {'resource_ref': _sourceRef, 'save_path': 'out/up-{id}.png'};

    await harness.estimate(args);
    final result = await harness.upscale(args);

    expect(result.isError, isFalse, reason: '${_json(result)}');
    final image = (_json(result)['images'] as List).single as Map;
    final savedPath = image['saved_path'] as String;
    expect(image['saved_path_source'], 'caller');
    expect(savedPath, endsWith('out/up-registered-1.png'));
    expect(File(savedPath).existsSync(), isTrue);
  });

  test('an upscale waiting on a busy backend stops when aborted', () async {
    final harness = await _Harness.create(
      source: _png(832, 1216),
      novelAiRunning: true,
    );
    addTearDown(harness.dispose);
    final args = {'resource_ref': _sourceRef};
    await harness.estimate(args);
    final controller = AbortController();

    final pending = harness.upscale(args, signal: controller.signal);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    controller.abort();

    await expectLater(pending, throwsStateError);
    expect(harness.coordinator.requests, isEmpty);
  });
}

final class _Harness {
  _Harness._({
    required this.container,
    required this.toolbox,
    required this.coordinator,
    required this.registrar,
    required this.models,
    required this.workspace,
    required this.reconfigure,
  });

  static Future<_Harness> create({
    required Uint8List source,
    UpscaleBackend pageBackend = UpscaleBackend.novelai,
    bool comfyEnabled = false,
    int subscriptionTier = 1,
    bool novelAiRunning = false,
    ImageUpscaleResult? result,
  }) async {
    final workspace = await Directory.systemTemp.createTemp('agent-upscale-');
    final registrar = _Registrar(workspace);
    final models = _StubModels();
    final container = ProviderContainer(
      overrides: [
        imageWorkflowControllerProvider.overrideWith(
          () => _StubWorkflowController(
            ImageWorkflowState(
              upscale: UpscaleWorkflowSettings(backend: pageBackend),
            ),
          ),
        ),
        subscriptionNotifierProvider.overrideWith(
          () => _TestSubscription(subscriptionTier),
        ),
        imageUpscaleCoordinatorProvider.overrideWith(
          (ref) => _FakeCoordinator(ref, result),
        ),
        imageGenerationNotifierProvider.overrideWith(() => registrar),
        comfyUISettingsProvider.overrideWith(
          () => _StubComfySettings(comfyEnabled),
        ),
        comfyUISeedvr2ModelsProvider.overrideWith(() => models),
        novelAiUpscaleTaskProvider.overrideWith(
          () => _StubNovelAiTask(running: novelAiRunning),
        ),
      ],
    );
    final coordinator =
        container.read(imageUpscaleCoordinatorProvider) as _FakeCoordinator;
    final ref = container.read(_refProvider);
    final pathResolver = GenerationWorkspacePathResolver(
      workspaceDir: workspace.path,
    );
    final writer = GeneratedImageExportWriter(env: pathResolver.env);
    final toolbox = ImageUpscaleToolbox(ref);
    void configure() => toolbox.configure(
      sourceLoader: AgentImageSourceLoader(
        resolver: _BytesResolver(ref, _withComment(source)),
        pathResolver: pathResolver,
      ),
      savePathValidator: GenerationSavePathValidator(
        pathResolver: pathResolver,
        exportWriter: writer,
      ),
      exporter: GenerationSavePathExporter(writer: writer),
      readContract: GenerationImageReadContract(pathResolver),
      referencesGalleryOriginal: false,
    );
    configure();
    return _Harness._(
      container: container,
      toolbox: toolbox,
      coordinator: coordinator,
      registrar: registrar,
      models: models,
      workspace: workspace,
      reconfigure: configure,
    );
  }

  final ProviderContainer container;
  final ImageUpscaleToolbox toolbox;
  final _FakeCoordinator coordinator;
  final _Registrar registrar;
  final _StubModels models;
  final Directory workspace;

  /// 权限档切换重建注册表时会重新配置同一个工具箱。
  final void Function() reconfigure;

  Future<int?> estimate(Map<String, dynamic> args) =>
      toolbox.estimateAnlas(args);

  Future<AgentToolResult> upscale(
    Map<String, dynamic> args, {
    AbortSignal? signal,
  }) => toolbox.tools().single.execute('upscale', args, signal);

  Future<void> dispose() async {
    container.dispose();
    await workspace.delete(recursive: true);
  }

  static Uint8List _withComment(Uint8List png) =>
      UnifiedMetadataParser.embedTextChunkOnly(png, 'Comment', _sourceComment);
}

final class _FakeCoordinator extends ImageUpscaleCoordinator {
  _FakeCoordinator(super.ref, this._result);

  final ImageUpscaleResult? _result;
  final requests = <ImageUpscaleRequest>[];

  @override
  Future<ImageUpscaleResult> execute(
    ImageUpscaleRequest request, {
    required ImageUpscaleAdopter adopt,
  }) async {
    requests.add(request);
    final result = _result;
    if (result != null) return result;
    await adopt(
      ImageUpscaleOutput(
        bytes: _png(1664, 2432),
        kind: ImageUpscaleKind.novelAi,
        width: 1664,
        height: 2432,
      ),
    );
    return const ImageUpscaleSuccess(
      kind: ImageUpscaleKind.novelAi,
      width: 1664,
      height: 2432,
    );
  }
}

final class _Registration {
  const _Registration({
    required this.bytes,
    required this.saveToLocal,
    required this.replaceCurrentDisplay,
    required this.embedNaiMetadata,
  });

  final Uint8List bytes;
  final bool saveToLocal;
  final bool replaceCurrentDisplay;
  final bool embedNaiMetadata;
}

final class _Registrar extends ImageGenerationNotifier {
  _Registrar(this._directory);

  final Directory _directory;
  final registrations = <_Registration>[];
  int restoreCalls = 0;

  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<void> ensureGenerationHistoryRestored() async => restoreCalls++;

  @override
  Future<GeneratedImage?> registerExternalImageEntry(
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
        replaceCurrentDisplay: replaceCurrentDisplay,
        embedNaiMetadata: embedNaiMetadata,
      ),
    );
    final id = 'registered-${registrations.length}';
    final file = File('${_directory.path}/gallery/$id.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(imageBytes);
    return GeneratedImage(
      id: id,
      bytes: imageBytes,
      width: 1664,
      height: 2432,
      filePath: file.path,
    );
  }
}

final class _BytesResolver extends AgentResourceResolver {
  _BytesResolver(super.ref, this._bytes);

  final Uint8List _bytes;

  @override
  Future<ResolvedAgentResource?> resolve(
    AgentChatResourceReference requested,
  ) async => ResolvedAgentResource(
    reference: requested,
    label: 'source',
    bytes: _bytes,
  );
}

final class _StubWorkflowController extends ImageWorkflowController {
  _StubWorkflowController(this._initial);

  final ImageWorkflowState _initial;

  @override
  ImageWorkflowState build() => _initial;
}

final class _TestSubscription extends SubscriptionNotifier {
  _TestSubscription(this._tier);

  final int _tier;

  @override
  SubscriptionState build() =>
      SubscriptionState.loaded(UserSubscription(tier: _tier, active: true));
}

final class _StubComfySettings extends ComfyUISettings {
  _StubComfySettings(this._enabled);

  final bool _enabled;

  @override
  ComfyUISettingsState build() => ComfyUISettingsState(enabled: _enabled);
}

final class _StubModels extends ComfyUISeedvr2Models {
  int fetchCalls = 0;

  @override
  List<String> build() => const [];

  @override
  Future<void> fetch({bool force = false}) async => fetchCalls++;
}

final class _StubNovelAiTask extends NovelAiUpscaleTaskNotifier {
  _StubNovelAiTask({required this.running});

  final bool running;

  @override
  NovelAiUpscaleTaskState build() => NovelAiUpscaleTaskState(
    status: running
        ? NovelAiUpscaleTaskStatus.running
        : NovelAiUpscaleTaskStatus.idle,
  );
}
