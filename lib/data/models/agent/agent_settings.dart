import 'dart:convert';

import '../../../presentation/prompt_assistant/models/prompt_assistant_models.dart';

const String legacyDefaultAgentChatPrompt =
    'You are a helpful assistant embedded in a NovelAI image-generation client. '
    'Answer concisely in the user\'s language and use tools to edit prompts when asked.';

enum AgentSystemPromptMode { append, override }

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

class AgentMigratedChatRule {
  const AgentMigratedChatRule({
    required this.id,
    required this.name,
    required this.content,
    required this.enabled,
    required this.isDefault,
    required this.order,
  });

  final String id;
  final String name;
  final String content;
  final bool enabled;
  final bool isDefault;
  final int order;

  bool get isUnmodifiedLegacyDefault =>
      id == 'chat_default' && content.trim() == legacyDefaultAgentChatPrompt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'enabled': enabled,
    'isDefault': isDefault,
    'order': order,
  };

  factory AgentMigratedChatRule.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('migratedChatRules entries must be objects.');
    }
    _rejectUnknownFields(value, const {
      'id',
      'name',
      'content',
      'enabled',
      'isDefault',
      'order',
    }, 'migrated chat rule');
    final id = value['id'];
    final name = value['name'];
    final content = value['content'];
    final enabled = value['enabled'];
    final isDefault = value['isDefault'];
    final order = value['order'];
    if (id is! String ||
        name is! String ||
        content is! String ||
        enabled is! bool ||
        isDefault is! bool ||
        order is! int ||
        id.isEmpty ||
        id.length > 128 ||
        name.length > 256) {
      throw const FormatException('migratedChatRules contains invalid data.');
    }
    return AgentMigratedChatRule(
      id: id,
      name: name,
      content: content,
      enabled: enabled,
      isDefault: isDefault,
      order: order,
    );
  }
}

class AgentChatConfig {
  const AgentChatConfig({
    this.modelReference = const AgentModelReference(),
    this.permissionMode = AgentPermissionMode.askBeforeSensitiveActions,
    this.webAccessEnabled = false,
    this.systemPromptMode = AgentSystemPromptMode.append,
    this.customSystemPrompt = '',
    this.migratedChatRules = const [],
  });

  final AgentModelReference modelReference;
  final AgentPermissionMode permissionMode;
  final bool webAccessEnabled;
  final AgentSystemPromptMode systemPromptMode;
  final String customSystemPrompt;
  final List<AgentMigratedChatRule> migratedChatRules;

  String behaviorInstructions({
    String? customPromptOverride,
    AgentSystemPromptMode? modeOverride,
  }) {
    final mode = modeOverride ?? systemPromptMode;
    final custom = (customPromptOverride ?? customSystemPrompt).trim();
    if (mode == AgentSystemPromptMode.override) return custom;
    final migrated =
        migratedChatRules
            .where((rule) => rule.enabled && !rule.isUnmodifiedLegacyDefault)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (final rule in migrated)
        if (rule.content.trim().isNotEmpty) rule.content.trim(),
      if (custom.isNotEmpty) custom,
    ].join('\n\n');
  }

  AgentChatConfig copyWith({
    AgentModelReference? modelReference,
    AgentPermissionMode? permissionMode,
    bool? webAccessEnabled,
    AgentSystemPromptMode? systemPromptMode,
    String? customSystemPrompt,
    List<AgentMigratedChatRule>? migratedChatRules,
  }) {
    return AgentChatConfig(
      modelReference: modelReference ?? this.modelReference,
      permissionMode: permissionMode ?? this.permissionMode,
      webAccessEnabled: webAccessEnabled ?? this.webAccessEnabled,
      systemPromptMode: systemPromptMode ?? this.systemPromptMode,
      customSystemPrompt: customSystemPrompt ?? this.customSystemPrompt,
      migratedChatRules: migratedChatRules ?? this.migratedChatRules,
    );
  }

  Map<String, dynamic> toJson() => {
    'modelReference': modelReference.toJson(),
    'permissionMode': permissionMode.name,
    'webAccessEnabled': webAccessEnabled,
    'systemPromptMode': systemPromptMode.name,
    'customSystemPrompt': customSystemPrompt,
    'migratedChatRules': [for (final rule in migratedChatRules) rule.toJson()],
  };

  factory AgentChatConfig.fromJson(
    Object? value, {
    required int schemaVersion,
  }) {
    if (value is! Map) {
      throw const FormatException('chat must be an object.');
    }
    final permission = value['permissionMode'];
    final webAccess = value['webAccessEnabled'];
    final promptMode = value['systemPromptMode'];
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
      'systemPromptMode',
      'customSystemPrompt',
      'migratedChatRules',
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
    if (schemaVersion >= 4 && promptMode is! String) {
      throw const FormatException('systemPromptMode must be a string.');
    }
    final systemPromptMode = schemaVersion < 4
        ? AgentSystemPromptMode.append
        : switch (promptMode) {
            'append' => AgentSystemPromptMode.append,
            'override' => AgentSystemPromptMode.override,
            _ => throw FormatException('Unknown systemPromptMode: $promptMode'),
          };
    final migratedValue = value['migratedChatRules'];
    if (schemaVersion >= 3 && migratedValue is! List) {
      throw const FormatException('migratedChatRules must be a list.');
    }
    final migratedRules = <AgentMigratedChatRule>[];
    if (migratedValue != null) {
      if (migratedValue is! List ||
          migratedValue.length > AgentSettings.maxMigratedChatRules) {
        throw const FormatException(
          'migratedChatRules must be a bounded list.',
        );
      }
      for (final item in migratedValue) {
        migratedRules.add(AgentMigratedChatRule.fromJson(item));
      }
    }
    final migratedLength = migratedRules.fold<int>(
      0,
      (length, rule) => length + rule.content.length,
    );
    if (migratedLength > AgentSettings.maxCustomPromptLength) {
      throw const FormatException('migratedChatRules content is too large.');
    }
    return AgentChatConfig(
      modelReference: AgentModelReference.fromJson(value['modelReference']),
      permissionMode: permissionMode,
      webAccessEnabled: webAccess,
      systemPromptMode: systemPromptMode,
      customSystemPrompt: customPrompt,
      migratedChatRules: List.unmodifiable(migratedRules),
    );
  }
}

class AgentSettings {
  const AgentSettings({
    this.schemaVersion = currentSchemaVersion,
    this.chat = const AgentChatConfig(),
    this.disabledSkillIds = const {},
  });

  static const int currentSchemaVersion = 4;
  static const int maxCustomPromptLength = 50000;
  static const int maxSkillPreferences = 5000;
  static const int maxMigratedChatRules = 100;
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
      chat: AgentChatConfig.fromJson(decoded['chat'], schemaVersion: version),
      disabledSkillIds: disabledIds,
    );
  }

  static AgentSettings migrateLegacy({
    required PromptAssistantConfigState promptAssistant,
    required bool webAccessEnabled,
  }) {
    final chatRules = promptAssistant.rules
        .where((rule) => rule.taskType == AssistantTaskType.chat)
        .map(
          (rule) => AgentMigratedChatRule(
            id: rule.id,
            name: rule.name,
            content: rule.content,
            enabled: rule.enabled,
            isDefault: rule.isDefault,
            order: rule.order,
          ),
        )
        .toList();
    final migratedLength = chatRules.fold<int>(
      0,
      (length, rule) => length + rule.content.length,
    );
    if (chatRules.length > maxMigratedChatRules ||
        migratedLength > maxCustomPromptLength) {
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
        migratedChatRules: List.unmodifiable(chatRules),
      ),
    );
  }
}

void _rejectUnknownFields(Map value, Set<String> allowed, String objectName) {
  if (value.keys.any((key) => key is! String || !allowed.contains(key))) {
    throw FormatException('$objectName contains unknown fields.');
  }
}
