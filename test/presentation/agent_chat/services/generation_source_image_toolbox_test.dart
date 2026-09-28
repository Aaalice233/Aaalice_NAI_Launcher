import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_source_image_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_workspace_path_resolver.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';

final _refProvider = Provider<Ref>((ref) => ref);

Map<String, dynamic> _json(AgentToolResult result) =>
    jsonDecode(result.content.whereType<ToolResultTextContent>().single.text)
        as Map<String, dynamic>;

Uint8List _png({int width = 64, int height = 96}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

final _reference = AgentChatResourceReference(
  kind: AgentChatResourceKind.localGalleryImage,
  source: 'local_gallery',
  resourceId: 'source-1',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late Directory workspaceDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('nai_source_image_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
    workspaceDir = await Directory.systemTemp.createTemp('nai_source_image_ws_');
  });

  tearDown(() async {
    if (await workspaceDir.exists()) await workspaceDir.delete(recursive: true);
  });

  ({ProviderContainer container, List<AgentTool> tools}) build({
    Uint8List? resolvedBytes,
    bool allowOutsideWorkspace = false,
  }) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ref = container.read(_refProvider);
    final tools = GenerationSourceImageToolbox(
      ref,
      resolver: _StubResolver(ref, bytes: resolvedBytes),
      pathResolver: GenerationWorkspacePathResolver(
        workspaceDir: workspaceDir.path,
        allowOutsideWorkspace: allowOutsideWorkspace,
      ),
    ).tools();
    return (container: container, tools: tools);
  }

  AgentTool toolNamed(List<AgentTool> tools, String name) =>
      tools.firstWhere((tool) => tool.name == name);

  Map<String, dynamic> encodedReference() =>
      AgentChatResourceReferenceCodec.encodeJsonMap(_reference);

  test('declares strict schemas and generation-domain permissions', () {
    final built = build();

    expect(built.tools.map((tool) => tool.name), [
      'get_generation_source_image',
      'set_generation_source_image',
      'clear_generation_source_image',
      'update_generation_source_settings',
    ]);
    for (final tool in built.tools) {
      expect(tool.parameters['type'], 'object', reason: tool.name);
      final descriptor = describeAgentToolPermission(tool.name);
      expect(
        tool.parameters['additionalProperties'],
        isFalse,
        reason: tool.name,
      );
      expect(
        descriptor.domain,
        AgentPermissionDomain.generation,
        reason: tool.name,
      );
      expect(descriptor.mayConsumeAnlas, isFalse, reason: tool.name);
    }
    expect(
      describeAgentToolPermission('get_generation_source_image').operation,
      AgentPermissionOperation.read,
    );
    expect(
      describeAgentToolPermission('set_generation_source_image').operation,
      AgentPermissionOperation.update,
    );
    expect(
      describeAgentToolPermission('clear_generation_source_image').operation,
      AgentPermissionOperation.delete,
    );
    expect(
      describeAgentToolPermission('update_generation_source_settings').operation,
      AgentPermissionOperation.update,
    );
  });

  test('loads a resource reference into the generation page panel', () async {
    final bytes = _png(width: 640, height: 960);
    final built = build(resolvedBytes: bytes);

    final result = await toolNamed(
      built.tools,
      'set_generation_source_image',
    ).execute('set', {'resource_ref': encodedReference()});

    expect(result.isError, isFalse);
    final params = built.container.read(generationParamsNotifierProvider);
    expect(params.action, ImageGenerationAction.img2img);
    expect(params.sourceImage, bytes);
    expect(
      built.container.read(imageWorkflowControllerProvider).isPanelExpanded,
      isTrue,
    );

    final json = _json(result);
    expect(json['has_source_image'], isTrue);
    expect(json['source_image'], containsPair('width', 640));
    expect(json['source_image'], containsPair('height', 960));
    expect(json['source_image'], containsPair('byte_size', bytes.length));
    expect(json['resource_ref'], encodedReference());
  });

  test('loads a workspace file and reports no path back to the model', () async {
    final bytes = _png();
    final file = File('${workspaceDir.path}${Platform.pathSeparator}base.png');
    await file.writeAsBytes(bytes);
    final built = build();

    final result = await toolNamed(
      built.tools,
      'set_generation_source_image',
    ).execute('set', {'image_path': 'base.png'});

    expect(result.isError, isFalse);
    expect(
      built.container.read(generationParamsNotifierProvider).sourceImage,
      bytes,
    );
    final json = _json(result);
    expect(json.keys, isNot(contains('image_path')));
    expect(json.keys, isNot(contains('path')));
    expect(json.keys, isNot(contains('file_path')));
  });

  test('rejects an outside-workspace path without leaking it', () async {
    final outside = File(
      '${hiveDir.path}${Platform.pathSeparator}outside.png',
    );
    await outside.writeAsBytes(_png());
    final built = build();

    final result = await toolNamed(
      built.tools,
      'set_generation_source_image',
    ).execute('set', {'image_path': outside.path});

    expect(result.isError, isTrue);
    final json = _json(result);
    expect(json['code'], 'image_path_not_permitted');
    expect(json['message'], isNot(contains(hiveDir.path)));
    expect(
      built.container.read(generationParamsNotifierProvider).sourceImage,
      isNull,
    );
  });

  test('requires exactly one of resource_ref and image_path', () async {
    final built = build(resolvedBytes: _png());
    final tool = toolNamed(built.tools, 'set_generation_source_image');

    final neither = await tool.execute('neither', const {});
    final both = await tool.execute('both', {
      'resource_ref': encodedReference(),
      'image_path': 'base.png',
    });

    expect(_json(neither)['code'], 'invalid_source');
    expect(_json(both)['code'], 'invalid_source');
  });

  test('rejects data that is not a decodable image', () async {
    final built = build(resolvedBytes: Uint8List.fromList([1, 2, 3, 4]));

    final result = await toolNamed(
      built.tools,
      'set_generation_source_image',
    ).execute('set', {'resource_ref': encodedReference()});

    expect(_json(result)['code'], 'invalid_image');
    expect(
      built.container.read(generationParamsNotifierProvider).sourceImage,
      isNull,
    );
  });

  test('clear is idempotent and returns to text-to-image', () async {
    final built = build(resolvedBytes: _png());
    await toolNamed(
      built.tools,
      'set_generation_source_image',
    ).execute('set', {'resource_ref': encodedReference()});
    final clear = toolNamed(built.tools, 'clear_generation_source_image');

    final first = _json(await clear.execute('clear-1', const {}));
    final second = _json(await clear.execute('clear-2', const {}));

    expect(first['cleared'], isTrue);
    expect(second['cleared'], isFalse);
    expect(second['has_source_image'], isFalse);
    final params = built.container.read(generationParamsNotifierProvider);
    expect(params.sourceImage, isNull);
    expect(params.action, ImageGenerationAction.generate);
  });

  test('writes strength, noise and inpaint strength in base mode', () async {
    final built = build(resolvedBytes: _png());
    await toolNamed(
      built.tools,
      'set_generation_source_image',
    ).execute('set', {'resource_ref': encodedReference()});

    final result = await toolNamed(
      built.tools,
      'update_generation_source_settings',
    ).execute('update', {
      'strength': 0.4,
      'noise': 0.1,
      'inpaint_strength': 0.8,
    });

    expect(result.isError, isFalse);
    final params = built.container.read(generationParamsNotifierProvider);
    expect(params.strength, 0.4);
    expect(params.noise, 0.1);
    expect(params.inpaintStrength, 0.8);
  });

  test('set applies inline strength together with the source image', () async {
    final built = build(resolvedBytes: _png());

    await toolNamed(built.tools, 'set_generation_source_image').execute('set', {
      'resource_ref': encodedReference(),
      'strength': 0.35,
      'noise': 0.05,
    });

    final params = built.container.read(generationParamsNotifierProvider);
    expect(params.strength, 0.35);
    expect(params.noise, 0.05);
  });

  test('rejects strength while the Enhance sub-mode owns it', () async {
    final built = build(resolvedBytes: _png());
    await toolNamed(
      built.tools,
      'set_generation_source_image',
    ).execute('set', {'resource_ref': encodedReference()});
    built.container.read(imageWorkflowControllerProvider.notifier)
      ..setSourceImageDimensions(640, 960)
      ..enterEnhanceMode();

    final rejected = await toolNamed(
      built.tools,
      'update_generation_source_settings',
    ).execute('enhance', {'strength': 0.4});
    final allowed = await toolNamed(
      built.tools,
      'update_generation_source_settings',
    ).execute('enhance-inpaint', {'inpaint_strength': 0.6});

    expect(_json(rejected)['code'], 'enhance_owns_strength');
    expect(allowed.isError, isFalse);
    expect(
      built.container.read(generationParamsNotifierProvider).inpaintStrength,
      0.6,
    );
  });

  test('rejects strength while the Upscale sub-mode owns it', () async {
    final built = build(resolvedBytes: _png());
    await toolNamed(
      built.tools,
      'set_generation_source_image',
    ).execute('set', {'resource_ref': encodedReference()});
    built.container.read(imageWorkflowControllerProvider.notifier)
      ..setSourceImageDimensions(640, 960)
      ..enterUpscaleMode();

    final result = await toolNamed(
      built.tools,
      'update_generation_source_settings',
    ).execute('upscale', {'noise': 0.2});

    expect(_json(result)['code'], 'upscale_owns_strength');
  });

  test('settings need a source image and at least one value', () async {
    final built = build(resolvedBytes: _png());
    final tool = toolNamed(built.tools, 'update_generation_source_settings');

    final empty = await tool.execute('empty', const {});
    final noSource = await tool.execute('no-source', {'strength': 0.4});

    expect(_json(empty)['code'], 'no_settings');
    expect(_json(noSource)['code'], 'no_source_image');
  });

  test('replacing keeps the Enhance sub-mode but drops a stale mask', () async {
    final built = build(resolvedBytes: _png());
    final set = toolNamed(built.tools, 'set_generation_source_image');
    final workflow = built.container.read(
      imageWorkflowControllerProvider.notifier,
    );
    await set.execute('first', {'resource_ref': encodedReference()});

    workflow
      ..setSourceImageDimensions(640, 960)
      ..enterEnhanceMode();
    final keptEnhance = _json(
      await set.execute('second', {'resource_ref': encodedReference()}),
    );

    expect(keptEnhance['mode'], 'enhance');

    workflow.enterBaseMode();
    workflow.onMaskChanged(_png());
    workflow.enterInpaintMode();
    expect(
      built.container.read(generationParamsNotifierProvider).maskImage,
      isNotNull,
    );

    final afterReplace = _json(
      await set.execute('third', {'resource_ref': encodedReference()}),
    );

    expect(afterReplace['mode'], 'base');
    expect(afterReplace['has_mask'], isFalse);
    expect(
      built.container.read(generationParamsNotifierProvider).maskImage,
      isNull,
    );
  });

  test('get reports panel state without exposing any path', () async {
    final built = build(resolvedBytes: _png(width: 512, height: 512));
    final get = toolNamed(built.tools, 'get_generation_source_image');

    final before = _json(await get.execute('before', const {}));
    await toolNamed(
      built.tools,
      'set_generation_source_image',
    ).execute('set', {'resource_ref': encodedReference()});
    final after = _json(await get.execute('after', const {}));

    expect(before['has_source_image'], isFalse);
    expect(before['source_image'], isNull);
    expect(before['action'], 'generate');
    expect(after['has_source_image'], isTrue);
    expect(after['action'], 'img2img');
    expect(after['mode'], 'base');
    expect(after['has_mask'], isFalse);
    expect(after['source_image'], containsPair('width', 512));
    expect(after['request_size'], isNotNull);
    expect(jsonEncode(after), isNot(contains(workspaceDir.path)));
  });
}

class _StubResolver extends AgentResourceResolver {
  _StubResolver(super.ref, {this.bytes});

  final Uint8List? bytes;

  @override
  Future<ResolvedAgentResource?> resolve(
    AgentChatResourceReference requested,
  ) async => bytes == null
      ? null
      : ResolvedAgentResource(
          reference: requested,
          label: 'source',
          bytes: bytes,
          filePath: 'C:\\secret\\source.png',
        );
}
