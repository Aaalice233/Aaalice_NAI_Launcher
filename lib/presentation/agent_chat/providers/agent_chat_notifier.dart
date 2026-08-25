import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/agent/agent.dart';
import '../../../core/agent/harness/compaction/compaction.dart';
import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/harness/session/session_context.dart';
import '../../../core/agent/harness/session/session_jsonl.dart';
import '../../../core/agent/harness/session/session.dart';
import '../../../core/agent/harness/session/session_types.dart'
    as session_types;
import '../../../core/agent/harness/skills.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../prompt_assistant/models/agent_protocol.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../prompt_assistant/services/provider_adapters/anthropic_messages_adapter.dart';
import '../../prompt_assistant/services/provider_adapters/gemini_generate_content_adapter.dart';
import '../../prompt_assistant/services/provider_adapters/openai_chat_completions_adapter.dart';
import '../../prompt_assistant/services/provider_adapters/openai_responses_adapter.dart';
import '../../prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';
import '../../prompt_assistant/services/prompt_assistant_service.dart';
import '../services/agent_stream_bridge.dart';
import '../services/execution_toolbox.dart';
import '../services/generation_toolbox.dart';
import '../services/prompt_toolbox.dart';
import '../services/tag_toolbox.dart';
import 'agent_chat_session_view.dart';

/// Agent 会话 UI 状态。
class AgentChatState {
  const AgentChatState({
    this.initialized = false,
    this.status = AgentChatRunStatus.idle,
    this.messages = const [],
    this.streamingText = '',
    this.activities = const [],
    this.queuedCount = 0,
    this.sessions = const [],
    this.activeSessionId = '',
    this.skills = const [],
    this.routeLabel = '',
    this.routeReady = false,
    this.routeError = '',
    this.error = '',
    this.compacting = false,
    this.totalUsage,
  });

  final bool initialized;
  final AgentChatRunStatus status;

  /// 当前会话转录（user/assistant/toolResult）。
  final List<Message> messages;
  final String streamingText;
  final List<AgentToolActivity> activities;
  final int queuedCount;
  final List<AgentChatSessionSummary> sessions;
  final String activeSessionId;
  final List<HarnessSkill> skills;
  final String routeLabel;
  final bool routeReady;
  final String routeError;
  final String error;
  final bool compacting;
  final Usage? totalUsage;

  AgentChatState copyWith({
    bool? initialized,
    AgentChatRunStatus? status,
    List<Message>? messages,
    String? streamingText,
    List<AgentToolActivity>? activities,
    int? queuedCount,
    List<AgentChatSessionSummary>? sessions,
    String? activeSessionId,
    List<HarnessSkill>? skills,
    String? routeLabel,
    bool? routeReady,
    String? routeError,
    String? error,
    bool? compacting,
    Usage? totalUsage,
  }) {
    return AgentChatState(
      initialized: initialized ?? this.initialized,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      streamingText: streamingText ?? this.streamingText,
      activities: activities ?? this.activities,
      queuedCount: queuedCount ?? this.queuedCount,
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      skills: skills ?? this.skills,
      routeLabel: routeLabel ?? this.routeLabel,
      routeReady: routeReady ?? this.routeReady,
      routeError: routeError ?? this.routeError,
      error: error ?? this.error,
      compacting: compacting ?? this.compacting,
      totalUsage: totalUsage ?? this.totalUsage,
    );
  }
}

enum AgentChatRunStatus { idle, running }

/// 工具执行卡片状态。
class AgentToolActivity {
  const AgentToolActivity({
    required this.toolCallId,
    required this.toolName,
    required this.args,
    this.status = AgentToolActivityStatus.running,
    this.content = '',
  });

  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> args;
  final AgentToolActivityStatus status;
  final String content;

  AgentToolActivity copyWith({
    AgentToolActivityStatus? status,
    String? content,
  }) {
    return AgentToolActivity(
      toolCallId: toolCallId,
      toolName: toolName,
      args: args,
      status: status ?? this.status,
      content: content ?? this.content,
    );
  }
}

enum AgentToolActivityStatus { running, succeeded, failed }

/// Agent HTTP 请求分发。
class AgentApiClient {
  AgentApiClient(this._dio);

  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  void cancel(String sessionId) {
    final token = _cancelTokens.remove(sessionId);
    token?.cancel('cancelled by user');
  }

  PromptAssistantProviderAdapter _adapterFor(ProviderConfig provider) {
    switch (provider.protocol) {
      case ProviderProtocol.openaiChatCompletions:
        return const OpenAiChatCompletionsAdapter();
      case ProviderProtocol.openaiResponses:
        return const OpenAiResponsesAdapter();
      case ProviderProtocol.anthropicMessages:
        return const AnthropicMessagesAdapter();
      case ProviderProtocol.geminiGenerateContent:
        return const GeminiGenerateContentAdapter();
      case ProviderProtocol.ollamaChatCompletions:
        return const OpenAiChatCompletionsAdapter(ollamaTagsFallback: true);
    }
  }

  Stream<AgentWireEvent> complete(
    AgentChatRequest request, {
    String cancelSessionId = 'agent_chat',
  }) {
    _cancelTokens.remove(cancelSessionId)?.cancel('replaced by new request');
    final cancelToken = CancelToken();
    _cancelTokens[cancelSessionId] = cancelToken;
    return _adapterFor(
      request.provider,
    ).completeAgent(dio: _dio, request: request, cancelToken: cancelToken);
  }
}

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
  AgentChatNotifier(this._ref, {List<HarnessSkill>? presetSkills})
    : super(const AgentChatState()) {
    _init(presetSkills: presetSkills);
  }

  final Ref _ref;
  late Directory _supportDir;
  late Directory _workspaceDir;
  late JsonlSessionRepo _repo;
  late AgentApiClient _client;
  Agent? _agent;
  dynamic _session;
  final Map<String, HarnessSkill> _skills = {};
  (ProviderConfig, String, String?)? _routeCache;
  Usage _usageTotal = const Usage();

  LocalStorageService get _local => _ref.read(localStorageServiceProvider);

  Future<void> _init({List<HarnessSkill>? presetSkills}) async {
    try {
      _supportDir = await getApplicationSupportDirectory();
    } catch (e) {
      AppLogger.w('agent chat init failed: $e', 'AgentChat');
      _supportDir = Directory.systemTemp;
    }
    _repo = JsonlSessionRepo(_supportDir);
    // 文件工具工作区（read 的 cwd 与相对路径根）。
    // 默认指向图片导出根目录（自定义保存路径或 Documents/NAI_Launcher/
    // images），让 Agent 能直接按相对路径读取生成的图片；解析失败时
    // 回退到应用支持目录下的 agent/workspace。
    Directory? workspaceDir;
    try {
      final exportRoot = await GalleryFolderRepository.instance.getRootPath();
      if (exportRoot != null && exportRoot.isNotEmpty) {
        workspaceDir = Directory(exportRoot);
      }
    } catch (e) {
      AppLogger.w('resolve image export dir failed: $e', 'AgentChat');
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

    if (presetSkills != null) {
      for (final skill in presetSkills) {
        _skills[skill.name] = skill;
      }
    } else {
      try {
        // 代理 目录发现规则：~/.pi/agent/skills、~/.agents/skills、
        // 项目 .pi/skills（cwd 向上至 git 根）+ 应用托管目录。
        final env = DartIoExecutionEnv();
        final home =
            Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        final appSkills = Directory(
          '${_supportDir.path}${Platform.pathSeparator}agent'
          '${Platform.pathSeparator}skills',
        );
        final dirs = <({String path, String source})>[
          (path: appSkills.path, source: 'app'),
          if (home != null) ...[
            (
              path:
                  '$home${Platform.pathSeparator}.pi${Platform.pathSeparator}agent'
                  '${Platform.pathSeparator}skills',
              source: 'user',
            ),
            (
              path:
                  '$home${Platform.pathSeparator}.agents'
                  '${Platform.pathSeparator}skills',
              source: 'user',
            ),
          ],
        ];
        final loaded = await loadSourcedSkills<String>(env, dirs);
        for (final item in loaded.skills) {
          final skill = item.skill;
          _skills.putIfAbsent(skill.name, () => skill);
        }
      } catch (e) {
        AppLogger.w('agent skills load failed: $e', 'AgentChat');
      }
    }

    _client = AgentApiClient(_ref.read(promptAssistantDioProvider));
    _refreshRoute();
    await _restoreLastSession();
    state = state.copyWith(
      initialized: true,
      skills: _skills.values.toList(growable: false),
    );
  }

  Future<Agent> _buildAgent() async {
    final agent = Agent(
      AgentOptions(
        streamFn: _streamFn,
        initialSystemPrompt: await _buildSystemPrompt(),
        // 提示词工具（含 read_skill）+ 只读文件工具 + 生成/反推/队列工具
        // + 标签检索工具。
        initialTools: [
          ...PromptToolbox(_ref, skills: _skills).tools(),
          ...ExecutionToolbox(_workspaceDir.path).tools(),
          ...GenerationToolbox(_ref).tools(),
          ...TagToolbox(_ref).tools(),
        ],
        convertToLlm: (messages) async => messages
            .where(
              (m) =>
                  m.role == 'user' ||
                  m.role == 'assistant' ||
                  m.role == 'toolResult' ||
                  m.role == 'bashExecution' ||
                  m.role == 'custom' ||
                  m.role == 'branchSummary' ||
                  m.role == 'compactionSummary',
            )
            .toList(),
        transformContext: (messages, signal) async =>
            await _maybeCompactContext(messages, signal) ?? messages,
      ),
    );
    agent.subscribe(_handleEvent);
    return agent;
  }

  /// 代理 compaction：上下文超阈值时折叠旧消息为摘要消息
  /// （消息空间实现。
  /// [returnResult] 为 true 时返回压缩结果而不只是变换列表。
  Future<List<AgentMessage>?> _maybeCompactContext(
    List<AgentMessage> messages,
    AbortSignal? signal, {
    bool returnResult = false,
  }) async {
    try {
      final route = _routeCache ?? _resolveRoute();
      if (route == null || messages.length <= 8) {
        return messages;
      }
      final contextWindow = _contextWindowFor(route.$1);
      final estimate = estimateContextTokens(messages);
      const settings = defaultCompactionSettings;
      if (!shouldCompact(estimate.tokens, contextWindow, settings)) {
        return messages;
      }

      state = state.copyWith(compacting: true);
      // 消息空间 → 条目空间（compaction 需要会话条目）。
      final entries = <session_types.SessionEntry>[
        for (var i = 0; i < messages.length; i++)
          session_types.MessageEntry(id: 'v$i', message: messages[i]),
      ];
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
      // 摘要消息 + 保留尾部（消息空间）。
      return [
        CompactionSummaryMessage(
          summary: compactResult.summary,
          tokensBefore: compactResult.tokensBefore,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
        ...compactResult.retainedTail,
      ];
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
      final route = _routeCache;
      if (route == null) {
        return _errorStream('No LLM provider configured for chat.');
      }
      final request = AgentChatRequest(
        sessionId: 'agent_chat',
        provider: route.$1,
        model: route.$2,
        systemPrompt: context.systemPrompt,
        messages: context.messages,
        tools: [
          for (final tool in context.tools ?? const <Tool>[])
            Tool(
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters,
            ),
        ],
        apiKey: route.$3,
        maxOutputTokens: options?.maxTokens,
      );
      final wireEvents = _client.complete(request);
      final signal = options?.signal;
      if (signal is AbortSignal) {
        signal.addListener((_) => _client.cancel('agent_chat'));
      }
      return agentWireEventStream(wireEvents);
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
    final routedProviderId = config.routing.providerIdFor(
      AssistantTaskType.chat,
    );
    final routedModel = config.routing.modelFor(AssistantTaskType.chat);
    final provider = enabled.firstWhere(
      (p) => p.id == routedProviderId,
      orElse: () => enabled.first,
    );
    final models = config.modelsForProviderTask(
      providerId: provider.id,
      taskType: AssistantTaskType.chat,
    );
    final realModels = models.where((m) => !m.isPlaceholder).toList();
    var model = routedModel.trim();
    final isPlaceholder = model.isEmpty || model == 'default-model';
    if (isPlaceholder && realModels.isNotEmpty) {
      model = realModels.first.name;
    } else if (!isPlaceholder && !models.any((m) => m.name == model)) {
      model = realModels.isNotEmpty ? realModels.first.name : model;
    }
    if (model.isEmpty) {
      model = provider.preset?.defaultModelNames.firstOrNull ?? '';
    }
    if (model.isEmpty) {
      return null;
    }
    return (provider, model, null);
  }

  int _contextWindowFor(ProviderConfig provider) {
    switch (provider.preset) {
      case ProviderPreset.anthropic:
        return 200000;
      case ProviderPreset.gemini:
        return 1000000;
      case ProviderPreset.openaiChat:
      case ProviderPreset.openaiResponses:
      case ProviderPreset.openaiCompatibleChat:
      case ProviderPreset.openaiCompatibleResponses:
        return 128000;
      case ProviderPreset.deepseek:
        return 64000;
      case ProviderPreset.ollama:
      case ProviderPreset.lmStudioChat:
      case ProviderPreset.lmStudioResponses:
        return 8192;
      case ProviderPreset.pollinations:
        return 32000;
      case null:
        return 32768;
    }
  }

  Future<String> _buildSystemPrompt() async {
    // 路由缓存 + API Key 解析（短期 token 每次运行刷新）。
    final route = _routeCache ?? _resolveRoute();
    if (route != null) {
      final apiKey = await _ref
          .read(promptAssistantConfigProvider.notifier)
          .getProviderApiKey(route.$1.id);
      _routeCache = (route.$1, route.$2, apiKey);
    }
    final workspacePath = _workspaceDir.path;
    final skillBlock = formatSkillsForSystemPrompt(
      _skills.values.toList(growable: false),
    );
    return [
      'You are the AI agent inside Aaalice, a NovelAI image-generation client.',
      'You chat with the user and edit their image prompts via tools.',
      '',
      'Tools:',
      '- Call get_prompt_state first to inspect the workspace before editing.',
      '- set_positive_prompt / set_negative_prompt write the main prompts '
          '(mode: replace, append, prepend).',
      '- add_character creates a character; update_character edits an '
          'existing one (match by id or name, only provided fields change). '
          'Set "enabled" to false to temporarily exclude a character from '
          'generation while keeping it in the list, and true to include it '
          'again. remove_character deletes it permanently.',
      '- All edits apply immediately and are visible to the user in the UI.',
      '',
      'File tools:',
      '- read works inside the image export root: $workspacePath '
          '(relative paths resolve against it). Generated images are '
          'auto-saved there in dated subfolders (e.g. 2026-08-25/), so you '
          'can read exported images by relative path; generate_image and '
          'get_generation_status also return absolute paths.',
      '- Use it for prompt drafts, exports, and reading skill files when a '
          'skill references them.',
      '',
      'Image tools:',
      '- interrogate_image reverse-engineers a prompt from an image file. '
          'It uses the chat model directly when image input is supported; '
          'the dedicated "reverse" vision model is only a fallback.',
      '- generate_image is the default way to create images: count maps to '
          'the app generation count (no upper limit), and source_image / '
          'mask_image switch to img2img / inpaint. It returns saved file '
          'paths plus thumbnails; when the generation page is busy it waits '
          'and runs in order automatically.',
      '- queue_image_task adds tasks to the generation queue; use it when '
          'the user asks for queueing. Queue outputs do not appear '
          'automatically — when the queue finishes, call get_recent_images '
          'to show them in the chat.',
      '- get_generation_status reports generation progress, queue stats, '
          'and recent output paths.',
      '- get_recent_images shows recently generated images (including '
          'queue results) as thumbnails in the conversation.',
      '- get_generation_settings / update_generation_settings read and '
          'change model, sampler, steps, scale and other page settings. '
          'When the user names a model ("use V5", "switch to v4.5 '
          'curated"), pass that friendly name to update_generation_settings '
          '— it resolves aliases. For transparent-background requests '
          'toggle the transparent_background switch there (V5 renders '
          'native alpha), optionally reinforced with the prompt tags.',
      '- search_tags looks up danbooru tags as a reference (English fuzzy '
          'search, Chinese translation, co-occurrence suggestions); newer '
          'models also understand natural language, so use whichever fits.',
      '- Generated images appear as thumbnails in this chat automatically; '
          'the user can expand them to view the full image.',
      '',
      'Prompt conventions:',
      '- Prompts are English danbooru tags separated by commas, important '
          'tags first. NEVER use (tag:1.2) — that is Stable Diffusion '
          'syntax and does nothing in NovelAI.',
      '- Emphasis: {tag} strengthens and [tag] weakens on every model '
          '(each bracket ~1.05x). Numeric emphasis like 1.3::tag :: is '
          'V4+ only; negative numeric emphasis like -1::tag :: (removes or '
          'inverts a concept) is V4.5+ only. On V3 use braces only.',
      '- Natural language: V4/V4.5 understand plain English sentences '
          'mixed with tags; V5 understands natural language best of all — '
          'for complex scenes prefer describing the picture in English '
          'sentences, tags stay fully supported. V3 is tags-only and '
          'weights tags near the start more heavily.',
      '- Character prompts exist only on V4+: put per-character appearance '
          'and actions in the character list via add_character, never into '
          'the main prompt. V4.5 supports up to 6 characters with '
          'interaction tags source# / target# / mutual#; V5 allows many '
          'more (20+) with free canvas positioning.',
      '- V4/V4.5 share a ~512 T5 token budget across base + character '
          'prompts; V5 allows noticeably longer prompts. Avoid emoji / '
          'non-ASCII in V4 prompts.',
      '- V5 extras: native alpha transparency — prompt "transparent '
          'background", "has alpha" or "alpha transparency" (strengthen '
          'like 2.1::transparent background:: if weak); multi-language '
          'prompting (officially English + Japanese, Chinese usually '
          'works); multi-language text rendering via a "Text: ..." block '
          'at the very end of the prompt; whole comic-page layouts can be '
          'described in natural language.',
      '- The app can auto-append quality tags and the negative preset '
          '(quality_toggle / uc_preset settings); do not add quality or '
          'aesthetic tags manually unless the user asks. V4.5+ reference '
          'tags: masterpiece, very aesthetic, location, year 2025.',
      if (skillBlock.isNotEmpty) ...['', skillBlock],
      '',
      "Reply in the user's language. Be concise. After using tools, briefly "
          'confirm what you changed. Do not invent tools that are not listed.',
    ].join('\n');
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
      );
      return;
    }
    state = state.copyWith(
      routeReady: true,
      routeLabel: '${_routeCache!.$1.name} / ${_routeCache!.$2}',
      routeError: '',
    );
  }

  // -------------------------------------------------------------------------
  // 会话管理
  // -------------------------------------------------------------------------

  Future<void> _restoreLastSession() async {
    final sessions = await _listSessions();
    final savedId = _local.getSetting<String>(
      StorageKeys.agentChatActiveSession,
    );
    final target = sessions.any((s) => s.metadata.id == savedId)
        ? savedId!
        : sessions.isNotEmpty
        ? sessions.first.metadata.id
        : '';
    if (target.isEmpty) {
      await newSession();
      return;
    }
    await _activateSession(target);
  }

  Future<List<AgentChatSessionSummary>> _listSessions() async {
    try {
      final raw = await _repo.listWithNames();
      return [
        for (final (metadata, name) in raw)
          AgentChatSessionSummary(
            metadata: metadata,
            name: name,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(metadata.createdAt),
          ),
      ];
    } catch (e) {
      AppLogger.w('list sessions failed: $e', 'AgentChat');
      return const [];
    }
  }

  Future<void> _activateSession(String sessionId) async {
    final metadata = (await _repo.list()).firstWhere(
      (m) => m.id == sessionId,
      orElse: () => session_types.SessionMetadata(
        id: sessionId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    Session session;
    try {
      session = await _repo.open(metadata);
    } catch (_) {
      session = await _repo.create(
        session_types.SessionCreateOptions(id: sessionId),
      );
    }
    _session = session;
    // 重建 Agent（每次会话独立转录）。
    await _agent?.waitForIdle();
    _agent = null;
    _agent = await _buildAgent();
    // 从 Session 树恢复转录（含 compaction 折叠语义）。
    final entries = await session.findEntriesOnBranch(
      const session_types.EntryQuery(
        order: session_types.EntryOrder.oldestFirst,
      ),
    );
    final context = buildSessionContext(entries);
    _agent!.state.messages = context.messages;
    _agent!.setSystemPrompt(await _buildSystemPrompt());

    await _local.setSetting(StorageKeys.agentChatActiveSession, sessionId);
    state = state.copyWith(
      activeSessionId: sessionId,
      messages: List.of(context.messages),
      activities: const [],
      streamingText: '',
      error: '',
      queuedCount: 0,
      sessions: await _listSessions(),
    );
  }

  Future<void> newSession() async {
    final session = await _repo.create();
    final metadata = await session.getMetadata();
    await _activateSession(metadata.id);
  }

  Future<void> switchSession(String sessionId) async {
    await _activateSession(sessionId);
  }

  /// 删除指定会话；删除当前会话时自动切到最近剩余会话（无则新建）。
  Future<void> deleteSession(String sessionId) async {
    if (sessionId.isEmpty) {
      return;
    }
    // 直接按 id 删文件，不依赖列表匹配（避免表头解析失败导致删不掉）。
    _repo.deleteById(sessionId);
    if (sessionId != state.activeSessionId) {
      state = state.copyWith(sessions: await _listSessions());
      return;
    }
    final remaining = (await _listSessions())
        .where((s) => s.id != sessionId)
        .toList();
    if (remaining.isNotEmpty) {
      await _activateSession(remaining.first.id);
    } else {
      await newSession();
    }
  }

  /// 重命名会话（持久化 name 记录，列表即时刷新）。
  Future<void> renameSession(String sessionId, String name) async {
    final trimmed = name.trim();
    if (sessionId.isEmpty || trimmed.isEmpty) {
      return;
    }
    try {
      final metadata = (await _repo.list()).firstWhere(
        (m) => m.id == sessionId,
      );
      final session = await _repo.open(metadata);
      await session.setName(trimmed);
      state = state.copyWith(sessions: await _listSessions());
    } catch (e) {
      AppLogger.w('rename session failed: $e', 'AgentChat');
    }
  }

  /// 切换聊天模型：写入 chat 任务路由并持久化，随后刷新本地路由缓存。
  Future<void> selectChatModel(String providerId, String model) async {
    if (providerId.isEmpty || model.isEmpty) {
      return;
    }
    final config = _ref.read(promptAssistantConfigProvider);
    if (!config.providers.any((p) => p.id == providerId && p.enabled)) {
      return;
    }
    await _ref
        .read(promptAssistantConfigProvider.notifier)
        .setRouting(
          config.routing.copyWithTask(
            taskType: AssistantTaskType.chat,
            providerId: providerId,
            model: model,
          ),
        );
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
  Future<void> sendContent(List<UserContent> content) async {
    final normalized = <UserContent>[
      for (final block in content)
        if (block is! UserTextContent || block.text.trim().isNotEmpty) block,
    ];
    if (normalized.isEmpty) {
      return;
    }
    await _sendMessage(UserMessage(content: normalized));
  }

  Future<void> _sendMessage(UserMessage message) async {
    final agent = _agent;
    if (agent == null || !state.routeReady) {
      _refreshRoute();
      state = state.copyWith(
        error: state.routeError.isNotEmpty
            ? state.routeError
            : 'No LLM provider configured. Open Settings to add one.',
      );
      return;
    }
    _refreshRoute();
    agent.setSystemPrompt(await _buildSystemPrompt());

    if (state.status == AgentChatRunStatus.running) {
      agent.steer(message);
      state = state.copyWith(queuedCount: _queuedCount(agent));
      return;
    }
    state = state.copyWith(
      status: AgentChatRunStatus.running,
      error: '',
      activities: const [],
      streamingText: '',
    );
    try {
      await agent.prompt(message);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      if (mounted) {
        state = state.copyWith(
          status: AgentChatRunStatus.idle,
          streamingText: '',
          queuedCount: _queuedCount(agent),
        );
      }
    }
  }

  int _queuedCount(Agent agent) => agent.hasQueuedMessages() ? 1 : 0;

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

  /// 会话自动命名：首条用户消息入库后，以其文本派生会话名并持久化
  /// （对未命名会话仅生效一次）。
  Future<void> _autoNameSession(Message message) async {
    final session = _session;
    if (session == null || message is! UserMessage) {
      return;
    }
    try {
      final existing = await session.getName();
      if (existing != null && existing.trim().isNotEmpty) {
        return;
      }
      final normalized = message.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isEmpty) {
        return;
      }
      final name = normalized.length <= 40
          ? normalized
          : '${normalized.substring(0, 40)}…';
      await session.setName(name);
      state = state.copyWith(sessions: await _listSessions());
    } catch (e) {
      AppLogger.w('auto name session failed: $e', 'AgentChat');
    }
  }

  Future<void> abort() async {
    final agent = _agent;
    if (agent == null) {
      return;
    }
    agent.abort();
    _client.cancel('agent_chat');
    await agent.waitForIdle();
  }

  /// 手动 compaction。
  Future<void> compactNow() async {
    final agent = _agent;
    if (agent == null || state.status == AgentChatRunStatus.running) {
      return;
    }
    final compressed = await _maybeCompactContext(
      List.of(agent.state.messages),
      null,
      returnResult: true,
    );
    if (compressed != null) {
      agent.state.messages = List.of(compressed);
      state = state.copyWith(messages: List.of(compressed));
    }
  }

  Future<void> _handleEvent(AgentEvent event, AbortSignal signal) async {
    if (!mounted) {
      return;
    }
    switch (event) {
      case AgentEventMessageStart():
        if (event.message is AssistantMessage) {
          state = state.copyWith(streamingText: '');
        }
      case AgentEventMessageUpdate():
        final evt = event.assistantMessageEvent;
        if (evt is AmTextDelta) {
          state = state.copyWith(streamingText: evt.partial.text);
        }
      case AgentEventMessageEnd():
        final message = event.message;
        // 先同步追加到转录（保证 UI 顺序与事件顺序一致），再异步持久化。
        // 同时清空流式文本：消息已固化到消息流，live 区继续显示会造成
        // 同一段文字重复出现（工具结果之后尤为明显）。
        state = state.copyWith(
          messages: [...state.messages, message],
          streamingText: '',
        );
        await _persistMessage(message);
        if (message is UserMessage) {
          await _autoNameSession(message);
        }
        if (message is AssistantMessage && message.usage != null) {
          _usageTotal = _usageTotal + message.usage!;
          state = state.copyWith(totalUsage: _usageTotal);
        }
      case AgentEventToolExecutionStart():
        final args = event.args;
        state = state.copyWith(
          activities: [
            ...state.activities,
            AgentToolActivity(
              toolCallId: event.toolCallId,
              toolName: event.toolName,
              args: args is Map<String, dynamic> ? args : const {},
            ),
          ],
        );
      case AgentEventToolExecutionUpdate():
        final partial = event.partialResult;
        final preview = partial.content
            .whereType<ToolResultTextContent>()
            .map((c) => c.text)
            .join();
        state = state.copyWith(
          activities: [
            for (final activity in state.activities)
              activity.toolCallId == event.toolCallId
                  ? activity.copyWith(content: preview)
                  : activity,
          ],
        );
      case AgentEventToolExecutionEnd():
        state = state.copyWith(
          activities: [
            for (final activity in state.activities)
              activity.toolCallId == event.toolCallId
                  ? activity.copyWith(
                      status: event.isError
                          ? AgentToolActivityStatus.failed
                          : AgentToolActivityStatus.succeeded,
                      content: _resultPreview(event.result),
                    )
                  : activity,
          ],
        );
      case AgentEventAgentEnd():
        // 运行结束：活动卡片已固化为消息流中的工具结果，清空避免重复。
        state = state.copyWith(
          activities: const [],
          sessions: await _listSessions(),
          queuedCount: _agent == null ? 0 : _queuedCount(_agent!),
        );
      case AgentEventTurnEnd():
        final message = event.message;
        if (message is AssistantMessage &&
            message.errorMessage != null &&
            message.stopReason == StopReason.error) {
          state = state.copyWith(error: message.errorMessage);
        }
      default:
        break;
    }
  }

  String _resultPreview(AgentToolResult result) {
    return result.content
        .whereType<ToolResultTextContent>()
        .map((c) => c.text)
        .join();
  }

  Future<void> _persistMessage(Message message) async {
    final session = _session;
    if (session == null) {
      return;
    }
    try {
      if (message is AssistantMessage &&
          message.stopReason == StopReason.aborted) {
        // 中止消息仍持久化（代理 会话保留部分结果）。
      }
      await session.appendMessage(message);
    } catch (e) {
      AppLogger.w('persist message failed: $e', 'AgentChat');
    }
  }

  @override
  void dispose() {
    _agent?.clearAllQueues();
    super.dispose();
  }
}
