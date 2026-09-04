import 'dart:convert';

class CloudSyncContentSelection {
  const CloudSyncContentSelection({
    this.includeSettings = true,
    this.includePromptsAndTags = true,
    this.includeTagThumbnails = true,
    this.includeOnlineGallerySettings = true,
    this.includeOnlineGalleryFavorites = true,
    this.includeGalleryAlbums = true,
    this.includeAgentSystemPrompt = true,
    this.includeSkills = true,
    this.includeVibes = false,
    this.includePreciseReferences = false,
    this.selectedSkillIds = const {},
  });

  static const int currentSchemaVersion = 2;
  static const int maxSelectedSkills = 500;

  final bool includeSettings;
  final bool includePromptsAndTags;
  final bool includeTagThumbnails;
  final bool includeOnlineGallerySettings;
  final bool includeOnlineGalleryFavorites;
  final bool includeGalleryAlbums;
  final bool includeAgentSystemPrompt;
  final bool includeSkills;
  final bool includeVibes;
  final bool includePreciseReferences;
  final Set<String> selectedSkillIds;

  int get selectedItemCount => [
    includeSettings,
    includePromptsAndTags,
    includeTagThumbnails && includePromptsAndTags,
    includeOnlineGallerySettings,
    includeOnlineGalleryFavorites,
    includeGalleryAlbums,
    includeAgentSystemPrompt,
    includeSkills,
    includeVibes,
    includePreciseReferences,
  ].where((selected) => selected).length;

  CloudSyncContentSelection copyWith({
    bool? includeSettings,
    bool? includePromptsAndTags,
    bool? includeTagThumbnails,
    bool? includeOnlineGallerySettings,
    bool? includeOnlineGalleryFavorites,
    bool? includeGalleryAlbums,
    bool? includeAgentSystemPrompt,
    bool? includeSkills,
    bool? includeVibes,
    bool? includePreciseReferences,
    Set<String>? selectedSkillIds,
  }) => CloudSyncContentSelection(
    includeSettings: includeSettings ?? this.includeSettings,
    includePromptsAndTags: includePromptsAndTags ?? this.includePromptsAndTags,
    includeTagThumbnails: includeTagThumbnails ?? this.includeTagThumbnails,
    includeOnlineGallerySettings:
        includeOnlineGallerySettings ?? this.includeOnlineGallerySettings,
    includeOnlineGalleryFavorites:
        includeOnlineGalleryFavorites ?? this.includeOnlineGalleryFavorites,
    includeGalleryAlbums: includeGalleryAlbums ?? this.includeGalleryAlbums,
    includeAgentSystemPrompt:
        includeAgentSystemPrompt ?? this.includeAgentSystemPrompt,
    includeSkills: includeSkills ?? this.includeSkills,
    includeVibes: includeVibes ?? this.includeVibes,
    includePreciseReferences:
        includePreciseReferences ?? this.includePreciseReferences,
    selectedSkillIds: selectedSkillIds ?? this.selectedSkillIds,
  );

  Map<String, Object> toJson() {
    if (selectedSkillIds.length > maxSelectedSkills ||
        selectedSkillIds.any((id) => !_isValidSkillId(id))) {
      throw const FormatException('Invalid selected Skill identity.');
    }
    return {
      'version': currentSchemaVersion,
      'includeSettings': includeSettings,
      'includePromptsAndTags': includePromptsAndTags,
      'includeTagThumbnails': includeTagThumbnails,
      'includeOnlineGallerySettings': includeOnlineGallerySettings,
      'includeOnlineGalleryFavorites': includeOnlineGalleryFavorites,
      'includeGalleryAlbums': includeGalleryAlbums,
      'includeAgentSystemPrompt': includeAgentSystemPrompt,
      'includeSkills': includeSkills,
      'includeVibes': includeVibes,
      'includePreciseReferences': includePreciseReferences,
      'selectedSkillIds': selectedSkillIds.toList()..sort(),
    };
  }

  String encode() => jsonEncode(toJson());

  factory CloudSyncContentSelection.decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map || value['version'] is! int) {
      throw const FormatException('Invalid cloud backup content selection.');
    }
    final version = value['version'] as int;
    if (version == 1) return _decodeV1(value);
    if (version != currentSchemaVersion ||
        value.keys.any((key) => !_v2Keys.contains(key)) ||
        _boolKeys.any((key) => value[key] is! bool) ||
        value['selectedSkillIds'] is! List) {
      throw const FormatException('Invalid cloud backup content selection.');
    }
    return CloudSyncContentSelection(
      includeSettings: value['includeSettings']! as bool,
      includePromptsAndTags: value['includePromptsAndTags']! as bool,
      includeTagThumbnails: value['includeTagThumbnails']! as bool,
      includeOnlineGallerySettings:
          value['includeOnlineGallerySettings']! as bool,
      includeOnlineGalleryFavorites:
          value['includeOnlineGalleryFavorites']! as bool,
      includeGalleryAlbums: value['includeGalleryAlbums']! as bool,
      includeAgentSystemPrompt: value['includeAgentSystemPrompt']! as bool,
      includeSkills: value['includeSkills']! as bool,
      includeVibes: value['includeVibes']! as bool,
      includePreciseReferences: value['includePreciseReferences']! as bool,
      selectedSkillIds: _decodeSkillIds(value['selectedSkillIds']! as List),
    );
  }

  static CloudSyncContentSelection _decodeV1(Map<dynamic, dynamic> value) {
    const keys = {
      'version',
      'includeAgentSystemPrompt',
      'includeSkills',
      'selectedSkillIds',
    };
    if (value.keys.any((key) => !keys.contains(key)) ||
        value['includeAgentSystemPrompt'] is! bool ||
        value['includeSkills'] is! bool ||
        value['selectedSkillIds'] is! List) {
      throw const FormatException('Invalid cloud backup content selection.');
    }
    return CloudSyncContentSelection(
      includeAgentSystemPrompt: value['includeAgentSystemPrompt']! as bool,
      includeSkills: value['includeSkills']! as bool,
      selectedSkillIds: _decodeSkillIds(value['selectedSkillIds']! as List),
    );
  }

  static Set<String> _decodeSkillIds(List rawIds) {
    if (rawIds.length > maxSelectedSkills) {
      throw const FormatException('Too many selected Skills.');
    }
    final ids = <String>{};
    for (final id in rawIds) {
      if (id is! String || !_isValidSkillId(id) || !ids.add(id)) {
        throw const FormatException('Invalid selected Skill identity.');
      }
    }
    return Set.unmodifiable(ids);
  }

  static const _boolKeys = {
    'includeSettings',
    'includePromptsAndTags',
    'includeTagThumbnails',
    'includeOnlineGallerySettings',
    'includeOnlineGalleryFavorites',
    'includeGalleryAlbums',
    'includeAgentSystemPrompt',
    'includeSkills',
    'includeVibes',
    'includePreciseReferences',
  };
  static const _v2Keys = {'version', ..._boolKeys, 'selectedSkillIds'};

  static final RegExp _skillId = RegExp(
    r'^(workspace|piUser|commonUser):[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$',
  );

  static bool _isValidSkillId(String value) =>
      _skillId.hasMatch(value) && !value.contains('--');
}
