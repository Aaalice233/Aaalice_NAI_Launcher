import 'dart:convert';

import '../../../presentation/prompt_assistant/models/prompt_assistant_models.dart';

const String legacyDefaultAgentChatPrompt =
    'You are a helpful assistant embedded in a NovelAI image-generation client. '
    'Answer concisely in the user\'s language and use tools to edit prompts when asked.';

class AgentModelReference {
  const AgentModelReference({this.providerId = '', this.model = ''});

  final String providerId;
  final String model;

  bool get isConfigured => providerId.isNotEmpty && model.isNotEmpty;

  Map<String, dynamic> toJson() => {'providerId': providerId, 'model': model};

  factory AgentModelReference.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('modelReference must be an object.');
    }
    final providerId = value['providerId'];
    final model = value['model'];
    if (providerId is! String || model is! String) {
      throw const FormatException(
        'modelReference providerId and model must be strings.',
      );
    }
    _rejectUnknownFields(value, const {
      'providerId',
      'model',
    }, 'modelReference');
    return AgentModelReference(
      providerId: providerId.trim(),
      model: model.trim(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AgentModelReference &&
      other.providerId == providerId &&
      other.model == model;

  @override
  int get hashCode => Object.hash(providerId, model);
}

class AgentChatConfig {
  const AgentChatConfig({
    this.modelReference = const AgentModelReference(),
    this.permissionMode = AgentPermissionMode.askBeforeSensitiveActions,
    this.webAccessEnabled = false,
    this.customSystemPrompt = '',
  });

  final AgentModelReference modelReference;
  final AgentPermissionMode permissionMode;
  final bool webAccessEnabled;
  final String customSystemPrompt;

  AgentChatConfig copyWith({
    AgentModelReference? modelReference,
    AgentPermissionMode? permissionMode,
    bool? webAccessEnabled,
    String? customSystemPrompt,
  }) {
    return AgentChatConfig(
      modelReference: modelReference ?? this.modelReference,
      permissionMode: permissionMode ?? this.permissionMode,
      webAccessEnabled: webAccessEnabled ?? this.webAccessEnabled,
      customSystemPrompt: customSystemPrompt ?? this.customSystemPrompt,
    );
  }

  Map<String, dynamic> toJson() => {
    'modelReference': modelReference.toJson(),
    'permissionMode': permissionMode.name,
    'webAccessEnabled': webAccessEnabled,
    'customSystemPrompt': customSystemPrompt,
  };

  factory AgentChatConfig.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('chat must be an object.');
    }
    final permission = value['permissionMode'];
    final webAccess = value['webAccessEnabled'];
    final customPrompt = value['customSystemPrompt'];
    if (permission is! String ||
        webAccess is! bool ||
        customPrompt is! String) {
      throw const FormatException('chat contains invalid field types.');
    }
    _rejectUnknownFields(value, const {
      'modelReference',
      'permissionMode',
      'webAccessEnabled',
      'customSystemPrompt',
    }, 'chat');
    final permissionMode = AgentPermissionMode.values
        .cast<AgentPermissionMode?>()
        .firstWhere((mode) => mode?.name == permission, orElse: () => null);
    if (permissionMode == null) {
      throw FormatException('Unknown permissionMode: $permission');
    }
    if (customPrompt.length > AgentSettings.maxCustomPromptLength) {
      throw const FormatException('customSystemPrompt is too large.');
    }
    return AgentChatConfig(
      modelReference: AgentModelReference.fromJson(value['modelReference']),
      permissionMode: permissionMode,
      webAccessEnabled: webAccess,
      customSystemPrompt: customPrompt,
    );
  }
}

class AgentSettings {
  const AgentSettings({
    this.schemaVersion = currentSchemaVersion,
    this.chat = const AgentChatConfig(),
    this.disabledSkillIds = const {},
  });

  static const int currentSchemaVersion = 2;
  static const int maxCustomPromptLength = 50000;
  static const int maxSkillPreferences = 5000;
  static const int maxEncodedBytes = 1024 * 1024;

  final int schemaVersion;
  final AgentChatConfig chat;

  /// Logical Skill IDs are names rather than paths, so preferences survive
  /// upgrades and a same-name source taking precedence.
  final Set<String> disabledSkillIds;

  AgentSettings copyWith({
    AgentChatConfig? chat,
    Set<String>? disabledSkillIds,
  }) {
    return AgentSettings(
      chat: chat ?? this.chat,
      disabledSkillIds: disabledSkillIds ?? this.disabledSkillIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'chat': chat.toJson(),
    'disabledSkillIds': disabledSkillIds.toList()..sort(),
  };

  String encode() => jsonEncode(toJson());

  factory AgentSettings.decode(String raw) {
    if (utf8.encode(raw).length > maxEncodedBytes) {
      throw const FormatException('Agent settings are too large.');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Agent settings must be an object.');
    }
    final version = decoded['schemaVersion'];
    if (version is! int || version < 1 || version > currentSchemaVersion) {
      throw FormatException('Unsupported agent settings schema: $version');
    }
    _rejectUnknownFields(decoded, const {
      'schemaVersion',
      'chat',
      'disabledSkillIds',
    }, 'agent settings');
    final disabled = decoded['disabledSkillIds'];
    if (disabled is! List || disabled.length > maxSkillPreferences) {
      throw const FormatException('disabledSkillIds must be a bounded list.');
    }
    final disabledIds = <String>{};
    for (final value in disabled) {
      if (value is! String || !RegExp(r'^[a-z0-9-]{1,64}$').hasMatch(value)) {
        throw const FormatException('disabledSkillIds contains an invalid ID.');
      }
      disabledIds.add(value);
    }
    return AgentSettings(
      chat: AgentChatConfig.fromJson(decoded['chat']),
      disabledSkillIds: disabledIds,
    );
  }

  static AgentSettings migrateLegacy({
    required PromptAssistantConfigState promptAssistant,
    required bool webAccessEnabled,
  }) {
    final chatRules =
        promptAssistant.rules
            .where(
              (rule) => rule.taskType == AssistantTaskType.chat && rule.enabled,
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    final customRules = chatRules
        .where(
          (rule) =>
              !(rule.id == 'chat_default' &&
                  rule.content.trim() == legacyDefaultAgentChatPrompt),
        )
        .map((rule) => rule.content.trim())
        .where((content) => content.isNotEmpty)
        .toList();
    final customSystemPrompt = customRules.join('\n\n');
    if (customSystemPrompt.length > maxCustomPromptLength) {
      throw const FormatException(
        'Legacy chat instructions exceed the Agent prompt size limit.',
      );
    }
    return AgentSettings(
      chat: AgentChatConfig(
        modelReference: AgentModelReference(
          providerId: promptAssistant.routing.chatProviderId,
          model: promptAssistant.routing.chatModel,
        ),
        permissionMode: promptAssistant.agentPermissionMode,
        webAccessEnabled: webAccessEnabled,
        customSystemPrompt: customSystemPrompt,
      ),
    );
  }
}

void _rejectUnknownFields(Map value, Set<String> allowed, String objectName) {
  if (value.keys.any((key) => key is! String || !allowed.contains(key))) {
    throw FormatException('$objectName contains unknown fields.');
  }
}
