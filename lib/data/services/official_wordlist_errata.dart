import 'package:collection/collection.dart';

import '../../core/utils/app_logger.dart';
import '../models/prompt/official_wordlist.dart';

/// A correction for a record that the source-locked asset keeps verbatim.
///
/// The record is located by generator, group and its complete original
/// content, never by position, so a reordered asset still matches and a record
/// that upstream has since changed is left untouched.
class OfficialWordlistErratum {
  const OfficialWordlistErratum({
    required this.generatorId,
    required this.groupId,
    required this.original,
    required this.corrected,
    required this.reason,
  });

  final String generatorId;
  final String groupId;
  final List<Object?> original;
  final List<Object?> corrected;
  final String reason;

  Object? get value => original.first;

  bool matches(OfficialWordlistEntry entry) =>
      const DeepCollectionEquality().equals(entry.raw, original);
}

const officialWordlistErrata = <OfficialWordlistErratum>[
  OfficialWordlistErratum(
    generatorId: 'characterPrompts',
    groupId: 'dk',
    original: [
      'socks',
      12,
      [],
      ['feel'],
      [],
    ],
    corrected: [
      'socks',
      12,
      [],
      ['feet'],
      [],
    ],
    reason: 'No record provides feel; every other sock requires feet.',
  ),
  OfficialWordlistErratum(
    generatorId: 'characterPrompts',
    groupId: 'dT',
    original: [
      'opaque glasses',
      12,
      12,
      [],
      [],
      ['eyes'],
    ],
    corrected: [
      'opaque glasses',
      12,
      [],
      [],
      ['eyes'],
    ],
    reason:
        'A doubled weight pushes the eyes exclusion that coke-bottle glasses '
        'keeps into the ignored trailing field.',
  ),
  OfficialWordlistErratum(
    generatorId: 'characterPrompts',
    groupId: 'dz',
    original: [
      'ocean',
      12,
      'location',
      [],
      ['location'],
    ],
    corrected: [
      'ocean',
      12,
      ['location'],
      [],
      ['location'],
    ],
    reason:
        'Declared flags must be a list; the bare string provided nothing, so '
        'a second location could follow.',
  ),
  OfficialWordlistErratum(
    generatorId: 'characterPrompts',
    groupId: 'dE',
    original: ['sleeping', 12, [], [], []],
    corrected: [
      'sleeping',
      12,
      ['eyes'],
      [],
      ['eyes', 'noeyes'],
    ],
    reason:
        'Sleeping implies closed eyes, which carry these flags; upstream '
        'Legacy and Furry likewise drop eye colors for it.',
  ),
  OfficialWordlistErratum(
    generatorId: 'characterPrompts',
    groupId: 'dR',
    original: ['^_^', 12, [], [], []],
    corrected: [
      '^_^',
      12,
      ['eyes'],
      [],
      ['eyes', 'noeyes'],
    ],
    reason:
        'The other record of this closed-eyes emoticon carries these flags; '
        'both records stay.',
  ),
];

final _correctedWordlists = Expando<OfficialWordlist>('officialWordlistErrata');

/// Corrects each loaded wordlist once; a reloaded asset is corrected afresh.
OfficialWordlist correctedOfficialWordlist(OfficialWordlist source) =>
    _correctedWordlists[source] ??= applyOfficialWordlistErrata(source);

/// Returns [source] with every matching erratum applied, reporting each
/// erratum of this generator that no longer matches any record to [onSkipped].
OfficialWordlist applyOfficialWordlistErrata(
  OfficialWordlist source, {
  Iterable<OfficialWordlistErratum> errata = officialWordlistErrata,
  void Function(OfficialWordlistErratum erratum) onSkipped = _logSkippedErratum,
}) {
  final pending = errata
      .where((erratum) => erratum.generatorId == source.id)
      .toList(growable: false);
  if (pending.isEmpty) return source;
  final applied = <OfficialWordlistErratum>{};
  final groups = [
    for (final group in source.groups) _correctGroup(group, pending, applied),
  ];
  for (final erratum in pending) {
    if (!applied.contains(erratum)) onSkipped(erratum);
  }
  if (applied.isEmpty) return source;
  return OfficialWordlist(
    id: source.id,
    entryFields: source.entryFields,
    groups: groups,
    declaredEntryCount: source.entryCount,
  );
}

OfficialWordlistGroup _correctGroup(
  OfficialWordlistGroup group,
  List<OfficialWordlistErratum> errata,
  Set<OfficialWordlistErratum> applied,
) {
  final groupErrata = errata
      .where((erratum) => erratum.groupId == group.id)
      .toList(growable: false);
  if (groupErrata.isEmpty) return group;
  final entries = <OfficialWordlistEntry>[];
  for (final entry in group.entries) {
    final erratum = groupErrata.firstWhereOrNull(
      (erratum) => erratum.matches(entry),
    );
    if (erratum == null) {
      entries.add(entry);
      continue;
    }
    applied.add(erratum);
    entries.add(
      OfficialWordlistEntry.fromRaw(groupId: group.id, raw: erratum.corrected),
    );
  }
  return OfficialWordlistGroup(
    id: group.id,
    semantic: group.semantic,
    entries: entries,
  );
}

void _logSkippedErratum(OfficialWordlistErratum erratum) {
  AppLogger.d(
    'Skipped official wordlist erratum ${erratum.generatorId}/'
        '${erratum.groupId} "${erratum.value}": the asset record has changed',
    'RandomGen',
  );
}
