import 'dart:collection';

class GalleryBlacklistTagNormalizer {
  const GalleryBlacklistTagNormalizer._();

  static String? normalize(String value) {
    var normalized = value.trim().toLowerCase();
    while (normalized.startsWith('-')) {
      normalized = normalized.substring(1).trimLeft();
    }
    normalized = normalized.replaceAll(RegExp(r'\s+'), '_');
    if (normalized.isEmpty ||
        normalized.contains(':') ||
        normalized.contains('*') ||
        normalized.startsWith('~')) {
      return null;
    }
    return normalized;
  }

  static Set<String> normalizeAll(Iterable<String> values) =>
      values.map(normalize).whereType<String>().toSet();

  static String? simpleCloudRule(String rule) {
    final trimmed = rule.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return null;
    if (trimmed.startsWith('-') ||
        trimmed.startsWith('~') ||
        trimmed.contains(':') ||
        trimmed.contains('*')) {
      return null;
    }
    return normalize(trimmed);
  }
}

class GalleryBlacklistRemoteSnapshot {
  const GalleryBlacklistRemoteSnapshot({
    required this.accountKey,
    required this.rules,
    required this.lastSyncAt,
    this.lastError,
  });

  final String accountKey;
  final List<String> rules;
  final DateTime lastSyncAt;
  final String? lastError;

  Set<String> get simpleTags => {
    for (final rule in rules)
      if (GalleryBlacklistTagNormalizer.simpleCloudRule(rule) case final tag?)
        tag,
  };

  List<String> get opaqueRules => [
    for (final rule in rules)
      if (GalleryBlacklistTagNormalizer.simpleCloudRule(rule) == null) rule,
  ];

  GalleryBlacklistRemoteSnapshot copyWith({
    List<String>? rules,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    return GalleryBlacklistRemoteSnapshot(
      accountKey: accountKey,
      rules: rules ?? this.rules,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, Object?> toJson() => {
    'accountKey': accountKey,
    'rules': rules,
    'lastSyncAt': lastSyncAt.millisecondsSinceEpoch,
    if (lastError != null) 'lastError': lastError,
  };

  factory GalleryBlacklistRemoteSnapshot.fromJson(Map<String, dynamic> json) {
    return GalleryBlacklistRemoteSnapshot(
      accountKey: json['accountKey']?.toString() ?? '',
      rules: (json['rules'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((rule) => rule.trim())
          .where((rule) => rule.isNotEmpty)
          .toList(growable: false),
      lastSyncAt: DateTime.fromMillisecondsSinceEpoch(
        json['lastSyncAt'] is int ? json['lastSyncAt'] as int : 0,
      ),
      lastError: json['lastError']?.toString(),
    );
  }
}

class GalleryBlacklistStore {
  static const currentSchemaVersion = 2;

  const GalleryBlacklistStore({
    this.schemaVersion = currentSchemaVersion,
    this.revision = 0,
    this.desiredTags = const {},
    this.tombstones = const {},
    this.pendingRemoteDeletions = const {},
    this.remoteSnapshots = const {},
    this.legacyUnscopedRules = const [],
    this.legacyUnscopedLastSyncAt,
  });

  final int schemaVersion;
  final int revision;
  final Set<String> desiredTags;
  final Set<String> tombstones;
  final Set<String> pendingRemoteDeletions;
  final Map<String, GalleryBlacklistRemoteSnapshot> remoteSnapshots;
  final List<String> legacyUnscopedRules;
  final DateTime? legacyUnscopedLastSyncAt;

  GalleryBlacklistStore copyWith({
    int? revision,
    Set<String>? desiredTags,
    Set<String>? tombstones,
    Set<String>? pendingRemoteDeletions,
    Map<String, GalleryBlacklistRemoteSnapshot>? remoteSnapshots,
    List<String>? legacyUnscopedRules,
    DateTime? legacyUnscopedLastSyncAt,
    bool clearLegacyUnscopedLastSyncAt = false,
  }) {
    return GalleryBlacklistStore(
      revision: revision ?? this.revision,
      desiredTags: desiredTags ?? this.desiredTags,
      tombstones: tombstones ?? this.tombstones,
      pendingRemoteDeletions:
          pendingRemoteDeletions ?? this.pendingRemoteDeletions,
      remoteSnapshots: remoteSnapshots ?? this.remoteSnapshots,
      legacyUnscopedRules: legacyUnscopedRules ?? this.legacyUnscopedRules,
      legacyUnscopedLastSyncAt: clearLegacyUnscopedLastSyncAt
          ? null
          : (legacyUnscopedLastSyncAt ?? this.legacyUnscopedLastSyncAt),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'revision': revision,
    'desiredTags': desiredTags.toList()..sort(),
    'tombstones': tombstones.toList()..sort(),
    'pendingRemoteDeletions': pendingRemoteDeletions.toList()..sort(),
    'legacyUnscopedRules': legacyUnscopedRules,
    if (legacyUnscopedLastSyncAt != null)
      'legacyUnscopedLastSyncAt':
          legacyUnscopedLastSyncAt!.millisecondsSinceEpoch,
    'remoteSnapshots': {
      for (final entry in remoteSnapshots.entries)
        entry.key: entry.value.toJson(),
    },
  };

  factory GalleryBlacklistStore.fromJson(Map<String, dynamic> json) {
    final rawSnapshots = json['remoteSnapshots'];
    final snapshots = <String, GalleryBlacklistRemoteSnapshot>{};
    if (rawSnapshots is Map) {
      for (final entry in rawSnapshots.entries) {
        if (entry.value is! Map) continue;
        final snapshot = GalleryBlacklistRemoteSnapshot.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (snapshot.accountKey.isNotEmpty) {
          snapshots[entry.key.toString()] = snapshot;
        }
      }
    }
    return GalleryBlacklistStore(
      schemaVersion: json['schemaVersion'] is int
          ? json['schemaVersion'] as int
          : currentSchemaVersion,
      revision: json['revision'] is int ? json['revision'] as int : 0,
      desiredTags: Set.unmodifiable(
        GalleryBlacklistTagNormalizer.normalizeAll(
          (json['desiredTags'] as List<dynamic>? ?? const [])
              .whereType<String>(),
        ),
      ),
      tombstones: Set.unmodifiable(
        GalleryBlacklistTagNormalizer.normalizeAll(
          (json['tombstones'] as List<dynamic>? ?? const [])
              .whereType<String>(),
        ),
      ),
      pendingRemoteDeletions: Set.unmodifiable(
        GalleryBlacklistTagNormalizer.normalizeAll(
          (json['pendingRemoteDeletions'] as List<dynamic>? ?? const [])
              .whereType<String>(),
        ),
      ),
      remoteSnapshots: Map.unmodifiable(snapshots),
      legacyUnscopedRules: List.unmodifiable(
        (json['legacyUnscopedRules'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .where((rule) => rule.trim().isNotEmpty),
      ),
      legacyUnscopedLastSyncAt: json['legacyUnscopedLastSyncAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(
              json['legacyUnscopedLastSyncAt'] as int,
            )
          : null,
    );
  }
}

class GalleryBlacklistPullResult {
  const GalleryBlacklistPullResult({
    required this.addedCount,
    required this.existingCount,
    required this.skippedDeletedCount,
    required this.opaqueRuleCount,
  });

  final int addedCount;
  final int existingCount;
  final int skippedDeletedCount;
  final int opaqueRuleCount;
}

class GalleryBlacklistPushPreview {
  const GalleryBlacklistPushPreview({
    required this.accountKey,
    required this.localRevision,
    required this.remoteRules,
    required this.targetSimpleTagCount,
    required this.addedTags,
    required this.removedTags,
    required this.opaqueRulesToRemove,
    this.containsLegacyUnscopedData = false,
  });

  final String accountKey;
  final int localRevision;
  final List<String> remoteRules;
  final int targetSimpleTagCount;
  final Set<String> addedTags;
  final Set<String> removedTags;
  final List<String> opaqueRulesToRemove;
  final bool containsLegacyUnscopedData;

  bool get requiresEmptyConfirmation =>
      targetSimpleTagCount == 0 && remoteRules.isNotEmpty;

  bool get isEmpty =>
      !containsLegacyUnscopedData &&
      addedTags.isEmpty &&
      removedTags.isEmpty &&
      opaqueRulesToRemove.isEmpty;
}

enum GalleryBlacklistSyncPhase {
  idle,
  pulling,
  preparingPush,
  pushing,
  verifying,
}

class GalleryBlacklistUndo {
  const GalleryBlacklistUndo({
    required this.desiredTags,
    required this.tombstones,
    required this.pendingRemoteDeletions,
    this.syncCompensation = true,
  });

  final Set<String> desiredTags;
  final Set<String> tombstones;
  final Set<String> pendingRemoteDeletions;
  final bool syncCompensation;
}

UnmodifiableSetView<String> immutableTagSet(Iterable<String> tags) =>
    UnmodifiableSetView(Set<String>.of(tags));
