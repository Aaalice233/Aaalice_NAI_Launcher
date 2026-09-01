import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/inpaint/inpaint_draft_status.dart';
import 'package:nai_launcher/data/services/inpaint_draft_file_repository.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_image_observation_ledger.dart';
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
        anlasEstimator: (_, _) => 7,
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
      expect((await repository.get(id))!.estimatedAnlas, 7);
      expect(await toolbox.estimateAnlasForDraft(id), 7);

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
      anlasEstimator: (_, _) => 0,
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

  test(
    'session switch stops resource-backed draft before editor launch',
    () async {
      var sessionId = 'session-a';
      final pendingSource = Completer<Uint8List?>();
      var editorLaunches = 0;
      final reference = AgentChatResourceReference(
        kind: AgentChatResourceKind.generatedImage,
        source: 'generation_history',
        resourceId: 'generated-1',
      );
      final toolbox = ManualInpaintToolbox(
        container.read(_refProvider),
        supportDirectory: root,
        anlasEstimator: (_, _) => 0,
        repository: repository,
        resourceLoader: (_) async =>
            (bytes: (await pendingSource.future)!, filePath: null),
        activeSessionId: () => sessionId,
        editorLauncher: (_, __, ___) {
          editorLaunches += 1;
          return ManualInpaintEditorSession(
            result: Future<ImageEditorResult?>.value(),
            close: () {},
          );
        },
      );

      final resultFuture = toolbox.createDraftFromResource(reference);
      sessionId = 'session-b';
      pendingSource.complete(_png());

      final result = await resultFuture;
      expect(result.details['code'], 'session_switched');
      expect(editorLaunches, 0);
      expect(await repository.list(), isEmpty);
    },
  );

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
      anlasEstimator: (_, _) => 0,
      repository: repository,
      resourceLoader: (value) async =>
          value == reference ? (bytes: source, filePath: null) : null,
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

  group('authored masks', () {
    late Directory workspace;
    late AgentImageObservationLedger ledger;
    late File sourceFile;

    Future<ManualInpaintToolbox> buildToolbox({
      ManualInpaintAnlasEstimator? anlasEstimator,
    }) async {
      final toolbox = ManualInpaintToolbox(
        container.read(_refProvider),
        supportDirectory: root,
        workspaceDir: workspace.path,
        repository: repository,
        anlasEstimator: anlasEstimator ?? (_, _) => 5,
        activeSessionId: () => 'session-a',
      );
      toolbox.configureObservationLedger(
        ledger,
        activeSessionId: () => 'session-a',
      );
      return toolbox;
    }

    void markObserved(String path) => ledger.recordToolResult(
      'session-a',
      AgentToolResult(
        content: [
          const ToolResultImageContent(
            ImageContent(
              source: ImageSource.base64(
                mimeType: 'image/png',
                base64Data: 'AA==',
              ),
            ),
          ),
        ],
        details: <String, dynamic>{
          'files': [path],
        },
      ),
    );

    setUp(() async {
      workspace = await Directory('${root.path}/workspace').create();
      ledger = AgentImageObservationLedger();
      sourceFile = File('${workspace.path}/source.png');
      await sourceFile.writeAsBytes(_png(value: 40, width: 512, height: 512));
    });

    test('refuses a source the model has not actually read', () async {
      final toolbox = await buildToolbox();
      final tools = {for (final tool in toolbox.tools()) tool.name: tool};

      final result = await tools['create_inpaint_mask']!.execute('c1', {
        'source_image': 'source.png',
        'prompt': 'fix the hand',
        'focused': false,
        'regions': const [
          {'shape': 'rect', 'x': 0.4, 'y': 0.4, 'width': 0.2, 'height': 0.2},
        ],
      });

      expect(result.details['code'], 'image_not_observed');
      expect(await repository.list(), isEmpty);
    });

    test(
      'commits a ready draft with a mask once the source was read',
      () async {
        final toolbox = await buildToolbox();
        final tools = {for (final tool in toolbox.tools()) tool.name: tool};
        markObserved(sourceFile.path);

        final result = await tools['create_inpaint_mask']!.execute('c2', {
          'source_image': 'source.png',
          'prompt': 'fix the hand',
          'focused': false,
          'regions': const [
            {'shape': 'rect', 'x': 0.4, 'y': 0.4, 'width': 0.2, 'height': 0.2},
          ],
        });

        expect(result.details['ok'], isTrue);
        expect(result.details['focusedInpaint'], isFalse);
        expect(result.details['maskCoverage'], closeTo(0.04, 0.005));
        expect(
          result.content.whereType<ToolResultImageContent>(),
          hasLength(1),
          reason: 'an overlay preview should let the model verify placement',
        );

        final drafts = await repository.list();
        expect(drafts, hasLength(1));
        expect(drafts.single.status, InpaintDraftStatus.ready);
        expect(await repository.readMask(drafts.single.id), isNotNull);
      },
    );

    test(
      'prices focused drafts on the upscaled request, not the source',
      () async {
        final sizes = <(int, int)>[];
        final toolbox = await buildToolbox(
          anlasEstimator: (params, _) {
            sizes.add((params.width, params.height));
            return 11;
          },
        );
        final tools = {for (final tool in toolbox.tools()) tool.name: tool};
        markObserved(sourceFile.path);

        await tools['create_inpaint_mask']!.execute('c3', {
          'source_image': 'source.png',
          'prompt': 'fix the hand',
          'focused': true,
          'preview': false,
          'regions': const [
            {
              'shape': 'rect',
              'x': 0.45,
              'y': 0.45,
              'width': 0.1,
              'height': 0.1,
            },
          ],
        });

        expect(sizes, isNotEmpty);
        final (width, height) = sizes.first;
        expect(
          width * height,
          greaterThan(512 * 512),
          reason:
              'focused inpaint upscales a small crop past the source size, '
              'so pricing it at 512x512 would undercharge the confirmation',
        );
      },
    );

    test('loads a ready draft into the generation panel', () async {
      ({bool focused, Rect? rect, bool outpaint, int width, int height})?
      handoff;
      final toolbox = await buildToolbox();
      toolbox.configurePanelHandoff(({
        required source,
        required sourceWidth,
        required sourceHeight,
        required mask,
        required focusedInpaintEnabled,
        required focusedSelectionRect,
        required minimumContextMegaPixels,
        required sourceIsOutpaint,
      }) async {
        handoff = (
          focused: focusedInpaintEnabled,
          rect: focusedSelectionRect,
          outpaint: sourceIsOutpaint,
          width: sourceWidth,
          height: sourceHeight,
        );
      });
      final tools = {for (final tool in toolbox.tools()) tool.name: tool};
      markObserved(sourceFile.path);

      final created = await tools['create_inpaint_mask']!.execute('p1', {
        'source_image': 'source.png',
        'prompt': 'fix the hand',
        'focused': true,
        'preview': false,
        'regions': const [
          {'shape': 'rect', 'x': 0.45, 'y': 0.45, 'width': 0.1, 'height': 0.1},
        ],
      });
      final draftId = created.details['draft']['draftId'] as String;

      final loaded = await tools['load_inpaint_draft_into_panel']!.execute(
        'p2',
        {'draft_id': draftId},
      );

      expect(loaded.details['ok'], isTrue);
      expect(loaded.details['focusedInpaint'], isTrue);
      expect(handoff, isNotNull);
      expect(handoff!.width, 512);
      expect(handoff!.height, 512);
      expect(handoff!.outpaint, isFalse);
      // 面板在 rect 为空时会把聚焦判为关闭，必须补上蒙版外接框，
      // 否则同一张草稿在面板与聊天两条路径下行为不一致。
      expect(handoff!.focused, isTrue);
      expect(handoff!.rect, isNotNull);
    });

    test('fails cleanly for malformed and missing draft ids', () async {
      final toolbox = await buildToolbox();
      toolbox.configurePanelHandoff(
        ({
          required source,
          required sourceWidth,
          required sourceHeight,
          required mask,
          required focusedInpaintEnabled,
          required focusedSelectionRect,
          required minimumContextMegaPixels,
          required sourceIsOutpaint,
        }) async => fail('handoff must not run for a missing draft'),
      );
      final tools = {for (final tool in toolbox.tools()) tool.name: tool};

      final malformed = await tools['load_inpaint_draft_into_panel']!.execute(
        'p3',
        {'draft_id': 'does-not-exist'},
      );
      expect(malformed.details['code'], 'invalid_draft_id');

      final missing = await tools['load_inpaint_draft_into_panel']!.execute(
        'p4',
        {'draft_id': '3f2504e0-4f89-41d3-9a0c-0305e82c3301'},
      );
      expect(missing.details['code'], 'not_found');
    });

    test(
      'expand_inpaint_canvas needs no prior read and builds its own mask',
      () async {
        final toolbox = await buildToolbox();
        final tools = {for (final tool in toolbox.tools()) tool.name: tool};

        final result = await tools['expand_inpaint_canvas']!.execute('c4', {
          'source_image': 'source.png',
          'prompt': 'extend the scenery',
          'preview': false,
          'edges': const {'left': 64, 'right': 64},
        });

        expect(result.details['ok'], isTrue);
        expect(result.details['focusedInpaint'], isFalse);
        expect(result.details['appliedEdges'], isA<Map<String, dynamic>>());

        final drafts = await repository.list();
        expect(drafts, hasLength(1));
        expect(drafts.single.status, InpaintDraftStatus.ready);
        expect(await repository.readMask(drafts.single.id), isNotNull);
      },
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

Uint8List _png({int value = 128, int width = 8, int height = 8}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return Uint8List.fromList(img.encodePng(image));
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams(negativePrompt: 'bad anatomy');
}
