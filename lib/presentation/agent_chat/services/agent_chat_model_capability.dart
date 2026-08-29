import '../../../core/agent/agent_types.dart';
import '../../prompt_assistant/models/agent_protocol.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../model/agent_reasoning_model_rule.dart';
import '../model/pi_reasoning_model_catalog.dart';

const _thinkingOrder = <ThinkingLevel>[
  ThinkingLevel.off,
  ThinkingLevel.minimal,
  ThinkingLevel.low,
  ThinkingLevel.medium,
  ThinkingLevel.high,
  ThinkingLevel.xhigh,
  ThinkingLevel.max,
];

class AgentChatModelMetadata {
  const AgentChatModelMetadata({
    required this.contextWindow,
    required this.maxOutputTokens,
    required this.thinkingLevels,
    this.reasoningRule,
  });

  static const unknown = AgentChatModelMetadata(
    contextWindow: 0,
    maxOutputTokens: 0,
    thinkingLevels: <ThinkingLevel>[],
  );

  final int contextWindow;
  final int maxOutputTokens;
  final List<ThinkingLevel> thinkingLevels;
  final AgentReasoningModelRule? reasoningRule;

  bool get reasoning => thinkingLevels.isNotEmpty;

  AgentReasoningRequest? resolveReasoningRequest(String? selectedLevel) {
    final rule = reasoningRule;
    if (rule == null || thinkingLevels.isEmpty) return null;

    if (selectedLevel == null && !thinkingLevels.contains(ThinkingLevel.off)) {
      final geminiUsesHiddenMinimum =
          rule.api == AgentReasoningApi.geminiLevel &&
          rule.disabledEffort != null;
      return AgentReasoningRequest(
        api: rule.api,
        enabled: false,
        effort: geminiUsesHiddenMinimum ? rule.disabledEffort : null,
        sendWhenDisabled: geminiUsesHiddenMinimum,
        preserveReasoningContent: rule.requiresReasoningContent,
        allowEmptySignature: rule.allowEmptySignature,
        alwaysIncludeEncryptedReasoning: rule.alwaysIncludeEncryptedReasoning,
      );
    }

    final requested = ThinkingLevel.values.where(
      (level) => level != ThinkingLevel.off && level.name == selectedLevel,
    );
    var selected = selectedLevel == null
        ? ThinkingLevel.off
        : requested.firstOrNull ?? ThinkingLevel.off;
    if (!thinkingLevels.contains(selected)) {
      selected = _nearestSupportedLevel(selected, thinkingLevels);
    }
    final enabled = selected != ThinkingLevel.off;
    final mapped = rule.mappedLevel(selected);

    return AgentReasoningRequest(
      api: rule.api,
      enabled: enabled,
      effort: _nativeEffort(rule, selected, mapped),
      budgetTokens: enabled ? _thinkingBudget(rule, selected) : 0,
      sendWhenDisabled:
          !rule.levelMap.containsKey(ThinkingLevel.off) ||
          rule.levelMap[ThinkingLevel.off] != null,
      preserveReasoningContent: rule.requiresReasoningContent,
      allowEmptySignature: rule.allowEmptySignature,
      alwaysIncludeEncryptedReasoning: rule.alwaysIncludeEncryptedReasoning,
    );
  }

  static ThinkingLevel _nearestSupportedLevel(
    ThinkingLevel requested,
    List<ThinkingLevel> supported,
  ) {
    final index = _thinkingOrder.indexOf(requested);
    for (var i = index + 1; i < _thinkingOrder.length; i++) {
      if (supported.contains(_thinkingOrder[i])) return _thinkingOrder[i];
    }
    for (var i = index - 1; i >= 0; i--) {
      if (supported.contains(_thinkingOrder[i])) return _thinkingOrder[i];
    }
    return supported.first;
  }

  static String? _nativeEffort(
    AgentReasoningModelRule rule,
    ThinkingLevel level,
    String mapped,
  ) {
    if (level == ThinkingLevel.off) {
      if (rule.levelMap.containsKey(level)) return rule.levelMap[level];
      return switch (rule.api) {
        AgentReasoningApi.openAiResponses ||
        AgentReasoningApi.openRouter => 'none',
        _ => null,
      };
    }
    return switch (rule.api) {
      AgentReasoningApi.deepSeek ||
      AgentReasoningApi.qwen => rule.supportsReasoningEffort ? mapped : null,
      AgentReasoningApi.anthropicAdaptive => switch (level) {
        ThinkingLevel.minimal || ThinkingLevel.low => 'low',
        ThinkingLevel.medium => 'medium',
        ThinkingLevel.high => 'high',
        ThinkingLevel.xhigh || ThinkingLevel.max => mapped,
        ThinkingLevel.off => null,
      },
      AgentReasoningApi.mistralPromptMode => null,
      AgentReasoningApi.mistralEffort => mapped,
      AgentReasoningApi.anthropicBudget ||
      AgentReasoningApi.geminiBudget => null,
      _ => mapped,
    };
  }

  static int? _thinkingBudget(
    AgentReasoningModelRule rule,
    ThinkingLevel level,
  ) {
    if (rule.thinkingBudgets[level] case final budget?) return budget;
    if (rule.api == AgentReasoningApi.geminiBudget) return -1;
    if (rule.api != AgentReasoningApi.anthropicBudget) return null;
    return switch (level) {
      ThinkingLevel.minimal => 1024,
      ThinkingLevel.low => 2048,
      ThinkingLevel.medium => 8192,
      ThinkingLevel.high || ThinkingLevel.xhigh || ThinkingLevel.max => 16384,
      ThinkingLevel.off => 0,
    };
  }
}

class AgentChatModelCatalog {
  const AgentChatModelCatalog._();

  static const _legacyDeepSeekChat = AgentReasoningModelRule(
    api: AgentReasoningApi.deepSeek,
    levels: [ThinkingLevel.off, ThinkingLevel.high],
    supportsReasoningEffort: false,
    contextWindow: 128000,
    maxOutputTokens: 8192,
  );

  static const _legacyDeepSeekReasoner = AgentReasoningModelRule(
    api: AgentReasoningApi.deepSeek,
    levels: [ThinkingLevel.high],
    levelMap: {ThinkingLevel.off: null},
    supportsReasoningEffort: false,
    contextWindow: 128000,
    maxOutputTokens: 65536,
  );

  static AgentChatModelMetadata resolve(ProviderPreset? preset, String model) {
    if (preset == null) return AgentChatModelMetadata.unknown;
    return resolveProvider(
      provider: preset.createConfig(id: 'capability'),
      model: model,
    );
  }

  static AgentChatModelMetadata resolveProvider({
    required ProviderConfig provider,
    required String model,
  }) {
    final providerKey = _resolvePiProvider(provider, model);
    var rule = providerKey == null ? null : _lookupRule(providerKey, model);

    if (rule == null && provider.preset == ProviderPreset.deepseek) {
      rule = switch (model) {
        'deepseek-chat' => _legacyDeepSeekChat,
        'deepseek-reasoner' => _legacyDeepSeekReasoner,
        _ => null,
      };
    }

    if (rule != null && !_protocolSupports(provider.protocol, rule.api)) {
      rule = null;
    }
    if (rule != null) {
      return AgentChatModelMetadata(
        contextWindow: rule.contextWindow,
        maxOutputTokens: rule.maxOutputTokens,
        thinkingLevels: rule.levels,
        reasoningRule: rule,
      );
    }

    if (provider.preset == ProviderPreset.openaiChat &&
        model.startsWith('gpt-4.1')) {
      return const AgentChatModelMetadata(
        contextWindow: 1047576,
        maxOutputTokens: 32768,
        thinkingLevels: [],
      );
    }
    return AgentChatModelMetadata.unknown;
  }

  static String? _resolvePiProvider(ProviderConfig provider, String model) {
    switch (provider.preset) {
      case ProviderPreset.openaiResponses:
        return 'openai';
      case ProviderPreset.anthropic:
        return 'anthropic';
      case ProviderPreset.gemini:
        return 'google';
      case ProviderPreset.deepseek:
        return 'deepseek';
      case ProviderPreset.openRouter:
        return 'openrouter';
      case ProviderPreset.xai:
        return 'xai';
      case ProviderPreset.mistral:
        return 'mistral';
      case ProviderPreset.groq:
        return 'groq';
      case ProviderPreset.cerebras:
        return 'cerebras';
      case ProviderPreset.minimax:
        return 'minimax';
      case ProviderPreset.minimaxCn:
        return 'minimax-cn';
      case ProviderPreset.kimiCoding:
        return 'kimi-coding';
      case ProviderPreset.moonshot:
        return 'moonshotai';
      case ProviderPreset.moonshotCn:
        return 'moonshotai-cn';
      case ProviderPreset.qwenTokenPlan:
        return 'qwen-token-plan';
      case ProviderPreset.qwenTokenPlanCn:
        return 'qwen-token-plan-cn';
      case ProviderPreset.qwenTokenPlanIndividual:
        return 'qwen-token-plan-individual';
      case ProviderPreset.openaiCompatibleResponses:
        if (_lookupRule('openai', model) != null) return 'openai';
      default:
        break;
    }

    final id = provider.id.toLowerCase();
    if (piReasoningModelCatalog.containsKey(id)) return id;

    final uri = Uri.tryParse(provider.baseUrl);
    final host = uri?.host.toLowerCase() ?? '';
    final path = uri?.path.toLowerCase() ?? '';
    if (host == 'api.openai.com') return 'openai';
    if (host == 'api.anthropic.com') return 'anthropic';
    if (host == 'generativelanguage.googleapis.com') return 'google';
    if (host == 'api.deepseek.com') return 'deepseek';
    if (host == 'openrouter.ai') return 'openrouter';
    if (host == 'api.x.ai') return 'xai';
    if (host == 'api.mistral.ai') return 'mistral';
    if (host == 'api.groq.com') return 'groq';
    if (host == 'api.cerebras.ai') return 'cerebras';
    if (host == 'api.minimax.io') return 'minimax';
    if (host == 'api.minimaxi.com') return 'minimax-cn';
    if (host == 'api.kimi.com' && path.startsWith('/coding')) {
      return 'kimi-coding';
    }
    if (host == 'api.moonshot.ai') return 'moonshotai';
    if (host == 'api.moonshot.cn') return 'moonshotai-cn';
    if (host == 'token-plan.cn-beijing.maas.aliyuncs.com') {
      return 'qwen-token-plan-cn';
    }
    if (host == 'token-plan.ap-southeast-1.maas.aliyuncs.com') {
      return 'qwen-token-plan';
    }
    return null;
  }

  static AgentReasoningModelRule? _lookupRule(String provider, String model) {
    final normalized = model.trim().toLowerCase();
    for (final entry in piReasoningModelCatalog[provider]!.entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value;
    }
    return null;
  }

  static bool _protocolSupports(
    ProviderProtocol protocol,
    AgentReasoningApi api,
  ) => switch (api) {
    AgentReasoningApi.openAiResponses =>
      protocol == ProviderProtocol.openaiResponses,
    AgentReasoningApi.anthropicBudget || AgentReasoningApi.anthropicAdaptive =>
      protocol == ProviderProtocol.anthropicMessages,
    AgentReasoningApi.geminiBudget || AgentReasoningApi.geminiLevel =>
      protocol == ProviderProtocol.geminiGenerateContent,
    _ =>
      protocol == ProviderProtocol.openaiChatCompletions ||
          protocol == ProviderProtocol.ollamaChatCompletions,
  };
}

class AgentChatModelCapability {
  const AgentChatModelCapability({
    required this.model,
    required this.levels,
    required this.metadata,
  });

  final Model model;
  final List<ThinkingLevel> levels;
  final AgentChatModelMetadata metadata;

  static const unavailable = AgentChatModelCapability(
    model: Model(id: '', name: '', api: '', provider: ''),
    levels: [],
    metadata: AgentChatModelMetadata.unknown,
  );

  AgentReasoningRequest? resolveReasoningRequest(String? selectedLevel) =>
      metadata.resolveReasoningRequest(selectedLevel);

  static AgentChatModelCapability resolve(
    ProviderConfig provider,
    String modelId,
  ) {
    final metadata = AgentChatModelCatalog.resolveProvider(
      provider: provider,
      model: modelId,
    );
    return AgentChatModelCapability(
      model: Model(
        id: modelId,
        name: modelId,
        api: provider.protocol.name,
        provider: provider.id,
        baseUrl: provider.baseUrl,
        contextWindow: metadata.contextWindow,
        maxTokens: metadata.maxOutputTokens,
        reasoning: metadata.reasoning,
      ),
      levels: metadata.thinkingLevels,
      metadata: metadata,
    );
  }
}
