import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/inpaint/inpaint_draft.dart';
import '../models/inpaint/inpaint_draft_status.dart';
import 'inpaint_draft_file_store.dart';
import 'inpaint_draft_repository.dart';

typedef InpaintDraftIdGenerator = String Function();
typedef InpaintDraftClock = DateTime Function();

class InpaintDraftFileRepository implements InpaintDraftRepository {
  InpaintDraftFileRepository({
    required Directory rootDirectory,
    InpaintDraftIdGenerator? idGenerator,
    InpaintDraftClock? clock,
  }) : _rootDirectory = rootDirectory,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _clock = clock ?? DateTime.now,
       _fileStore = InpaintDraftFileStore();

  static const _metadataFileName = 'metadata.json';
  static const _sourceFileName = 'source.image';
  static const _readySourceFileName = 'source.ready.image';
  static const _maskFileName = 'mask.image';
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final Directory _rootDirectory;
  final InpaintDraftIdGenerator _idGenerator;
  final InpaintDraftClock _clock;
  final InpaintDraftFileStore _fileStore;
  final Set<String> _activeSubmissions = {};

  @override
  Future<InpaintDraft> prepare({
    required Uint8List sourceBytes,
    required Map<String, dynamic> parameterSnapshot,
    required num estimatedAnlas,
  }) async {
    final source = _fileStore.inspectImage(sourceBytes, label: 'source');
    final snapshot = _normalizeSnapshot(parameterSnapshot);
    _validateEstimatedAnlas(estimatedAnlas);
    final id = _newId();
    final now = _clock().toUtc();
    final draft = InpaintDraft(
      id: id,
      status: InpaintDraftStatus.prepared,
      source: source,
      parameterSnapshot: snapshot,
      estimatedAnlas: estimatedAnlas,
      createdAt: now,
      updatedAt: now,
    );

    await _rootDirectory.create(recursive: true);
    final stagingDirectory = Directory(
      p.join(_rootDirectory.path, '.$id-${const Uuid().v4()}.preparing'),
    );
    final destination = _draftDirectory(id);
    if (await destination.exists()) {
      throw StateError('Generated inpaint draft ID already exists: $id');
    }
    await stagingDirectory.create();
    try {
      await File(
        p.join(stagingDirectory.path, _sourceFileName),
      ).writeAsBytes(sourceBytes, flush: true);
      await _writeMetadata(stagingDirectory, draft);
      await stagingDirectory.rename(destination.path);
      return draft;
    } catch (_) {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  @override
  Future<InpaintDraft?> get(String id) async {
    _validateId(id);
    final directory = _draftDirectory(id);
    if (!await directory.exists()) return null;
    final metadataFile = File(p.join(directory.path, _metadataFileName));
    await _fileStore.recoverAtomicTarget(metadataFile);
    if (!await metadataFile.exists()) {
      throw const InpaintDraftIntegrityException('metadata.json is missing');
    }
    try {
      final decoded = jsonDecode(await metadataFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Metadata root must be an object');
      }
      var draft = InpaintDraft.fromJson(decoded);
      if (draft.id != id) {
        throw const FormatException('Metadata ID does not match directory');
      }
      if (draft.status == InpaintDraftStatus.submitting &&
          !_activeSubmissions.contains(id)) {
        draft = draft.copyWith(
          status: InpaintDraftStatus.failed,
          updatedAt: _clock().toUtc(),
          failureMessage:
              'Submission was interrupted before completion. Inspect the '
              'draft and re-edit it before submitting again.',
        );
        await _writeMetadata(directory, draft);
      }
      await _fileStore.verifyAsset(
        directory,
        _sourceFileNameFor(draft.status),
        draft.source,
        'source',
      );
      if (draft.mask != null) {
        await _fileStore.verifyAsset(
          directory,
          _maskFileName,
          draft.mask!,
          'mask',
        );
        if (draft.mask!.width != draft.source.width ||
            draft.mask!.height != draft.source.height) {
          throw const FormatException('Mask dimensions do not match source');
        }
      }
      if (_requiresCompletedMask(draft.status) && draft.mask == null) {
        throw FormatException('${draft.status.name} draft has no mask');
      }
      return draft;
    } on InpaintDraftIntegrityException {
      rethrow;
    } on Object catch (error) {
      throw InpaintDraftIntegrityException('invalid metadata: $error');
    }
  }

  @override
  Future<List<InpaintDraft>> list() async {
    if (!await _rootDirectory.exists()) return const [];
    final drafts = <InpaintDraft>[];
    await for (final entity in _rootDirectory.list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (!_uuidPattern.hasMatch(id)) continue;
      final draft = await get(id);
      if (draft != null) drafts.add(draft);
    }
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  @override
  Future<Uint8List> readSource(String id) async {
    final draft = await _requireDraft(id);
    final file = File(
      p.join(_draftDirectory(id).path, _sourceFileNameFor(draft.status)),
    );
    await _fileStore.recoverAtomicTarget(file);
    final bytes = await file.readAsBytes();
    _fileStore.verifyBytes(bytes, draft.source, 'source');
    return bytes;
  }

  @override
  Future<Uint8List?> readMask(String id) async {
    final draft = await _requireDraft(id);
    if (draft.mask == null) return null;
    final file = File(p.join(_draftDirectory(id).path, _maskFileName));
    await _fileStore.recoverAtomicTarget(file);
    final bytes = await file.readAsBytes();
    _fileStore.verifyBytes(bytes, draft.mask!, 'mask');
    return bytes;
  }

  @override
  Future<InpaintDraft> beginEditing(String id) async {
    final draft = await _requireDraft(id);
    _requireStatus(draft, 'begin editing', {InpaintDraftStatus.prepared});
    return _save(
      draft.copyWith(
        status: InpaintDraftStatus.editing,
        updatedAt: _clock().toUtc(),
      ),
    );
  }

  @override
  Future<InpaintDraft> complete(
    String id, {
    required Uint8List sourceBytes,
    required Uint8List maskBytes,
    required Map<String, dynamic> parameterSnapshot,
    required num estimatedAnlas,
  }) async {
    final draft = await _requireDraft(id);
    _requireStatus(draft, 'complete', {InpaintDraftStatus.editing});
    final source = _fileStore.inspectImage(sourceBytes, label: 'source');
    final mask = _fileStore.inspectImage(maskBytes, label: 'mask');
    if (mask.width != source.width || mask.height != source.height) {
      throw const InpaintDraftIntegrityException(
        'mask dimensions must match source dimensions',
      );
    }
    final snapshot = _normalizeSnapshot(parameterSnapshot);
    _validateEstimatedAnlas(estimatedAnlas);
    final directory = _draftDirectory(id);
    // Metadata is the commit point. Until it is replaced, readers keep using
    // source.image and ignore these fully-written ready assets.
    await _fileStore.atomicWriteBytes(
      File(p.join(directory.path, _readySourceFileName)),
      sourceBytes,
    );
    await _fileStore.atomicWriteBytes(
      File(p.join(directory.path, _maskFileName)),
      maskBytes,
    );
    return _save(
      draft.copyWith(
        status: InpaintDraftStatus.ready,
        source: source,
        mask: mask,
        parameterSnapshot: snapshot,
        estimatedAnlas: estimatedAnlas,
        updatedAt: _clock().toUtc(),
        clearFailureMessage: true,
      ),
    );
  }

  @override
  Future<InpaintDraft> cancel(String id) async {
    final draft = await _requireDraft(id);
    _requireStatus(draft, 'cancel', {
      InpaintDraftStatus.prepared,
      InpaintDraftStatus.editing,
      InpaintDraftStatus.ready,
      InpaintDraftStatus.failed,
    });
    if (draft.status == InpaintDraftStatus.ready ||
        draft.status == InpaintDraftStatus.failed) {
      final directory = _draftDirectory(id);
      await _fileStore.atomicWriteBytes(
        File(p.join(directory.path, _sourceFileName)),
        await File(p.join(directory.path, _readySourceFileName)).readAsBytes(),
      );
    }
    return _save(
      draft.copyWith(
        status: InpaintDraftStatus.cancelled,
        updatedAt: _clock().toUtc(),
      ),
    );
  }

  @override
  Future<InpaintDraft> reEdit(String id) async {
    final draft = await _requireDraft(id);
    _requireStatus(draft, 're-edit', {
      InpaintDraftStatus.editing,
      InpaintDraftStatus.ready,
      InpaintDraftStatus.cancelled,
      InpaintDraftStatus.submitted,
      InpaintDraftStatus.failed,
    });
    if (draft.status == InpaintDraftStatus.editing) return draft;
    if (draft.status != InpaintDraftStatus.submitted) {
      if (draft.status == InpaintDraftStatus.ready ||
          draft.status == InpaintDraftStatus.failed) {
        final directory = _draftDirectory(id);
        await _fileStore.atomicWriteBytes(
          File(p.join(directory.path, _sourceFileName)),
          await File(
            p.join(directory.path, _readySourceFileName),
          ).readAsBytes(),
        );
      }
      return _save(
        draft.copyWith(
          status: InpaintDraftStatus.editing,
          updatedAt: _clock().toUtc(),
          clearFailureMessage: true,
        ),
      );
    }

    final sourceBytes = await readSource(id);
    final newDraft = await prepare(
      sourceBytes: sourceBytes,
      parameterSnapshot: draft.parameterSnapshot,
      estimatedAnlas: draft.estimatedAnlas,
    );
    final maskBytes = await readMask(id);
    if (maskBytes != null) {
      await _fileStore.atomicWriteBytes(
        File(p.join(_draftDirectory(newDraft.id).path, _maskFileName)),
        maskBytes,
      );
    }
    final editingDraft = InpaintDraft(
      id: newDraft.id,
      status: InpaintDraftStatus.editing,
      source: newDraft.source,
      mask: draft.mask,
      parameterSnapshot: newDraft.parameterSnapshot,
      estimatedAnlas: newDraft.estimatedAnlas,
      createdAt: newDraft.createdAt,
      updatedAt: _clock().toUtc(),
      reEditOfDraftId: draft.id,
    );
    return _save(editingDraft);
  }

  @override
  Future<InpaintDraft> markSubmitted(String id) async {
    final draft = await _requireDraft(id);
    _requireStatus(draft, 'mark submitted', {InpaintDraftStatus.submitting});
    try {
      return await _save(
        draft.copyWith(
          status: InpaintDraftStatus.submitted,
          updatedAt: _clock().toUtc(),
        ),
      );
    } finally {
      _activeSubmissions.remove(id);
    }
  }

  @override
  Future<InpaintDraft> beginSubmission(String id) async {
    final draft = await _requireDraft(id);
    _requireStatus(draft, 'begin submission', {InpaintDraftStatus.ready});
    _activeSubmissions.add(id);
    try {
      return await _save(
        draft.copyWith(
          status: InpaintDraftStatus.submitting,
          updatedAt: _clock().toUtc(),
          clearFailureMessage: true,
        ),
      );
    } on Object {
      _activeSubmissions.remove(id);
      rethrow;
    }
  }

  @override
  Future<InpaintDraft> restoreReady(
    String id, {
    required String message,
  }) async {
    final draft = await _requireDraft(id);
    _requireStatus(draft, 'restore ready', {InpaintDraftStatus.submitting});
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      throw ArgumentError.value(message, 'message', 'Must not be empty');
    }
    try {
      return await _save(
        draft.copyWith(
          status: InpaintDraftStatus.ready,
          updatedAt: _clock().toUtc(),
          failureMessage: normalizedMessage,
        ),
      );
    } finally {
      _activeSubmissions.remove(id);
    }
  }

  @override
  Future<InpaintDraft> markFailed(String id, {required String message}) async {
    final draft = await _requireDraft(id);
    _requireStatus(draft, 'mark failed', {InpaintDraftStatus.ready});
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      throw ArgumentError.value(message, 'message', 'Must not be empty');
    }
    return _save(
      draft.copyWith(
        status: InpaintDraftStatus.failed,
        updatedAt: _clock().toUtc(),
        failureMessage: normalizedMessage,
      ),
    );
  }

  Future<InpaintDraft> _requireDraft(String id) async {
    return await get(id) ?? (throw InpaintDraftNotFoundException(id));
  }

  Future<InpaintDraft> _save(InpaintDraft draft) async {
    await _writeMetadata(_draftDirectory(draft.id), draft);
    return draft;
  }

  Future<void> _writeMetadata(Directory directory, InpaintDraft draft) async {
    final target = File(p.join(directory.path, _metadataFileName));
    final bytes = utf8.encode(jsonEncode(draft.toJson()));
    await _fileStore.atomicWriteBytes(target, bytes);
  }

  Map<String, dynamic> _normalizeSnapshot(Map<String, dynamic> snapshot) {
    try {
      final decoded = jsonDecode(jsonEncode(snapshot));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Snapshot must be a JSON object');
      }
      return decoded;
    } on Object catch (error) {
      throw ArgumentError.value(
        snapshot,
        'parameterSnapshot',
        'Must contain only structured JSON values: $error',
      );
    }
  }

  void _validateEstimatedAnlas(num value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'estimatedAnlas',
        'Must be a finite non-negative number',
      );
    }
  }

  void _requireStatus(
    InpaintDraft draft,
    String operation,
    Set<InpaintDraftStatus> allowed,
  ) {
    if (!allowed.contains(draft.status)) {
      throw InpaintDraftTransitionException(draft.status.name, operation);
    }
  }

  bool _requiresCompletedMask(InpaintDraftStatus status) {
    return status == InpaintDraftStatus.ready ||
        status == InpaintDraftStatus.submitting ||
        status == InpaintDraftStatus.submitted ||
        status == InpaintDraftStatus.failed;
  }

  String _newId() {
    final id = _idGenerator().toLowerCase();
    _validateId(id);
    return id;
  }

  void _validateId(String id) {
    if (!_uuidPattern.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Must be a canonical UUID v4');
    }
  }

  Directory _draftDirectory(String id) {
    _validateId(id);
    return Directory(p.join(_rootDirectory.path, id));
  }

  String _sourceFileNameFor(InpaintDraftStatus status) {
    return switch (status) {
      InpaintDraftStatus.ready ||
      InpaintDraftStatus.submitting ||
      InpaintDraftStatus.submitted ||
      InpaintDraftStatus.failed => _readySourceFileName,
      _ => _sourceFileName,
    };
  }
}
