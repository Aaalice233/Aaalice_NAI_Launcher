import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/windowing/agent_window_protocol.dart';
import '../../../core/windowing/agent_window_runtime.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../providers/agent_chat_notifier.dart';
import '../models/agent_chat_turn_timeline.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../providers/layout_state_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/theme_provider.dart';

/// Binds the secondary window to the one authoritative Agent notifier owned
/// by the main engine. The secondary engine only renders snapshots and emits
/// commands; it never owns providers, sessions, queues, or model clients.
final class AgentWindowBridgeAdapter {
  AgentWindowBridgeAdapter._(this._container)
    : _loadEarlierHistoryForTesting = null;

  @visibleForTesting
  AgentWindowBridgeAdapter.forTesting(
    this._container, {
    Future<void> Function()? loadEarlierHistory,
  }) : _loadEarlierHistoryForTesting = loadEarlierHistory;

  final ProviderContainer _container;
  final Future<void> Function()? _loadEarlierHistoryForTesting;
  ProviderSubscription<AgentChatState>? _subscription;
  ProviderSubscription<Locale>? _localeSubscription;
  ProviderSubscription<Object?>? _appearanceSubscription;
  ProviderSubscription<Object?>? _fontSubscription;
  ProviderSubscription<Object?>? _fontScaleSubscription;
  ProviderSubscription<Object?>? _configSubscription;
  ProviderSubscription<AgentSettingsState>? _agentSettingsSubscription;
  int _revision = 0;
  int _historyTurnOffset = 0;
  AgentChatState? _pendingState;
  bool _publishing = false;
  final Map<ImageContent, String> _imageAssetIds = Map.identity();
  final Map<ImageContent, String> _imageErrors = Map.identity();
  final Map<String, String> _fileImageAssetIds = {};
  final Set<String> _currentFileImageKeys = {};
  final Map<String, String> _fileImageErrors = {};
  final Set<String> _publishedImageAssetIds = {};
  final Set<String> _currentImageAssetIds = {};
  final Map<String, Object?> _pendingImageAssets = {};
  int _pendingImageAssetBytes = 0;
  int _nextImageAssetId = 0;

  static Future<AgentWindowBridgeAdapter> attach(
    ProviderContainer container,
  ) async {
    final adapter = AgentWindowBridgeAdapter._(container);
    adapter._subscription = container.listen<AgentChatState>(
      agentChatNotifierProvider,
      (_, next) => unawaited(adapter._publish(next)),
      fireImmediately: true,
    );
    adapter._localeSubscription = container.listen<Locale>(
      localeNotifierProvider,
      (_, _) => unawaited(
        adapter._publish(container.read(agentChatNotifierProvider)),
      ),
    );
    adapter._appearanceSubscription = container.listen<Object?>(
      themeNotifierProvider,
      (_, _) => unawaited(
        adapter._publish(container.read(agentChatNotifierProvider)),
      ),
    );
    adapter._fontSubscription = container.listen<Object?>(
      fontNotifierProvider,
      (_, _) => unawaited(
        adapter._publish(container.read(agentChatNotifierProvider)),
      ),
    );
    adapter._fontScaleSubscription = container.listen<Object?>(
      fontScaleNotifierProvider,
      (_, _) => unawaited(
        adapter._publish(container.read(agentChatNotifierProvider)),
      ),
    );
    adapter._configSubscription = container.listen<Object?>(
      promptAssistantConfigProvider,
      (_, _) => unawaited(
        adapter._publish(container.read(agentChatNotifierProvider)),
      ),
    );
    adapter._agentSettingsSubscription = container.listen<AgentSettingsState>(
      agentSettingsProvider,
      (_, _) => unawaited(
        adapter._publish(container.read(agentChatNotifierProvider)),
      ),
    );
    return adapter;
  }

  Future<Object?> handleCommand(
    String name,
    Map<String, Object?> payload,
  ) async {
    final testHistoryLoader = _loadEarlierHistoryForTesting;
    if (name == 'loadEarlierHistory' && testHistoryLoader != null) {
      await testHistoryLoader();
      return const {'ok': true};
    }
    final notifier = _container.read(agentChatNotifierProvider.notifier);
    switch (name) {
      case 'dockRequested':
        await _container
            .read(layoutStateNotifierProvider.notifier)
            .setRightPanelExpanded(true);
      case 'sendText':
        _historyTurnOffset = 0;
        final text = payload['text'];
        if (text is! String || text.trim().isEmpty) {
          throw const FormatException('sendText requires non-empty text');
        }
        if (!await notifier.validatePendingResourcesForSend()) {
          return const {'ok': false, 'error': 'resource_unavailable'};
        }
        await notifier.clearComposerText();
        await notifier.sendContent([
          UserTextContent(text.trim()),
        ], followUp: payload['followUp'] == true);
        return const {'ok': true};
      case 'updateComposer':
        final text = payload['text'];
        if (text is! String || text.length > 200000) {
          throw const FormatException('composer text is invalid');
        }
        notifier.setComposerText(text);
      case 'addResource':
        final encoded = payload['reference'];
        if (encoded is! String) {
          throw const FormatException('reference must be encoded JSON');
        }
        await notifier.addPendingResource(
          AgentChatResourceReferenceCodec.decodeJson(encoded),
        );
      case 'removeResource':
        final encoded = payload['reference'];
        if (encoded is! String) {
          throw const FormatException('reference must be encoded JSON');
        }
        final reference = AgentChatResourceReferenceCodec.decodeJson(encoded);
        final index = _container
            .read(agentChatNotifierProvider)
            .pendingResources
            .indexOf(reference);
        if (index >= 0) await notifier.removePendingResource(index);
      case 'stop':
        notifier.abort();
      case 'retryLastMessage':
        _historyTurnOffset = 0;
        if (_container.read(agentChatNotifierProvider).status ==
            AgentChatRunStatus.running) {
          return const {'ok': false, 'error': 'agent_running'};
        }
        final message = await notifier.rewindLastUserMessage();
        if (message == null) return const {'ok': false};
        await notifier.sendContent(message.content);
        return const {'ok': true};
      case 'removeQueuedMessage':
        final queued = _queuedMessage(payload);
        if (queued == null) {
          throw const FormatException('queued message no longer exists');
        }
        notifier.removeQueuedMessage(queued);
      case 'editQueuedMessage':
        final queued = _queuedMessage(payload);
        if (queued == null) {
          throw const FormatException('queued message no longer exists');
        }
        if (_messageImages(queued.message).isNotEmpty) {
          return const {'ok': false, 'error': 'queued_attachments'};
        }
        final removed = notifier.removeQueuedMessage(queued);
        if (removed is HarnessCustomMessage) {
          final references = removed.details is Map
              ? (removed.details as Map)['references']
              : null;
          if (references is List) {
            for (final value in references) {
              if (value is Map) {
                await notifier.addPendingResource(
                  AgentChatResourceReferenceCodec.decodeJsonMap(
                    Map<String, dynamic>.from(value),
                  ),
                );
              }
            }
          }
        }
        return {'ok': true, 'text': queued.text};
      case 'clearQueuedMessages':
        notifier.clearQueuedMessages();
      case 'loadEarlierHistory':
        final before = _container.read(agentChatNotifierProvider);
        final beforeWindow = _historyWindow(before);
        final beforeStart = beforeWindow.turns.isEmpty
            ? 0
            : before.turns.indexOf(beforeWindow.turns.first);
        if (beforeStart > 0) {
          _historyTurnOffset += beforeStart.clamp(1, 8).toInt();
          await _publish(before);
          return const {'ok': true};
        }
        await notifier.loadEarlierHistory();
        final after = _container.read(agentChatNotifierProvider);
        if (beforeWindow.turns.length == agentWindowMaxTimelineTurns &&
            after.turns.length > before.turns.length) {
          _historyTurnOffset += (after.turns.length - before.turns.length)
              .clamp(1, 8)
              .toInt();
        }
        await _publish(after);
        return const {'ok': true};
      case 'loadLatestHistory':
        _historyTurnOffset = 0;
        await _publish(_container.read(agentChatNotifierProvider));
        return const {'ok': true};
      case 'newSession':
        _historyTurnOffset = 0;
        await notifier.newSession();
      case 'switchSession':
        _historyTurnOffset = 0;
        final id = payload['id'];
        if (id is! String || id.isEmpty) {
          throw const FormatException('switchSession requires id');
        }
        await notifier.switchSession(id);
      case 'renameSession':
        final id = payload['id'];
        final name = payload['name'];
        if (id is! String || name is! String) {
          throw const FormatException('renameSession requires id and name');
        }
        await notifier.renameSession(id, name);
      case 'deleteSession':
        final id = payload['id'];
        if (id is! String || id.isEmpty) {
          throw const FormatException('deleteSession requires id');
        }
        await notifier.deleteSession(id);
      case 'compact':
        await notifier.compactNow();
      case 'dismissError':
        notifier.dismissError();
      case 'setPermissionMode':
        final value = payload['value'];
        final mode = AgentPermissionMode.values
            .where((candidate) => candidate.name == value)
            .firstOrNull;
        if (mode == null) {
          throw const FormatException('Invalid permission mode');
        }
        await notifier.setPermissionMode(mode);
      case 'selectModel':
        final providerId = payload['providerId'];
        final model = payload['model'];
        if (providerId is! String || model is! String) {
          throw const FormatException(
            'selectModel requires providerId and model',
          );
        }
        await notifier.selectChatModel(providerId, model);
      case 'setThinkingLevel':
        final value = payload['value'];
        final level = ThinkingLevel.values
            .where((candidate) => candidate.name == value)
            .firstOrNull;
        if (level == null) {
          throw const FormatException('Invalid thinking level');
        }
        await notifier.setThinkingLevel(level);
      case 'setWebAccess':
        final value = payload['value'];
        if (value is! bool) throw const FormatException('value must be bool');
        await _container
            .read(agentSettingsProvider.notifier)
            .setWebAccessEnabled(value);
      case 'resolveApproval':
        final value = payload['value'];
        final toolCallId = payload['toolCallId'];
        if (value is! bool || toolCallId is! String || toolCallId.isEmpty) {
          throw const FormatException(
            'resolveApproval requires toolCallId and bool value',
          );
        }
        return {'ok': notifier.resolveToolApproval(toolCallId, value)};
      default:
        throw UnsupportedError('Unsupported Agent window command: $name');
    }
    return null;
  }

  Future<void> _publish(AgentChatState state) async {
    _pendingState = state;
    if (_publishing) return;
    _publishing = true;
    try {
      while (_pendingState != null) {
        final next = _pendingState!;
        _pendingState = null;
        await _publishNow(next);
      }
    } finally {
      _publishing = false;
    }
  }

  Future<void> _publishNow(AgentChatState state) async {
    if (state.status == AgentChatRunStatus.running) {
      _historyTurnOffset = 0;
    }
    _pendingImageAssets.clear();
    _pendingImageAssetBytes = 0;
    _currentImageAssetIds.clear();
    _currentFileImageKeys.clear();
    _fileImageErrors.clear();
    final historyWindow = _historyWindow(state);
    final visibleTurnIds = historyWindow.turns.map((turn) => turn.id).toSet();
    final messageMetadata = _timelineMetadataByMessageIndex(state);
    final visibleMessages = <Message>[
      for (var index = 0; index < state.messages.length; index++)
        if (messageMetadata[index] case final Map<String, Object?> metadata
            when visibleTurnIds.contains(metadata['turnId']))
          state.messages[index],
    ];
    await _prepareFileImageAssets(
      visibleMessages,
      streamingMessage: _historyTurnOffset == 0 ? state.streamingMessage : null,
    );
    final config = _container.read(promptAssistantConfigProvider);
    final chatSettings = _container.read(agentSettingsProvider).settings.chat;
    final modelReference = chatSettings.modelReference;
    await AgentWindowRuntime.instance.publishSnapshot(
      AgentWindowSnapshot(
        revision: _revision++,
        payload: {
          ..._serializeAuthoritativeState(state, historyWindow),
          'locale': _container.read(localeNotifierProvider).toLanguageTag(),
          'theme': _container.read(themeNotifierProvider).name,
          'font': _container.read(fontNotifierProvider).key,
          'fontScale': _container.read(fontScaleNotifierProvider),
          'activeProviderId': modelReference.providerId,
          'activeModel': modelReference.model,
          'modelOptions': [
            for (final provider in config.providers.where(
              (item) => item.enabled,
            ))
              for (final model in config.modelsForProviderTask(
                providerId: provider.id,
                taskType: AssistantTaskType.chat,
              ))
                if (!model.isPlaceholder)
                  {
                    'providerId': provider.id,
                    'providerName': provider.name,
                    'model': model.name,
                    'displayName': model.displayName,
                  },
          ],
          'thinkingLevel': state.thinkingLevel.name,
          'thinkingLevels': [
            for (final level in state.availableThinkingLevels) level.name,
          ],
          'permissionMode': chatSettings.permissionMode.name,
          'webAccessEnabled': chatSettings.webAccessEnabled,
          'messages': [
            for (var index = 0; index < state.messages.length; index++)
              if (messageMetadata[index]
                  case final Map<String, Object?> metadata
                  when visibleTurnIds.contains(metadata['turnId']))
                {..._serializeMessage(state.messages[index]), ...metadata},
            if (_historyTurnOffset == 0)
              if (state.streamingMessage case final message?)
                {..._serializeMessage(message), 'live': true},
          ],
          'imageAssets': Map<String, Object?>.from(_pendingImageAssets),
          'referencedImageAssets': _currentImageAssetIds.toList(
            growable: false,
          ),
        },
      ),
    );
    _publishedImageAssetIds.addAll(_pendingImageAssets.keys);
    _publishedImageAssetIds.retainAll(_currentImageAssetIds);
    _fileImageAssetIds.removeWhere(
      (key, _) => !_currentFileImageKeys.contains(key),
    );
  }

  Map<String, Object?> _serializeAuthoritativeState(
    AgentChatState state, [
    _AgentWindowHistoryWindow? selectedWindow,
  ]) {
    final window = selectedWindow ?? _historyWindow(state);
    final windowTurnIds = window.turns.map((turn) => turn.id).toSet();
    return {
      'initialized': state.initialized,
      'composerText': state.composerText,
      'running': state.status == AgentChatRunStatus.running,
      'workPhase': state.workPhase.name,
      'routeLabel': state.routeLabel,
      'routeReady': state.routeReady,
      if (state.routeError.isNotEmpty) 'routeError': state.routeError,
      'compacting': state.compacting,
      'sessionTransitioning': state.sessionTransitioning,
      'sessionContentLoading': state.sessionContentLoading,
      'activeSessionId': state.activeSessionId,
      'sessions': [
        for (final session in state.sessions.take(100))
          {
            'id': session.id,
            'name': session.name,
            'updatedAt': session.updatedAt.toUtc().toIso8601String(),
          },
      ],
      'queue': [
        for (final queued in state.queuedMessages)
          {
            'kind': queued.kind.name,
            'id': queued.id,
            'text': queued.text,
            'editable': _messageImages(queued.message).isEmpty,
          },
      ],
      if (state.contextUsage case final usage?) 'contextUsage': usage.toJson(),
      if (state.contextWindow case final window?) 'contextWindow': window,
      'activities': [
        for (final activity in state.activities)
          if ((activity.turnId == null && !window.hasNewer) ||
              windowTurnIds.contains(activity.turnId))
            {
              'toolCallId': activity.toolCallId,
              'toolName': activity.toolName,
              'status': activity.status.name,
              'content': activity.content,
              'args': _ipcValue(activity.args),
              if (activity.turnId != null) 'turnId': activity.turnId,
              if (activity.itemId != null) 'itemId': activity.itemId,
              if (activity.startedAt != null) 'startedAt': activity.startedAt,
              if (activity.completedAt != null)
                'completedAt': activity.completedAt,
            },
      ],
      'timeline': [for (final turn in window.turns) _serializeTurn(turn)],
      'history': {
        'hasEarlier': window.hasEarlier,
        'hasNewer': window.hasNewer,
        if (state.historyCursor case final cursor?)
          'cursor': {
            'beforeSeq': cursor.beforeSeq,
            'parentEntryId': cursor.parentEntryId,
          },
        if (state.prependAnchorEntryId case final anchor?)
          'prependAnchorEntryId': anchor,
      },
      if (state.approvalRequest case final approval?)
        'approval': _serializeApproval(approval),
      'resources': [
        for (final reference in state.pendingResources)
          {
            ...AgentChatResourceReferenceCodec.encodeJsonMap(reference),
            'encoded': AgentChatResourceReferenceCodec.encodeJson(reference),
            'unavailable': state.unavailableResourceKeys.contains(
              AgentChatResourceReferenceCodec.encodeJson(reference),
            ),
          },
      ],
      if (state.error.isNotEmpty) 'error': state.error,
    };
  }

  _AgentWindowHistoryWindow _historyWindow(AgentChatState state) {
    final turns = state.turns;
    final selected = <AgentChatTurnTimeline>[];
    var itemCount = 0;
    var messageCount = 0;
    final offset = _historyTurnOffset.clamp(0, turns.length).toInt();
    _historyTurnOffset = offset;
    final end = turns.length - offset;
    var start = end;
    for (var index = end - 1; index >= 0; index--) {
      final turn = turns[index];
      final turnMessageCount = turn.items
          .where((item) => item.kind != AgentChatTimelineItemKind.toolCall)
          .length;
      if (selected.length == agentWindowMaxTimelineTurns ||
          itemCount + turn.items.length > agentWindowMaxTimelineItems ||
          messageCount + turnMessageCount > agentWindowMaxTranscriptMessages) {
        break;
      }
      selected.insert(0, turn);
      itemCount += turn.items.length;
      messageCount += turnMessageCount;
      start = index;
    }
    return _AgentWindowHistoryWindow(
      turns: List.unmodifiable(selected),
      hasEarlier: start > 0 || state.hasEarlierTurns,
      hasNewer: offset > 0,
    );
  }

  List<Map<String, Object?>?> _timelineMetadataByMessageIndex(
    AgentChatState state,
  ) {
    final metadata = <Map<String, Object?>?>[];
    for (final turn in state.turns) {
      for (final item in turn.items.where(
        (item) => item.kind != AgentChatTimelineItemKind.toolCall,
      )) {
        metadata.add({
          'turnId': turn.id,
          'entryId': item.entryId,
          'seq': item.seq,
          'parentEntryId': item.parentEntryId,
        });
      }
    }
    while (metadata.length < state.messages.length) {
      metadata.add(null);
    }
    if (metadata.length > state.messages.length) {
      metadata.removeRange(state.messages.length, metadata.length);
    }
    return metadata;
  }

  Map<String, Object?> _serializeTurn(AgentChatTurnTimeline turn) => {
    'id': turn.id,
    'status': turn.status.name,
    'firstSeq': turn.firstSeq,
    'lastSeq': turn.lastSeq,
    if (turn.startedAt != null) 'startedAt': turn.startedAt,
    if (turn.completedAt != null) 'completedAt': turn.completedAt,
    if (turn.duration != null) 'durationMs': turn.duration!.inMilliseconds,
    if (turn.error case final error? when error.trim().isNotEmpty)
      'error': error,
    'items': [
      for (final item in turn.items)
        {
          'id': item.id,
          'entryId': item.entryId,
          'seq': item.seq,
          'parentEntryId': item.parentEntryId,
          'kind': item.kind.name,
          if (item.timestamp != null) 'timestamp': item.timestamp,
          if (item.toolCallId != null) 'toolCallId': item.toolCallId,
          if (item.toolName != null) 'toolName': item.toolName,
          'isError': item.isError,
        },
    ],
  };

  @visibleForTesting
  Map<String, Object?> serializeAuthoritativeStateForTesting(
    AgentChatState state,
  ) => _serializeAuthoritativeState(state);

  Future<void> _prepareFileImageAssets(
    List<Message> messages, {
    AssistantMessage? streamingMessage,
  }) async {
    for (final image in <ImageContent>[
      for (final message in messages) ..._messageImagesForTransport(message),
      if (streamingMessage case final message?)
        ..._messageImagesForTransport(message),
    ]) {
      final path = _localImagePath(image.source.url);
      if (path == null) continue;
      final existing = _imageAssetIds[image];
      if (existing != null && _publishedImageAssetIds.contains(existing)) {
        _currentImageAssetIds.add(existing);
        continue;
      }
      try {
        final bytes = await loadAgentWindowImageAsset(path);
        final assetId = existing ?? 'image-${_nextImageAssetId++}';
        _imageAssetIds[image] = assetId;
        final queued = _queueImageAsset(
          assetId,
          base64Encode(bytes),
          bytes.length,
          _imageMimeType(path),
        );
        if (queued) {
          _imageErrors.remove(image);
          _currentImageAssetIds.add(assetId);
        } else {
          _imageErrors[image] = 'image_snapshot_limit';
        }
      } on AgentWindowImageAssetException catch (error) {
        _imageErrors[image] = error.code;
      } on FileSystemException {
        _imageErrors[image] = 'image_unavailable';
      } on FormatException {
        _imageErrors[image] = 'image_invalid';
      }
    }
    await _prepareToolResultImageAssets(
      messages.whereType<ToolResultMessage>(),
    );
  }

  Future<void> _prepareToolResultImageAssets(
    Iterable<ToolResultMessage> messages,
  ) async {
    for (final message in messages) {
      for (final path in _toolResultLocalImagePaths(message)) {
        final key = _toolResultFileKey(message, path);
        _currentFileImageKeys.add(key);
        if (_fileImageAssetIds[key] case final existing?
            when _publishedImageAssetIds.contains(existing)) {
          _currentImageAssetIds.add(existing);
          continue;
        }
        try {
          final bytes = await loadAgentWindowImageAsset(path);
          final assetId =
              _fileImageAssetIds[key] ?? 'tool-image-${_nextImageAssetId++}';
          _fileImageAssetIds[key] = assetId;
          final queued = _queueImageAsset(
            assetId,
            base64Encode(bytes),
            bytes.length,
            _imageMimeType(path),
          );
          if (queued) {
            _currentImageAssetIds.add(assetId);
          } else {
            _fileImageErrors[key] = 'image_snapshot_limit';
          }
        } on AgentWindowImageAssetException catch (error) {
          _fileImageErrors[key] = error.code;
        } on FileSystemException {
          _fileImageErrors[key] = 'image_unavailable';
        } on FormatException {
          _fileImageErrors[key] = 'image_invalid';
        }
      }
    }
  }

  @visibleForTesting
  Future<Map<String, Object?>> serializeToolResultForTesting(
    ToolResultMessage message,
  ) async {
    _pendingImageAssets.clear();
    _currentImageAssetIds.clear();
    _currentFileImageKeys.clear();
    _fileImageErrors.clear();
    await _prepareToolResultImageAssets([message]);
    final result = <String, Object?>{
      'message': _serializeToolResultMessage(message),
      'imageAssets': Map<String, Object?>.from(_pendingImageAssets),
      'referencedImageAssets': _currentImageAssetIds.toList(growable: false),
    };
    _publishedImageAssetIds.addAll(_pendingImageAssets.keys);
    _publishedImageAssetIds.retainAll(_currentImageAssetIds);
    _fileImageAssetIds.removeWhere(
      (key, _) => !_currentFileImageKeys.contains(key),
    );
    return result;
  }

  Map<String, Object?> _serializeMessage(Message message) {
    return switch (message) {
      UserMessage() => {
        'role': 'user',
        'text': message.text,
        'timestamp': message.timestamp,
        'images': [for (final image in message.images) _serializeImage(image)],
      },
      HarnessCustomMessage() when message.customType == 'agentResourcePrompt' =>
        {
          'role': 'user',
          'text': message.content
              .skip(1)
              .whereType<UserTextContent>()
              .map((content) => content.text)
              .join(),
          'timestamp': message.timestamp,
          'images': [
            for (final image in _messageImages(message)) _serializeImage(image),
          ],
        },
      AssistantMessage() => {
        'role': 'assistant',
        'text': message.text,
        'timestamp': message.timestamp,
        'thinking': message.content
            .whereType<AssistantThinkingContent>()
            .map((content) => content.thinking)
            .join(),
        'stopReason': message.stopReason.name,
        if (message.provider case final provider?) 'provider': provider,
        if (message.model case final model?) 'model': model,
        if (message.usage case final usage?) 'usage': usage.toJson(),
        'toolCalls': [
          for (final call in message.toolCalls)
            {
              'id': call.id,
              'name': call.name,
              'args': sanitizeAgentWindowIpcValue(call.arguments),
            },
        ],
        if (message.errorMessage != null) 'error': message.errorMessage,
      },
      ToolResultMessage() => _serializeToolResultMessage(message),
      _ => {'role': 'system', 'text': message.toString()},
    };
  }

  AgentQueuedMessage? _queuedMessage(Map<String, Object?> payload) {
    final kind = payload['kind'];
    final id = payload['id'];
    if (kind is! String || id is! int) return null;
    return _container
        .read(agentChatNotifierProvider)
        .queuedMessages
        .where((item) => item.kind.name == kind && item.id == id)
        .firstOrNull;
  }

  bool _queueImageAsset(
    String assetId,
    String base64Data,
    int decodedBytes,
    String? mimeType,
  ) {
    if (_pendingImageAssets.containsKey(assetId)) return true;
    if (decodedBytes > agentWindowMaxImageAssetBytes ||
        _pendingImageAssets.length >= agentWindowMaxImageAssetsPerSnapshot ||
        _pendingImageAssetBytes + decodedBytes >
            agentWindowMaxImageAssetBytesPerSnapshot) {
      return false;
    }
    _pendingImageAssets[assetId] = {
      'base64': base64Data,
      if (mimeType != null) 'mimeType': mimeType,
    };
    _pendingImageAssetBytes += decodedBytes;
    return true;
  }

  Map<String, Object?> _serializeImage(ImageContent image) {
    if (image.source.base64Data case final data?) {
      if (data.length > ((agentWindowMaxImageAssetBytes + 2) ~/ 3) * 4) {
        return const {'error': 'image_too_large'};
      }
      final List<int> bytes;
      try {
        bytes = base64Decode(data);
      } on FormatException {
        return const {'error': 'image_invalid'};
      }
      if (bytes.length > agentWindowMaxImageAssetBytes) {
        return const {'error': 'image_too_large'};
      }
      final assetId = _imageAssetIds.putIfAbsent(
        image,
        () => 'image-${_nextImageAssetId++}',
      );
      _currentImageAssetIds.add(assetId);
      if (!_publishedImageAssetIds.contains(assetId)) {
        if (!_queueImageAsset(
          assetId,
          data,
          bytes.length,
          image.source.mimeType,
        )) {
          _currentImageAssetIds.remove(assetId);
          return const {'error': 'image_snapshot_limit'};
        }
      }
      return {'assetId': assetId};
    }
    if (_localImagePath(image.source.url) != null) {
      if (_imageAssetIds[image] case final assetId?) {
        return {'assetId': assetId};
      }
      return {'error': _imageErrors[image] ?? 'image_unavailable'};
    }
    return {
      if (image.source.url case final url?)
        'url': sanitizeAgentWindowRemoteUrl(url),
    };
  }

  Map<String, Object?> _serializeToolResultMessage(ToolResultMessage message) {
    final files = _toolResultFilePaths(message);
    final preferFileImages = files.any(_isImagePath);
    return {
      'role': 'tool',
      'toolCallId': message.toolCallId,
      'toolName': message.toolName,
      'text': message.text,
      'timestamp': message.timestamp,
      'isError': message.isError,
      if (message.usage case final usage?) 'usage': usage.toJson(),
      if (message.addedToolNames case final names?)
        'addedToolNames': List<String>.of(names),
      if (message.details != null) 'details': _ipcToolDetails(message.details),
      'artifacts': [
        for (final path in files)
          if (!_isImagePath(path))
            {
              'kind': 'file',
              'name': _artifactDisplayName(path),
              'availability': 'primary_only',
            },
      ],
      'images': [
        for (final path in files)
          if (_isImagePath(path))
            if (_localImagePath(path) case final localPath?)
              _serializeToolFileImage(message, localPath)
            else
              {'url': sanitizeAgentWindowRemoteUrl(path)},
        if (!preferFileImages)
          for (final content in message.content)
            if (content is ToolResultImageContent)
              if (_serializeToolContentImage(message, content, files)
                  case final image?)
                image,
      ],
    };
  }

  Map<String, Object?>? _serializeToolContentImage(
    ToolResultMessage message,
    ToolResultImageContent content,
    List<String> detailFiles,
  ) {
    final source = content.image.source.url;
    if (_localImagePath(source) case final path?) {
      if (detailFiles.any((file) => _localImagePath(file) == path)) return null;
      return _serializeToolFileImage(message, path);
    }
    return _serializeImage(content.image);
  }

  Map<String, Object?> _serializeToolFileImage(
    ToolResultMessage message,
    String path,
  ) {
    final key = _toolResultFileKey(message, path);
    if (_fileImageAssetIds[key] case final assetId?) {
      return {'assetId': assetId};
    }
    return {'error': _fileImageErrors[key] ?? 'image_unavailable'};
  }

  List<String> _toolResultFilePaths(ToolResultMessage message) {
    final details = message.details;
    return <String>{
      if (details is Map && details['files'] is List)
        for (final file in details['files'] as List)
          if (file is String) file,
    }.toList(growable: false);
  }

  List<String> _toolResultLocalImagePaths(ToolResultMessage message) {
    final paths = <String>{
      for (final path in _toolResultFilePaths(message))
        if (_isImagePath(path))
          if (_localImagePath(path) case final localPath?) localPath,
      for (final content in message.content)
        if (content is ToolResultImageContent)
          if (_localImagePath(content.image.source.url) case final path?) path,
    };
    return paths.toList(growable: false);
  }

  String _toolResultFileKey(ToolResultMessage message, String path) =>
      '${message.toolCallId}\u0000$path';

  String _artifactDisplayName(String value) {
    final uri = Uri.tryParse(value);
    final source = uri != null && uri.hasScheme ? uri.path : value;
    final segments = source.split(RegExp(r'[\\/]'));
    return segments.lastWhere(
      (segment) => segment.isNotEmpty,
      orElse: () => 'file',
    );
  }

  String? _localImagePath(String? value) {
    if (value == null || value.isEmpty) return null;
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) {
      return value;
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme == 'file') return uri.toFilePath();
      return null;
    }
    return value;
  }

  Object? _ipcToolDetails(Object? value) =>
      sanitizeAgentWindowIpcValue(sanitizeAgentWindowToolDetails(value));

  Map<String, Object?> _serializeApproval(AgentToolApprovalRequest approval) =>
      {
        'toolCallId': approval.toolCallId,
        'toolName': approval.toolName,
        'args': sanitizeAgentWindowIpcValue(approval.args),
        'estimatedAnlas': approval.estimatedAnlas,
        if (approval.turnId != null) 'turnId': approval.turnId,
        if (approval.itemId != null) 'itemId': approval.itemId,
      };

  @visibleForTesting
  Map<String, Object?> serializeApprovalForTesting(
    AgentToolApprovalRequest approval,
  ) => _serializeApproval(approval);

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String? _imageMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return null;
  }

  Object? _ipcValue(Object? value) {
    return sanitizeAgentWindowIpcValue(value);
  }

  List<ImageContent> _messageImagesForTransport(Message message) =>
      switch (message) {
        UserMessage() => message.images,
        HarnessCustomMessage()
            when message.customType == 'agentResourcePrompt' =>
          _messageImages(message),
        _ => const [],
      };

  @visibleForTesting
  Future<Map<String, Object?>> serializeMessageForTesting(
    Message message,
  ) async {
    _pendingImageAssets.clear();
    _currentImageAssetIds.clear();
    _fileImageErrors.clear();
    if (message is ToolResultMessage) {
      await _prepareToolResultImageAssets([message]);
    }
    return _serializeMessage(message);
  }

  @visibleForTesting
  Future<List<Map<String, Object?>>> serializeMessagesForTesting(
    List<Message> messages,
  ) async {
    _pendingImageAssets.clear();
    _currentImageAssetIds.clear();
    _currentFileImageKeys.clear();
    _fileImageErrors.clear();
    await _prepareToolResultImageAssets(
      messages.whereType<ToolResultMessage>(),
    );
    return [for (final message in messages) _serializeMessage(message)];
  }

  List<ImageContent> _messageImages(AgentMessage message) => switch (message) {
    UserMessage() => message.images,
    HarnessCustomMessage() when message.customType == 'agentResourcePrompt' => [
      for (final content in message.content.skip(1))
        if (content is UserImageContent) content.image,
    ],
    _ => const [],
  };

  void dispose() {
    _subscription?.close();
    _subscription = null;
    _localeSubscription?.close();
    _localeSubscription = null;
    _appearanceSubscription?.close();
    _appearanceSubscription = null;
    _fontSubscription?.close();
    _fontSubscription = null;
    _fontScaleSubscription?.close();
    _fontScaleSubscription = null;
    _configSubscription?.close();
    _configSubscription = null;
    _agentSettingsSubscription?.close();
    _agentSettingsSubscription = null;
  }
}

/// Reads and validates a tool-produced image in the primary engine before it
/// crosses the detached-window IPC boundary.
@visibleForTesting
Future<Uint8List> loadAgentWindowImageAsset(String path) async {
  final file = File(path);
  final length = await file.length();
  if (length > agentWindowMaxImageAssetBytes) {
    throw const AgentWindowImageAssetException('image_too_large');
  }
  final bytes = await file.readAsBytes();
  final lower = path.toLowerCase();
  final valid = switch (lower) {
    _ when lower.endsWith('.png') =>
      bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a,
    _ when lower.endsWith('.jpg') || lower.endsWith('.jpeg') =>
      bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff,
    _ when lower.endsWith('.webp') =>
      bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP',
    _ when lower.endsWith('.gif') =>
      bytes.length >= 6 &&
          (String.fromCharCodes(bytes.sublist(0, 6)) == 'GIF87a' ||
              String.fromCharCodes(bytes.sublist(0, 6)) == 'GIF89a'),
    _ => false,
  };
  if (!valid) throw const FormatException('Invalid image asset');
  return bytes;
}

final class AgentWindowImageAssetException implements Exception {
  const AgentWindowImageAssetException(this.code);

  final String code;
}

/// Removes primary-only file metadata recursively before protocol encoding.
@visibleForTesting
Object? sanitizeAgentWindowToolDetails(Object? value) {
  if (value is Iterable) {
    return [for (final item in value) sanitizeAgentWindowToolDetails(item)];
  }
  if (value is! Map) return value;
  return {
    for (final entry in value.entries)
      if (entry.key.toString() != 'files' &&
          entry.key.toString() != 'preferFileImages')
        entry.key.toString(): sanitizeAgentWindowToolDetails(entry.value),
  };
}

/// Converts arbitrary tool values to bounded IPC-safe semantics while keeping
/// the argument shape understandable for approval and audit surfaces.
@visibleForTesting
Object? sanitizeAgentWindowIpcValue(
  Object? value, [
  String? fieldName,
  int depth = 0,
]) {
  if (depth > 16) return '[truncated]';
  if (value is Uint8List || value is ByteBuffer || value is ByteData) {
    return '[binary omitted]';
  }
  if (value == null || value is bool || value is num) return value;
  if (value is String) {
    if (_isSensitiveAgentWindowField(fieldName) ||
        _looksLikeAgentWindowCredential(value)) {
      return '[redacted]';
    }
    if (_looksLikeAgentWindowEmbeddedData(value)) return '[binary omitted]';
    if (_isLocalAgentWindowPathField(fieldName) || _looksLikeLocalPath(value)) {
      return '[local path]';
    }
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return sanitizeAgentWindowRemoteUrl(value);
    }
    return value.length <= 16384 ? value : '${value.substring(0, 16384)}…';
  }
  if (value is Map) {
    final entries = value.entries.take(512).toList(growable: false);
    return <String, Object?>{
      for (final entry in entries)
        entry.key.toString(): sanitizeAgentWindowIpcValue(
          entry.value,
          entry.key.toString(),
          depth + 1,
        ),
      if (value.length > entries.length) '__truncated__': true,
    };
  }
  if (value is Iterable) {
    final boundedItems = value.take(513).toList(growable: false);
    final truncated = boundedItems.length > 512;
    final items = truncated ? boundedItems.take(512) : boundedItems;
    return <Object?>[
      for (final item in items)
        sanitizeAgentWindowIpcValue(item, fieldName, depth + 1),
      if (truncated) '[truncated]',
    ];
  }
  return value.toString();
}

@visibleForTesting
String sanitizeAgentWindowRemoteUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return value;
  }
  final query = <String, String>{};
  for (final entry in uri.queryParameters.entries) {
    query[entry.key] = _isSensitiveAgentWindowField(entry.key)
        ? '[redacted]'
        : entry.value;
  }
  return uri
      .replace(
        userInfo: '',
        queryParameters: query.isEmpty ? null : query,
        fragment: '',
      )
      .toString();
}

bool _isSensitiveAgentWindowField(String? value) {
  if (value == null) return false;
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized.contains('token') ||
      normalized.contains('secret') ||
      normalized.contains('password') ||
      normalized.contains('credential') ||
      normalized == 'authorization' ||
      normalized == 'cookie' ||
      normalized == 'auth' ||
      normalized == 'key' ||
      normalized == 'apikey' ||
      normalized == 'accesskey' ||
      normalized == 'privatekey' ||
      normalized.contains('signature') ||
      normalized.endsWith('sig');
}

class _AgentWindowHistoryWindow {
  const _AgentWindowHistoryWindow({
    required this.turns,
    required this.hasEarlier,
    required this.hasNewer,
  });

  final List<AgentChatTurnTimeline> turns;
  final bool hasEarlier;
  final bool hasNewer;
}

bool _looksLikeAgentWindowCredential(String value) {
  final normalized = value.trimLeft().toLowerCase();
  return normalized.startsWith('bearer ') ||
      normalized.startsWith('basic ') ||
      normalized.contains('-----begin private key-----');
}

bool _looksLikeAgentWindowEmbeddedData(String value) {
  final normalized = value.trim();
  if (normalized.toLowerCase().startsWith('data:')) return true;
  return normalized.length >= 1024 &&
      normalized.length % 4 == 0 &&
      RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(normalized);
}

bool _isLocalAgentWindowPathField(String? value) {
  if (value == null) return false;
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized == 'path' ||
      normalized.endsWith('path') ||
      normalized == 'directory' ||
      normalized.endsWith('directory');
}

bool _looksLikeLocalPath(String value) {
  final normalized = value.trim();
  if (normalized.startsWith('file:') ||
      normalized.startsWith('/') ||
      normalized.startsWith(r'\\') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(normalized)) {
    return true;
  }
  return normalized.split(RegExp(r'[\\/]')).any((part) => part == '..');
}
