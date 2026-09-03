import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/agent/skill_archive_service.dart';
import '../../core/agent/skill_catalog.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../models/agent/agent_settings.dart';
import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

class AgentSystemPromptCloudSyncAdapter extends ValidatingCloudSyncDataAdapter {
  AgentSystemPromptCloudSyncAdapter(this._storage);

  final LocalStorageService _storage;

  @override
  String get id => 'agent-system-prompt';

  @override
  Set<String> get allowedKinds => const {'configuration'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    final raw = _storage.getSetting<String>(StorageKeys.agentSettingsJson);
    final settings = raw == null || raw.isEmpty
        ? const AgentSettings().toJson()
        : _jsonMap(jsonDecode(raw), 'Agent settings');
    final chat = _jsonMap(settings['chat'], 'Agent chat settings');
    final prompt = chat['customSystemPrompt'];
    final mode = chat['systemPromptMode'];
    if (prompt is! String ||
        prompt.length > AgentSettings.maxCustomPromptLength ||
        (mode != null && mode != 'append' && mode != 'override')) {
      throw const CloudSyncPreflightException(
        'Agent system prompt settings are invalid',
      );
    }
    yield PortableSyncRecord(
      adapterId: id,
      id: 'custom',
      kind: 'configuration',
      data: {
        'version': 1,
        'customSystemPrompt': prompt,
        'systemPromptMode': mode,
      },
    );
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.deleted) {
      if (record.id != 'custom' ||
          record.resource != null ||
          record.data.isNotEmpty) {
        throw const CloudSyncPreflightException(
          'Invalid Agent system prompt tombstone',
        );
      }
      return;
    }
    final localChat = _storedAgentChat();
    final mode = record.data['systemPromptMode'];
    if (record.id != 'custom' ||
        record.resource != null ||
        record.data.keys.toSet().difference(const {
          'version',
          'customSystemPrompt',
          'systemPromptMode',
        }).isNotEmpty ||
        record.data['version'] != 1 ||
        record.data['customSystemPrompt'] is! String ||
        (record.data['customSystemPrompt']! as String).length >
            AgentSettings.maxCustomPromptLength ||
        (mode != null && mode != 'append' && mode != 'override')) {
      throw const CloudSyncPreflightException(
        'Invalid Agent system prompt backup',
      );
    }
    if (mode != null && !localChat.containsKey('systemPromptMode')) {
      throw const CloudSyncPreflightException(
        'This app version cannot restore the system prompt mode',
      );
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    for (final record in records) {
      final raw = _storage.getSetting<String>(StorageKeys.agentSettingsJson);
      final settings = raw == null || raw.isEmpty
          ? const AgentSettings().toJson()
          : _jsonMap(jsonDecode(raw), 'Agent settings');
      final chat = _jsonMap(settings['chat'], 'Agent chat settings');
      if (record.deleted) {
        final defaults = _jsonMap(
          const AgentSettings().toJson()['chat'],
          'Default Agent chat settings',
        );
        chat['customSystemPrompt'] = defaults['customSystemPrompt'];
        chat['systemPromptMode'] = defaults['systemPromptMode'];
      } else {
        chat['customSystemPrompt'] = record.data['customSystemPrompt'];
        final mode = record.data['systemPromptMode'];
        if (mode != null) chat['systemPromptMode'] = mode;
      }
      settings['chat'] = chat;
      await _storage.setSetting(
        StorageKeys.agentSettingsJson,
        jsonEncode(settings),
      );
    }
  }

  Map<String, dynamic> _storedAgentChat() {
    final raw = _storage.getSetting<String>(StorageKeys.agentSettingsJson);
    if (raw == null || raw.isEmpty) {
      return _jsonMap(
        const AgentSettings().toJson()['chat'],
        'Agent chat settings',
      );
    }
    final settings = _jsonMap(jsonDecode(raw), 'Agent settings');
    return _jsonMap(settings['chat'], 'Agent chat settings');
  }
}

class AgentSkillsCloudSyncAdapter extends ValidatingCloudSyncDataAdapter {
  AgentSkillsCloudSyncAdapter({
    required List<SkillRoot> roots,
    required List<SkillCatalogEntry> localEntries,
    required Set<String> selectedSkillIds,
    SkillArchiveService archiveService = const SkillArchiveService(),
  }) : _roots = {for (final root in roots) root.source: Directory(root.path)},
       _localEntries = List.unmodifiable(localEntries),
       _selectedSkillIds = Set.unmodifiable(selectedSkillIds),
       _archiveService = archiveService;

  final Map<SkillSource, Directory> _roots;
  final List<SkillCatalogEntry> _localEntries;
  final Set<String> _selectedSkillIds;
  final SkillArchiveService _archiveService;
  List<_SkillRestorePlan>? _preparedRestorePlans;
  List<PortableSyncRecord>? _preparedRecords;

  @override
  String get id => 'agent-skills';

  @override
  Set<String> get allowedKinds => const {'selection', 'skill'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    if (_selectedSkillIds.length > 500) {
      throw const CloudSyncPreflightException(
        'Too many Skills were selected for backup',
      );
    }
    final selectedEntries = <SkillCatalogEntry>[];
    for (final backupId in _selectedSkillIds) {
      final matches = _localEntries
          .where((entry) => entry.backupId == backupId)
          .toList(growable: false);
      if (matches.length != 1) {
        throw CloudSyncPreflightException(
          'Selected Skill $backupId is missing or ambiguous',
        );
      }
      selectedEntries.add(matches.single);
    }
    selectedEntries.sort((a, b) => a.backupId.compareTo(b.backupId));
    yield PortableSyncRecord(
      adapterId: id,
      id: 'selection',
      kind: 'selection',
      data: {
        'version': 1,
        'skillIds': [for (final entry in selectedEntries) entry.backupId],
      },
    );
    for (final entry in selectedEntries) {
      final bytes = await _archiveService.exportSkills([
        (name: entry.id, manifest: File(entry.skill.filePath)),
      ]);
      yield PortableSyncRecord(
        adapterId: id,
        id: entry.backupId,
        kind: 'skill',
        data: {
          'version': 1,
          'skillId': entry.backupId,
          'name': entry.id,
          'source': entry.source.name,
        },
        resource: PortableSyncResource(
          relativePath: 'agent-skills/${entry.source.name}/${entry.id}.zip',
          mediaType: 'application/zip',
          length: bytes.length,
          openRead: () => Stream.value(bytes),
        ),
      );
    }
  }

  @override
  Future<void> preflight(List<PortableSyncRecord> records) async {
    _preparedRestorePlans = null;
    _preparedRecords = null;
    await super.preflight(records);
    if (records.every((record) => record.deleted)) {
      _preparedRestorePlans = const [];
      _preparedRecords = records;
      return;
    }
    _validateSelectionGraph(records);
    _preparedRestorePlans = await _prepareRestorePlans(records);
    _preparedRecords = records;
  }

  void _validateSelectionGraph(List<PortableSyncRecord> records) {
    final selections = records
        .where((record) => record.kind == 'selection' && !record.deleted)
        .toList(growable: false);
    if (selections.length != 1) {
      throw const CloudSyncPreflightException(
        'Skill backup must contain one selection record',
      );
    }
    final selected = (selections.single.data['skillIds']! as List)
        .cast<String>()
        .toSet();
    final liveSkills = records
        .where((record) => record.kind == 'skill' && !record.deleted)
        .map((record) => record.id)
        .toSet();
    if (selected.length !=
            (selections.single.data['skillIds']! as List).length ||
        selected.length > 500 ||
        selected.length != liveSkills.length ||
        !selected.containsAll(liveSkills)) {
      throw const CloudSyncPreflightException(
        'Skill selection does not match its archived Skills',
      );
    }
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.kind == 'selection') {
      if (record.deleted) {
        if (record.id != 'selection' ||
            record.resource != null ||
            record.data.isNotEmpty) {
          throw const CloudSyncPreflightException(
            'Invalid Skill selection tombstone',
          );
        }
        return;
      }
      final ids = record.data['skillIds'];
      if (record.id != 'selection' ||
          record.resource != null ||
          record.data.keys.toSet().difference(const {
            'version',
            'skillIds',
          }).isNotEmpty ||
          record.data['version'] != 1 ||
          ids is! List ||
          !ids.every((value) => value is String && _isValidBackupId(value))) {
        throw const CloudSyncPreflightException(
          'Invalid Skill selection backup',
        );
      }
      return;
    }
    if (record.deleted) {
      if (record.resource != null ||
          record.data.isNotEmpty ||
          !_isValidBackupId(record.id)) {
        throw const CloudSyncPreflightException('Invalid Skill tombstone');
      }
      return;
    }
    final source = record.data['source'];
    final name = record.data['name'];
    final skillId = record.data['skillId'];
    if (record.data.keys.toSet().difference(const {
          'version',
          'skillId',
          'name',
          'source',
        }).isNotEmpty ||
        record.data['version'] != 1 ||
        source is! String ||
        name is! String ||
        skillId != record.id ||
        !_isValidBackupId(record.id)) {
      throw const CloudSyncPreflightException('Invalid archived Skill');
    }
    final parsed = parseSkillBackupId(record.id);
    if (parsed.source.name != source || parsed.name != name) {
      throw const CloudSyncPreflightException(
        'Archived Skill identity does not match its source',
      );
    }
    final resource = record.resource;
    if (resource == null ||
        resource.mediaType != 'application/zip' ||
        resource.length <= 0 ||
        resource.length > SkillArchiveService.maxArchiveBytes ||
        resource.relativePath != 'agent-skills/$source/$name.zip') {
      throw const CloudSyncPreflightException('Invalid Skill archive');
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    _validateSelectionGraph(records);
    final plans = identical(records, _preparedRecords)
        ? _preparedRestorePlans!
        : await _prepareRestorePlans(records);
    _preparedRestorePlans = null;
    _preparedRecords = null;
    for (final plan in plans) {
      await _archiveService.install(
        bytes: plan.bytes,
        targetDirectory: plan.target,
        replaceSkillNames: plan.replace ? {plan.name} : const {},
      );
    }
  }

  Future<List<_SkillRestorePlan>> _prepareRestorePlans(
    List<PortableSyncRecord> records,
  ) async {
    final remoteSelection =
        records
                .singleWhere((record) => record.kind == 'selection')
                .data['skillIds']!
            as List;
    final remoteSelectedIds = remoteSelection.cast<String>().toSet();
    final plans = <_SkillRestorePlan>[];
    for (final record in records) {
      if (record.kind != 'skill' || record.deleted) continue;
      final parsed = parseSkillBackupId(record.id);
      final target = _roots[parsed.source];
      if (target == null) {
        throw CloudSyncPreflightException(
          'The ${parsed.source.name} Skill source is unavailable',
        );
      }
      if (await _hasInterruptedInstall(target)) {
        throw CloudSyncPreflightException(
          'The ${parsed.source.name} Skill source requires recovery first',
        );
      }
      final bytes = await _readArchive(record.resource!);
      final preview = await _archiveService.previewImport(
        bytes: bytes,
        targetDirectory: target,
        recoverInterruptedTransactions: false,
      );
      if (preview.items.length != 1 ||
          preview.items.single.name != parsed.name) {
        throw const CloudSyncPreflightException(
          'Skill archive identity does not match its record',
        );
      }
      final localMatches = _localEntries
          .where((entry) => entry.backupId == record.id)
          .toList(growable: false);
      if (localMatches.length > 1) {
        throw CloudSyncPreflightException(
          'Local Skill ${record.id} is ambiguous',
        );
      }
      if (localMatches.length == 1) {
        final local = localMatches.single;
        final localBytes = await _archiveService.exportSkills([
          (name: local.id, manifest: File(local.skill.filePath)),
        ]);
        if (sha256.convert(localBytes) == sha256.convert(bytes)) continue;
        final normalizedTarget = p.normalize(
          p.join(target.path, parsed.name, 'SKILL.md'),
        );
        if (!remoteSelectedIds.contains(record.id) ||
            p.normalize(local.skill.filePath) != normalizedTarget) {
          throw CloudSyncPreflightException(
            'Skill ${record.id} conflicts with a different local source',
          );
        }
      }
      final item = preview.items.single;
      if (item.conflicts &&
          (!item.canReplace || !remoteSelectedIds.contains(record.id))) {
        throw CloudSyncPreflightException(
          'Skill ${record.id} conflicts with a non-replaceable target',
        );
      }
      plans.add(
        _SkillRestorePlan(
          name: parsed.name,
          target: target,
          bytes: bytes,
          replace: item.conflicts,
        ),
      );
    }
    return plans;
  }

  Future<bool> _hasInterruptedInstall(Directory target) async {
    if (!await target.exists()) return false;
    await for (final entity in target.list(followLinks: false)) {
      if (p.basename(entity.path).startsWith('.skill-import-')) return true;
    }
    return false;
  }

  Future<Uint8List> _readArchive(PortableSyncResource resource) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in resource.openRead()) {
      length += chunk.length;
      if (length > resource.length ||
          length > SkillArchiveService.maxArchiveBytes) {
        throw const CloudSyncPreflightException(
          'Skill archive length exceeds its declaration',
        );
      }
      builder.add(chunk);
    }
    if (length != resource.length) {
      throw const CloudSyncPreflightException(
        'Skill archive length does not match its declaration',
      );
    }
    return builder.takeBytes();
  }

  bool _isValidBackupId(String value) {
    try {
      parseSkillBackupId(value);
      return true;
    } on FormatException {
      return false;
    }
  }
}

class _SkillRestorePlan {
  const _SkillRestorePlan({
    required this.name,
    required this.target,
    required this.bytes,
    required this.replace,
  });

  final String name;
  final Directory target;
  final Uint8List bytes;
  final bool replace;
}

Map<String, dynamic> _jsonMap(Object? value, String name) {
  if (value is! Map) throw CloudSyncPreflightException('$name is invalid');
  return value.map((key, value) {
    if (key is! String) {
      throw CloudSyncPreflightException('$name has a non-string field');
    }
    return MapEntry(key, value);
  });
}
