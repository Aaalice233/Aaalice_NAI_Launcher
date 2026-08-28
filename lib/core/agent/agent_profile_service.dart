import 'dart:convert';

import '../../data/models/agent/agent_settings.dart';
import 'private_data_guard.dart';

class AgentProfilePreview {
  const AgentProfilePreview({
    required this.settings,
    required this.changes,
    required this.warnings,
  });

  final AgentSettings settings;
  final List<String> changes;
  final List<String> warnings;
}

class AgentProfileService {
  const AgentProfileService();

  static const int schemaVersion = 1;
  static const int maxProfileBytes = 1024 * 1024;

  String exportProfile(AgentSettings settings) {
    final payload = <String, Object?>{
      'format': 'aaalice-agent-profile',
      'schemaVersion': schemaVersion,
      'settings': settings.toJson(),
    };
    _assertPortable(payload);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  AgentProfilePreview previewImport({
    required String raw,
    required AgentSettings current,
    Set<String> availableModelReferences = const {},
    Set<String> availableSkillIds = const {},
  }) {
    if (utf8.encode(raw).length > maxProfileBytes) {
      throw const FormatException('Agent profile exceeds the size limit.');
    }
    final privateData = PrivateDataGuard.detect(raw);
    if (privateData != null) {
      throw FormatException('Agent profile contains $privateData.');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['format'] != 'aaalice-agent-profile' ||
        decoded['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported Agent profile format.');
    }
    const allowedTopLevel = {'format', 'schemaVersion', 'settings'};
    if (decoded.keys.any((key) => !allowedTopLevel.contains(key))) {
      throw const FormatException('Agent profile contains unknown fields.');
    }
    _assertPortable(decoded);
    final settingsValue = decoded['settings'];
    if (settingsValue is! Map) {
      throw const FormatException('Agent profile settings must be an object.');
    }
    final imported = AgentSettings.decode(jsonEncode(settingsValue));
    final changes = <String>[];
    final warnings = <String>[];
    if (current.chat.modelReference != imported.chat.modelReference) {
      changes.add('chatModel');
    }
    if (current.chat.permissionMode != imported.chat.permissionMode) {
      changes.add('permissionMode');
    }
    if (current.chat.webAccessEnabled != imported.chat.webAccessEnabled) {
      changes.add('webAccess');
    }
    if (current.chat.customSystemPrompt != imported.chat.customSystemPrompt) {
      changes.add('customSystemPrompt');
    }
    if (!_sameSet(current.disabledSkillIds, imported.disabledSkillIds)) {
      changes.add('skillPreferences');
    }

    final model = imported.chat.modelReference;
    final modelId = '${model.providerId}/${model.model}';
    if (model.isConfigured && !availableModelReferences.contains(modelId)) {
      warnings.add('unmatchedModel:$modelId');
    }
    for (final skillId in imported.disabledSkillIds) {
      if (!availableSkillIds.contains(skillId)) {
        warnings.add('unmatchedSkill:$skillId');
      }
    }
    return AgentProfilePreview(
      settings: imported,
      changes: changes,
      warnings: warnings,
    );
  }

  bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  void _assertPortable(Object? value, [String key = '']) {
    if (value is Map) {
      for (final entry in value.entries) {
        final field = entry.key.toString();
        if (RegExp(
          r'(api.?key|access.?token|refresh.?token|authorization|chat.?history)',
          caseSensitive: false,
        ).hasMatch(field)) {
          throw FormatException('Agent profile cannot contain $field.');
        }
        _assertPortable(entry.value, field);
      }
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        _assertPortable(item, key);
      }
      return;
    }
    if (value is! String) return;
    final privateDataKind = PrivateDataGuard.detect(value);
    if (privateDataKind != null) {
      throw FormatException(
        'Agent profile field $key contains a non-portable $privateDataKind.',
      );
    }
  }
}
