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
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/inpaint/inpaint_draft.dart';
import '../../../data/models/inpaint/inpaint_draft_status.dart';
import '../../../data/services/inpaint_draft_file_repository.dart';
import '../../../data/services/inpaint_draft_repository.dart';
import '../../providers/image_generation_provider.dart';
import '../../widgets/image_editor/image_editor_screen.dart';
import 'agent_image_observation_ledger.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_anlas_estimator.dart';
import 'inpaint_draft_authoring_service.dart';
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

typedef ManualInpaintResolvedResource = InpaintResolvedSource;
typedef ManualInpaintResourceLoader =
    Future<ManualInpaintResolvedResource?> Function(
      AgentChatResourceReference reference,
    );
typedef ManualInpaintAnlasEstimator =
    int Function(ImageParams params, int batchSize);

/// 把 ready 草稿装载进生成页重绘面板，并把用户带到那一页。
typedef ManualInpaintPanelHandoff =
    Future<void> Function({
      required Uint8List source,
      required int sourceWidth,
      required int sourceHeight,
      required Uint8List mask,
      required bool focusedInpaintEnabled,
      required Rect? focusedSelectionRect,
      required double minimumContextMegaPixels,
      required bool sourceIsOutpaint,
    });

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
class ManualInpaintToolbox implements InpaintDraftAuthoringHost {
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

  /// 与 ImageWorkflowState.minimumContextMegaPixels 的默认值一致。
  static const double _defaultContextPadding =
      FocusedInpaintUtils.defaultContextPadding;

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
  ManualInpaintPanelHandoff? _panelHandoff;
  late final InpaintDraftAuthoringService _authoring =
      InpaintDraftAuthoringService(this);

  @override
  InpaintDraftRepository get draftRepository => _repository;

  @override
  String? get currentSessionId => _activeSessionId?.call();

  @override
  int get requestBatchSize => _ref.read(imagesPerRequestProvider);

  @override
  ImageParams get baseGenerationParams =>
      _ref.read(generationParamsNotifierProvider);

  @override
  void bindDraftSession(String draftId, String sessionId) =>
      _draftSessionIds[draftId] = sessionId;

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
    _resourceLoader = (reference) async {
      final resolved = await resolver.resolve(reference);
      final bytes = resolved?.bytes;
      return bytes == null
          ? null
          : (bytes: bytes, filePath: resolved!.filePath);
    };
  }

  void configurePanelHandoff(ManualInpaintPanelHandoff handoff) =>
      _panelHandoff = handoff;

  void configureObservationLedger(
    AgentImageObservationLedger ledger, {
    required String Function() activeSessionId,
  }) => _authoring.configureObservationLedger(
    ledger,
    activeSessionId: activeSessionId,
  );

  Future<int?> estimateAnlasForDraft(String draftId) async {
    final draft = await _repository.get(draftId);
    if (draft == null) return null;
    final snapshot = draft.parameterSnapshot;
    final storedBatchSize = snapshot['_agentBatchSize'];
    final batchSize = storedBatchSize is int && storedBatchSize > 0
        ? storedBatchSize
        : _ref.read(imagesPerRequestProvider);
    return estimateInfillAnlas(
      ImageParams.fromJson(snapshot),
      batchSize: batchSize,
      maskImage: await _repository.readMask(draftId),
      focused: readFocusedSnapshot(snapshot),
    );
  }

  /// 聚焦重绘实际请求的是放大后的裁剪区，而不是原图尺寸；按原图估价在小底图上
  /// 会低估，用户确认到的数字就会比真实扣费少。
  @override
  int estimateInfillAnlas(
    ImageParams params, {
    required int batchSize,
    required Uint8List? maskImage,
    required GenerationFocusedSnapshot focused,
  }) {
    var effective = params.copyWith(action: ImageGenerationAction.infill);
    if (focused.enabled && maskImage != null) {
      final geometry = FocusedInpaintUtils.resolveGeometryForMask(
        maskImage: maskImage,
        minContextMegaPixels: focused.minimumContextMegaPixels,
      );
      if (geometry != null) {
        effective = effective.copyWith(
          width: geometry.requestWidth,
          height: geometry.requestHeight,
        );
      }
    }
    return _estimateAnlas(effective, batchSize);
  }

  List<AgentTool> tools() => buildManualInpaintToolDefinitions(
    create: _create,
    list: _list,
    get: _get,
    cancel: _cancel,
    reEdit: _reEdit,
    submit: _submit,
    createMask: _authoring.createFromGeometry,
    expandCanvas: _authoring.createFromExpansion,
    loadIntoPanel: _loadIntoPanel,
  );

  Future<List<Map<String, dynamic>>> listDraftSummaries() async => [
    for (final draft in await _repository.list()) manualInpaintDraftJson(draft),
  ];

  /// Opens the same persisted manual draft flow used by the Agent inpaint
  /// tools, without submitting it.
  Future<AgentToolResult> createDraftFromResource(
    AgentChatResourceReference reference,
  ) {
    final prompt = _ref.read(generationParamsNotifierProvider).prompt.trim();
    return _create({
      'source_ref': AgentChatResourceReferenceCodec.encodeJsonMap(reference),
      'prompt': prompt.isEmpty ? 'Edit the selected area' : prompt,
    }, expectedSessionId: _activeSessionId?.call());
  }

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
    final InpaintDraft? draft;
    try {
      draft = await _repository.get(args['draft_id'] as String);
    } on Object catch (error) {
      return agentToolError('invalid_draft_id', '$error');
    }
    return draft == null
        ? agentToolError('not_found', 'Inpaint draft not found.')
        : buildManualInpaintDraftResult(draft, _repository);
  }

  Future<AgentToolResult> _cancel(Map<String, dynamic> args) async {
    final id = args['draft_id'] as String;
    final InpaintDraft draft;
    try {
      draft = await _repository.cancel(id);
    } on Object catch (error) {
      return agentToolError('cancel_failed', '$error');
    }
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

  @override
  Future<InpaintSourceResolution> resolveInpaintSource(
    Map<String, dynamic> args,
  ) async {
    final encodedReference = args['source_ref'];
    if (encodedReference != null) {
      final resourceLoader = _resourceLoader;
      if (resourceLoader == null) {
        return InpaintSourceResolution.failed(
          agentToolError(
            'resource_resolver_unavailable',
            'Resource resolution is unavailable.',
          ),
        );
      }
      final reference = AgentChatResourceReferenceCodec.decodeJsonMap(
        Map<String, dynamic>.from(encodedReference as Map),
      );
      final resolved = await resourceLoader(reference);
      return resolved == null
          ? InpaintSourceResolution.failed(
              agentToolError(
                'resource_unavailable',
                'Source image resource is unavailable.',
              ),
            )
          : InpaintSourceResolution.ok(resolved);
    }

    final rawPath = args['source_image'];
    if (rawPath is! String || rawPath.trim().isEmpty) {
      return InpaintSourceResolution.failed(
        agentToolError(
          'source_required',
          'source_ref or source_image is required.',
        ),
      );
    }
    final sourcePath = getOrThrow(await _fileEnv.absolutePath(rawPath));
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return InpaintSourceResolution.failed(
        agentToolError('not_found', 'Source image not found.'),
      );
    }
    return InpaintSourceResolution.ok((
      bytes: await sourceFile.readAsBytes(),
      filePath: sourcePath,
    ));
  }

  /// 没有台账记录说明模型没真正看过这张图，坐标只能是猜的，不能放行到扣费环节。
  Future<AgentToolResult> _create(
    Map<String, dynamic> args, {
    String? expectedSessionId,
  }) async {
    final sessionId = expectedSessionId ?? _activeSessionId?.call();
    bool isCurrentSession() => _activeSessionId?.call() == sessionId;
    final prompt = (args['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      return agentToolError('invalid_prompt', 'prompt must not be empty.');
    }
    String? createdDraftId;
    try {
      final encodedReference = args['source_ref'];
      final resolution = await resolveInpaintSource(args);
      final resolutionError = resolution.error;
      if (resolutionError != null) return resolutionError;
      if (!isCurrentSession()) {
        return agentToolError(
          'session_switched',
          'The Agent session changed before the inpaint draft was prepared.',
        );
      }
      final source = resolution.resource!.bytes;
      final snapshot = buildManualInpaintParameterSnapshot(
        _ref.read(generationParamsNotifierProvider),
        prompt,
        args['params'],
        sourceImage: source,
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
      if (!isCurrentSession()) {
        await _repository.cancel(prepared.id);
        return agentToolError(
          'session_switched',
          'The Agent session changed before the inpaint editor was opened.',
        );
      }
      _draftSessionIds[prepared.id] = sessionId ?? '';
      final editing = await _repository.beginEditing(prepared.id);
      if (!isCurrentSession()) {
        await _repository.cancel(editing.id);
        _draftSessionIds.remove(editing.id);
        return agentToolError(
          'session_switched',
          'The Agent session changed before the inpaint editor was opened.',
        );
      }
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
        await notifyDraftChanged(await _repository.cancel(id));
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
      await notifyDraftChanged(ready);
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
          await notifyDraftChanged(await _repository.cancel(id));
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

  Future<AgentToolResult> _loadIntoPanel(Map<String, dynamic> args) async {
    final handoff = _panelHandoff;
    if (handoff == null) {
      return agentToolError(
        'panel_unavailable',
        'The generation page is not available in this runtime.',
      );
    }
    final id = args['draft_id'] as String;
    final InpaintDraft? draft;
    try {
      // 仓库对非法 ID 抛异常而不是返回 null，不包住会把异常抛回 loop。
      draft = await _repository.get(id);
    } on Object catch (error) {
      return agentToolError('invalid_draft_id', '$error');
    }
    if (draft == null) {
      return agentToolError('not_found', 'Inpaint draft not found.');
    }
    if (draft.status != InpaintDraftStatus.ready) {
      return agentToolError(
        'not_ready',
        'Draft status is ${draft.status.name}; ready is required.',
      );
    }
    final mask = await _repository.readMask(id);
    if (mask == null) {
      return agentToolError('invalid_draft', 'Ready draft has no mask.');
    }
    final source = await _repository.readSource(id);
    final size = NaiResolutionAdapter.readImageSize(source);
    if (size == null) {
      return agentToolError(
        'invalid_draft',
        'The draft source image could not be decoded.',
      );
    }
    final (width, height) = size;

    final focused = readFocusedSnapshot(draft.parameterSnapshot);
    // 面板在 selectionRect 为空时会把聚焦重绘判为关闭，所以这里补上提交路径
    // 隐式使用的那个矩形——蒙版外接框——两条路径才会得到同一个结果。
    Rect? selectionRect;
    if (focused.enabled) {
      selectionRect = FocusedInpaintUtils.resolveGeometryForMask(
        maskImage: mask,
        minContextMegaPixels: focused.minimumContextMegaPixels,
      )?.focusBounds.rect;
    }
    final storedOutpaint = draft.parameterSnapshot['_agentSourceIsOutpaint'];
    final sourceIsOutpaint =
        storedOutpaint == true &&
        NaiResolutionAdapter.isCompatible(width, height);

    try {
      await handoff(
        source: source,
        sourceWidth: width,
        sourceHeight: height,
        mask: mask,
        focusedInpaintEnabled: focused.enabled && selectionRect != null,
        focusedSelectionRect: selectionRect,
        minimumContextMegaPixels: focused.minimumContextMegaPixels,
        sourceIsOutpaint: sourceIsOutpaint,
      );
    } on Object catch (error) {
      return agentToolError('panel_load_failed', '$error');
    }
    return agentToolJsonResult({
      'ok': true,
      'draftId': id,
      'focusedInpaint': focused.enabled && selectionRect != null,
      'size': '${width}x$height',
      'next_step':
          'The mask is now loaded on the Generation page for the user to '
          'review or adjust. Generating from there is their call; '
          'submit_manual_inpaint_draft still works if they prefer chat.',
    });
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
      if (draft.estimatedAnlas < 0) {
        return agentToolError(
          'invalid_cost_estimate',
          'The inpaint draft does not have a valid Anlas estimate and cannot '
              'be submitted.',
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
      unawaited(
        _finishSubmission(
          id,
          params,
          batchSize,
          readFocusedSnapshot(draft.parameterSnapshot),
        ),
      );
      return agentToolJsonResult({
        'ok': true,
        'asynchronous': true,
        'draft': manualInpaintDraftJson(submitting),
      });
    } on Object catch (error) {
      return agentToolError('submit_failed', '$error');
    }
  }

  /// Agent 草稿的聚焦参数必须随请求走：它从不经过生成页的 workflow controller，
  /// 沿用环境状态会拿到上一张图残留的选区，或默认关闭而失去小目标所需的放大。
  @override
  GenerationFocusedSnapshot readFocusedSnapshot(Map<String, dynamic> snapshot) {
    final stored = snapshot['_agentFocusedInpaint'];
    if (stored is! Map) {
      return const GenerationFocusedSnapshot(
        enabled: false,
        minimumContextMegaPixels: _defaultContextPadding,
      );
    }
    final padding = (stored['contextPadding'] as num?)?.toDouble();
    return GenerationFocusedSnapshot(
      enabled: stored['enabled'] == true,
      minimumContextMegaPixels: padding == null
          ? _defaultContextPadding
          : FocusedInpaintUtils.clampContextPadding(padding),
    );
  }

  Future<void> _finishSubmission(
    String id,
    ImageParams params,
    int? batchSize,
    GenerationFocusedSnapshot focused,
  ) async {
    try {
      final result = _submitter == null
          ? await _submitThroughProvider(
              params,
              batchSize: batchSize,
              focused: focused,
            )
          : await _submitter(params);
      if (!result.accepted) {
        final ready = await _repository.restoreReady(
          id,
          message: result.error ?? 'Generation provider rejected submission.',
        );
        await notifyDraftChanged(ready);
        return;
      }
      await notifyDraftChanged(await _repository.markSubmitted(id));
    } on Object catch (error, stackTrace) {
      try {
        final current = await _repository.get(id);
        if (current?.status == InpaintDraftStatus.submitting) {
          await notifyDraftChanged(
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

  @override
  Future<void> notifyDraftChanged(InpaintDraft draft) async {
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
    required GenerationFocusedSnapshot focused,
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
        .generate(
          params,
          batchSizeOverride: batchSize,
          focusedOverride: focused,
        );
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
