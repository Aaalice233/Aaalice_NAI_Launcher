import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/agent/agent_system_prompt.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/skill_archive_service.dart';
import '../../../core/agent/skill_catalog.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/web_access/web_access_models.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/agent/agent_settings.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../agent_chat/services/agent_system_prompt.dart';
import '../../providers/image_save_settings_provider.dart';
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

class AgentSkillBackupContext {
  const AgentSkillBackupContext({required this.roots, required this.entries});

  final List<SkillRoot> roots;
  final List<SkillCatalogEntry> entries;
}

final agentSettingsProvider =
    StateNotifierProvider<AgentSettingsNotifier, AgentSettingsState>((ref) {
      final notifier = AgentSettingsNotifier(ref);
      ref.listen<String?>(
        imageSaveSettingsNotifierProvider.select(
          (settings) => settings.customPath,
        ),
        (_, _) => unawaited(notifier.handleImageProjectChanged()),
      );
      return notifier;
    });

class AgentSettingsNotifier extends StateNotifier<AgentSettingsState> {
  AgentSettingsNotifier(
    this._ref, {
    Directory? supportDirectory,
    Directory? workspaceDirectory,
    Map<String, String>? environment,
    SkillCatalogService? skillCatalogService,
    Future<Directory> Function()? workspaceDirectoryResolver,
  }) : _supportDirectory = supportDirectory,
       _providedWorkspaceDirectory = workspaceDirectory,
       _environment = environment,
       _workspaceDirectoryResolver = workspaceDirectoryResolver,
       _skillCatalogService =
           skillCatalogService ?? const SkillCatalogService(),
       super(const AgentSettingsState()) {
    _initialization = _load();
  }

  final Ref _ref;
  final SkillCatalogService _skillCatalogService;
  final Directory? _providedWorkspaceDirectory;
  Directory? _resolvedWorkspaceDirectory;
  Directory? _supportDirectory;
  final Map<String, String>? _environment;
  final Future<Directory> Function()? _workspaceDirectoryResolver;
  Future<void> _mutationQueue = Future.value();
  late Future<void> _initialization;
  var _skillReloadGeneration = 0;
  var _imageProjectRefreshPending = false;

  LocalStorageService get _local => _ref.read(localStorageServiceProvider);

  Future<void> _load() async {
    state = state.copyWith(initialized: false, error: '');
    try {
      final raw = _local.getSetting<String>(StorageKeys.agentSettingsJson);
      AgentSettings settings;
      if (raw != null) {
        final storedDocument = jsonDecode(raw);
        final storedSchemaVersion = storedDocument is Map
            ? storedDocument['schemaVersion']
            : null;
        settings = AgentSettings.decode(raw);
        await _removeLegacyAgentFields(
          _local.getSetting<String>(StorageKeys.promptAssistantConfigJson),
        );
        if (storedSchemaVersion != AgentSettings.currentSchemaVersion) {
          await _local.setSetting(
            StorageKeys.agentSettingsJson,
            settings.encode(),
          );
        }
      } else {
        settings = await _migrateLegacy();
      }
      if (!mounted) return;
      state = state.copyWith(settings: settings, error: '');
      await reloadSkills();
      if (!mounted) return;
      state = state.copyWith(initialized: true, error: '');
      if (_imageProjectRefreshPending) {
        await handleImageProjectChanged();
      }
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
        throw FormatException(
          'Cannot migrate the existing Agent web access configuration: '
          '$error',
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
    final unavailable = _editingUnavailableError();
    if (unavailable != null) return Future.error(unavailable);
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

  String buildDefaultSystemPrompt() {
    final workspaceDirectory =
        _providedWorkspaceDirectory ??
        _resolvedWorkspaceDirectory ??
        (_supportDirectory == null
            ? Directory.current
            : Directory(
                '${_supportDirectory!.path}${Platform.pathSeparator}agent'
                '${Platform.pathSeparator}workspace',
              ));
    final skillBlock = formatSkillsForSystemPrompt(
      state.skills.enabledSkillMap().values.toList(growable: false),
    );
    return buildAgentSystemPrompt(
      workspacePath: workspaceDirectory.path,
      webAccessEnabled: state.settings.chat.webAccessEnabled,
      skillBlock: skillBlock,
    );
  }

  String buildSystemPromptPreview({
    required String customInstructions,
    required AgentSystemPromptMode mode,
  }) {
    final builtInPrompt = buildDefaultSystemPrompt();
    return composeAgentSystemPrompt(
      builtInPrompt: builtInPrompt,
      customInstructions: state.settings.chat.behaviorInstructions(
        customPromptOverride: customInstructions,
        modeOverride: mode,
      ),
      mode: mode,
    );
  }

  Future<void> saveCustomSystemPrompt({
    required AgentSystemPromptMode mode,
    required String value,
  }) {
    if (value.length > AgentSettings.maxCustomPromptLength) {
      throw const FormatException('Custom system prompt is too large.');
    }
    return _update(
      (current) => current.copyWith(
        chat: current.chat.copyWith(
          systemPromptMode: mode,
          customSystemPrompt: value,
        ),
      ),
    );
  }

  Future<void> replaceSettings(AgentSettings settings) {
    final unavailable = _editingUnavailableError();
    if (unavailable != null) return Future.error(unavailable);
    final operation = _mutationQueue.catchError((Object _) {}).then((_) async {
      final previousSettings = state.settings;
      final previousSkills = state.skills;
      final scanGeneration = ++_skillReloadGeneration;
      final skills = await _scanSkills(settings.skillEnabledOverrides);
      try {
        await _local.setSetting(
          StorageKeys.agentSettingsJson,
          settings.encode(),
        );
        if (mounted) {
          final scanIsCurrent = scanGeneration == _skillReloadGeneration;
          state = state.copyWith(
            settings: settings,
            skills: scanIsCurrent ? skills : state.skills,
            refreshingSkills: false,
            error: '',
          );
          if (!scanIsCurrent) await reloadSkills();
        }
      } catch (applyError, applyStack) {
        try {
          await _local.setSetting(
            StorageKeys.agentSettingsJson,
            previousSettings.encode(),
          );
        } catch (rollbackError, rollbackStack) {
          Error.throwWithStackTrace(
            StateError(
              'Agent profile import failed: $applyError\n'
              'Restoring the previous profile also failed: $rollbackError\n'
              'Original import stack:\n$applyStack',
            ),
            rollbackStack,
          );
        }
        if (mounted) {
          state = state.copyWith(
            settings: previousSettings,
            skills: previousSkills,
            refreshingSkills: false,
            error: '',
          );
        }
        Error.throwWithStackTrace(applyError, applyStack);
      }
    });
    _mutationQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> retryInitialization() {
    _initialization = _load();
    return _initialization;
  }

  Future<void> setSkillEnabled(String id, bool enabled) async {
    await _update((current) {
      final overrides = {...current.skillEnabledOverrides, id: enabled};
      return current.copyWith(skillEnabledOverrides: overrides);
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
    final generation = ++_skillReloadGeneration;
    state = state.copyWith(refreshingSkills: true, error: '');
    try {
      final snapshot = await _scanSkills(state.settings.skillEnabledOverrides);
      if (!mounted || generation != _skillReloadGeneration) return;
      final currentOverrides = state.settings.skillEnabledOverrides;
      state = state.copyWith(
        skills: SkillCatalogSnapshot(
          entries: [
            for (final entry in snapshot.entries)
              entry.copyWith(
                enabled:
                    currentOverrides[entry.id] ?? entry.source.defaultEnabled,
              ),
          ],
          diagnostics: snapshot.diagnostics,
        ),
        refreshingSkills: false,
      );
    } catch (error) {
      if (!mounted || generation != _skillReloadGeneration) return;
      state = state.copyWith(refreshingSkills: false, error: error.toString());
      rethrow;
    }
  }

  StateError? _editingUnavailableError() {
    if (!state.initialized || state.error.isNotEmpty) {
      return StateError('Agent settings are not available for editing.');
    }
    return null;
  }

  Future<void> handleImageProjectChanged() async {
    if (!mounted) return;
    if (!state.initialized) {
      _imageProjectRefreshPending = true;
      return;
    }
    _imageProjectRefreshPending = false;
    try {
      await reloadSkills();
    } catch (error) {
      AppLogger.w(
        'refresh Skills for the current image project failed: $error',
        'AgentSettings',
      );
    }
  }

  Future<SkillCatalogSnapshot> _scanSkills(
    Map<String, bool> skillEnabledOverrides,
  ) async {
    _supportDirectory ??= await getApplicationSupportDirectory();
    final workspaceDirectory =
        _providedWorkspaceDirectory ?? await _resolveWorkspaceDirectory();
    final roots = SkillCatalogService.roots(
      workspaceDirectory: workspaceDirectory,
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
      skillEnabledOverrides: skillEnabledOverrides,
    );
    return SkillCatalogSnapshot(
      entries: [
        for (final entry in snapshot.entries)
          entry.copyWith(
            enabled:
                skillEnabledOverrides[entry.id] ?? entry.source.defaultEnabled,
          ),
      ],
      diagnostics: snapshot.diagnostics,
    );
  }

  Future<Directory> userSkillDirectory() async {
    final roots = await _skillRoots();
    return Directory(
      roots.firstWhere((root) => root.source == SkillSource.piUser).path,
    );
  }

  Future<AgentSkillBackupContext> skillBackupContext() async {
    await _initialization;
    if (!state.initialized || state.error.isNotEmpty) {
      throw StateError('Agent Skills are not available for backup.');
    }
    return AgentSkillBackupContext(
      roots: await _skillRoots(),
      entries: List.unmodifiable(state.skills.entries),
    );
  }

  Future<List<SkillRoot>> _skillRoots() async {
    _supportDirectory ??= await getApplicationSupportDirectory();
    final workspaceDirectory =
        _providedWorkspaceDirectory ?? await _resolveWorkspaceDirectory();
    return SkillCatalogService.roots(
      workspaceDirectory: workspaceDirectory,
      supportDirectory: _supportDirectory!,
      environment: _environment,
    );
  }

  Future<Directory?> _resolveWorkspaceDirectory() async {
    final resolver = _workspaceDirectoryResolver;
    if (resolver != null) {
      return _resolvedWorkspaceDirectory = await resolver();
    }
    try {
      final root = await GalleryFolderRepository.instance.getRootPath();
      if (root != null && root.isNotEmpty) {
        return _resolvedWorkspaceDirectory = Directory(root);
      }
    } catch (error) {
      AppLogger.w(
        'Gallery workspace lookup failed; project Skills are unavailable: '
            '$error',
        'AgentSettings',
      );
    }
    _resolvedWorkspaceDirectory = null;
    return null;
  }
}
