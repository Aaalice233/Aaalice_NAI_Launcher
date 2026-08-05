import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/comfyui/comfyui.dart';
import '../../../core/comfyui/object_info_parser.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';

part 'comfyui_provider.g.dart';

// ==================== 连接设置持久化 ====================

@Riverpod(keepAlive: true)
class ComfyUISettings extends _$ComfyUISettings {
  @override
  ComfyUISettingsState build() {
    final box = Hive.box(StorageKeys.settingsBox);
    final storedServerUrl =
        box.get(
              StorageKeys.comfyuiServerUrl,
              defaultValue: 'http://127.0.0.1:8188',
            )
            as String;
    final serverUrl = normalizeComfyUIBaseUrl(storedServerUrl);
    if (serverUrl != storedServerUrl) {
      box.put(StorageKeys.comfyuiServerUrl, serverUrl);
    }
    return ComfyUISettingsState(
      serverUrl: serverUrl,
      enabled: box.get(StorageKeys.comfyuiEnabled, defaultValue: false) as bool,
    );
  }

  void setServerUrl(String url) {
    final trimmed = url.trim();
    if (trimmed == state.serverUrl) return;
    state = state.copyWith(serverUrl: trimmed);
    _persist();
  }

  void setEnabled(bool enabled) {
    if (enabled == state.enabled) return;
    state = state.copyWith(enabled: enabled);
    _persist();
  }

  void _persist() {
    final box = Hive.box(StorageKeys.settingsBox);
    box.put(StorageKeys.comfyuiServerUrl, state.serverUrl);
    box.put(StorageKeys.comfyuiEnabled, state.enabled);
  }
}

class ComfyUISettingsState {
  final String serverUrl;
  final bool enabled;

  const ComfyUISettingsState({
    this.serverUrl = 'http://127.0.0.1:8188',
    this.enabled = false,
  });

  ComfyUISettingsState copyWith({String? serverUrl, bool? enabled}) {
    return ComfyUISettingsState(
      serverUrl: serverUrl ?? this.serverUrl,
      enabled: enabled ?? this.enabled,
    );
  }
}

// ==================== 连接管理 ====================

@Riverpod(keepAlive: true)
class ComfyUIConnection extends _$ComfyUIConnection {
  ComfyUIConnectionManager? _manager;

  @override
  ComfyUIConnectionStatus build() {
    ref.onDispose(() {
      _manager?.dispose();
      _manager = null;
    });
    return ComfyUIConnectionStatus.disconnected;
  }

  ComfyUIConnectionManager? get manager => _manager;

  Future<bool> connect() async {
    final settings = ref.read(comfyUISettingsProvider);
    _manager?.dispose();
    _manager = ComfyUIConnectionManager(serverUrl: settings.serverUrl);

    state = ComfyUIConnectionStatus.connecting;
    final ok = await _manager!.connect();
    state = ok
        ? ComfyUIConnectionStatus.connected
        : ComfyUIConnectionStatus.error;

    if (ok) {
      _manager!.statusStream.listen((s) {
        state = s;
      });
    }
    return ok;
  }

  void disconnect() {
    _manager?.disconnect();
    _manager = null;
    state = ComfyUIConnectionStatus.disconnected;
  }

  Future<bool> testConnection() async {
    final settings = ref.read(comfyUISettingsProvider);
    final api = ComfyUIApiService(baseUrl: settings.serverUrl);
    try {
      return await api.testConnection();
    } finally {
      api.dispose();
    }
  }
}

// ==================== 工作流模板管理 ====================

@Riverpod(keepAlive: true)
class ComfyUIWorkflows extends _$ComfyUIWorkflows {
  final WorkflowTemplateManager _manager = WorkflowTemplateManager();

  @override
  List<WorkflowTemplate> build() {
    _initAsync();
    return _manager.templates;
  }

  Future<void> _initAsync() async {
    await _manager.loadAllTemplates();
    state = _manager.templates;
  }

  WorkflowTemplateManager get manager => _manager;

  WorkflowTemplate? getById(String id) => _manager.getById(id);

  List<WorkflowTemplate> getByCategory(WorkflowCategory category) =>
      _manager.getByCategory(category);

  Future<void> addCustomTemplate(WorkflowTemplate template) async {
    await _manager.addCustomTemplate(template);
    state = _manager.templates;
  }

  Future<void> removeCustomTemplate(String templateId) async {
    await _manager.removeCustomTemplate(templateId);
    state = _manager.templates;
  }

  List<WorkflowTemplate> get customTemplates => _manager.customTemplates;
}

// ==================== 任务执行 ====================

@riverpod
class ComfyUITask extends _$ComfyUITask {
  static const String _tag = 'ComfyUI-Task';

  static String _summarizeInputImages(Map<String, Uint8List> images) {
    return images.entries
        .map((entry) => '${entry.key}:${entry.value.length}')
        .join(', ');
  }

  static String _summarizeOutputImages(List<Uint8List> images) {
    return 'count=${images.length}, bytes=[${images.map((i) => i.length).join(', ')}]';
  }

  @override
  ComfyUITaskState build() => const ComfyUITaskState();

  /// 执行工作流
  ///
  /// [templateId] 工作流模板 ID
  /// [inputImages] 输入图像 {slotId: imageBytes}
  /// [paramValues] 参数值 {slotId: value}
  Future<List<Uint8List>?> execute({
    required String templateId,
    Map<String, Uint8List> inputImages = const {},
    Map<String, dynamic> paramValues = const {},
  }) async {
    final connNotifier = ref.read(comfyUIConnectionProvider.notifier);
    final connStatus = ref.read(comfyUIConnectionProvider);
    final workflows = ref.read(comfyUIWorkflowsProvider.notifier);
    final manager = workflows.manager;

    AppLogger.i(
      'Execute requested: template=$templateId, connection=$connStatus, '
      'inputs=[${_summarizeInputImages(inputImages)}], '
      'paramKeys=[${paramValues.keys.join(', ')}]',
      _tag,
    );

    // 确保已连接
    if (connStatus != ComfyUIConnectionStatus.connected) {
      AppLogger.d(
        'Connection not ready ($connStatus); connecting before execute',
        _tag,
      );
      final ok = await connNotifier.connect();
      if (!ok) {
        AppLogger.w('Connection attempt failed before execute', _tag);
        state = state.copyWith(
          status: ComfyUITaskStatus.failed,
          errorCode: ComfyUITaskErrorCode.connectionFailed,
        );
        return null;
      }
    }

    final conn = connNotifier.manager;
    if (conn?.api == null || conn?.ws == null) {
      AppLogger.w(
        'Connection manager unavailable: hasApi=${conn?.api != null}, '
        'hasWs=${conn?.ws != null}',
        _tag,
      );
      state = state.copyWith(
        status: ComfyUITaskStatus.failed,
        errorCode: ComfyUITaskErrorCode.connectionUnavailable,
      );
      return null;
    }

    final template = manager.getById(templateId);
    if (template == null) {
      AppLogger.w('Workflow template not found: $templateId', _tag);
      state = state.copyWith(
        status: ComfyUITaskStatus.failed,
        errorCode: ComfyUITaskErrorCode.workflowNotFound,
        errorDetails: templateId,
      );
      return null;
    }

    try {
      final outputNodeIds = template.outputSlots
          .map((slot) => slot.nodeId)
          .toSet();

      // 1. 上传图像
      state = state.copyWith(status: ComfyUITaskStatus.uploading, progress: 0);
      AppLogger.d('Uploading inputs for template=$templateId', _tag);
      final uploadedFiles = await manager.uploadInputImages(
        api: conn!.api!,
        template: template,
        imageData: inputImages,
      );
      AppLogger.d(
        'Inputs uploaded for template=$templateId: $uploadedFiles',
        _tag,
      );

      // 2. 处理种子：-1 表示随机
      final effectiveParams = Map<String, dynamic>.from(paramValues);
      final seedSlot = template.slots.where((s) => s.id == 'seed').toList();
      if (seedSlot.isNotEmpty) {
        final seedValue =
            effectiveParams['seed'] ?? seedSlot.first.defaultValue;
        if (seedValue is int && seedValue == -1) {
          effectiveParams['seed'] = Random().nextInt(4294967295);
        }
      }

      // 3. 构建可执行工作流
      AppLogger.d('Building workflow for template=$templateId', _tag);
      final workflow = manager.buildExecutableWorkflow(
        template: template,
        paramValues: effectiveParams,
        uploadedFiles: uploadedFiles,
      );
      AppLogger.d(
        'Validating workflow node types for template=$templateId',
        _tag,
      );
      await manager.validateWorkflowNodeTypes(
        api: conn.api!,
        workflow: workflow,
      );
      AppLogger.d(
        'Workflow node validation passed: template=$templateId',
        _tag,
      );

      // 4. 提交工作流
      state = state.copyWith(status: ComfyUITaskStatus.queued);
      AppLogger.i(
        'Queue prompt start: template=$templateId, clientId=${conn.clientId}',
        _tag,
      );
      final result = await conn.api!.queuePrompt(
        workflow: workflow,
        clientId: conn.clientId,
      );
      state = state.copyWith(promptId: result.promptId);
      conn.ws!.trackPrompt(result.promptId);
      AppLogger.i(
        'Queue prompt returned: template=$templateId, '
        'promptId=${result.promptId}, '
        'webSocketOutput=${template.usesWebSocketOutput}',
        _tag,
      );

      // 5. 等待完成
      state = state.copyWith(status: ComfyUITaskStatus.running);

      final images = template.usesWebSocketOutput
          ? await _waitForWebSocketResult(conn, result.promptId, outputNodeIds)
          : await _waitForHttpResult(conn, result.promptId, outputNodeIds);
      AppLogger.i(
        'Workflow result collected: template=$templateId, '
        'promptId=${result.promptId}, ${_summarizeOutputImages(images)}',
        _tag,
      );
      return images;
    } on _ComfyUITaskLocalizedException catch (e, stackTrace) {
      AppLogger.e(
        'Task execution failed: template=$templateId',
        e,
        stackTrace,
        _tag,
      );
      state = state.copyWith(
        status: ComfyUITaskStatus.failed,
        errorCode: e.code,
        errorDetails: e.details,
      );
      return null;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Task execution failed: template=$templateId',
        e,
        stackTrace,
        _tag,
      );
      state = state.copyWith(
        status: ComfyUITaskStatus.failed,
        errorCode: ComfyUITaskErrorCode.executionFailed,
        errorDetails: e.toString(),
      );
      return null;
    }
  }

  Future<List<Uint8List>> _waitForWebSocketResult(
    ComfyUIConnectionManager conn,
    String promptId,
    Set<String> outputNodeIds,
  ) async {
    final images = <Uint8List>[];
    final completer = Completer<List<Uint8List>>();

    final imageSub = conn.ws!.imageStream.listen((ComfyUIImageFrame frame) {
      if (frame.isPreview) {
        state = state.copyWith(previewImage: frame.data);
      } else {
        images.add(frame.data);
        AppLogger.d(
          'Received final WS image: ${frame.data.length} bytes',
          _tag,
        );
      }
    });

    final progressSub = conn.ws!.progressStream.listen((progress) {
      if (progress.promptId != promptId) return;

      state = state.copyWith(
        progress: progress.progressFraction,
        currentStep: progress.currentStep,
        totalSteps: progress.totalSteps,
      );

      if (progress.status == ComfyUITaskStatus.completed) {
        if (!completer.isCompleted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!completer.isCompleted) {
              completer.complete(images);
            }
          });
        }
      } else if (progress.status == ComfyUITaskStatus.failed) {
        if (!completer.isCompleted) {
          completer.completeError(
            _ComfyUITaskLocalizedException(
              ComfyUITaskErrorCode.executionFailed,
              details: progress.errorMessage,
            ),
          );
        }
      }
    });

    try {
      var result = await completer.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () => throw const _ComfyUITaskLocalizedException(
          ComfyUITaskErrorCode.timeout,
        ),
      );
      // SaveImageWebsocket 在部分版本/节点下可能未推送二进制帧，改从 history+view 拉取
      if (result.isEmpty) {
        try {
          result = await conn.api!.getOutputImages(
            promptId,
            allowedNodeIds: outputNodeIds,
          );
        } catch (e) {
          AppLogger.w('WS 无图像且 history 拉取失败: $e', _tag);
        }
      }
      state = state.copyWith(
        status: ComfyUITaskStatus.completed,
        progress: 1.0,
      );
      return result;
    } finally {
      await imageSub.cancel();
      await progressSub.cancel();
    }
  }

  Future<List<Uint8List>> _waitForHttpResult(
    ComfyUIConnectionManager conn,
    String promptId,
    Set<String> outputNodeIds,
  ) async {
    final completer = Completer<void>();

    final imageSub = conn.ws!.imageStream.listen((ComfyUIImageFrame frame) {
      if (frame.isPreview) {
        state = state.copyWith(previewImage: frame.data);
      }
    });

    final progressSub = conn.ws!.progressStream.listen((progress) {
      if (progress.promptId != promptId) return;

      state = state.copyWith(
        progress: progress.progressFraction,
        currentStep: progress.currentStep,
        totalSteps: progress.totalSteps,
      );

      if (progress.status == ComfyUITaskStatus.completed) {
        if (!completer.isCompleted) completer.complete();
      } else if (progress.status == ComfyUITaskStatus.failed) {
        if (!completer.isCompleted) {
          completer.completeError(
            _ComfyUITaskLocalizedException(
              ComfyUITaskErrorCode.executionFailed,
              details: progress.errorMessage,
            ),
          );
        }
      }
    });

    try {
      await completer.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () => throw const _ComfyUITaskLocalizedException(
          ComfyUITaskErrorCode.timeout,
        ),
      );

      AppLogger.d(
        'Task $promptId completed, fetching output images via HTTP...',
        _tag,
      );
      final images = await conn.api!.getOutputImages(
        promptId,
        allowedNodeIds: outputNodeIds,
      );
      AppLogger.i(
        'Got ${images.length} images from history (sizes: ${images.map((i) => i.length).toList()})',
        _tag,
      );
      state = state.copyWith(
        status: ComfyUITaskStatus.completed,
        progress: 1.0,
      );
      return images;
    } finally {
      await imageSub.cancel();
      await progressSub.cancel();
    }
  }

  void cancel() {
    final conn = ref.read(comfyUIConnectionProvider.notifier).manager;
    conn?.api?.interrupt();
    state = state.copyWith(status: ComfyUITaskStatus.cancelled);
  }
}

/// 从 ComfyUI object_info 获取可用于超分的模型列表。
///
/// 包含：
/// - SeedVR2LoadDiTModel 的 DiT 模型
/// - UpscaleModelLoader 的普通超分模型（.pth/.pt/.safetensors 等）
@riverpod
class ComfyUISeedvr2Models extends _$ComfyUISeedvr2Models {
  static const _tag = 'ComfyUIUpscaleModels';
  static const _seedvr2NodeClass = 'SeedVR2LoadDiTModel';
  static const _upscaleNodeClass = 'UpscaleModelLoader';
  static const _fallback = ['seedvr2_ema_7b_fp16.safetensors'];
  bool _isFetching = false;
  bool _hasFetchedFromServer = false;

  bool get hasFetchedFromServer => _hasFetchedFromServer;

  @override
  List<String> build() {
    ref.listen<ComfyUISettingsState>(comfyUISettingsProvider, (prev, next) {
      if (!next.enabled) {
        _hasFetchedFromServer = false;
        _isFetching = false;
        state = _fallback;
        return;
      }

      final serverChanged = prev?.serverUrl != next.serverUrl;
      final enabledChanged = prev?.enabled != next.enabled;
      if (serverChanged || enabledChanged) {
        _hasFetchedFromServer = false;
        _scheduleAutoFetch(force: true);
      }
    });

    ref.listen<ComfyUIConnectionStatus>(comfyUIConnectionProvider, (
      previous,
      next,
    ) {
      if (next == ComfyUIConnectionStatus.connected) {
        _scheduleAutoFetch();
      }
    });

    if (ref.read(comfyUISettingsProvider).enabled) {
      _scheduleAutoFetch();
    }
    return _fallback;
  }

  void _scheduleAutoFetch({bool force = false}) {
    if (_isFetching) return;
    if (_hasFetchedFromServer && !force) return;
    Future.microtask(() => fetch(force: force));
  }

  Future<void> fetch({bool force = false}) async {
    if (_isFetching) return;
    if (_hasFetchedFromServer && !force) return;

    _isFetching = true;
    final connNotifier = ref.read(comfyUIConnectionProvider.notifier);
    var conn = connNotifier.manager;

    if (conn?.api == null) {
      final connStatus = ref.read(comfyUIConnectionProvider);
      if (connStatus != ComfyUIConnectionStatus.connected) {
        AppLogger.d(
          'Attempting to connect ComfyUI before fetching models...',
          _tag,
        );
        final ok = await connNotifier.connect();
        if (!ok) {
          AppLogger.w('Cannot fetch models: ComfyUI not connected', _tag);
          _isFetching = false;
          return;
        }
      }
      conn = connNotifier.manager;
      if (conn?.api == null) {
        AppLogger.w('ComfyUI manager or api is null after connect', _tag);
        _isFetching = false;
        return;
      }
    }

    try {
      final seedvr2Models = await _fetchModelsFromNode(
        conn!,
        nodeClass: _seedvr2NodeClass,
        candidateFields: const ['model', 'dit_model', 'dit_model_name'],
      );
      final normalUpscaleModels = await _fetchModelsFromNode(
        conn,
        nodeClass: _upscaleNodeClass,
        candidateFields: const ['model_name', 'upscale_model', 'model'],
      );

      final models = <String>[
        ...seedvr2Models,
        for (final model in normalUpscaleModels)
          if (!seedvr2Models.contains(model)) model,
      ];

      if (models.isNotEmpty) {
        AppLogger.i(
          'Found ${seedvr2Models.length} SeedVR2 and '
          '${normalUpscaleModels.length} regular upscale model(s)',
          _tag,
        );
        state = models;
        _hasFetchedFromServer = true;
      } else {
        AppLogger.w('Could not extract any ComfyUI upscale model list', _tag);
      }
    } catch (e, st) {
      AppLogger.w('Failed to fetch ComfyUI upscale models: $e', _tag);
      AppLogger.d('Stack: $st', _tag);
    } finally {
      _isFetching = false;
    }
  }

  Future<List<String>> _fetchModelsFromNode(
    ComfyUIConnectionManager conn, {
    required String nodeClass,
    required Iterable<String> candidateFields,
  }) async {
    try {
      final info = await conn.api!.getObjectInfo(nodeClass);
      AppLogger.d(
        '$nodeClass object_info raw keys: ${info.keys.toList()}',
        _tag,
      );

      final node = info[nodeClass] as Map<String, dynamic>?;
      if (node == null) {
        AppLogger.w(
          'Node "$nodeClass" not found. Available: ${info.keys.take(10)}',
          _tag,
        );
        return const [];
      }

      final input = node['input'] as Map<String, dynamic>?;
      if (input == null) {
        AppLogger.w('$nodeClass has no "input" key. Keys: ${node.keys}', _tag);
        return const [];
      }

      final required = input['required'] as Map<String, dynamic>?;
      if (required == null) {
        AppLogger.w(
          '$nodeClass has no required inputs. Keys: ${input.keys}',
          _tag,
        );
        return const [];
      }

      AppLogger.d(
        '$nodeClass required fields: ${required.keys.toList()}',
        _tag,
      );
      final models = extractChoiceListFromCandidateFields(
        required,
        candidateFields,
      );

      if (models != null && models.isNotEmpty) {
        return models;
      }

      AppLogger.w('Could not extract model list from $nodeClass', _tag);
      for (final entry in required.entries) {
        AppLogger.d(
          '  ${entry.key}: ${entry.value.runtimeType} = '
          '${_truncate(entry.value.toString(), 200)}',
          _tag,
        );
      }
      return const [];
    } catch (e) {
      AppLogger.w('Failed to fetch models from $nodeClass: $e', _tag);
      return const [];
    }
  }

  static String _truncate(String s, int maxLen) =>
      s.length <= maxLen ? s : '${s.substring(0, maxLen)}...';
}

enum ComfyUITaskErrorCode {
  connectionFailed,
  connectionUnavailable,
  workflowNotFound,
  executionFailed,
  timeout,
}

class _ComfyUITaskLocalizedException implements Exception {
  const _ComfyUITaskLocalizedException(this.code, {this.details});

  final ComfyUITaskErrorCode code;
  final String? details;
}

class ComfyUITaskState {
  final ComfyUITaskStatus status;
  final double progress;
  final int currentStep;
  final int totalSteps;
  final String? promptId;
  final String? errorMessage;
  final ComfyUITaskErrorCode? errorCode;
  final String? errorDetails;

  /// WebSocket 推送的中间步骤预览图
  final Uint8List? previewImage;

  const ComfyUITaskState({
    this.status = ComfyUITaskStatus.completed,
    this.progress = 0,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.promptId,
    this.errorMessage,
    this.errorCode,
    this.errorDetails,
    this.previewImage,
  });

  bool get isRunning =>
      status == ComfyUITaskStatus.uploading ||
      status == ComfyUITaskStatus.queued ||
      status == ComfyUITaskStatus.running;

  bool get hasPreview => previewImage != null && previewImage!.isNotEmpty;

  String? localizedError(AppLocalizations l10n) {
    return switch (errorCode) {
      ComfyUITaskErrorCode.connectionFailed =>
        l10n.comfyTask_errorConnectionFailed,
      ComfyUITaskErrorCode.connectionUnavailable =>
        l10n.comfyTask_errorConnectionUnavailable,
      ComfyUITaskErrorCode.workflowNotFound =>
        l10n.comfyTask_errorWorkflowNotFound(errorDetails ?? ''),
      ComfyUITaskErrorCode.executionFailed =>
        errorDetails == null || errorDetails!.isEmpty
            ? l10n.comfyTask_errorExecutionFailedGeneric
            : l10n.comfyTask_errorExecutionFailed(errorDetails!),
      ComfyUITaskErrorCode.timeout => l10n.comfyTask_errorTimeout,
      null => errorMessage,
    };
  }

  ComfyUITaskState copyWith({
    ComfyUITaskStatus? status,
    double? progress,
    int? currentStep,
    int? totalSteps,
    String? promptId,
    String? errorMessage,
    ComfyUITaskErrorCode? errorCode,
    String? errorDetails,
    Uint8List? previewImage,
    bool clearPreview = false,
  }) {
    return ComfyUITaskState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      promptId: promptId ?? this.promptId,
      errorMessage: errorMessage,
      errorCode: errorCode,
      errorDetails: errorDetails,
      previewImage: clearPreview ? null : (previewImage ?? this.previewImage),
    );
  }
}
