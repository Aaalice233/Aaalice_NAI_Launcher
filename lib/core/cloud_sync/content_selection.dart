import 'dart:convert';

class CloudSyncContentSelection {
  const CloudSyncContentSelection({
    this.includeAgentSystemPrompt = true,
    this.includeSkills = false,
    this.selectedSkillIds = const {},
  });

  static const int currentSchemaVersion = 1;
  static const int maxSelectedSkills = 500;

  final bool includeAgentSystemPrompt;
  final bool includeSkills;
  final Set<String> selectedSkillIds;

  CloudSyncContentSelection copyWith({
    bool? includeAgentSystemPrompt,
    bool? includeSkills,
    Set<String>? selectedSkillIds,
  }) => CloudSyncContentSelection(
    includeAgentSystemPrompt:
        includeAgentSystemPrompt ?? this.includeAgentSystemPrompt,
    includeSkills: includeSkills ?? this.includeSkills,
    selectedSkillIds: selectedSkillIds ?? this.selectedSkillIds,
  );

  Map<String, Object> toJson() {
    if (selectedSkillIds.length > maxSelectedSkills ||
        selectedSkillIds.any((id) => !_isValidSkillId(id))) {
      throw const FormatException('Invalid selected Skill identity.');
    }
    return {
      'version': currentSchemaVersion,
      'includeAgentSystemPrompt': includeAgentSystemPrompt,
      'includeSkills': includeSkills,
      'selectedSkillIds': selectedSkillIds.toList()..sort(),
    };
  }

  String encode() => jsonEncode(toJson());

  factory CloudSyncContentSelection.decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map ||
        value.keys.any(
          (key) =>
              key != 'version' &&
              key != 'includeAgentSystemPrompt' &&
              key != 'includeSkills' &&
              key != 'selectedSkillIds',
        ) ||
        value['version'] != currentSchemaVersion ||
        value['includeAgentSystemPrompt'] is! bool ||
        value['includeSkills'] is! bool ||
        value['selectedSkillIds'] is! List) {
      throw const FormatException('Invalid cloud backup content selection.');
    }
    final rawIds = value['selectedSkillIds']! as List;
    if (rawIds.length > maxSelectedSkills) {
      throw const FormatException('Too many selected Skills.');
    }
    final ids = <String>{};
    for (final id in rawIds) {
      if (id is! String || !_isValidSkillId(id) || !ids.add(id)) {
        throw const FormatException('Invalid selected Skill identity.');
      }
    }
    return CloudSyncContentSelection(
      includeAgentSystemPrompt: value['includeAgentSystemPrompt']! as bool,
      includeSkills: value['includeSkills']! as bool,
      selectedSkillIds: Set.unmodifiable(ids),
    );
  }

  static final RegExp _skillId = RegExp(
    r'^(workspace|piUser|commonUser):[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$',
  );

  static bool _isValidSkillId(String value) =>
      _skillId.hasMatch(value) && !value.contains('--');
}
