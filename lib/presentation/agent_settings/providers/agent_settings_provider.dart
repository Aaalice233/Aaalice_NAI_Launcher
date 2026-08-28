import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/agent/skill_catalog.dart';
import '../../../core/agent/skill_archive_service.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/web_access/web_access_models.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/agent/agent_settings.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';

class AgentSettingsState {
  const AgentSettingsState({
    this.settings = const AgentSettings(),
    this.skills = const SkillCatalogSnapshot(),
    this.initialized = false,
    this.refreshingSkills = false,
    this.error = '',
  });

  final AgentSettings settings;
  final SkillCatalogSnapshot skills;
  final bool initialized;
  final bool refreshingSkills;
  final String error;

  AgentSettingsState copyWith({
    AgentSettings? settings,
    SkillCatalogSnapshot? skills,
    bool? initialized,
    bool? refreshingSkills,
    String? error,
  }) => AgentSettingsState(
    settings: settings ?? this.settings,
    skills: skills ?? this.skills,
    initialized: initialized ?? this.initialized,
    refreshingSkills: refreshingSkills ?? this.refreshingSkills,
    error: error ?? this.error,
  );
}

final agentSettingsProvider =
    StateNotifierProvider<AgentSettingsNotifier, AgentSettingsState>(
      (ref) => AgentSettingsNotifier(ref),
    );

class AgentSettingsNotifier extends StateNotifier<AgentSettingsState> {
  AgentSettingsNotifier(
    this._ref, {
    Directory? supportDirectory,
    Directory? workspaceDirectory,
    Map<String, String>? environment,
    SkillCatalogService? skillCatalogService,
  }) : _supportDirectory = supportDirectory,
       _workspaceDirectory = workspaceDirectory,
       _environment = environment,
       _skillCatalogService =
           skillCatalogService ?? const SkillCatalogService(),
       super(const AgentSettingsState()) {
    unawaited(_load());
  }

  final Ref _ref;
  final SkillCatalogService _skillCatalogService;
  Directory? _workspaceDirectory;
  Directory? _supportDirectory;
  final Map<String, String>? _environment;
  Future<void> _mutationQueue = Future.value();

  LocalStorageService get _local => _ref.read(localStorageServiceProvider);

  Future<void> _load() async {
    state = state.copyWith(initialized: false, error: '');
    try {
      final raw = _local.getSetting<String>(StorageKeys.agentSettingsJson);
      AgentSettings settings;
      if (raw != null) {
        settings = AgentSettings.decode(raw);
        await _removeLegacyAgentFields(
          _local.getSetting<String>(StorageKeys.promptAssistantConfigJson),
        );
      } else {
        settings = await _migrateLegacy();
      }
      if (!mounted) return;
      state = state.copyWith(settings: settings, error: '');
      await reloadSkills();
      if (!mounted) return;
      state = state.copyWith(initialized: true, error: '');
    } catch (error) {
      AppLogger.e(
        'Agent settings initialization failed',
        error,
        null,
        'AgentSettings',
      );
      if (mounted) {
        state = state.copyWith(initialized: true, error: error.toString());
      }
    }
  }

  Future<AgentSettings> _migrateLegacy() async {
    var promptConfig = PromptAssistantConfigState.defaults();
    final promptRaw = _local.getSetting<String>(
      StorageKeys.promptAssistantConfigJson,
    );
    if (promptRaw != null && promptRaw.isNotEmpty) {
      try {
        promptConfig = PromptAssistantConfigState.decode(
          promptRaw,
          migrateLegacyChatRouting: true,
        );
      } catch (error) {
        throw FormatException(
          'Cannot migrate the existing chat configuration: $error',
        );
      }
    }
    var webEnabled = false;
    final webRaw = _local.getSetting<String>(
      StorageKeys.agentWebAccessConfigJson,
    );
    if (webRaw != null && webRaw.isNotEmpty) {
      try {
        webEnabled = WebAccessConfig.decode(webRaw).enabled;
      } catch (error) {
        AppLogger.w(
          'Ignoring invalid legacy web access state during Agent migration: '
              '$error',
          'AgentSettings',
        );
      }
    }
    final migrated = AgentSettings.migrateLegacy(
      promptAssistant: promptConfig,
      webAccessEnabled: webEnabled,
    );
    await _local.setSetting(StorageKeys.agentSettingsJson, migrated.encode());
    await _removeLegacyAgentFields(promptRaw);
    return migrated;
  }

  Future<void> _removeLegacyAgentFields(String? raw) async {
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Cannot clean migrated chat fields from Prompt Assistant settings.',
      );
    }
    var changed = false;
    final rules = decoded['rules'];
    if (rules is List) {
      final retainedRules = rules.where((item) {
        return item is! Map || item['taskType'] != AssistantTaskType.chat.name;
      }).toList();
      if (retainedRules.length != rules.length) {
        decoded['rules'] = retainedRules;
        changed = true;
      }
    }
    final routing = decoded['routing'];
    if (routing is Map) {
      changed = routing.containsKey('chatProviderId') || changed;
      routing.remove('chatProviderId');
      changed = routing.containsKey('chatModel') || changed;
      routing.remove('chatModel');
    }
    changed = decoded.containsKey('agentPermissionMode') || changed;
    decoded.remove('agentPermissionMode');
    if (!changed) return;
    await _local.setSetting(
      StorageKeys.promptAssistantConfigJson,
      jsonEncode(decoded),
    );
  }

  Future<void> _persist(AgentSettings next) async {
    await _local.setSetting(StorageKeys.agentSettingsJson, next.encode());
    if (mounted) state = state.copyWith(settings: next, error: '');
  }

  Future<void> _update(
    AgentSettings Function(AgentSettings current) transform,
  ) {
    if (!state.initialized || state.error.isNotEmpty) {
      return Future.error(
        StateError('Agent settings are not available for editing.'),
      );
    }
    final operation = _mutationQueue
        .catchError((Object _) {})
        .then((_) => _persist(transform(state.settings)));
    _mutationQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> setModelReference(AgentModelReference reference) => _update(
    (current) => current.copyWith(
      chat: current.chat.copyWith(modelReference: reference),
    ),
  );

  Future<void> setPermissionMode(AgentPermissionMode mode) => _update(
    (current) =>
        current.copyWith(chat: current.chat.copyWith(permissionMode: mode)),
  );

  Future<void> setWebAccessEnabled(bool enabled) => _update(
    (current) => current.copyWith(
      chat: current.chat.copyWith(webAccessEnabled: enabled),
    ),
  );

  Future<void> saveCustomSystemPrompt(String value) {
    if (value.length > AgentSettings.maxCustomPromptLength) {
      throw const FormatException('Custom system prompt is too large.');
    }
    return _update(
      (current) => current.copyWith(
        chat: current.chat.copyWith(customSystemPrompt: value),
      ),
    );
  }

  Future<void> replaceSettings(AgentSettings settings) async {
    await _update((_) => settings);
    await reloadSkills();
  }

  Future<void> retryInitialization() => _load();

  Future<void> setSkillEnabled(String id, bool enabled) async {
    await _update((current) {
      final disabled = {...current.disabledSkillIds};
      enabled ? disabled.remove(id) : disabled.add(id);
      return current.copyWith(disabledSkillIds: disabled);
    });
    if (!mounted) return;
    state = state.copyWith(
      skills: SkillCatalogSnapshot(
        entries: [
          for (final entry in state.skills.entries)
            entry.id == id ? entry.copyWith(enabled: enabled) : entry,
        ],
        diagnostics: state.skills.diagnostics,
      ),
    );
  }

  Future<void> reloadSkills() async {
    state = state.copyWith(refreshingSkills: true, error: '');
    try {
      _supportDirectory ??= await getApplicationSupportDirectory();
      _workspaceDirectory ??= await _resolveWorkspaceDirectory();
      final roots = SkillCatalogService.roots(
        workspaceDirectory: _workspaceDirectory!,
        supportDirectory: _supportDirectory!,
        environment: _environment,
      );
      final userRoot = roots.firstWhere(
        (root) => root.source == SkillSource.piUser,
      );
      await const SkillArchiveService().recoverInterruptedInstalls(
        Directory(userRoot.path),
      );
      final snapshot = await _skillCatalogService.scan(
        roots: roots,
        disabledSkillIds: state.settings.disabledSkillIds,
      );
      if (!mounted) return;
      final currentDisabled = state.settings.disabledSkillIds;
      state = state.copyWith(
        skills: SkillCatalogSnapshot(
          entries: [
            for (final entry in snapshot.entries)
              entry.copyWith(enabled: !currentDisabled.contains(entry.id)),
          ],
          diagnostics: snapshot.diagnostics,
        ),
        refreshingSkills: false,
      );
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          refreshingSkills: false,
          error: error.toString(),
        );
      }
      rethrow;
    }
  }

  Future<Directory> userSkillDirectory() async {
    _supportDirectory ??= await getApplicationSupportDirectory();
    _workspaceDirectory ??= await _resolveWorkspaceDirectory();
    return Directory(
      SkillCatalogService.roots(
        workspaceDirectory: _workspaceDirectory!,
        supportDirectory: _supportDirectory!,
        environment: _environment,
      ).firstWhere((root) => root.source == SkillSource.piUser).path,
    );
  }

  Future<Directory> _resolveWorkspaceDirectory() async {
    try {
      final root = await GalleryFolderRepository.instance.getRootPath();
      if (root != null && root.isNotEmpty) return Directory(root);
    } catch (error) {
      AppLogger.w(
        'Gallery workspace lookup failed; using the Agent workspace: $error',
        'AgentSettings',
      );
    }
    return Directory(
      '${_supportDirectory!.path}${Platform.pathSeparator}agent${Platform.pathSeparator}workspace',
    );
  }
}
