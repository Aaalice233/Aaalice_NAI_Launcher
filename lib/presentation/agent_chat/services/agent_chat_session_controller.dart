import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/agent/agent.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/harness/session/session.dart';
import '../../../core/agent/harness/session/session_context.dart';
import '../../../core/agent/harness/session/session_jsonl.dart';
import '../../../core/agent/harness/session/session_types.dart'
    as session_types;
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/inpaint/inpaint_draft.dart';
import '../providers/agent_chat_session_view.dart';
import '../providers/agent_chat_state.dart';
import '../models/agent_chat_turn_timeline.dart';
import 'agent_chat_draft_controller.dart';

class AgentChatSessionController {
  static const sessionSummaryLimit = 100;
  static const recentHistoryEntryLimit = 200;
  static const historyPageEntryLimit = 120;
  static const historyRecordLimit = 800;
  AgentChatSessionController({
    required JsonlSessionRepo repository,
    required LocalStorageService localStorage,
    required AgentChatDraftController draftController,
    required String workspaceDir,
    required Future<Agent> Function() buildAgent,
    required Future<String> Function() buildSystemPrompt,
    required AgentChatState Function() readState,
    required void Function(AgentChatState state) writeState,
    required bool Function() isMounted,
  }) : _repository = repository,
       _localStorage = localStorage,
       _draftController = draftController,
       _workspaceDir = workspaceDir,
       _buildAgent = buildAgent,
       _buildSystemPrompt = buildSystemPrompt,
       _readState = readState,
       _writeState = writeState,
       _isMounted = isMounted;

  final JsonlSessionRepo _repository;
  final LocalStorageService _localStorage;
  final AgentChatDraftController _draftController;
  final String _workspaceDir;
  final Future<Agent> Function() _buildAgent;
  final Future<String> Function() _buildSystemPrompt;
  final AgentChatState Function() _readState;
  final void Function(AgentChatState) _writeState;
  final bool Function() _isMounted;

  Agent? agent;
  Session? session;
  Usage totalUsage = const Usage();
  final List<session_types.MessageEntry> _visibleEntries = [];
  final List<session_types.LaneRecord> _visibleRecords = [];
  String? _activeTurnId;
  String? _activeAssistantEntryId;
  final Set<String> _finishedTurnIds = {};
  final Set<String> _finishingTurnIds = {};
  final Map<String, String> _pendingToolResultEntryIds = {};

  String? get activeTurnId => _activeTurnId;

  Future<void> restoreLastSession() async {
    final sessions = await listSessions();
    final savedId = _localStorage.getSetting<String>(
      StorageKeys.agentChatActiveSession,
    );
    final target = sessions.any((item) => item.metadata.id == savedId)
        ? savedId!
        : sessions.isNotEmpty
        ? sessions.first.metadata.id
        : '';
    if (target.isEmpty) {
      await _createAndActivateSession();
      return;
    }
    await activateSession(target);
  }

  Future<List<AgentChatSessionSummary>> listSessions() async {
    try {
      final raw = await _repository.listWithNames();
      return [
        for (final (metadata, name, updatedAt) in raw)
          AgentChatSessionSummary(
            metadata: metadata,
            name: name,
            updatedAt: updatedAt,
          ),
      ].take(sessionSummaryLimit).toList(growable: false);
    } catch (error) {
      AppLogger.w('list sessions failed: $error', 'AgentChat');
      return const [];
    }
  }

  Future<void> activateSession(String sessionId) async {
    await agent?.waitForIdle();
    final metadata = (await _repository.list()).firstWhere(
      (item) => item.id == sessionId,
      orElse: () => session_types.SessionMetadata(
        id: sessionId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    Session nextSession;
    try {
      nextSession = await _repository.open(metadata);
    } catch (_) {
      nextSession = await _repository.create(
        session_types.SessionCreateOptions(id: sessionId),
      );
    }
    final nextAgent = await _buildAgent();
    final entries = await nextSession.findEntriesOnBranch(
      const session_types.EntryQuery(
        order: session_types.EntryOrder.oldestFirst,
      ),
    );
    final context = buildSessionContext(entries);
    final restoredMessages = _restoreLegacyReadImageDetails(context.messages);
    final usage = calculateAgentChatSessionUsage(entries);
    final latestContextUsage = restoredMessages.reversed
        .whereType<AssistantMessage>()
        .map((message) => message.usage)
        .whereType<Usage>()
        .firstOrNull;
    nextAgent.state.messages = restoredMessages;
    nextAgent.state.thinkingLevel = ThinkingLevel.values.firstWhere(
      (level) => level.name == context.thinkingLevel,
      orElse: () => ThinkingLevel.off,
    );
    nextAgent.setSystemPrompt(await _buildSystemPrompt());

    final recentEntries = (await nextSession.findEntriesOnBranch(
      const session_types.EntryQuery(
        type: 'message',
        order: session_types.EntryOrder.newestFirst,
        limit: recentHistoryEntryLimit,
      ),
    )).whereType<session_types.MessageEntry>().toList().reversed.toList();
    final recentRecords = await nextSession.findRecords(
      const session_types.RecordQuery(
        lane: 'main',
        order: session_types.EntryOrder.newestFirst,
        limit: historyRecordLimit,
      ),
    );
    _visibleEntries
      ..clear()
      ..addAll(recentEntries);
    _visibleRecords
      ..clear()
      ..addAll(recentRecords);
    _activeTurnId = null;
    _activeAssistantEntryId = null;
    _finishedTurnIds
      ..clear()
      ..addAll(
        recentRecords.whereType<session_types.OperationFinishedRecord>().map(
          (record) => record.runId,
        ),
      );
    _finishingTurnIds.clear();
    _pendingToolResultEntryIds.clear();
    final timelinePage = _buildVisibleTimelinePage(
      hasEarlier: entries.length > recentEntries.length,
    );

    session = nextSession;
    agent = nextAgent;
    totalUsage = usage;

    await _localStorage.setSetting(
      StorageKeys.agentChatActiveSession,
      sessionId,
    );
    final draft = await _draftController.loadSession(sessionId);
    _writeState(
      _readState().copyWith(
        activeSessionId: sessionId,
        messages: timelinePage.messages,
        turns: timelinePage.turns,
        hasEarlierTurns: timelinePage.hasEarlier,
        historyCursor: timelinePage.earlierCursor,
        clearHistoryCursor: timelinePage.earlierCursor == null,
        clearPrependAnchorEntryId: true,
        activities: const [],
        clearStreamingMessage: true,
        error: '',
        queuedMessages: const [],
        workPhase: AgentChatWorkPhase.idle,
        sessions: await listSessions(),
        totalUsage: usage,
        contextUsage: latestContextUsage,
        clearContextUsage: latestContextUsage == null,
        thinkingLevel: nextAgent.state.thinkingLevel,
        pendingResources: draft.resources,
        composerText: draft.composerText,
      ),
    );
    await _draftController.refreshPendingResourceAvailability();
  }

  AgentChatTimelinePage _buildVisibleTimelinePage({
    required bool hasEarlier,
    String? prependAnchorEntryId,
  }) => buildAgentChatTimelinePage(
    entries: List.unmodifiable(_visibleEntries),
    records: List.unmodifiable(_visibleRecords),
    hasEarlier: hasEarlier,
    prependAnchorEntryId: prependAnchorEntryId,
    activeTurnId: _activeTurnId,
  );

  void _publishVisibleTimeline({String? prependAnchorEntryId}) {
    final page = _buildVisibleTimelinePage(
      hasEarlier: _readState().hasEarlierTurns,
      prependAnchorEntryId: prependAnchorEntryId,
    );
    _writeState(
      _readState().copyWith(
        messages: page.messages,
        turns: page.turns,
        historyCursor: page.earlierCursor,
        clearHistoryCursor: page.earlierCursor == null,
        prependAnchorEntryId: prependAnchorEntryId,
        clearPrependAnchorEntryId: prependAnchorEntryId == null,
      ),
    );
  }

  /// Prepends one bounded branch page. The returned anchor is the entry that
  /// occupied the top of the previous window, allowing stable scroll restore.
  Future<void> loadEarlierHistory() async {
    final currentSession = session;
    final cursor = _readState().historyCursor;
    if (currentSession == null ||
        cursor == null ||
        _readState().historyLoading) {
      return;
    }
    _writeState(_readState().copyWith(historyLoading: true));
    final anchor = _visibleEntries.firstOrNull?.id;
    try {
      final older = (await currentSession.findEntriesOnBranch(
        session_types.EntryQuery(
          type: 'message',
          order: session_types.EntryOrder.newestFirst,
          limit: historyPageEntryLimit,
          cursor: session_types.EntryCursor(afterSeq: cursor.beforeSeq),
        ),
      )).whereType<session_types.MessageEntry>().toList().reversed.toList();
      final oldestSeq = older.firstOrNull?.seq;
      final records = oldestSeq == null
          ? const <session_types.LaneRecord>[]
          : await currentSession.findRecords(
              session_types.RecordQuery(
                lane: 'main',
                order: session_types.EntryOrder.newestFirst,
                limit: historyRecordLimit,
                cursor: session_types.EntryCursor(afterSeq: cursor.beforeSeq),
              ),
            );
      final existingIds = _visibleEntries.map((entry) => entry.id).toSet();
      _visibleEntries.insertAll(
        0,
        older.where((entry) => !existingIds.contains(entry.id)),
      );
      final recordIds = _visibleRecords.map((record) => record.id).toSet();
      _visibleRecords.addAll(
        records.where((record) => !recordIds.contains(record.id)),
      );
      final hasEarlier = older.length == historyPageEntryLimit;
      final page = _buildVisibleTimelinePage(
        hasEarlier: hasEarlier,
        prependAnchorEntryId: anchor,
      );
      _writeState(
        _readState().copyWith(
          messages: page.messages,
          turns: page.turns,
          hasEarlierTurns: hasEarlier,
          historyCursor: page.earlierCursor,
          clearHistoryCursor: page.earlierCursor == null,
          prependAnchorEntryId: anchor,
        ),
      );
    } finally {
      if (_isMounted()) {
        _writeState(_readState().copyWith(historyLoading: false));
      }
    }
  }

  Future<String?> startTurn() async {
    final currentSession = session;
    if (currentSession == null) return null;
    final id = currentSession.idGenerator();
    final sourceLeafId = await currentSession.getLeafId();
    final record = await currentSession.appendRecord(
      session_types.OperationStartedRecord(
        id: id,
        lane: 'main',
        sourceLeafId: sourceLeafId,
        intent: const session_types.RunIntent(
          kind: session_types.RunIntentKind.run,
        ),
      ),
    );
    _activeTurnId = id;
    _activeAssistantEntryId = null;
    _visibleRecords.add(record);
    _publishVisibleTimeline();
    return id;
  }

  Future<void> finishTurn({
    required String turnId,
    required session_types.OperationOutcomeKind outcome,
    String? error,
  }) async {
    final currentSession = session;
    if (currentSession == null ||
        _finishedTurnIds.contains(turnId) ||
        !_finishingTurnIds.add(turnId)) {
      return;
    }
    try {
      final durableFinish = await currentSession.findRecords(
        session_types.RecordQuery(
          lane: 'main',
          type: 'operation_finished',
          runId: turnId,
          limit: 1,
        ),
      );
      if (durableFinish.isNotEmpty) {
        _finishedTurnIds.add(turnId);
        final record = durableFinish.single;
        if (_visibleRecords.every((candidate) => candidate.id != record.id)) {
          _visibleRecords.add(record);
        }
        if (_activeTurnId == turnId) {
          _activeTurnId = null;
          _activeAssistantEntryId = null;
        }
        _publishVisibleTimeline();
        return;
      }
      final record = await currentSession.appendRecord(
        session_types.OperationFinishedRecord(
          id: currentSession.idGenerator(),
          lane: 'main',
          runId: turnId,
          outcome: outcome,
          error: error == null ? null : (code: 'agent_error', message: error),
        ),
      );
      _finishedTurnIds.add(turnId);
      _visibleRecords.add(record);
      if (_activeTurnId == turnId) {
        _activeTurnId = null;
        _activeAssistantEntryId = null;
      }
      _publishVisibleTimeline();
    } finally {
      _finishingTurnIds.remove(turnId);
    }
  }

  Future<void> recordToolStarted({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    final currentSession = session;
    final turnId = _activeTurnId;
    final assistantEntryId = _activeAssistantEntryId;
    if (currentSession == null || turnId == null || assistantEntryId == null) {
      return;
    }
    final assistant = await currentSession.getEntry(assistantEntryId);
    final toolIndex =
        assistant is session_types.MessageEntry &&
            assistant.message is AssistantMessage
        ? (assistant.message as AssistantMessage).toolCalls.indexWhere(
            (call) => call.id == toolCallId,
          )
        : -1;
    final resultEntryId = currentSession.idGenerator();
    _pendingToolResultEntryIds[toolCallId] = resultEntryId;
    final record = await currentSession.appendRecord(
      session_types.ToolStartedRecord(
        id: currentSession.idGenerator(),
        lane: 'main',
        runId: turnId,
        assistantEntryId: assistantEntryId,
        toolIndex: toolIndex < 0 ? 0 : toolIndex,
        toolCallId: toolCallId,
        toolName: toolName,
        effectiveArgs: args,
        resultEntryId: resultEntryId,
        replay: session_types.ReplayMode.never,
      ),
    );
    _visibleRecords.add(record);
    _publishVisibleTimeline();
  }

  List<AgentMessage> _restoreLegacyReadImageDetails(
    List<AgentMessage> messages,
  ) {
    final readPaths = <String, String>{};
    for (final message in messages) {
      if (message is AssistantMessage) {
        for (final call in message.toolCalls) {
          final path = call.arguments['path'];
          if (call.name == 'read' && path is String && path.isNotEmpty) {
            readPaths[call.id] = path;
          }
        }
        continue;
      }
      if (message is! ToolResultMessage ||
          message.toolName != 'read' ||
          message.isError ||
          !message.text.startsWith('Read image file [') ||
          _hasPersistedImageFiles(message.details)) {
        continue;
      }
      final path = readPaths[message.toolCallId];
      if (path == null) continue;
      final absolutePath = p.normalize(
        p.isAbsolute(path) ? path : p.join(_workspaceDir, path),
      );
      if (File(absolutePath).existsSync()) {
        message.details = <String, dynamic>{
          'files': [absolutePath],
        };
      }
    }
    return messages;
  }

  bool _hasPersistedImageFiles(dynamic details) {
    if (details is! Map || details['files'] is! List) return false;
    return (details['files'] as List).any(
      (file) => file is String && file.isNotEmpty,
    );
  }

  Future<void> _createAndActivateSession() async {
    final created = await _repository.create();
    final metadata = await created.getMetadata();
    await activateSession(metadata.id);
  }

  Future<void> _runTransition(
    Future<void> Function() action, {
    required bool loadsContent,
  }) async {
    final current = _readState();
    if (!canManageAgentChatSessions(current)) return;
    _writeState(
      current.copyWith(
        sessionTransitioning: true,
        sessionContentLoading: loadsContent,
      ),
    );
    try {
      await action();
    } finally {
      if (_isMounted()) {
        _writeState(
          _readState().copyWith(
            sessionTransitioning: false,
            sessionContentLoading: false,
          ),
        );
      }
    }
  }

  Future<void> newSession() =>
      _runTransition(_createAndActivateSession, loadsContent: true);

  Future<void> switchSession(String sessionId) {
    final current = _readState();
    if (sessionId.isEmpty || sessionId == current.activeSessionId) {
      return Future.value();
    }
    return _runTransition(() => activateSession(sessionId), loadsContent: true);
  }

  Future<UserMessage?> rewindLastUserMessage() async {
    UserMessage? rewoundMessage;
    try {
      await _runTransition(() async {
        final currentSession = session;
        final sessionId = _readState().activeSessionId;
        if (currentSession == null || sessionId.isEmpty) return;
        final entries = await currentSession.findEntriesOnBranch(
          const session_types.EntryQuery(
            order: session_types.EntryOrder.oldestFirst,
          ),
        );
        session_types.MessageEntry? target;
        for (final entry in entries.reversed) {
          if (entry is session_types.MessageEntry &&
              (entry.message is UserMessage ||
                  (entry.message is HarnessCustomMessage &&
                      (entry.message as HarnessCustomMessage).customType ==
                          'agentResourcePrompt'))) {
            target = entry;
            break;
          }
        }
        if (target == null) return;
        final restoredResources = <AgentChatResourceReference>[];
        final targetMessage = target.message;
        if (targetMessage is UserMessage) {
          rewoundMessage = targetMessage;
        } else if (targetMessage is HarnessCustomMessage) {
          rewoundMessage = UserMessage(
            content: targetMessage.content.skip(1).toList(growable: false),
            timestamp: targetMessage.timestamp,
          );
          final details = targetMessage.details;
          if (details is Map && details['references'] is List) {
            for (final value in details['references'] as List) {
              if (value is Map) {
                restoredResources.add(
                  AgentChatResourceReferenceCodec.decodeJsonMap(
                    Map<String, dynamic>.from(value),
                  ),
                );
              }
            }
          }
        }
        await currentSession.moveLane('main', target.parentId);
        await activateSession(sessionId);
        if (restoredResources.isNotEmpty) {
          _writeState(
            _readState().copyWith(pendingResources: restoredResources),
          );
          await _draftController.savePendingResources(
            sessionId,
            restoredResources,
          );
          await _draftController.refreshPendingResourceAvailability();
        }
      }, loadsContent: true);
    } catch (error) {
      AppLogger.w('rewind last user message failed: $error', 'AgentChat');
    }
    return rewoundMessage;
  }

  Future<void> deleteSession(String sessionId) {
    if (sessionId.isEmpty) return Future.value();
    final deletesActive = sessionId == _readState().activeSessionId;
    return _runTransition(() async {
      _repository.deleteById(sessionId);
      await _draftController.deleteSession(sessionId);
      if (!deletesActive) {
        _writeState(_readState().copyWith(sessions: await listSessions()));
        return;
      }
      final remaining = (await listSessions())
          .where((item) => item.id != sessionId)
          .toList();
      if (remaining.isNotEmpty) {
        await activateSession(remaining.first.id);
      } else {
        await _createAndActivateSession();
      }
    }, loadsContent: deletesActive);
  }

  Future<void> renameSession(String sessionId, String name) {
    final trimmed = name.trim();
    if (sessionId.isEmpty || trimmed.isEmpty) return Future.value();
    return _runTransition(() async {
      try {
        final metadata = (await _repository.list()).firstWhere(
          (item) => item.id == sessionId,
        );
        final target = await _repository.open(metadata);
        await target.setName(trimmed);
        _writeState(_readState().copyWith(sessions: await listSessions()));
      } catch (error) {
        AppLogger.w('rename session failed: $error', 'AgentChat');
      }
    }, loadsContent: false);
  }

  Future<void> recordManualInpaintDraftUpdate(
    String ownerSessionId,
    InpaintDraft draft,
  ) async {
    final activeSessionId = _readState().activeSessionId;
    final targetSessionId = ownerSessionId.isEmpty
        ? activeSessionId
        : ownerSessionId;
    final message = HarnessCustomMessage(
      customType: 'manualInpaintDraftStatus',
      display: false,
      textContent:
          '[Manual inpaint draft update]\n'
          'Draft ID: ${draft.id}\n'
          'Status: ${draft.status.name}\n'
          'Use get_manual_inpaint_draft to inspect the persisted draft.',
      details: {
        'draftId': draft.id,
        'status': draft.status.name,
        'estimatedAnlas': draft.estimatedAnlas,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    if (targetSessionId == activeSessionId) {
      final currentAgent = agent;
      if (currentAgent == null) return;
      currentAgent.state.messages = [...currentAgent.state.messages, message];
      _writeState(
        _readState().copyWith(messages: [..._readState().messages, message]),
      );
      await persistMessage(message);
      return;
    }
    try {
      final metadata = (await _repository.list()).firstWhere(
        (item) => item.id == targetSessionId,
      );
      final target = await _repository.open(metadata);
      await target.appendMessage(message);
      if (_isMounted()) {
        _writeState(_readState().copyWith(sessions: await listSessions()));
      }
    } on Object catch (error) {
      AppLogger.w(
        'Persist manual inpaint draft update failed: $error',
        'AgentChat',
      );
    }
  }

  Future<void> autoNameSession(Message message) async {
    final currentSession = session;
    final userMessage = switch (message) {
      UserMessage() => message,
      HarnessCustomMessage() when message.customType == 'agentResourcePrompt' =>
        UserMessage(
          content: message.content.skip(1).toList(growable: false),
          timestamp: message.timestamp,
        ),
      _ => null,
    };
    if (currentSession == null || userMessage == null) return;
    try {
      final existing = await currentSession.getName();
      if (existing != null && existing.trim().isNotEmpty) return;
      final normalized = userMessage.text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (normalized.isEmpty) return;
      final name = normalized.length <= 40
          ? normalized
          : '${normalized.substring(0, 40)}…';
      await currentSession.setName(name);
      _writeState(_readState().copyWith(sessions: await listSessions()));
    } catch (error) {
      AppLogger.w('auto name session failed: $error', 'AgentChat');
    }
  }

  Future<session_types.MessageEntry?> persistMessage(Message message) async {
    final currentSession = session;
    if (currentSession == null) return null;
    if (message is AssistantMessage && !isReplayableAssistantMessage(message)) {
      return null;
    }
    try {
      final preferredId = message is ToolResultMessage
          ? _pendingToolResultEntryIds.remove(message.toolCallId)
          : null;
      final entry =
          await currentSession.appendEntry(
                session_types.MessageEntry(
                  id: preferredId ?? currentSession.idGenerator(),
                  message: message,
                ),
                'main',
              )
              as session_types.MessageEntry;
      _visibleEntries.add(entry);
      if (message is AssistantMessage) {
        _activeAssistantEntryId = entry.id;
      }
      _publishVisibleTimeline();
      return entry;
    } catch (error) {
      AppLogger.w('persist message failed: $error', 'AgentChat');
      return null;
    }
  }
}
