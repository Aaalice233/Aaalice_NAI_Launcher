import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'fixed_tag_entry.dart';
import 'fixed_tag_prompt_type.dart';

/// The fixed-tag configuration that was actually applied to one generation.
class FixedTagUsageSnapshot {
  const FixedTagUsageSnapshot({this.version = 1, this.entries = const []});

  factory FixedTagUsageSnapshot.capture(Iterable<FixedTagEntry> entries) {
    final enabled = entries.where((entry) => entry.enabled).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return FixedTagUsageSnapshot(
      entries: [
        for (var index = 0; index < enabled.length; index++)
          FixedTagUsageEntry.fromFixedTag(enabled[index], order: index),
      ],
    );
  }

  factory FixedTagUsageSnapshot.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return FixedTagUsageSnapshot(
      version: (json['version'] as num?)?.toInt() ?? 1,
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map(
                  (entry) => FixedTagUsageEntry.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  final int version;
  final List<FixedTagUsageEntry> entries;

  Map<String, dynamic> toJson() => {
    'version': version,
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
  };

  String get fingerprint =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  List<FixedTagUsageEntry> entriesFor({
    required FixedTagPromptType promptType,
    required FixedTagPosition position,
  }) => entries
      .where(
        (entry) => entry.promptType == promptType && entry.position == position,
      )
      .toList(growable: false);
}

class FixedTagUsageEntry {
  const FixedTagUsageEntry({
    this.fixedTagId,
    required this.name,
    required this.content,
    required this.weight,
    required this.renderedContent,
    required this.position,
    required this.promptType,
    required this.order,
  });

  factory FixedTagUsageEntry.fromFixedTag(
    FixedTagEntry entry, {
    required int order,
  }) => FixedTagUsageEntry(
    fixedTagId: entry.id,
    name: entry.name,
    content: entry.content,
    weight: entry.weight,
    renderedContent: entry.weightedContent,
    position: entry.position,
    promptType: entry.promptType,
    order: order,
  );

  factory FixedTagUsageEntry.legacy({
    required String renderedContent,
    required FixedTagPosition position,
    required FixedTagPromptType promptType,
    required int order,
  }) => FixedTagUsageEntry(
    name: renderedContent,
    content: renderedContent,
    weight: 1,
    renderedContent: renderedContent,
    position: position,
    promptType: promptType,
    order: order,
  );

  factory FixedTagUsageEntry.fromJson(Map<String, dynamic> json) {
    final position = FixedTagPosition.values.firstWhere(
      (value) => value.name == json['position'],
      orElse: () => FixedTagPosition.prefix,
    );
    final promptType = FixedTagPromptType.values.firstWhere(
      (value) => value.name == json['prompt_type'],
      orElse: () => FixedTagPromptType.positive,
    );
    final content = json['content'] as String? ?? '';
    final weight = (json['weight'] as num?)?.toDouble() ?? 1;
    return FixedTagUsageEntry(
      fixedTagId: json['fixed_tag_id'] as String?,
      name: json['name'] as String? ?? content,
      content: content,
      weight: weight,
      renderedContent:
          json['rendered_content'] as String? ??
          FixedTagEntry.applyWeight(content, weight),
      position: position,
      promptType: promptType,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String? fixedTagId;
  final String name;
  final String content;
  final double weight;
  final String renderedContent;
  final FixedTagPosition position;
  final FixedTagPromptType promptType;
  final int order;

  Map<String, dynamic> toJson() => {
    if (fixedTagId != null) 'fixed_tag_id': fixedTagId,
    'name': name,
    'content': content,
    'weight': weight,
    'rendered_content': renderedContent,
    'position': position.name,
    'prompt_type': promptType.name,
    'order': order,
  };
}

class FixedTagScope {
  const FixedTagScope(this.promptType, this.position);

  final FixedTagPromptType promptType;
  final FixedTagPosition position;

  @override
  bool operator ==(Object other) =>
      other is FixedTagScope &&
      other.promptType == promptType &&
      other.position == position;

  @override
  int get hashCode => Object.hash(promptType, position);
}
