import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/inpaint/inpaint_draft_status.dart';
import 'package:nai_launcher/data/services/inpaint_draft_file_repository.dart';
import 'package:nai_launcher/presentation/agent_chat/services/manual_inpaint_toolbox.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late Directory root;
  late ProviderContainer container;
  late InpaintDraftFileRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('manual_inpaint_tool_test_');
    container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
      ],
    );
    repository = InpaintDraftFileRepository(
      rootDirectory: Directory('${root.path}/drafts'),
    );
  });

  tearDown(() async {
    container.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'create returns while editor is open, then ready draft submits',
    () async {
      final source = _png(value: 30);
      final mask = _png(value: 255);
      final sourceFile = File('${root.path}/source.png');
      await sourceFile.writeAsBytes(source);
      final editorResult = Completer<ImageEditorResult?>();
      ImageParams? submittedParams;
      final updates = <(String, InpaintDraftStatus)>[];
      final toolbox = ManualInpaintToolbox(
        container.read(_refProvider),
        supportDirectory: root,
        workspaceDir: root.path,
        repository: repository,
        editorLauncher: (_, __, ___) => ManualInpaintEditorSession(
          result: editorResult.future,
          close: () {},
        ),
        submitter: (params) async {
          submittedParams = params;
          return const ManualInpaintSubmissionResult(accepted: true);
        },
        activeSessionId: () => 'session-a',
        onDraftChanged: (sessionId, draft) {
          updates.add((sessionId, draft.status));
        },
      );
      final tools = {for (final tool in toolbox.tools()) tool.name: tool};
      expect(tools, contains('reedit_manual_inpaint_draft'));

      final createResult = await tools['create_manual_inpaint_draft']!.execute(
        'create',
        {
          'source_image': sourceFile.path,
          'prompt': ' repair face ',
          'params': {'steps': 31, 'inpaintStrength': 0.65},
        },
      );
      final created = _json(createResult)['draft'] as Map<String, dynamic>;
      final id = created['draftId'] as String;
      expect(created['status'], 'editing');
      expect(editorResult.isCompleted, isFalse);
      expect(
        (await repository.get(id))!.parameterSnapshot['prompt'],
        'repair face',
      );

      editorResult.complete(
        ImageEditorResult(
          maskImage: mask,
          inpaintSourceImage: source,
          hasMaskChanges: true,
        ),
      );
      await _waitForStatus(repository, id, InpaintDraftStatus.ready);
      expect(updates, contains(('session-a', InpaintDraftStatus.ready)));

      final getResult = await tools['get_manual_inpaint_draft']!.execute(
        'get',
        {'draft_id': id},
      );
      expect((_json(getResult)['draft'] as Map)['status'], 'ready');
      expect(
        getResult.content.whereType<ToolResultImageContent>(),
        hasLength(2),
      );
      final listResult = await tools['list_manual_inpaint_drafts']!.execute(
        'list',
        const {},
      );
      expect((_json(listResult)['drafts'] as List), hasLength(1));

      final unconfirmed = await tools['submit_manual_inpaint_draft']!.execute(
        'submit-no',
        {'draft_id': id, 'confirm': false},
      );
      expect(unconfirmed.isError, isTrue);
      expect((await repository.get(id))!.status, InpaintDraftStatus.ready);

      final submitted = await tools['submit_manual_inpaint_draft']!.execute(
        'submit',
        {'draft_id': id, 'confirm': true},
      );
      expect(submitted.isError, isFalse);
      expect((_json(submitted)['draft'] as Map)['status'], 'submitting');
      expect(_json(submitted)['asynchronous'], isTrue);
      await _waitForStatus(repository, id, InpaintDraftStatus.submitted);
      expect(updates, contains(('session-a', InpaintDraftStatus.submitted)));
      expect((await repository.get(id))!.status, InpaintDraftStatus.submitted);
      expect(submittedParams!.action, ImageGenerationAction.infill);
      expect(submittedParams!.prompt, 'repair face');
      expect(submittedParams!.steps, 31);
      expect(submittedParams!.inpaintStrength, 0.65);
      expect(submittedParams!.sourceImage, source);
      expect(submittedParams!.maskImage, mask);
    },
  );

  test('cancel closes editor and persists cancelled status', () async {
    final sourceFile = File('${root.path}/source.png');
    await sourceFile.writeAsBytes(_png());
    final editorResult = Completer<ImageEditorResult?>();
    var closed = false;
    final toolbox = ManualInpaintToolbox(
      container.read(_refProvider),
      supportDirectory: root,
      workspaceDir: root.path,
      repository: repository,
      editorLauncher: (_, __, ___) => ManualInpaintEditorSession(
        result: editorResult.future,
        close: () {
          closed = true;
          editorResult.complete(null);
        },
      ),
      submitter: (_) async =>
          const ManualInpaintSubmissionResult(accepted: true),
    );
    final tools = {for (final tool in toolbox.tools()) tool.name: tool};
    final created = _json(
      await tools['create_manual_inpaint_draft']!.execute('create', {
        'source_image': sourceFile.path,
        'prompt': 'repair',
      }),
    );
    final id = (created['draft'] as Map)['draftId'] as String;

    await tools['cancel_manual_inpaint_draft']!.execute('cancel', {
      'draft_id': id,
    });

    expect(closed, isTrue);
    expect((await repository.get(id))!.status, InpaintDraftStatus.cancelled);
  });

  test('create resolves and persists a stable source reference', () async {
    final source = _png(value: 72);
    final editorResult = Completer<ImageEditorResult?>();
    final reference = AgentChatResourceReference(
      kind: AgentChatResourceKind.localGalleryImage,
      source: 'local_gallery',
      resourceId: '42',
      display: const {'name': 'source.png'},
    );
    final toolbox = ManualInpaintToolbox(
      container.read(_refProvider),
      supportDirectory: root,
      repository: repository,
      resourceLoader: (value) async => value == reference ? source : null,
      editorLauncher: (_, __, ___) =>
          ManualInpaintEditorSession(result: editorResult.future, close: () {}),
    );
    final tools = {for (final tool in toolbox.tools()) tool.name: tool};

    final result = await tools['create_manual_inpaint_draft']!.execute(
      'create-ref',
      {
        'source_ref': AgentChatResourceReferenceCodec.encodeJsonMap(reference),
        'prompt': 'repair',
      },
    );

    expect(result.isError, isFalse);
    final draftJson = _json(result)['draft'] as Map<String, dynamic>;
    expect(draftJson['sourceReference'], {
      'version': 1,
      'kind': 'localGalleryImage',
      'source': 'local_gallery',
      'resourceId': '42',
      'display': {'name': 'source.png'},
    });
    final persisted = await repository.get(draftJson['draftId'] as String);
    expect(
      persisted!.parameterSnapshot['_agentSourceReference'],
      draftJson['sourceReference'],
    );
    editorResult.complete(null);
    await _waitForStatus(
      repository,
      persisted.id,
      InpaintDraftStatus.cancelled,
    );
  });
}

Map<String, dynamic> _json(AgentToolResult result) =>
    jsonDecode(result.content.whereType<ToolResultTextContent>().single.text)
        as Map<String, dynamic>;

Future<void> _waitForStatus(
  InpaintDraftFileRepository repository,
  String id,
  InpaintDraftStatus expected,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if ((await repository.get(id))?.status == expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Draft $id did not reach ${expected.name}.');
}

Uint8List _png({int value = 128}) {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return Uint8List.fromList(img.encodePng(image));
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams(negativePrompt: 'bad anatomy');
}
