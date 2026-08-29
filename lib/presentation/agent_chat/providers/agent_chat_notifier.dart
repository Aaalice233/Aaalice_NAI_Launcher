import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/agent/agent.dart';
import '../../../core/agent/agent_system_prompt.dart';
import '../../../core/agent/audit/jsonl_audit_sink.dart';
import '../../../core/agent/harness/compaction/compaction.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/harness/session/session_jsonl.dart';
import '../../../core/agent/harness/session/session.dart';
import '../../../core/agent/harness/session/session_types.dart'
    as session_types;
import '../../../core/agent/harness/skills.dart';
import '../../../core/agent/resources/agent_chat_resource_draft_store.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/skill_catalog.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/agent/agent_settings.dart';
import '../../../data/models/inpaint/inpaint_draft.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/models/agent_protocol.dart';
import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../prompt_assistant/providers/web_access_provider.dart';
import '../../prompt_assistant/services/prompt_assistant_service.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/precise_ref_library_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../router/app_router_config.dart';
import '../services/agent_api_client.dart';
import '../services/agent_chat_draft_controller.dart';
import '../services/agent_chat_event_controller.dart';
import '../services/agent_chat_session_controller.dart';
import '../services/agent_chat_model_capability.dart';
import '../services/agent_stream_bridge.dart';
import '../services/agent_system_prompt.dart';
import '../services/agent_resource_resolver.dart';
import '../services/generation_preparation_runtime.dart';
import '../services/manual_inpaint_toolbox.dart';
import '../services/queue_toolbox.dart';
import '../services/agent_tool_permission_controller.dart';
import '../services/agent_tool_registry_builder.dart';
import 'agent_chat_state.dart';

export 'agent_chat_state.dart';
export '../services/agent_api_client.dart';

typedef AgentWireCompletion =
    Stream<AgentWireEvent> Function(AgentChatRequest request);

final agentChatNotifierProvider =
    StateNotifierProvider<AgentChatNotifier, AgentChatState>((ref) {
      return AgentChatNotifier(ref);
    });

/// 聊天 agent 编排层：
/// - 底层 Agent loop（core/agent）驱动多轮对话与工具执行；
/// - 会话经 [Session]/[JsonlSessionRepo] 持久化为 JSONL 树；
/// - 上下文压缩经 [prepareCompaction]/[compact]（自动阈值 + 手动触发）；
/// - skills 经目录发现加载，并以 XML 清单注入系统提示词。
class AgentChatNotifier extends StateNotifier<AgentChatState> {
  AgentChatNotifier(
    this._ref, {
    List<HarnessSkill>? presetSkills,
    Directory? supportDir,
    Directory? workspaceDir,
    JsonlSessionRepo? sessionRepo,
    AgentWireCompletion? completeRequest,
    Map<String, String>? skillEnvironment,
    Future<Directory?> Function()? imageProjectDirectoryResolver,
  }) : _providedSupportDir = supportDir,
       _providedWorkspaceDir = workspaceDir,
       _providedSessionRepo = sessionRepo,
       _completeRequest = completeRequest,
       _skillEnvironment = skillEnvironment,
       _imageProjectDirectoryResolver = imageProjectDirectoryResolver,
       super(const AgentChatState()) {
    _ref.listen<WebAccessConfigState>(webAccessConfigProvider, (_, _) {
      unawaited(_refreshWebAccessTools());
    });
    _ref.listen<PromptAssistantConfigState>(promptAssistantConfigProvider, (
      previous,
      next,
    ) {
      _refreshRoute();
    });
    _ref.listen<AgentSettingsState>(agentSettingsProvider, (_, _) {
      _queueSettingsRefresh();
    });
    for (final provider in [
      fixedTagsNotifierProvider,
      tagLibraryPageNotifierProvider,
      vibeLibraryNotifierProvider,
      preciseRefLibraryNotifierProvider,
    ]) {
      _ref.listen(provider, (_, _) {
        unawaited(refreshPendingResourceAvailability());
      });
    }
    _initializing = _init(presetSkills: presetSkills);
  }

  final Ref _ref;
  final Directory? _providedSupportDir;
  final Directory? _providedWorkspaceDir;
  final JsonlSessionRepo? _providedSessionRepo;
  final AgentWireCompletion? _completeRequest;
  final Map<String, String>? _skillEnvironment;
  final Future<Directory?> Function()? _imageProjectDirectoryResolver;
  late Directory _supportDir;
  late Directory _workspaceDir;
  late AgentChatDraftController _draftController;
  bool _draftControllerInitialized = false;
  late AgentChatEventController _eventController;
  AgentChatSessionController? _sessionControllerValue;
  AgentToolPermissionController? _permissionController;
  late AgentToolRegistryBuilder _toolRegistryBuilder;
  late ManualInpaintToolbox _manualInpaintToolbox;
  late AgentApiClient _client;
  final Map<String, HarnessSkill> _skills = {};
  final List<SkillDiagnostic> _skillDiagnostics = [];
  final GenerationPreparationRuntime _generationPreparationRuntime =
      GenerationPreparationRuntime();
  final QueueControlRuntime _queueControlRuntime = QueueControlRuntime();
  late final Future<void> _initializing;
  bool _usesPresetSkills = false;
  bool _runtimeReady = false;
  Future<void> _settingsRefresh = Future<void>.value();
  Future<void> _sendDispatch = Future<void>.value();
  bool _settingsApplyPending = false;
  bool _preparingRun = false;
  AgentPermissionMode? _activePermissionMode;
  AgentSettings? _activeAgentSettings;
  (ProviderConfig, String, String?)? _routeCache;
  (ProviderConfig, String, String?)? _activeRoute;

  LocalStorageService get _local => _ref.read(localStorageServiceProvider);
  AgentChatSessionController get _sessionController => _sessionControllerValue!;

  Future<void> _init({List<HarnessSkill>? presetSkills}) async {
    final providedSupportDir = _providedSupportDir;
    if (providedSupportDir != null) {
      _supportDir = providedSupportDir;
    } else {
      try {
        _supportDir = await getApplicationSupportDirectory();
      } catch (e) {
        AppLogger.w('agent chat init failed: $e', 'AgentChat');
        _supportDir = Directory.systemTemp;
      }
    }
    final sessionRepository =
        _providedSessionRepo ?? JsonlSessionRepo(_supportDir);
    final resourceDraftStore = AgentChatResourceDraftStore(
      File(
        '${_supportDir.path}${Platform.pathSeparator}agent'
        '${Platform.pathSeparator}resource-drafts-v1.json',
      ),
    );
    final auditSink = JsonlAgentAuditSink(
      File(
        '${_supportDir.path}${Platform.pathSeparator}agent'
        '${Platform.pathSeparator}audit-v1.jsonl',
      ),
    );
    // 文件工具工作区（read 的 cwd 与相对路径根）。
    // 默认指向图片导出根目录（自定义保存路径或 Documents/NAI_Launcher/
    // images），让 Agent 能直接按相对路径读取生成的图片；解析失败时
    // 回退到应用支持目录下的 agent/workspace。
    Directory? workspaceDir = _providedWorkspaceDir;
    if (workspaceDir == null) {
      try {
        workspaceDir = await _resolveCurrentImageProjectDirectory();
      } catch (e) {
        AppLogger.w('resolve image export dir failed: $e', 'AgentChat');
      }
    }
    _workspaceDir =
        workspaceDir ??
        Directory(
          '${_supportDir.path}${Platform.pathSeparator}agent'
          '${Platform.pathSeparator}workspace',
        );
    try {
      await _workspaceDir.create(recursive: true);
    } catch (e) {
      AppLogger.w('agent workspace create failed: $e', 'AgentChat');
    }
    _manualInpaintToolbox = ManualInpaintToolbox(
      _ref,
      supportDirectory: _supportDir,
      workspaceDir: _workspaceDir.path,
      navigator: () =>
          _ref.read(appRouterProvider).routerDelegate.navigatorKey.currentState,
      activeSessionId: () => state.activeSessionId,
      onDraftChanged: _recordManualInpaintDraftUpdate,
    );
    AgentResourceResolver createResourceResolver() => AgentResourceResolver(
      _ref,
      loadInpaintDraftImage: _manualInpaintToolbox.loadDraftImage,
    );
    _draftController = AgentChatDraftController(
      resourceStore: resourceDraftStore,
      localStorage: _local,
      readState: () => state,
      writeState: (next) => state = next,
      createResourceResolver: createResourceResolver,
      isMounted: () => mounted,
    );
    _draftControllerInitialized = true;
    _permissionController = AgentToolPermissionController(
      auditSink: auditSink,
      estimateAnlas: _estimatePreparedAnlas,
      onApprovalChanged: (request) {
        final boundRequest = request?.bind(
          turnId: _sessionControllerValue?.activeTurnId,
          itemId: 'call:${request.toolCallId}',
        );
        state = request == null
            ? state.copyWith(
                clearApprovalRequest: true,
                workPhase: AgentChatWorkPhase.usingTools,
              )
            : state.copyWith(
                approvalRequest: boundRequest,
                workPhase: AgentChatWorkPhase.awaitingApproval,
              );
      },
      isMounted: () => mounted,
    );
    _toolRegistryBuilder = AgentToolRegistryBuilder(
      ref: _ref,
      workspaceDir: _workspaceDir.path,
      skills: _skills,
      skillDiagnostics: _skillDiagnostics,
      reloadSkills: reloadSkills,
      generationRuntime: _generationPreparationRuntime,
      queueRuntime: _queueControlRuntime,
      manualInpaintToolbox: _manualInpaintToolbox,
    );
    _sessionControllerValue = AgentChatSessionController(
      repository: sessionRepository,
      localStorage: _local,
      draftController: _draftController,
      workspaceDir: _workspaceDir.path,
      buildAgent: _buildAgent,
      buildSystemPrompt: _buildSystemPrompt,
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => mounted,
    );
    _eventController = AgentChatEventController(
      sessionController: _sessionController,
      permissionController: _permissionController!,
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => mounted,
    );

    _usesPresetSkills = presetSkills != null;
    if (presetSkills != null) {
      for (final skill in presetSkills) {
        _skills[skill.name] = skill;
      }
    } else {
      await _loadSkillsFromDisk();
    }

    _client = AgentApiClient(_ref.read(promptAssistantDioProvider));
    _runtimeReady = true;
    _refreshRoute();
    await _sessionController.restoreLastSession();
    _refreshRoute();
    state = state.copyWith(
      initialized: true,
      skills: _skills.values.toList(growable: false),
    );
  }

  Future<Agent> _buildAgent() async {
    final permissionMode = _ref
        .read(agentSettingsProvider)
        .settings
        .chat
        .permissionMode;
    final fullAccess = permissionMode == AgentPermissionMode.fullAccess;
    final capability = _modelCapability(_routeCache);
    final agent = Agent(
      AgentOptions(
        streamFn: _streamFn,
        initialSystemPrompt: await _buildSystemPrompt(),
        initialModel: capability.model,
        // 提示词工具（含 read_skill）+ 只读文件工具 + 生成/反推/队列工具
        // + 标签检索工具。
        initialTools: _buildTools(fullAccess: fullAccess),
        convertToLlm: (messages) async => harnessConvertToLlm(messages),
        transformContext: (messages, signal) async =>
            await _maybeCompactContext(messages, signal) ?? messages,
        beforeToolCall: _beforeToolCall,
        toolExecution: ToolExecutionMode.sequential,
      ),
    );
    agent.subscribe(_handleEvent);
    return agent;
  }

  Future<BeforeToolCallResult?> _beforeToolCall(
    BeforeToolCallContext context,
    AbortSignal? signal,
  ) => _permissionController!.beforeToolCall(context, signal);

  bool resolveToolApproval(String toolCallId, bool approved) =>
      _permissionController?.resolveApproval(toolCallId, approved) ?? false;

  Future<void> setPermissionMode(AgentPermissionMode mode) async {
    if (!canManageAgentChatSessions(state)) {
      return;
    }
    await _ref.read(agentSettingsProvider.notifier).setPermissionMode(mode);
    await _settingsRefresh;
  }

  List<AgentTool> _buildTools({required bool fullAccess}) {
    final permissionMode =
        _activePermissionMode ??
        _ref.read(agentSettingsProvider).settings.chat.permissionMode;
    final registry = _toolRegistryBuilder.build(
      fullAccess: fullAccess,
      permissionMode: permissionMode,
    );
    _permissionController!.configure(registry);
    return registry.tools;
  }

  Future<void> _refreshWebAccessTools() async {
    if (_runActive) {
      _queueSettingsRefresh();
      return;
    }
    final agent = _sessionControllerValue?.agent;
    if (agent == null) return;
    final mode = _ref.read(agentSettingsProvider).settings.chat.permissionMode;
    agent.state.tools = _buildTools(
      fullAccess: mode == AgentPermissionMode.fullAccess,
    );
    agent.setSystemPrompt(await _buildSystemPrompt());
  }

  Future<void> _loadSkillsFromDisk({
    Map<String, bool>? skillEnabledOverrides,
  }) async {
    try {
      final loaded = await _scanCurrentSkills(
        skillEnabledOverrides: skillEnabledOverrides,
      );
      if (!mounted) return;
      _skills.clear();
      _skillDiagnostics
        ..clear()
        ..addAll([for (final item in loaded.diagnostics) item.diagnostic]);
      _skills.addAll(loaded.enabledSkillMap());
    } catch (e) {
      AppLogger.w('agent skills load failed: $e', 'AgentChat');
    }
  }

  Future<SkillCatalogSnapshot> _scanCurrentSkills({
    Map<String, bool>? skillEnabledOverrides,
  }) async {
    final resolvedOverrides =
        skillEnabledOverrides ??
        _ref.read(agentSettingsProvider).settings.skillEnabledOverrides;
    Directory? skillWorkspace = _providedWorkspaceDir;
    if (_providedWorkspaceDir == null) {
      try {
        skillWorkspace = await _resolveCurrentImageProjectDirectory();
      } catch (error) {
        AppLogger.w(
          'resolve current image project for Skills failed: $error',
          'AgentChat',
        );
      }
    }
    return const SkillCatalogService().scan(
      roots: SkillCatalogService.roots(
        workspaceDirectory: skillWorkspace,
        supportDirectory: _supportDir,
        environment: _skillEnvironment,
      ),
      skillEnabledOverrides: resolvedOverrides,
    );
  }

  Future<Directory?> _resolveCurrentImageProjectDirectory() async {
    final resolver = _imageProjectDirectoryResolver;
    if (resolver != null) return resolver();
    final currentRoot = await GalleryFolderRepository.instance.getRootPath();
    if (currentRoot == null || currentRoot.isEmpty) return null;
    return Directory(currentRoot);
  }

  Future<int> reloadSkills() async {
    if (!_usesPresetSkills) {
      await _loadSkillsFromDisk(
        skillEnabledOverrides: _activeAgentSettings?.skillEnabledOverrides,
      );
    }
    if (!mounted) return _skills.length;
    state = state.copyWith(skills: _skills.values.toList(growable: false));
    final agent = _sessionController.agent;
    if (agent != null) {
      final mode = _ref
          .read(agentSettingsProvider)
          .settings
          .chat
          .permissionMode;
      agent.state.tools = _buildTools(
        fullAccess: mode == AgentPermissionMode.fullAccess,
      );
      agent.setSystemPrompt(
        await _buildSystemPrompt(settingsOverride: _activeAgentSettings),
      );
    }
    return _skills.length;
  }

  Future<void> _applyAgentSettings() async {
    if (!mounted) return;
    _settingsApplyPending = true;
    if (!_runtimeReady || _runActive) return;
    if (!_usesPresetSkills) await _loadSkillsFromDisk();
    if (!mounted) return;
    _refreshRoute();
    final agent = _sessionControllerValue?.agent;
    if (agent != null) {
      final mode = _ref
          .read(agentSettingsProvider)
          .settings
          .chat
          .permissionMode;
      agent.state.tools = _buildTools(
        fullAccess: mode == AgentPermissionMode.fullAccess,
      );
      agent.setSystemPrompt(await _buildSystemPrompt());
    }
    if (mounted) {
      state = state.copyWith(skills: _skills.values.toList(growable: false));
    }
    _settingsApplyPending = false;
  }

  bool get _runActive =>
      _preparingRun || state.status == AgentChatRunStatus.running;

  void _queueSettingsRefresh() {
    if (!mounted) return;
    _settingsApplyPending = true;
    _settingsRefresh = _settingsRefresh
        .catchError((Object error) {
          AppLogger.w('agent settings refresh failed: $error', 'AgentChat');
        })
        .then((_) async {
          if (!mounted) return;
          await _applyAgentSettings();
        });
  }

  /// 代理 compaction：上下文超阈值时折叠旧消息为摘要消息
  /// （消息空间实现。
  /// [force] 为 true 时跳过 token 阈值检查，供用户手动压缩。
  Future<List<AgentMessage>?> _maybeCompactContext(
    List<AgentMessage> messages,
    AbortSignal? signal, {
    bool force = false,
  }) async {
    try {
      final route = _activeRoute ?? _routeCache ?? _resolveRoute();
      final session = _sessionController.session;
      if (route == null || session == null || messages.length <= 8) {
        return messages;
      }
      final contextWindow = _modelCapability(route).model.contextWindow;
      if (contextWindow <= 0) return messages;
      final estimate = estimateContextTokens(messages);
      const settings = defaultCompactionSettings;
      if (!force && !shouldCompact(estimate.tokens, contextWindow, settings)) {
        return messages;
      }

      state = state.copyWith(compacting: true);
      final entries = await session.findEntriesOnBranch(
        const session_types.EntryQuery(
          order: session_types.EntryOrder.oldestFirst,
        ),
      );
      final prep = prepareCompaction(entries, settings);
      final preparation = prep.valueOrNull;
      if (preparation == null) {
        state = state.copyWith(compacting: false);
        return messages;
      }
      final result = await compact(
        preparation,
        _completeSimple,
        Model(
          id: route.$2,
          name: route.$2,
          api: route.$1.protocol.name,
          provider: route.$1.id,
          contextWindow: contextWindow,
        ),
        signal: signal,
      );
      final compactResult = result.valueOrNull;
      state = state.copyWith(compacting: false);
      if (compactResult == null) {
        return messages;
      }

      final entry =
          await session.appendEntry(
                session_types.CompactionEntry(
                  id: session.idGenerator(),
                  summary: compactResult.summary,
                  retainedTail: compactResult.retainedTail,
                  tokensBefore: compactResult.tokensBefore,
                  details: compactResult.details,
                  usage: compactResult.usage,
                ),
                'main',
              )
              as session_types.CompactionEntry;
      final compressed = <AgentMessage>[
        createCompactionSummaryMessage(
          entry.summary,
          entry.tokensBefore,
          entry.timestamp,
        ),
        ...compactResult.retainedTail,
      ];
      messages
        ..clear()
        ..addAll(compressed);
      _sessionController.agent?.state.messages = List.of(compressed);
      if (compactResult.usage != null) {
        _sessionController.totalUsage =
            _sessionController.totalUsage + compactResult.usage!;
      }
      state = state.copyWith(
        messages: List.of(compressed),
        totalUsage: _sessionController.totalUsage,
      );
      return messages;
    } catch (e) {
      AppLogger.w('agent compaction skipped: $e', 'AgentChat');
      state = state.copyWith(compacting: false);
      return messages;
    }
  }

  /// completeSimple：经 StreamFn 收敛的一次性调用。
  Future<AssistantMessage> _completeSimple(
    Model model,
    Context context, [
    SimpleStreamOptions? options,
  ]) {
    return completeSimpleViaStreamFn(_streamFn, model, context, options);
  }

  /// StreamFn：解析路由 → 线请求 → 适配器流 → 桥接。
  AssistantMessageEventStream _streamFn(
    Model model,
    Context context, [
    SimpleStreamOptions? options,
  ]) {
    try {
      final route = _activeRoute ?? _routeCache;
      if (route == null) {
        return _errorStream('No LLM provider configured for chat.');
      }
      final request = AgentChatRequest(
        sessionId: 'agent_chat',
        provider: route.$1,
        model: route.$2,
        systemPrompt: context.systemPrompt,
        messages: List.unmodifiable(context.messages),
        tools: [
          for (final tool in context.tools ?? const <Tool>[])
            Tool(
              name: tool.name,
              description: tool.description,
              parameters: Map.unmodifiable(
                Map<String, dynamic>.from(tool.parameters),
              ),
            ),
        ],
        apiKey: route.$3,
        maxOutputTokens: options?.maxTokens,
        reasoning: options?.reasoning,
      );
      final wireEvents =
          _completeRequest?.call(request) ?? _client.complete(request);
      final signal = options?.signal;
      if (signal is AbortSignal) {
        signal.addListener((_) => _client.cancel('agent_chat'));
      }
      return agentWireEventStream(
        wireEvents,
        provider: request.provider.id,
        model: request.model,
      );
    } catch (e) {
      return _errorStream(e.toString());
    }
  }

  static AssistantMessageEventStream _errorStream(String message) {
    final stream = EventStream<AssistantMessageEvent, AssistantMessage>();
    final failure = AssistantMessage(
      content: const [],
      stopReason: StopReason.error,
      errorMessage: message,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    scheduleMicrotask(() {
      stream.push(AmStart(partial: failure));
      stream.push(AmError(partial: failure, error: message));
      stream.end(failure);
    });
    return stream;
  }

  (ProviderConfig, String, String?)? _resolveRoute() {
    final config = _ref.read(promptAssistantConfigProvider);
    final enabled = config.providers.where((p) => p.enabled).toList();
    if (enabled.isEmpty) {
      return null;
    }
    final modelReference = _ref
        .read(agentSettingsProvider)
        .settings
        .chat
        .modelReference;
    if (!modelReference.isConfigured) return null;
    final provider = enabled
        .where((item) => item.id == modelReference.providerId)
        .firstOrNull;
    if (provider == null) return null;
    final models = config.modelsForProviderTask(
      providerId: provider.id,
      taskType: AssistantTaskType.chat,
    );
    final model = modelReference.model.trim();
    if (!models.any((item) => !item.isPlaceholder && item.name == model)) {
      return null;
    }
    return (provider, model, null);
  }

  AgentChatModelCapability _modelCapability(
    (ProviderConfig, String, String?)? route,
  ) {
    return route == null
        ? AgentChatModelCapability.unavailable
        : AgentChatModelCapability.resolve(route.$1, route.$2);
  }

  Future<String> _buildSystemPrompt({
    String? customInstructionsOverride,
    AgentSystemPromptMode? modeOverride,
    Iterable<HarnessSkill>? skillsOverride,
    AgentSettings? settingsOverride,
  }) async {
    // 路由缓存 + API Key 解析（短期 token 每次运行刷新）。
    final route = _activeRoute ?? _routeCache ?? _resolveRoute();
    if (route != null) {
      final apiKey = await _ref
          .read(promptAssistantConfigProvider.notifier)
          .getProviderApiKey(route.$1.id);
      final resolvedRoute = (route.$1, route.$2, apiKey);
      if (_activeRoute != null) {
        _activeRoute = resolvedRoute;
      } else {
        _routeCache = resolvedRoute;
      }
    }
    final agentSettings =
        settingsOverride ?? _ref.read(agentSettingsProvider).settings;
    final skillBlock = formatSkillsForSystemPrompt(
      (skillsOverride ?? _skills.values).toList(growable: false),
    );
    final builtInPrompt = buildAgentSystemPrompt(
      workspacePath: _workspaceDir.path,
      webAccessEnabled: agentSettings.chat.webAccessEnabled,
      skillBlock: skillBlock,
    );
    return composeAgentSystemPrompt(
      builtInPrompt: builtInPrompt,
      customInstructions: agentSettings.chat.behaviorInstructions(
        customPromptOverride: customInstructionsOverride,
        modeOverride: modeOverride,
      ),
      mode: modeOverride ?? agentSettings.chat.systemPromptMode,
    );
  }

  Future<String> buildSystemPromptPreview({
    String? customInstructions,
    AgentSystemPromptMode? mode,
  }) async {
    await _initializing;
    await _settingsRefresh;
    final previewSkills = _usesPresetSkills
        ? _skills.values
        : (await _scanCurrentSkills()).enabledSkillMap().values;
    return _buildSystemPrompt(
      customInstructionsOverride: customInstructions,
      modeOverride: mode,
      skillsOverride: previewSkills,
    );
  }

  void _refreshRoute() {
    _routeCache = _resolveRoute();
    if (_routeCache == null) {
      final hasProvider = _ref
          .read(promptAssistantConfigProvider)
          .providers
          .any((p) => p.enabled);
      state = state.copyWith(
        routeReady: false,
        routeLabel: '',
        routeError: hasProvider
            ? 'The chat task has no usable model. Pick a model in Settings.'
            : 'No LLM provider configured. Add one in Settings > '
                  'Integrations.',
        clearContextWindow: true,
        availableThinkingLevels: const [],
        thinkingLevel: ThinkingLevel.off,
      );
      return;
    }
    final capability = _modelCapability(_routeCache);
    final currentLevel = capability.levels.contains(state.thinkingLevel)
        ? state.thinkingLevel
        : capability.levels.firstOrNull ?? ThinkingLevel.off;
    final agent = _sessionControllerValue?.agent;
    if (agent != null) {
      agent.state.model = capability.model;
      agent.state.thinkingLevel = currentLevel;
    }
    state = state.copyWith(
      routeReady: true,
      routeLabel: '${_routeCache!.$1.name} / ${_routeCache!.$2}',
      routeError: '',
      contextWindow: capability.model.contextWindow > 0
          ? capability.model.contextWindow
          : null,
      clearContextWindow: capability.model.contextWindow <= 0,
      availableThinkingLevels: capability.levels,
      thinkingLevel: currentLevel,
    );
  }

  Future<void> setThinkingLevel(ThinkingLevel level) async {
    if (!canManageAgentChatSessions(state) ||
        !state.availableThinkingLevels.contains(level)) {
      return;
    }
    final agent = _sessionControllerValue?.agent;
    final session = _sessionControllerValue?.session;
    if (agent == null ||
        session == null ||
        agent.state.thinkingLevel == level) {
      return;
    }
    agent.state.thinkingLevel = level;
    await session.appendEntry(
      session_types.ThinkingLevelEntry(
        id: session.idGenerator(),
        thinkingLevel: level.name,
      ),
      'main',
    );
    if (mounted) state = state.copyWith(thinkingLevel: level);
  }

  // -------------------------------------------------------------------------
  // 会话管理
  // -------------------------------------------------------------------------

  Future<int?> _estimatePreparedAnlas(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    if (toolName == 'submit_generation' ||
        toolName == 'generate_image' ||
        toolName == 'queue_image_task') {
      final id = args['preparation_id'];
      if (id is String) {
        return _generationPreparationRuntime.get(id)?.estimatedAnlas;
      }
    }
    if (toolName == 'submit_manual_inpaint_draft') {
      final id = args['draft_id'];
      return id is String
          ? await _manualInpaintToolbox.estimateAnlasForDraft(id)
          : null;
    }
    if (toolName == 'start_generation_queue' ||
        toolName == 'resume_generation_queue') {
      final id = args['queue_preparation_id'];
      return id is String ? _queueControlRuntime.get(id)?.estimatedAnlas : null;
    }
    return null;
  }

  Future<void> addPendingResource(AgentChatResourceReference reference) async {
    await _initializing;
    await _draftController.addPendingResource(reference);
  }

  Future<void> removePendingResource(int index) {
    if (!_draftControllerInitialized) return Future<void>.value();
    return _draftController.removePendingResource(index);
  }

  Future<void> clearPendingResources() {
    if (!_draftControllerInitialized) return Future<void>.value();
    return _draftController.clearPendingResources();
  }

  void setComposerText(String value) {
    if (!_draftControllerInitialized) {
      if (value != state.composerText) {
        state = state.copyWith(composerText: value);
      }
      return;
    }
    _draftController.setComposerText(value);
  }

  Future<void> clearComposerText() {
    if (!_draftControllerInitialized) {
      state = state.copyWith(composerText: '');
      return Future<void>.value();
    }
    return _draftController.clearComposerText();
  }

  Future<void> refreshPendingResourceAvailability() {
    if (!_draftControllerInitialized) {
      if (mounted && state.unavailableResourceKeys.isNotEmpty) {
        state = state.copyWith(unavailableResourceKeys: const {});
      }
      return Future<void>.value();
    }
    return _draftController.refreshPendingResourceAvailability();
  }

  Future<bool> validatePendingResourcesForSend() {
    if (!_draftControllerInitialized) return Future<bool>.value(true);
    return _draftController.validatePendingResourcesForSend();
  }

  Future<void> _recordManualInpaintDraftUpdate(
    String ownerSessionId,
    InpaintDraft draft,
  ) => _sessionController.recordManualInpaintDraftUpdate(ownerSessionId, draft);

  Future<ResolvedAgentResource?> resolveResourcePreview(
    AgentChatResourceReference reference,
  ) async {
    await _initializing;
    return _draftController.resolveResourcePreview(reference);
  }

  Future<void> newSession() async {
    await _sessionController.newSession();
    _refreshRoute();
  }

  Future<void> switchSession(String sessionId) async {
    await _sessionController.switchSession(sessionId);
    _refreshRoute();
  }

  /// 将主分支回退到最后一条用户消息之前，并返回该消息供输入框恢复。
  ///
  /// 原条目仍保留在会话树中，只移动 main lane 指针；后续发送会从回退点
  /// 建立新分支，与 `/rewind` 的语义一致。
  Future<UserMessage?> rewindLastUserMessage() =>
      _sessionController.rewindLastUserMessage();

  Future<void> loadEarlierHistory() => _sessionController.loadEarlierHistory();

  /// 删除指定会话；删除当前会话时自动切到最近剩余会话（无则新建）。
  Future<void> deleteSession(String sessionId) =>
      _sessionController.deleteSession(sessionId);

  /// 重命名会话（持久化 name 记录，列表即时刷新）。
  Future<void> renameSession(String sessionId, String name) =>
      _sessionController.renameSession(sessionId, name);

  /// 切换聊天模型：写入 chat 任务路由并持久化，随后刷新本地路由缓存。
  Future<void> selectChatModel(String providerId, String model) async {
    if (!canManageAgentChatSessions(state) ||
        providerId.isEmpty ||
        model.isEmpty) {
      return;
    }
    final config = _ref.read(promptAssistantConfigProvider);
    if (!config.providers.any((p) => p.id == providerId && p.enabled)) {
      return;
    }
    await _ref
        .read(agentSettingsProvider.notifier)
        .setModelReference(
          AgentModelReference(providerId: providerId, model: model),
        );
    await _settingsRefresh;
    _refreshRoute();
  }

  // -------------------------------------------------------------------------
  // 运行
  // -------------------------------------------------------------------------

  /// 发送一条用户消息；[images] 为可选的内联图片附件（base64）。
  Future<void> send(String text, {List<ImageContent>? images}) async {
    final trimmed = text.trim();
    final hasImages = images != null && images.isNotEmpty;
    if (trimmed.isEmpty && !hasImages) {
      return;
    }
    final message = _buildUserMessage(trimmed, hasImages ? images : null);
    await _sendMessage(message);
  }

  /// 发送已按输入位置排列的文本与图片内容块。
  Future<void> sendContent(
    List<UserContent> content, {
    bool followUp = false,
  }) async {
    final normalized = <UserContent>[
      for (final block in content)
        if (block is! UserTextContent || block.text.trim().isNotEmpty) block,
    ];
    if (normalized.isEmpty) {
      return;
    }
    await _sendMessage(UserMessage(content: normalized), followUp: followUp);
  }

  Future<void> _sendMessage(
    UserMessage message, {
    bool followUp = false,
  }) async {
    if (state.sessionTransitioning) {
      return;
    }
    await _initializing;
    final previousDispatch = _sendDispatch;
    final dispatchDone = Completer<void>();
    _sendDispatch = dispatchDone.future;
    Future<void>? run;
    Agent? runAgent;
    var ownsRun = false;

    try {
      await previousDispatch;
      if (state.sessionTransitioning ||
          !await validatePendingResourcesForSend()) {
        return;
      }
      final agent = _sessionController.agent;
      if (agent == null) {
        state = state.copyWith(
          error: 'Agent chat is still initializing. Try again in a moment.',
        );
        return;
      }
      final attachedResources = List<AgentChatResourceReference>.of(
        state.pendingResources,
      );
      final promptMessage = attachedResources.isEmpty
          ? message
          : _draftController.resourcePromptMessage(message, attachedResources);

      if (_runActive) {
        if (followUp) {
          agent.followUp(promptMessage);
        } else {
          agent.steer(promptMessage);
        }
        await _draftController.consumePendingResources(attachedResources);
        state = state.copyWith(queuedMessages: _queuedMessages(agent));
        return;
      }

      ownsRun = true;
      _preparingRun = true;
      await _settingsRefresh;
      if (_settingsApplyPending) await _applyAgentSettings();
      _refreshRoute();
      if (!state.routeReady) {
        state = state.copyWith(
          error: state.routeError.isNotEmpty
              ? state.routeError
              : 'No LLM provider configured. Open Settings to add one.',
        );
        _preparingRun = false;
        return;
      }
      final agentSettings = _ref.read(agentSettingsProvider).settings;
      final permissionMode = agentSettings.chat.permissionMode;
      _activeAgentSettings = agentSettings;
      _activePermissionMode = permissionMode;
      _activeRoute = _routeCache;
      final capability = _modelCapability(_activeRoute);
      agent.state.model = capability.model;
      if (!capability.levels.contains(agent.state.thinkingLevel)) {
        agent.state.thinkingLevel =
            capability.levels.firstOrNull ?? ThinkingLevel.off;
      }
      agent.state.tools = _buildTools(
        fullAccess: permissionMode == AgentPermissionMode.fullAccess,
      );
      agent.setSystemPrompt(
        await _buildSystemPrompt(settingsOverride: agentSettings),
      );
      state = state.copyWith(
        status: AgentChatRunStatus.running,
        error: '',
        activities: const [],
        clearStreamingMessage: true,
        workPhase: AgentChatWorkPhase.preparing,
      );
      run = agent.prompt(promptMessage);
      runAgent = agent;
      _preparingRun = false;
      await _draftController.consumePendingResources(attachedResources);
    } catch (e) {
      _preparingRun = false;
      if (ownsRun && run == null) {
        _activePermissionMode = null;
        _activeAgentSettings = null;
        _activeRoute = null;
      }
      state = state.copyWith(error: e.toString());
      if (ownsRun && run == null && _settingsApplyPending) {
        _queueSettingsRefresh();
      }
    } finally {
      if (!dispatchDone.isCompleted) dispatchDone.complete();
    }

    if (run == null || runAgent == null) return;
    try {
      await run;
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      _activePermissionMode = null;
      _activeAgentSettings = null;
      _activeRoute = null;
      if (mounted) {
        state = state.copyWith(
          status: AgentChatRunStatus.idle,
          clearStreamingMessage: true,
          queuedMessages: _queuedMessages(runAgent),
          workPhase: AgentChatWorkPhase.idle,
        );
      }
      if (_settingsApplyPending) _queueSettingsRefresh();
    }
  }

  List<AgentQueuedMessage> _queuedMessages(Agent agent) => [
    for (final entry in agent.steeringQueue)
      AgentQueuedMessage(
        kind: AgentQueuedMessageKind.steering,
        id: entry.id,
        message: entry.message,
      ),
    for (final entry in agent.followUpQueue)
      AgentQueuedMessage(
        kind: AgentQueuedMessageKind.followUp,
        id: entry.id,
        message: entry.message,
      ),
  ];

  AgentMessage? removeQueuedMessage(AgentQueuedMessage queued) {
    final agent = _sessionController.agent;
    if (agent == null) return null;
    final message = switch (queued.kind) {
      AgentQueuedMessageKind.steering => agent.removeSteeringById(queued.id),
      AgentQueuedMessageKind.followUp => agent.removeFollowUpById(queued.id),
    };
    state = state.copyWith(queuedMessages: _queuedMessages(agent));
    return message;
  }

  void clearQueuedMessages() {
    final agent = _sessionController.agent;
    if (agent == null) return;
    agent.clearAllQueues();
    state = state.copyWith(queuedMessages: const []);
  }

  /// 组装用户消息：文本在前，图片附件随后（与 agent.prompt 的
  /// 字符串+images 归一化结果一致）。
  UserMessage _buildUserMessage(String text, List<ImageContent>? images) {
    final content = <UserContent>[
      if (text.isNotEmpty) UserTextContent(text),
      if (images != null)
        for (final image in images) UserImageContent(image),
    ];
    return UserMessage(content: content);
  }

  /// 关闭错误提示条。
  void dismissError() {
    state = state.copyWith(error: '');
  }

  Future<void> abort() async {
    final agent = _sessionController.agent;
    if (agent == null) {
      return;
    }
    state = state.copyWith(workPhase: AgentChatWorkPhase.stopping);
    agent.abort();
    _permissionController?.cancelApproval();
    _client.cancel('agent_chat');
    await agent.waitForIdle();
  }

  /// 手动 compaction。
  Future<void> compactNow() async {
    final agent = _sessionController.agent;
    if (agent == null || state.status == AgentChatRunStatus.running) {
      return;
    }
    final compressed = await _maybeCompactContext(
      List.of(agent.state.messages),
      null,
      force: true,
    );
    if (compressed != null) {
      agent.state.messages = List.of(compressed);
      state = state.copyWith(messages: List.of(compressed));
    }
  }

  Future<void> _handleEvent(AgentEvent event, AbortSignal signal) =>
      _eventController.handle(event, signal);

  @override
  void dispose() {
    _permissionController?.dispose();
    _sessionControllerValue?.agent?.clearAllQueues();
    super.dispose();
  }
}
