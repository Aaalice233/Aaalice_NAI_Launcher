import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_result.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/inpaint/inpaint_draft.dart';
import '../../../data/models/inpaint/inpaint_draft_status.dart';
import '../../../data/services/inpaint_draft_file_repository.dart';
import '../../../data/services/inpaint_draft_repository.dart';
import '../../providers/image_generation_provider.dart';
import '../../widgets/image_editor/image_editor_screen.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_anlas_estimator.dart';
import 'manual_inpaint_tool_definitions.dart';
import 'manual_inpaint_toolbox_serialization.dart';

typedef ManualInpaintEditorLauncher =
    ManualInpaintEditorSession Function(
      String draftId,
      Uint8List source,
      Uint8List? mask,
    );
typedef ManualInpaintSubmitter =
    Future<ManualInpaintSubmissionResult> Function(ImageParams params);
typedef ManualInpaintDraftListener =
    FutureOr<void> Function(String sessionId, InpaintDraft draft);
typedef ManualInpaintResourceLoader =
    Future<Uint8List?> Function(AgentChatResourceReference reference);
typedef ManualInpaintAnlasEstimator =
    int Function(ImageParams params, int batchSize);

class ManualInpaintEditorSession {
  const ManualInpaintEditorSession({required this.result, required this.close});

  final Future<ImageEditorResult?> result;
  final void Function() close;
}

class ManualInpaintSubmissionResult {
  const ManualInpaintSubmissionResult({required this.accepted, this.error});

  final bool accepted;
  final String? error;
}

/// Asynchronous Agent bridge for user-authored inpaint masks.
///
/// Draft files are the synchronization boundary: editor completion commits
/// `ready` before an Agent can observe it, and submission goes through the
/// application's generation notifier rather than a second transport path.
class ManualInpaintToolbox {
  ManualInpaintToolbox(
    this._ref, {
    required Directory supportDirectory,
    String? workspaceDir,
    bool allowOutsideWorkspace = false,
    InpaintDraftRepository? repository,
    ManualInpaintEditorLauncher? editorLauncher,
    ManualInpaintSubmitter? submitter,
    NavigatorState? Function()? navigator,
    String Function()? activeSessionId,
    ManualInpaintDraftListener? onDraftChanged,
    ManualInpaintResourceLoader? resourceLoader,
    ManualInpaintAnlasEstimator? anlasEstimator,
  }) : _repository =
           repository ??
           InpaintDraftFileRepository(
             rootDirectory: Directory(
               '${supportDirectory.path}${Platform.pathSeparator}agent'
               '${Platform.pathSeparator}inpaint-drafts-v1',
             ),
           ),
       _fileEnv = DartIoExecutionEnv(
         workingDirectory: workspaceDir,
         allowOutsideWorkingDirectory: allowOutsideWorkspace,
       ),
       _editorLauncher = editorLauncher,
       _submitter = submitter,
       _navigator = navigator,
       _activeSessionId = activeSessionId,
       _onDraftChanged = onDraftChanged,
       _resourceLoader = resourceLoader,
       _estimateAnlas =
           anlasEstimator ??
           ((params, batchSize) => GenerationAnlasEstimator(
             _ref,
           ).estimate(params, requestCount: 1, batchSize: batchSize));

  final Ref _ref;
  final InpaintDraftRepository _repository;
  DartIoExecutionEnv _fileEnv;
  final ManualInpaintEditorLauncher? _editorLauncher;
  final ManualInpaintSubmitter? _submitter;
  final NavigatorState? Function()? _navigator;
  final String Function()? _activeSessionId;
  final ManualInpaintDraftListener? _onDraftChanged;
  final ManualInpaintAnlasEstimator _estimateAnlas;
  final Map<String, ManualInpaintEditorSession> _sessions = {};
  final Map<String, String> _draftSessionIds = {};
  ManualInpaintResourceLoader? _resourceLoader;

  void configureFileAccess({
    required String workspaceDir,
    required bool allowOutsideWorkspace,
  }) {
    _fileEnv = DartIoExecutionEnv(
      workingDirectory: workspaceDir,
      allowOutsideWorkingDirectory: allowOutsideWorkspace,
    );
  }

  void configureResourceResolver(AgentResourceResolver resolver) {
    _resourceLoader = (reference) async =>
        (await resolver.resolve(reference))?.bytes;
  }

  Future<int?> estimateAnlasForDraft(String draftId) async {
    final draft = await _repository.get(draftId);
    if (draft == null) return null;
    final snapshot = draft.parameterSnapshot;
    final storedBatchSize = snapshot['_agentBatchSize'];
    final batchSize = storedBatchSize is int && storedBatchSize > 0
        ? storedBatchSize
        : _ref.read(imagesPerRequestProvider);
    return _estimateAnlas(
      ImageParams.fromJson(snapshot).copyWith(
        action: ImageGenerationAction.infill,
      ),
      batchSize,
    );
  }

  List<AgentTool> tools() => buildManualInpaintToolDefinitions(
    create: _create,
    list: _list,
    get: _get,
    cancel: _cancel,
    reEdit: _reEdit,
    submit: _submit,
  );

  Future<List<Map<String, dynamic>>> listDraftSummaries() async => [
    for (final draft in await _repository.list()) manualInpaintDraftJson(draft),
  ];

  Future<Uint8List?> loadDraftImage(
    String draftId, {
    required bool mask,
  }) async {
    try {
      return mask
          ? await _repository.readMask(draftId)
          : await _repository.readSource(draftId);
    } on InpaintDraftNotFoundException {
      return null;
    }
  }

  Future<AgentToolResult> _list(Map<String, dynamic> args) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 20;
    if (limit < 1 || limit > 100) {
      return agentToolError('invalid_limit', 'limit must be from 1 to 100.');
    }
    final drafts = await _repository.list();
    return agentToolJsonResult({
      'ok': true,
      'drafts': drafts.take(limit).map(manualInpaintDraftJson).toList(),
    });
  }

  Future<AgentToolResult> _get(Map<String, dynamic> args) async {
    final draft = await _repository.get(args['draft_id'] as String);
    return draft == null
        ? agentToolError('not_found', 'Inpaint draft not found.')
        : buildManualInpaintDraftResult(draft, _repository);
  }

  Future<AgentToolResult> _cancel(Map<String, dynamic> args) async {
    final id = args['draft_id'] as String;
    final draft = await _repository.cancel(id);
    _sessions[id]?.close();
    return agentToolJsonResult({
      'ok': true,
      'draft': manualInpaintDraftJson(draft),
    });
  }

  Future<AgentToolResult> _reEdit(Map<String, dynamic> args) async {
    final requestedId = args['draft_id'] as String;
    try {
      final editing = await _repository.reEdit(requestedId);
      _draftSessionIds[editing.id] = _activeSessionId?.call() ?? '';
      final source = await _repository.readSource(editing.id);
      final mask = await _repository.readMask(editing.id);
      _sessions.remove(editing.id)?.close();
      final session = (_editorLauncher ?? _openEditor)(
        editing.id,
        source,
        mask,
      );
      _sessions[editing.id] = session;
      unawaited(_observeEditor(editing.id, source, session.result));
      return agentToolJsonResult({
        'ok': true,
        'draft': manualInpaintDraftJson(editing),
      });
    } on Object catch (error) {
      return agentToolError('reedit_failed', '$error');
    }
  }

  Future<AgentToolResult> _create(Map<String, dynamic> args) async {
    final prompt = (args['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      return agentToolError('invalid_prompt', 'prompt must not be empty.');
    }
    String? createdDraftId;
    try {
      final encodedReference = args['source_ref'];
      final Uint8List source;
      if (encodedReference != null) {
        final resourceLoader = _resourceLoader;
        if (resourceLoader == null) {
          return agentToolError(
            'resource_resolver_unavailable',
            'Resource resolution is unavailable.',
          );
        }
        final reference = AgentChatResourceReferenceCodec.decodeJsonMap(
          Map<String, dynamic>.from(encodedReference as Map),
        );
        final resolved = await resourceLoader(reference);
        if (resolved == null) {
          return agentToolError(
            'resource_unavailable',
            'Source image resource is unavailable.',
          );
        }
        source = resolved;
      } else {
        final rawPath = args['source_image'];
        if (rawPath is! String || rawPath.trim().isEmpty) {
          return agentToolError(
            'source_required',
            'source_ref or source_image is required.',
          );
        }
        final sourcePath = getOrThrow(await _fileEnv.absolutePath(rawPath));
        final sourceFile = File(sourcePath);
        if (!await sourceFile.exists()) {
          return agentToolError('not_found', 'Source image not found.');
        }
        source = await sourceFile.readAsBytes();
      }
      final snapshot = buildManualInpaintParameterSnapshot(
        _ref.read(generationParamsNotifierProvider),
        prompt,
        args['params'],
      );
      if (encodedReference != null) {
        snapshot['_agentSourceReference'] =
            AgentChatResourceReferenceCodec.encodeJsonMap(
              AgentChatResourceReferenceCodec.decodeJsonMap(
                Map<String, dynamic>.from(encodedReference as Map),
              ),
            );
      }
      final params = ImageParams.fromJson(snapshot);
      final batchSize = _ref.read(imagesPerRequestProvider);
      snapshot['_agentBatchSize'] = batchSize;
      final prepared = await _repository.prepare(
        sourceBytes: source,
        parameterSnapshot: snapshot,
        estimatedAnlas: _estimateAnlas(
          params.copyWith(action: ImageGenerationAction.infill),
          batchSize,
        ),
      );
      createdDraftId = prepared.id;
      _draftSessionIds[prepared.id] = _activeSessionId?.call() ?? '';
      final editing = await _repository.beginEditing(prepared.id);
      final session = (_editorLauncher ?? _openEditor)(
        editing.id,
        source,
        null,
      );
      _sessions[editing.id] = session;
      unawaited(_observeEditor(editing.id, source, session.result));
      return agentToolJsonResult({
        'ok': true,
        'draft': manualInpaintDraftJson(editing),
      });
    } on Object catch (error) {
      if (createdDraftId != null) {
        final current = await _repository.get(createdDraftId);
        if (current != null &&
            (current.status == InpaintDraftStatus.prepared ||
                current.status == InpaintDraftStatus.editing)) {
          await _repository.cancel(createdDraftId);
        }
      }
      return agentToolError('create_failed', '$error');
    }
  }

  Future<void> _observeEditor(
    String id,
    Uint8List originalSource,
    Future<ImageEditorResult?> resultFuture,
  ) async {
    try {
      final result = await resultFuture;
      final current = await _repository.get(id);
      if (current == null || current.status != InpaintDraftStatus.editing) {
        return;
      }
      final mask = result?.maskImage;
      if (result == null || mask == null) {
        await _notifyDraftChanged(await _repository.cancel(id));
        return;
      }
      final source =
          result.outpaintSourceImage ??
          result.inpaintSourceImage ??
          originalSource;
      final ready = await _repository.complete(
        id,
        sourceBytes: source,
        maskBytes: mask,
        parameterSnapshot: current.parameterSnapshot,
        estimatedAnlas: current.estimatedAnlas,
      );
      await _notifyDraftChanged(ready);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Manual inpaint editor lifecycle failed: $error',
        error,
        stackTrace,
        'AgentChat',
      );
      try {
        final current = await _repository.get(id);
        if (current?.status == InpaintDraftStatus.editing) {
          await _notifyDraftChanged(await _repository.cancel(id));
        }
      } on Object catch (cleanupError, cleanupStackTrace) {
        AppLogger.e(
          'Failed to cancel an invalid manual inpaint editor session',
          cleanupError,
          cleanupStackTrace,
          'AgentChat',
        );
      }
    } finally {
      _sessions.remove(id);
    }
  }

  Future<AgentToolResult> _submit(Map<String, dynamic> args) async {
    if (args['confirm'] != true) {
      return agentToolError(
        'confirmation_required',
        'Explicit user confirmation is required before submission.',
      );
    }
    final id = args['draft_id'] as String;
    try {
      final draft = await _repository.get(id);
      if (draft == null) {
        return agentToolError('not_found', 'Inpaint draft not found.');
      }
      if (draft.status != InpaintDraftStatus.ready) {
        return agentToolError(
          'not_ready',
          'Draft status is ${draft.status.name}; ready is required.',
        );
      }
      final source = await _repository.readSource(id);
      final mask = await _repository.readMask(id);
      if (mask == null) {
        return agentToolError('invalid_draft', 'Ready draft has no mask.');
      }
      final params = ImageParams.fromJson(draft.parameterSnapshot).copyWith(
        action: ImageGenerationAction.infill,
        sourceImage: source,
        maskImage: mask,
      );
      final batchSize = draft.parameterSnapshot['_agentBatchSize'] as int?;
      final submitting = await _repository.beginSubmission(id);
      unawaited(_finishSubmission(id, params, batchSize));
      return agentToolJsonResult({
        'ok': true,
        'asynchronous': true,
        'draft': manualInpaintDraftJson(submitting),
      });
    } on Object catch (error) {
      return agentToolError('submit_failed', '$error');
    }
  }

  Future<void> _finishSubmission(
    String id,
    ImageParams params,
    int? batchSize,
  ) async {
    try {
      final result = _submitter == null
          ? await _submitThroughProvider(params, batchSize: batchSize)
          : await _submitter(params);
      if (!result.accepted) {
        final ready = await _repository.restoreReady(
          id,
          message: result.error ?? 'Generation provider rejected submission.',
        );
        await _notifyDraftChanged(ready);
        return;
      }
      await _notifyDraftChanged(await _repository.markSubmitted(id));
    } on Object catch (error, stackTrace) {
      try {
        final current = await _repository.get(id);
        if (current?.status == InpaintDraftStatus.submitting) {
          await _notifyDraftChanged(
            await _repository.restoreReady(id, message: '$error'),
          );
        }
      } on Object catch (restoreError, restoreStackTrace) {
        AppLogger.e(
          'Failed to restore manual inpaint draft after submission error',
          restoreError,
          restoreStackTrace,
          'AgentChat',
        );
      }
      AppLogger.e(
        'Manual inpaint submission failed: $error',
        error,
        stackTrace,
        'AgentChat',
      );
    }
  }

  Future<void> _notifyDraftChanged(InpaintDraft draft) async {
    final listener = _onDraftChanged;
    if (listener == null) return;
    try {
      await listener(_draftSessionIds[draft.id] ?? '', draft);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Manual inpaint draft notification failed',
        error,
        stackTrace,
        'AgentChat',
      );
    }
  }

  ManualInpaintEditorSession _openEditor(
    String draftId,
    Uint8List source,
    Uint8List? mask,
  ) {
    final navigator = _navigator?.call();
    if (navigator == null) {
      throw StateError('Application navigator is not ready.');
    }
    final route = MaterialPageRoute<ImageEditorResult>(
      builder: (context) => ImageEditorScreen(
        initialImage: source,
        existingMask: mask,
        mode: ImageEditorMode.inpaint,
        title: context.l10n.agentChat_manualInpaintTitle,
        completionLabel: context.l10n.agentChat_manualInpaintComplete,
      ),
    );
    return ManualInpaintEditorSession(
      result: navigator.push(route),
      close: () {
        if (route.isActive) navigator.removeRoute(route);
      },
    );
  }

  Future<ManualInpaintSubmissionResult> _submitThroughProvider(
    ImageParams params, {
    int? batchSize,
  }) async {
    final before = _ref.read(imageGenerationNotifierProvider);
    if (before.status == GenerationStatus.generating) {
      return const ManualInpaintSubmissionResult(
        accepted: false,
        error: 'Another generation is already running.',
      );
    }
    await _ref
        .read(imageGenerationNotifierProvider.notifier)
        .generate(params, batchSizeOverride: batchSize);
    final after = _ref.read(imageGenerationNotifierProvider);
    return switch (after.status) {
      GenerationStatus.completed => const ManualInpaintSubmissionResult(
        accepted: true,
      ),
      GenerationStatus.error => ManualInpaintSubmissionResult(
        accepted: false,
        error: after.errorMessage ?? 'Generation failed.',
      ),
      GenerationStatus.cancelled => const ManualInpaintSubmissionResult(
        accepted: false,
        error: 'Generation was cancelled.',
      ),
      _ => const ManualInpaintSubmissionResult(
        accepted: false,
        error: 'Generation was not started (authentication may be required).',
      ),
    };
  }
}
