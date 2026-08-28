import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/models/inpaint/inpaint_draft.dart';
import 'package:nai_launcher/data/models/inpaint/inpaint_draft_status.dart';
import 'package:nai_launcher/data/services/inpaint_draft_file_repository.dart';
import 'package:nai_launcher/data/services/inpaint_draft_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late _IdSequence ids;
  late InpaintDraftFileRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('inpaint_drafts_test_');
    ids = _IdSequence();
    repository = InpaintDraftFileRepository(
      rootDirectory: root,
      idGenerator: ids.next,
      clock: () => DateTime.utc(2026, 3, 14, 12),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'persists schema v1 assets and structured generation snapshot',
    () async {
      final source = _png(width: 12, height: 8, value: 40);
      final snapshot = <String, dynamic>{
        'prompt': 'repair detail',
        'sampling': {'steps': 28, 'cfg': 5.5},
        'characters': [
          {
            'prompt': 'girl',
            'position': [0.25, 0.75],
          },
        ],
      };

      final draft = await repository.prepare(
        sourceBytes: source,
        parameterSnapshot: snapshot,
        estimatedAnlas: 7,
      );
      snapshot['prompt'] = 'mutated after save';

      expect(draft.status, InpaintDraftStatus.prepared);
      expect(draft.id, _IdSequence.first);
      expect(draft.source.width, 12);
      expect(draft.source.height, 8);
      expect(await repository.readSource(draft.id), source);
      final restored = await repository.get(draft.id);
      expect(restored!.parameterSnapshot['prompt'], 'repair detail');
      expect(restored.estimatedAnlas, 7);

      final directory = Directory(p.join(root.path, draft.id));
      expect(
        await File(p.join(directory.path, 'source.image')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(directory.path, 'mask.image')).exists(),
        isFalse,
      );
      final metadata =
          jsonDecode(
                await File(
                  p.join(directory.path, 'metadata.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(metadata['schemaVersion'], InpaintDraft.schemaVersion);
      expect(metadata.containsKey('sourcePath'), isFalse);
      expect(metadata.containsKey('maskPath'), isFalse);
      expect(
        directory.listSync().where((entry) => entry.path.endsWith('.tmp')),
        isEmpty,
      );
    },
  );

  test('enforces lifecycle and complete requires a matching mask', () async {
    final prepared = await _prepare(repository, width: 10, height: 6);

    expect(
      () => repository.complete(
        prepared.id,
        sourceBytes: _png(width: 10, height: 6),
        maskBytes: _png(width: 10, height: 6),
        parameterSnapshot: const {},
        estimatedAnlas: 1,
      ),
      throwsA(isA<InpaintDraftTransitionException>()),
    );

    final editing = await repository.beginEditing(prepared.id);
    expect(editing.status, InpaintDraftStatus.editing);
    await expectLater(
      repository.complete(
        prepared.id,
        sourceBytes: _png(width: 10, height: 6),
        maskBytes: _png(width: 9, height: 6),
        parameterSnapshot: const {},
        estimatedAnlas: 1,
      ),
      throwsA(isA<InpaintDraftIntegrityException>()),
    );

    final ready = await repository.complete(
      prepared.id,
      sourceBytes: _png(width: 10, height: 6, value: 60),
      maskBytes: _png(width: 10, height: 6, value: 220),
      parameterSnapshot: const {
        'prompt': 'final',
        'negativePrompt': 'artifact',
      },
      estimatedAnlas: 3.5,
    );
    expect(ready.status, InpaintDraftStatus.ready);
    expect(ready.mask, isNotNull);
    expect(
      await repository.readSource(prepared.id),
      _png(width: 10, height: 6, value: 60),
    );
    expect(await repository.readMask(prepared.id), isNotNull);

    final submitting = await repository.beginSubmission(prepared.id);
    expect(submitting.status, InpaintDraftStatus.submitting);
    final restored = await repository.restoreReady(
      prepared.id,
      message: 'authentication required',
    );
    expect(restored.status, InpaintDraftStatus.ready);
    expect(restored.failureMessage, 'authentication required');
    await repository.beginSubmission(prepared.id);
    final submitted = await repository.markSubmitted(prepared.id);
    expect(submitted.status, InpaintDraftStatus.submitted);
    await expectLater(
      repository.cancel(prepared.id),
      throwsA(isA<InpaintDraftTransitionException>()),
    );
  });

  test(
    'cancel, failure, and same-draft re-edit use explicit transitions',
    () async {
      final cancelled = await repository.cancel(
        (await _prepare(repository)).id,
      );
      expect(cancelled.status, InpaintDraftStatus.cancelled);
      final resumed = await repository.reEdit(cancelled.id);
      expect(resumed.id, cancelled.id);
      expect(resumed.status, InpaintDraftStatus.editing);

      final completed = await repository.complete(
        resumed.id,
        sourceBytes: _png(),
        maskBytes: _png(),
        parameterSnapshot: const {'seed': 42},
        estimatedAnlas: 2,
      );
      final failed = await repository.markFailed(
        completed.id,
        message: '  network rejected request  ',
      );
      expect(failed.status, InpaintDraftStatus.failed);
      expect(failed.failureMessage, 'network rejected request');
      final retried = await repository.reEdit(failed.id);
      expect(retried.status, InpaintDraftStatus.editing);
      expect(retried.failureMessage, isNull);
    },
  );

  test(
    'ready draft can be cancelled and re-edited without losing assets',
    () async {
      final draft = await _prepare(repository, width: 10, height: 6);
      await repository.beginEditing(draft.id);
      final editedSource = _png(width: 10, height: 6, value: 72);
      final mask = _png(width: 10, height: 6, value: 210);
      await repository.complete(
        draft.id,
        sourceBytes: editedSource,
        maskBytes: mask,
        parameterSnapshot: const {'prompt': 'keep this edit'},
        estimatedAnlas: 4,
      );

      final cancelled = await repository.cancel(draft.id);
      expect(cancelled.status, InpaintDraftStatus.cancelled);
      expect(await repository.readSource(draft.id), editedSource);
      expect(await repository.readMask(draft.id), mask);

      final editing = await repository.reEdit(draft.id);
      expect(editing.status, InpaintDraftStatus.editing);
      expect(await repository.readSource(draft.id), editedSource);
      expect(await repository.readMask(draft.id), mask);
    },
  );

  test('ready draft re-edit copies the committed edited source', () async {
    final draft = await _prepare(repository, width: 10, height: 6);
    await repository.beginEditing(draft.id);
    final editedSource = _png(width: 10, height: 6, value: 93);
    await repository.complete(
      draft.id,
      sourceBytes: editedSource,
      maskBytes: _png(width: 10, height: 6, value: 210),
      parameterSnapshot: const {'prompt': 'keep ready edit'},
      estimatedAnlas: 4,
    );

    final editing = await repository.reEdit(draft.id);

    expect(editing.status, InpaintDraftStatus.editing);
    expect(await repository.readSource(draft.id), editedSource);
  });

  test('new repository recovers interrupted submission as failed', () async {
    final draft = await _prepare(repository);
    await repository.beginEditing(draft.id);
    await repository.complete(
      draft.id,
      sourceBytes: _png(value: 70),
      maskBytes: _png(value: 200),
      parameterSnapshot: const {'prompt': 'recover me'},
      estimatedAnlas: 5,
    );
    await repository.beginSubmission(draft.id);

    final restarted = InpaintDraftFileRepository(
      rootDirectory: root,
      idGenerator: ids.next,
      clock: () => DateTime.utc(2026, 3, 14, 13),
    );
    final recovered = await restarted.get(draft.id);

    expect(recovered!.status, InpaintDraftStatus.failed);
    expect(recovered.failureMessage, contains('interrupted'));
    final editing = await restarted.reEdit(draft.id);
    expect(editing.status, InpaintDraftStatus.editing);
    expect(await restarted.readSource(draft.id), _png(value: 70));
  });

  test(
    're-editing a submitted snapshot creates a new independent draft',
    () async {
      final initial = await _prepare(repository);
      await repository.beginEditing(initial.id);
      final completed = await repository.complete(
        initial.id,
        sourceBytes: _png(),
        maskBytes: _png(value: 180),
        parameterSnapshot: const {'prompt': 'immutable snapshot'},
        estimatedAnlas: 9,
      );
      await repository.beginSubmission(completed.id);
      await repository.markSubmitted(completed.id);

      final fork = await repository.reEdit(completed.id);

      expect(fork.id, _IdSequence.second);
      expect(fork.id, isNot(completed.id));
      expect(fork.status, InpaintDraftStatus.editing);
      expect(fork.reEditOfDraftId, completed.id);
      expect(fork.parameterSnapshot, {'prompt': 'immutable snapshot'});
      expect(
        await repository.readSource(fork.id),
        await repository.readSource(completed.id),
      );
      expect(
        await repository.readMask(fork.id),
        await repository.readMask(completed.id),
      );
      expect(
        (await repository.get(completed.id))!.status,
        InpaintDraftStatus.submitted,
      );
    },
  );

  test('detects tampering and never accepts caller-controlled paths', () async {
    final draft = await _prepare(repository);
    final source = File(p.join(root.path, draft.id, 'source.image'));
    await source.writeAsBytes(_png(value: 99));

    await expectLater(
      repository.get(draft.id),
      throwsA(isA<InpaintDraftIntegrityException>()),
    );
    expect(() => repository.get('../metadata'), throwsArgumentError);
    expect(
      () => repository.get('00000000-0000-0000-0000-000000000000'),
      throwsArgumentError,
    );
  });

  test('rejects unsupported schemas and non-JSON snapshots', () async {
    final draft = await _prepare(repository);
    final metadataFile = File(p.join(root.path, draft.id, 'metadata.json'));
    final metadata =
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
    metadata['schemaVersion'] = 2;
    await metadataFile.writeAsString(jsonEncode(metadata));

    await expectLater(
      repository.get(draft.id),
      throwsA(isA<InpaintDraftIntegrityException>()),
    );
    expect(
      () => repository.prepare(
        sourceBytes: _png(),
        parameterSnapshot: {'bad': Object()},
        estimatedAnlas: 1,
      ),
      throwsArgumentError,
    );
  });
}

Future<InpaintDraft> _prepare(
  InpaintDraftFileRepository repository, {
  int width = 8,
  int height = 8,
}) {
  return repository.prepare(
    sourceBytes: _png(width: width, height: height),
    parameterSnapshot: const {'prompt': 'source'},
    estimatedAnlas: 1,
  );
}

Uint8List _png({int width = 8, int height = 8, int value = 128}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return Uint8List.fromList(img.encodePng(image));
}

class _IdSequence {
  static const first = '10000000-0000-4000-8000-000000000001';
  static const second = '10000000-0000-4000-8000-000000000002';

  var _index = 0;

  String next() {
    _index++;
    return '10000000-0000-4000-8000-${_index.toString().padLeft(12, '0')}';
  }
}
