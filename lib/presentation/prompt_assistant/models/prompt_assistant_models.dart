import 'dart:convert';

enum AssistantTaskType {
  llm,
  translate,
  reverse,
  characterReplace,
  custom,
  chat,
}

/// Agent 工具权限。除 [fullAccess] 外，文件访问始终限制在 Agent 工作区内。
enum AgentPermissionMode {
  safe,
  askBeforeSensitiveActions,
  fullAccess;

  static AgentPermissionMode fromName(String? value) =>
      AgentPermissionMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => AgentPermissionMode.askBeforeSensitiveActions,
      );
}

extension AssistantTaskTypeLabel on AssistantTaskType {
  String get label {
    switch (this) {
      case AssistantTaskType.llm:
        return 'Optimize';
      case AssistantTaskType.translate:
        return 'Translate';
      case AssistantTaskType.reverse:
        return 'Reverse Prompt';
      case AssistantTaskType.characterReplace:
        return 'Character Replace';
      case AssistantTaskType.custom:
        return 'Custom';
      case AssistantTaskType.chat:
        return 'Chat';
    }
  }
}

// Legacy storage/UI type. New code should prefer ProviderProtocol and
// ProviderPreset, but this remains to decode existing saved configs.
enum ProviderType { pollinations, openaiCompatible, ollama }

enum ProviderProtocol {
  openaiChatCompletions,
  openaiResponses,
  anthropicMessages,
  geminiGenerateContent,
  ollamaChatCompletions,
}

extension ProviderProtocolLabel on ProviderProtocol {
  String get label {
    switch (this) {
      case ProviderProtocol.openaiChatCompletions:
        return 'OpenAI Chat Completions';
      case ProviderProtocol.openaiResponses:
        return 'OpenAI Responses';
      case ProviderProtocol.anthropicMessages:
        return 'Anthropic Messages';
      case ProviderProtocol.geminiGenerateContent:
        return 'Gemini generateContent';
      case ProviderProtocol.ollamaChatCompletions:
        return 'Ollama Chat Completions';
    }
  }

  bool get supportsModelList => true;

  bool get supportsImagePayload {
    switch (this) {
      case ProviderProtocol.openaiChatCompletions:
      case ProviderProtocol.openaiResponses:
      case ProviderProtocol.anthropicMessages:
      case ProviderProtocol.geminiGenerateContent:
        return true;
      case ProviderProtocol.ollamaChatCompletions:
        return false;
    }
  }
}

enum ProviderPreset {
  openaiChat,
  openaiResponses,
  openaiCompatibleChat,
  openaiCompatibleResponses,
  anthropic,
  gemini,
  deepseek,
  lmStudioChat,
  lmStudioResponses,
  ollama,
  pollinations,
}

extension ProviderPresetDefaults on ProviderPreset {
  String get label {
    switch (this) {
      case ProviderPreset.openaiChat:
        return 'OpenAI Chat Completions';
      case ProviderPreset.openaiResponses:
        return 'OpenAI Responses';
      case ProviderPreset.openaiCompatibleChat:
        return 'OpenAI-compatible Chat';
      case ProviderPreset.openaiCompatibleResponses:
        return 'OpenAI-compatible Responses';
      case ProviderPreset.anthropic:
        return 'Anthropic';
      case ProviderPreset.gemini:
        return 'Gemini';
      case ProviderPreset.deepseek:
        return 'DeepSeek';
      case ProviderPreset.lmStudioChat:
        return 'LM Studio Chat';
      case ProviderPreset.lmStudioResponses:
        return 'LM Studio Responses';
      case ProviderPreset.ollama:
        return 'Ollama';
      case ProviderPreset.pollinations:
        return 'Pollinations';
    }
  }

  String get defaultId {
    switch (this) {
      case ProviderPreset.openaiChat:
        return 'openai_chat';
      case ProviderPreset.openaiResponses:
        return 'openai_responses';
      case ProviderPreset.openaiCompatibleChat:
        return 'openai_compatible_chat';
      case ProviderPreset.openaiCompatibleResponses:
        return 'openai_compatible_responses';
      case ProviderPreset.anthropic:
        return 'anthropic';
      case ProviderPreset.gemini:
        return 'gemini';
      case ProviderPreset.deepseek:
        return 'deepseek';
      case ProviderPreset.lmStudioChat:
        return 'lmstudio_chat';
      case ProviderPreset.lmStudioResponses:
        return 'lmstudio_responses';
      case ProviderPreset.ollama:
        return 'ollama';
      case ProviderPreset.pollinations:
        return 'pollinations';
    }
  }

  String get defaultName {
    switch (this) {
      case ProviderPreset.openaiChat:
        return 'OpenAI Chat';
      case ProviderPreset.openaiResponses:
        return 'OpenAI Responses';
      case ProviderPreset.openaiCompatibleChat:
        return 'OpenAI Compatible Chat';
      case ProviderPreset.openaiCompatibleResponses:
        return 'OpenAI Compatible Responses';
      case ProviderPreset.anthropic:
        return 'Anthropic';
      case ProviderPreset.gemini:
        return 'Gemini';
      case ProviderPreset.deepseek:
        return 'DeepSeek';
      case ProviderPreset.lmStudioChat:
        return 'LM Studio Chat';
      case ProviderPreset.lmStudioResponses:
        return 'LM Studio Responses';
      case ProviderPreset.ollama:
        return 'Ollama';
      case ProviderPreset.pollinations:
        return 'pollinations.ai';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case ProviderPreset.openaiChat:
      case ProviderPreset.openaiResponses:
        return 'https://api.openai.com/v1';
      case ProviderPreset.openaiCompatibleChat:
      case ProviderPreset.openaiCompatibleResponses:
        return '';
      case ProviderPreset.anthropic:
        return 'https://api.anthropic.com';
      case ProviderPreset.gemini:
        return 'https://generativelanguage.googleapis.com';
      case ProviderPreset.deepseek:
        return 'https://api.deepseek.com';
      case ProviderPreset.lmStudioChat:
      case ProviderPreset.lmStudioResponses:
        return 'http://localhost:1234/v1';
      case ProviderPreset.ollama:
        return 'http://127.0.0.1:11434/v1';
      case ProviderPreset.pollinations:
        return 'https://gen.pollinations.ai';
    }
  }

  ProviderProtocol get defaultProtocol {
    switch (this) {
      case ProviderPreset.openaiChat:
      case ProviderPreset.openaiCompatibleChat:
      case ProviderPreset.deepseek:
      case ProviderPreset.lmStudioChat:
      case ProviderPreset.pollinations:
        return ProviderProtocol.openaiChatCompletions;
      case ProviderPreset.openaiResponses:
      case ProviderPreset.openaiCompatibleResponses:
      case ProviderPreset.lmStudioResponses:
        return ProviderProtocol.openaiResponses;
      case ProviderPreset.anthropic:
        return ProviderProtocol.anthropicMessages;
      case ProviderPreset.gemini:
        return ProviderProtocol.geminiGenerateContent;
      case ProviderPreset.ollama:
        return ProviderProtocol.ollamaChatCompletions;
    }
  }

  List<String> get defaultModelNames {
    switch (this) {
      case ProviderPreset.openaiChat:
      case ProviderPreset.openaiResponses:
        return const ['gpt-4.1-mini'];
      case ProviderPreset.anthropic:
        return const ['claude-sonnet-4-20250514'];
      case ProviderPreset.gemini:
        return const ['gemini-2.5-flash'];
      case ProviderPreset.deepseek:
        return const ['deepseek-v4-flash', 'deepseek-v4-pro'];
      case ProviderPreset.pollinations:
        return const ['openai-large'];
      case ProviderPreset.openaiCompatibleChat:
      case ProviderPreset.openaiCompatibleResponses:
      case ProviderPreset.lmStudioChat:
      case ProviderPreset.lmStudioResponses:
      case ProviderPreset.ollama:
        return const [];
    }
  }

  bool get requiresApiKey {
    switch (this) {
      case ProviderPreset.lmStudioChat:
      case ProviderPreset.lmStudioResponses:
      case ProviderPreset.ollama:
      case ProviderPreset.pollinations:
        return false;
      case ProviderPreset.openaiChat:
      case ProviderPreset.openaiResponses:
      case ProviderPreset.openaiCompatibleChat:
      case ProviderPreset.openaiCompatibleResponses:
      case ProviderPreset.anthropic:
      case ProviderPreset.gemini:
      case ProviderPreset.deepseek:
        return true;
    }
  }

  bool get defaultAllowImageInput {
    switch (this) {
      case ProviderPreset.openaiChat:
      case ProviderPreset.openaiResponses:
      case ProviderPreset.openaiCompatibleChat:
      case ProviderPreset.openaiCompatibleResponses:
      case ProviderPreset.anthropic:
      case ProviderPreset.gemini:
      case ProviderPreset.lmStudioChat:
      case ProviderPreset.lmStudioResponses:
        return true;
      case ProviderPreset.deepseek:
      case ProviderPreset.ollama:
      case ProviderPreset.pollinations:
        return false;
    }
  }

  ProviderConfig createConfig({String? id}) {
    final resolvedId = (id == null || id.trim().isEmpty)
        ? defaultId
        : id.trim();
    return ProviderConfig(
      id: resolvedId,
      name: defaultName,
      type: legacyType,
      protocol: defaultProtocol,
      preset: this,
      baseUrl: defaultBaseUrl,
      allowImageInput: defaultAllowImageInput,
      enabled: true,
    );
  }

  ProviderType get legacyType {
    switch (this) {
      case ProviderPreset.pollinations:
        return ProviderType.pollinations;
      case ProviderPreset.ollama:
        return ProviderType.ollama;
      case ProviderPreset.openaiChat:
      case ProviderPreset.openaiResponses:
      case ProviderPreset.openaiCompatibleChat:
      case ProviderPreset.openaiCompatibleResponses:
      case ProviderPreset.anthropic:
      case ProviderPreset.gemini:
      case ProviderPreset.deepseek:
      case ProviderPreset.lmStudioChat:
      case ProviderPreset.lmStudioResponses:
        return ProviderType.openaiCompatible;
    }
  }
}

class ProviderConfig {
  final String id;
  final String name;
  final ProviderType type;
  final ProviderProtocol protocol;
  final ProviderPreset? preset;
  final String baseUrl;
  final bool enabled;
  final bool allowImageInput;

  const ProviderConfig({
    required this.id,
    required this.name,
    this.type = ProviderType.openaiCompatible,
    this.protocol = ProviderProtocol.openaiChatCompletions,
    this.preset,
    required this.baseUrl,
    this.enabled = true,
    this.allowImageInput = false,
  });

  ProviderConfig copyWith({
    String? id,
    String? name,
    ProviderType? type,
    ProviderProtocol? protocol,
    ProviderPreset? preset,
    bool clearPreset = false,
    String? baseUrl,
    bool? enabled,
    bool? allowImageInput,
  }) {
    return ProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      protocol: protocol ?? this.protocol,
      preset: clearPreset ? null : preset ?? this.preset,
      baseUrl: baseUrl ?? this.baseUrl,
      enabled: enabled ?? this.enabled,
      allowImageInput: allowImageInput ?? this.allowImageInput,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'protocol': protocol.name,
    'preset': preset?.name,
    'baseUrl': baseUrl,
    'enabled': enabled,
    'allowImageInput': allowImageInput,
  };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    final type = ProviderType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => ProviderType.openaiCompatible,
    );
    final preset = _decodePreset(json['preset'] as String?);
    final protocol = _decodeProtocol(
      json['protocol'] as String?,
      legacyType: type,
      preset: preset,
    );
    return ProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      protocol: protocol,
      preset: preset ?? _inferPreset(type, json['id'] as String?, protocol),
      baseUrl: json['baseUrl'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      allowImageInput:
          json['allowImageInput'] as bool? ??
          (preset?.defaultAllowImageInput ?? protocol.supportsImagePayload),
    );
  }

  static ProviderPreset? _decodePreset(String? value) {
    if (value == null || value.isEmpty) return null;
    return ProviderPreset.values.cast<ProviderPreset?>().firstWhere(
      (preset) => preset?.name == value,
      orElse: () => null,
    );
  }

  static ProviderProtocol _decodeProtocol(
    String? value, {
    required ProviderType legacyType,
    required ProviderPreset? preset,
  }) {
    if (value != null && value.isNotEmpty) {
      return ProviderProtocol.values.firstWhere(
        (protocol) => protocol.name == value,
        orElse: () => preset?.defaultProtocol ?? _protocolForLegacy(legacyType),
      );
    }
    return preset?.defaultProtocol ?? _protocolForLegacy(legacyType);
  }

  static ProviderProtocol _protocolForLegacy(ProviderType type) {
    switch (type) {
      case ProviderType.pollinations:
      case ProviderType.openaiCompatible:
        return ProviderProtocol.openaiChatCompletions;
      case ProviderType.ollama:
        return ProviderProtocol.ollamaChatCompletions;
    }
  }

  static ProviderPreset? _inferPreset(
    ProviderType type,
    String? id,
    ProviderProtocol protocol,
  ) {
    if (type == ProviderType.pollinations || id == 'pollinations') {
      return ProviderPreset.pollinations;
    }
    if (type == ProviderType.ollama || id == 'ollama') {
      return ProviderPreset.ollama;
    }
    if (id == 'lmstudio' || id == 'lmstudio_chat') {
      return ProviderPreset.lmStudioChat;
    }
    if (id == 'lmstudio_responses') {
      return ProviderPreset.lmStudioResponses;
    }
    if (id == 'deepseek') {
      return ProviderPreset.deepseek;
    }
    if (id == 'anthropic') {
      return ProviderPreset.anthropic;
    }
    if (id == 'gemini') {
      return ProviderPreset.gemini;
    }
    if (id == 'openai_responses') {
      return ProviderPreset.openaiResponses;
    }
    if (id == 'openai' || id == 'openai_chat') {
      return ProviderPreset.openaiChat;
    }
    if (protocol == ProviderProtocol.openaiResponses) {
      return ProviderPreset.openaiCompatibleResponses;
    }
    return ProviderPreset.openaiCompatibleChat;
  }
}

/// 模型条目的来源，用于刷新模型列表时区分“可回收的 API 模型”与
/// “用户/预设手动模型”，避免弃用模型残留，也避免误删手动模型。
enum ModelSource {
  /// 通过供应商 `/models` 接口拉取；刷新时若不在最新列表里可安全清理。
  api,

  /// 用户手动添加，或添加供应商时自动创建的默认/占位模型；刷新时永不删除。
  manual;

  static ModelSource fromName(String? value) => ModelSource.values.firstWhere(
    (source) => source.name == value,
    orElse: () => ModelSource.manual,
  );
}

class ModelConfig {
  final String providerId;
  final String name;
  final String displayName;
  final AssistantTaskType forTask;
  final bool isDefault;

  /// 该模型是自动拉取（[ModelSource.api]）还是手动/默认（[ModelSource.manual]）。
  /// 默认 [ModelSource.manual]：只有明确从接口拉取的路径才标记为 api，
  /// 因此手动、预设、占位、测试构造的模型天然免于被刷新清理。
  final ModelSource source;

  const ModelConfig({
    required this.providerId,
    required this.name,
    required this.displayName,
    required this.forTask,
    this.isDefault = false,
    this.source = ModelSource.manual,
  });

  bool get isPlaceholder =>
      name.trim().isEmpty || name.trim() == 'default-model';

  ModelConfig copyWith({
    String? providerId,
    String? name,
    String? displayName,
    AssistantTaskType? forTask,
    bool? isDefault,
    ModelSource? source,
  }) {
    return ModelConfig(
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      forTask: forTask ?? this.forTask,
      isDefault: isDefault ?? this.isDefault,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'name': name,
    'displayName': displayName,
    'forTask': forTask.name,
    'isDefault': isDefault,
    'source': source.name,
  };

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      providerId: json['providerId'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String? ?? (json['name'] as String),
      forTask: AssistantTaskType.values.firstWhere(
        (t) => t.name == json['forTask'],
        orElse: () => AssistantTaskType.llm,
      ),
      isDefault: json['isDefault'] as bool? ?? false,
      // 来源迁移（关键决策点）：
      // - 新数据带有 'source' 键 → 直接采用。
      // - 旧数据（升级前保存，无该键）→ 按 isDefault 推断：默认/占位模型
      //   视为 manual 永久保留；其余视为 api，让升级后第一次“刷新模型”
      //   就能清掉历史遗留的弃用模型，无需用户手动逐条删除。
      source: json.containsKey('source')
          ? ModelSource.fromName(json['source'] as String?)
          : ((json['isDefault'] as bool? ?? false)
                ? ModelSource.manual
                : ModelSource.api),
    );
  }
}

class TaskRoutingConfig {
  final String llmProviderId;
  final String llmModel;
  final String translateProviderId;
  final String translateModel;
  final String reverseProviderId;
  final String reverseModel;
  final String characterReplaceProviderId;
  final String characterReplaceModel;
  final String customProviderId;
  final String customModel;
  final String chatProviderId;
  final String chatModel;

  const TaskRoutingConfig({
    required this.llmProviderId,
    required this.llmModel,
    required this.translateProviderId,
    required this.translateModel,
    required this.reverseProviderId,
    required this.reverseModel,
    required this.characterReplaceProviderId,
    required this.characterReplaceModel,
    this.customProviderId = '',
    this.customModel = '',
    this.chatProviderId = '',
    this.chatModel = '',
  });

  TaskRoutingConfig copyWith({
    String? llmProviderId,
    String? llmModel,
    String? translateProviderId,
    String? translateModel,
    String? reverseProviderId,
    String? reverseModel,
    String? characterReplaceProviderId,
    String? characterReplaceModel,
    String? customProviderId,
    String? customModel,
    String? chatProviderId,
    String? chatModel,
  }) {
    return TaskRoutingConfig(
      llmProviderId: llmProviderId ?? this.llmProviderId,
      llmModel: llmModel ?? this.llmModel,
      translateProviderId: translateProviderId ?? this.translateProviderId,
      translateModel: translateModel ?? this.translateModel,
      reverseProviderId: reverseProviderId ?? this.reverseProviderId,
      reverseModel: reverseModel ?? this.reverseModel,
      characterReplaceProviderId:
          characterReplaceProviderId ?? this.characterReplaceProviderId,
      characterReplaceModel:
          characterReplaceModel ?? this.characterReplaceModel,
      customProviderId: customProviderId ?? this.customProviderId,
      customModel: customModel ?? this.customModel,
      chatProviderId: chatProviderId ?? this.chatProviderId,
      chatModel: chatModel ?? this.chatModel,
    );
  }

  String providerIdFor(AssistantTaskType taskType) {
    switch (taskType) {
      case AssistantTaskType.llm:
        return llmProviderId;
      case AssistantTaskType.translate:
        return translateProviderId;
      case AssistantTaskType.reverse:
        return reverseProviderId;
      case AssistantTaskType.characterReplace:
        return characterReplaceProviderId;
      case AssistantTaskType.custom:
        return customProviderId;
      case AssistantTaskType.chat:
        return chatProviderId;
    }
  }

  String modelFor(AssistantTaskType taskType) {
    switch (taskType) {
      case AssistantTaskType.llm:
        return llmModel;
      case AssistantTaskType.translate:
        return translateModel;
      case AssistantTaskType.reverse:
        return reverseModel;
      case AssistantTaskType.characterReplace:
        return characterReplaceModel;
      case AssistantTaskType.custom:
        return customModel;
      case AssistantTaskType.chat:
        return chatModel;
    }
  }

  TaskRoutingConfig copyWithTask({
    required AssistantTaskType taskType,
    required String providerId,
    required String model,
  }) {
    switch (taskType) {
      case AssistantTaskType.llm:
        return copyWith(llmProviderId: providerId, llmModel: model);
      case AssistantTaskType.translate:
        return copyWith(translateProviderId: providerId, translateModel: model);
      case AssistantTaskType.reverse:
        return copyWith(reverseProviderId: providerId, reverseModel: model);
      case AssistantTaskType.characterReplace:
        return copyWith(
          characterReplaceProviderId: providerId,
          characterReplaceModel: model,
        );
      case AssistantTaskType.custom:
        return copyWith(customProviderId: providerId, customModel: model);
      case AssistantTaskType.chat:
        return copyWith(chatProviderId: providerId, chatModel: model);
    }
  }

  Map<String, dynamic> toJson() => {
    'llmProviderId': llmProviderId,
    'llmModel': llmModel,
    'translateProviderId': translateProviderId,
    'translateModel': translateModel,
    'reverseProviderId': reverseProviderId,
    'reverseModel': reverseModel,
    'characterReplaceProviderId': characterReplaceProviderId,
    'characterReplaceModel': characterReplaceModel,
    'customProviderId': customProviderId,
    'customModel': customModel,
    'chatProviderId': chatProviderId,
    'chatModel': chatModel,
  };

  factory TaskRoutingConfig.fromJson(Map<String, dynamic> json) {
    final llmProviderId = _routingString(json, 'llmProviderId');
    final llmModel = _routingString(json, 'llmModel');
    return TaskRoutingConfig(
      llmProviderId: llmProviderId,
      llmModel: llmModel,
      translateProviderId: _routingString(json, 'translateProviderId'),
      translateModel: _routingString(json, 'translateModel'),
      reverseProviderId: _routingString(
        json,
        'reverseProviderId',
        fallback: llmProviderId,
      ),
      reverseModel: _routingString(json, 'reverseModel', fallback: llmModel),
      characterReplaceProviderId: _routingString(
        json,
        'characterReplaceProviderId',
        fallback: llmProviderId,
      ),
      characterReplaceModel: _routingString(
        json,
        'characterReplaceModel',
        fallback: llmModel,
      ),
      customProviderId: _routingString(
        json,
        'customProviderId',
        fallback: llmProviderId,
      ),
      customModel: _routingString(json, 'customModel', fallback: llmModel),
      chatProviderId: _routingString(json, 'chatProviderId'),
      chatModel: _routingString(json, 'chatModel'),
    );
  }
}

String _routingString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key] as String?;
  if (value == null) {
    return fallback;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

class PromptRuleTemplate {
  final String id;
  final String name;
  final AssistantTaskType taskType;
  final String content;
  final bool enabled;
  final bool isDefault;
  final int order;

  const PromptRuleTemplate({
    required this.id,
    required this.name,
    required this.taskType,
    required this.content,
    this.enabled = true,
    this.isDefault = false,
    this.order = 0,
  });

  PromptRuleTemplate copyWith({
    String? id,
    String? name,
    AssistantTaskType? taskType,
    String? content,
    bool? enabled,
    bool? isDefault,
    int? order,
  }) {
    return PromptRuleTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      taskType: taskType ?? this.taskType,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
      isDefault: isDefault ?? this.isDefault,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'taskType': taskType.name,
    'content': content,
    'enabled': enabled,
    'isDefault': isDefault,
    'order': order,
  };

  factory PromptRuleTemplate.fromJson(Map<String, dynamic> json) {
    return PromptRuleTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      taskType: AssistantTaskType.values.firstWhere(
        (t) => t.name == json['taskType'],
        orElse: () => AssistantTaskType.llm,
      ),
      content: json['content'] as String,
      enabled: json['enabled'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class StreamingChunk {
  final String delta;
  final bool done;

  const StreamingChunk({required this.delta, this.done = false});
}

class AssistantOperationResult {
  final bool success;
  final String content;
  final String? error;

  const AssistantOperationResult({
    required this.success,
    required this.content,
    this.error,
  });
}

class PromptAssistantConfigState {
  final bool enabled;
  final bool desktopOverlayEnabled;
  final bool streamOutput;
  final AgentPermissionMode agentPermissionMode;
  final List<ProviderConfig> providers;
  final List<ModelConfig> models;
  final TaskRoutingConfig routing;
  final List<PromptRuleTemplate> rules;
  final Map<String, bool> providerHasApiKey;

  const PromptAssistantConfigState({
    required this.enabled,
    required this.desktopOverlayEnabled,
    required this.streamOutput,
    this.agentPermissionMode = AgentPermissionMode.askBeforeSensitiveActions,
    required this.providers,
    required this.models,
    required this.routing,
    required this.rules,
    required this.providerHasApiKey,
  });

  factory PromptAssistantConfigState.defaults() {
    return const PromptAssistantConfigState(
      enabled: true,
      desktopOverlayEnabled: true,
      streamOutput: false,
      agentPermissionMode: AgentPermissionMode.askBeforeSensitiveActions,
      providers: [],
      models: [],
      routing: TaskRoutingConfig(
        llmProviderId: '',
        llmModel: '',
        translateProviderId: '',
        translateModel: '',
        reverseProviderId: '',
        reverseModel: '',
        characterReplaceProviderId: '',
        characterReplaceModel: '',
        customProviderId: '',
        customModel: '',
      ),
      rules: [
        PromptRuleTemplate(
          id: 'opt_default',
          name: 'Default Optimize Rule',
          taskType: AssistantTaskType.llm,
          content:
              'You are a prompt optimization assistant. Preserve the user intent, add actionable visual details, and output a single comma-separated prompt line.',
          isDefault: true,
        ),
        PromptRuleTemplate(
          id: 'translate_default',
          name: 'Default Translate Rule',
          taskType: AssistantTaskType.translate,
          content:
              'You are a translation assistant. Detect the source language, translate between Chinese and English automatically, and return only the translation without explanation.',
          isDefault: true,
        ),
        PromptRuleTemplate(
          id: 'reverse_default',
          name: 'Default Reverse Prompt Rule',
          taskType: AssistantTaskType.reverse,
          content:
              'You are an image reverse-prompt assistant. Based on the image and optional tagger results, output English comma-separated prompts suitable for NovelAI. Preserve subject, character, style, clothing, action, composition, lighting, and background. Do not explain.',
          isDefault: true,
        ),
        PromptRuleTemplate(
          id: 'character_replace_default',
          name: 'Default Character Replace Rule',
          taskType: AssistantTaskType.characterReplace,
          content:
              'You are a character replacement assistant. Replace the original character identity, hairstyle, outfit, and appearance in the input prompt with the target character while preserving action, composition, background, style, camera, and quality tags. Output only the replaced single-line prompt.',
          isDefault: true,
        ),
        PromptRuleTemplate(
          id: 'custom_default',
          name: 'Default Custom Rule',
          taskType: AssistantTaskType.custom,
          content:
              'You are a prompt rewriting assistant. Modify the prompt according to the current prompt, the user request, and optional reference images. Output only the final single-line prompt that can be used directly, without explanation.',
          isDefault: true,
        ),
      ],
      providerHasApiKey: {},
    );
  }

  PromptAssistantConfigState copyWith({
    bool? enabled,
    bool? desktopOverlayEnabled,
    bool? streamOutput,
    AgentPermissionMode? agentPermissionMode,
    List<ProviderConfig>? providers,
    List<ModelConfig>? models,
    TaskRoutingConfig? routing,
    List<PromptRuleTemplate>? rules,
    Map<String, bool>? providerHasApiKey,
  }) {
    return PromptAssistantConfigState(
      enabled: enabled ?? this.enabled,
      desktopOverlayEnabled:
          desktopOverlayEnabled ?? this.desktopOverlayEnabled,
      streamOutput: false,
      agentPermissionMode: agentPermissionMode ?? this.agentPermissionMode,
      providers: providers ?? this.providers,
      models: models ?? this.models,
      routing: routing ?? this.routing,
      rules: rules ?? this.rules,
      providerHasApiKey: providerHasApiKey ?? this.providerHasApiKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'enabled': enabled,
    'desktopOverlayEnabled': desktopOverlayEnabled,
    'streamOutput': false,
    'agentPermissionMode': agentPermissionMode.name,
    'providers': providers.map((e) => e.toJson()).toList(),
    'models': models.map((e) => e.toJson()).toList(),
    'routing': routing.toJson(),
    'rules': rules.map((e) => e.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  List<ModelConfig> modelsForProviderTask({
    required String providerId,
    required AssistantTaskType taskType,
  }) {
    return _modelsForProviderTask(
      models,
      providerId: providerId,
      taskType: taskType,
    );
  }

  factory PromptAssistantConfigState.decode(
    String raw, {
    bool migrateLegacyChatRouting = false,
  }) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final defaults = PromptAssistantConfigState.defaults();

    final providersRaw = json['providers'];
    var providers = providersRaw is List && providersRaw.isNotEmpty
        ? providersRaw
              .map((e) => ProviderConfig.fromJson(e as Map<String, dynamic>))
              .toList()
        : defaults.providers;

    final modelsRaw = json['models'];
    var decodedModels = modelsRaw is List && modelsRaw.isNotEmpty
        ? modelsRaw
              .map((e) => ModelConfig.fromJson(e as Map<String, dynamic>))
              .toList()
        : defaults.models;

    var routing = TaskRoutingConfig.fromJson(
      (json['routing'] as Map?)?.cast<String, dynamic>() ??
          defaults.routing.toJson(),
    );
    if (migrateLegacyChatRouting &&
        routing.chatProviderId.isEmpty &&
        routing.chatModel.isEmpty) {
      routing = routing.copyWith(
        chatProviderId: routing.llmProviderId,
        chatModel: routing.llmModel,
      );
    }

    if (_isUntouchedLegacyPollinationsDefault(
      providers: providers,
      models: decodedModels,
      routing: routing,
      schemaVersion: json['schemaVersion'] as int?,
    )) {
      providers = const [];
      decodedModels = const [];
      routing = defaults.routing;
    }

    final models = _expandProviderModelsToAllTasks(
      _mergeDefaultModels(decodedModels, defaults.models),
    );

    for (final taskType in AssistantTaskType.values) {
      final providerId = routing.providerIdFor(taskType);
      if (providerId.isNotEmpty &&
          !providers.any((provider) => provider.id == providerId)) {
        routing = routing.copyWithTask(
          taskType: taskType,
          providerId: '',
          model: '',
        );
      }
    }
    routing = _normalizeRoutingModels(
      routing: routing,
      providers: providers,
      models: models,
    );

    final rulesRaw = json['rules'];
    final decodedRules = rulesRaw is List && rulesRaw.isNotEmpty
        ? rulesRaw
              .map(
                (e) => PromptRuleTemplate.fromJson(e as Map<String, dynamic>),
              )
              .toList()
        : defaults.rules;
    final rules = _mergeDefaultRules(decodedRules, defaults.rules);

    return PromptAssistantConfigState(
      enabled: json['enabled'] as bool? ?? true,
      desktopOverlayEnabled: json['desktopOverlayEnabled'] as bool? ?? true,
      streamOutput: false,
      agentPermissionMode: AgentPermissionMode.fromName(
        json['agentPermissionMode'] as String?,
      ),
      providers: providers,
      models: models,
      routing: routing,
      rules: rules,
      providerHasApiKey: const {},
    );
  }

  static bool _isUntouchedLegacyPollinationsDefault({
    required List<ProviderConfig> providers,
    required List<ModelConfig> models,
    required TaskRoutingConfig routing,
    required int? schemaVersion,
  }) {
    if (schemaVersion != null) return false;
    final providerIds = providers.map((provider) => provider.id).toSet();
    final isSinglePollinationsDefault =
        providerIds.length == 1 && providerIds.contains('pollinations');
    final isOldThreeProviderDefault =
        providerIds.length == 3 &&
        providerIds.contains('pollinations') &&
        providerIds.contains('openai_custom') &&
        providerIds.contains('ollama');
    if (!isSinglePollinationsDefault && !isOldThreeProviderDefault) {
      return false;
    }
    final pollinations = providers.firstWhere(
      (provider) => provider.id == 'pollinations',
    );
    if (pollinations.enabled != true ||
        pollinations.baseUrl != 'https://gen.pollinations.ai') {
      return false;
    }
    if (isOldThreeProviderDefault) {
      final openai = providers.firstWhere(
        (provider) => provider.id == 'openai_custom',
      );
      final ollama = providers.firstWhere(
        (provider) => provider.id == 'ollama',
      );
      if (openai.enabled ||
          openai.baseUrl != 'https://api.openai.com/v1' ||
          ollama.enabled ||
          ollama.baseUrl != 'http://127.0.0.1:11434/v1') {
        return false;
      }
    }
    if (models.isEmpty) {
      return false;
    }
    for (final taskType in AssistantTaskType.values) {
      if (taskType == AssistantTaskType.custom) continue;
      if (routing.providerIdFor(taskType) != 'pollinations' ||
          routing.modelFor(taskType) != 'openai-large') {
        return false;
      }
    }
    return models.every(
      (model) =>
          model.providerId == 'pollinations' &&
          model.name == 'openai-large' &&
          model.isDefault,
    );
  }

  static List<ModelConfig> _mergeDefaultModels(
    List<ModelConfig> models,
    List<ModelConfig> defaults,
  ) {
    final result = [...models];
    for (final fallback in defaults) {
      final exists = result.any(
        (m) =>
            m.providerId == fallback.providerId &&
            m.name == fallback.name &&
            m.forTask == fallback.forTask,
      );
      if (!exists) {
        result.add(fallback);
      }
    }
    return result;
  }

  static List<ModelConfig> _expandProviderModelsToAllTasks(
    List<ModelConfig> models,
  ) {
    final result = [...models];
    final namesByProvider = <String, Map<String, ModelConfig>>{};

    for (final model in result) {
      namesByProvider.putIfAbsent(model.providerId, () => {})[model.name] =
          model;
    }

    for (final entry in namesByProvider.entries) {
      for (final model in entry.value.values) {
        for (final taskType in AssistantTaskType.values) {
          final exists = result.any(
            (candidate) =>
                candidate.providerId == model.providerId &&
                candidate.name == model.name &&
                candidate.forTask == taskType,
          );
          if (!exists) {
            result.add(model.copyWith(forTask: taskType));
          }
        }
      }
    }

    return result;
  }

  static TaskRoutingConfig _normalizeRoutingModels({
    required TaskRoutingConfig routing,
    required List<ProviderConfig> providers,
    required List<ModelConfig> models,
  }) {
    var next = routing;

    for (final taskType in AssistantTaskType.values) {
      final providerId = next.providerIdFor(taskType);
      if (providerId.isEmpty ||
          !providers.any((provider) => provider.id == providerId)) {
        continue;
      }

      final candidates = _modelsForProviderTask(
        models,
        providerId: providerId,
        taskType: taskType,
      );
      if (candidates.isEmpty) {
        continue;
      }

      final routedModel = next.modelFor(taskType);
      final hasRoutedModel = candidates.any(
        (candidate) => candidate.name == routedModel,
      );
      final isPlaceholderRoute =
          routedModel.trim().isEmpty || routedModel.trim() == 'default-model';
      final shouldReplacePlaceholder =
          isPlaceholderRoute &&
          candidates.any((candidate) => !candidate.isPlaceholder);

      if (!hasRoutedModel || shouldReplacePlaceholder) {
        next = next.copyWithTask(
          taskType: taskType,
          providerId: providerId,
          model: candidates.first.name,
        );
      }
    }

    return next;
  }

  static List<ModelConfig> _modelsForProviderTask(
    List<ModelConfig> source, {
    required String providerId,
    required AssistantTaskType taskType,
  }) {
    final candidates = <ModelConfig>[];
    final names = <String>{};

    void addCandidate(ModelConfig model) {
      if (!names.add(model.name)) {
        return;
      }
      candidates.add(model.copyWith(forTask: taskType));
    }

    for (final model in source) {
      if (model.providerId == providerId && model.forTask == taskType) {
        addCandidate(model);
      }
    }

    for (final model in source) {
      if (model.providerId == providerId) {
        addCandidate(model);
      }
    }

    candidates.sort((a, b) {
      final aPlaceholder = a.isPlaceholder;
      final bPlaceholder = b.isPlaceholder;
      if (aPlaceholder != bPlaceholder) {
        return aPlaceholder ? 1 : -1;
      }
      return a.displayName.compareTo(b.displayName);
    });

    return candidates;
  }

  static List<PromptRuleTemplate> _mergeDefaultRules(
    List<PromptRuleTemplate> rules,
    List<PromptRuleTemplate> defaults,
  ) {
    final result = [...rules];
    for (final fallback in defaults) {
      final index = result.indexWhere((r) => r.id == fallback.id);
      if (index >= 0) {
        result[index] = result[index].copyWith(isDefault: true);
      } else {
        result.add(fallback);
      }
    }
    result.sort((a, b) => a.order.compareTo(b.order));
    return result;
  }
}
