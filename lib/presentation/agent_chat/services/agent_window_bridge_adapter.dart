import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/windowing/agent_window_protocol.dart';
import '../../../core/windowing/agent_window_runtime.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../providers/agent_chat_notifier.dart';
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
  AgentWindowBridgeAdapter._(this._container);

  final ProviderContainer _container;
  ProviderSubscription<AgentChatState>? _subscription;
  ProviderSubscription<Locale>? _localeSubscription;
  ProviderSubscription<Object?>? _appearanceSubscription;
  ProviderSubscription<Object?>? _fontSubscription;
  ProviderSubscription<Object?>? _fontScaleSubscription;
  ProviderSubscription<Object?>? _configSubscription;
  ProviderSubscription<AgentSettingsState>? _agentSettingsSubscription;
  int _revision = 0;
  AgentChatState? _pendingState;
  bool _publishing = false;
  final Map<ImageContent, String> _imageAssetIds = Map.identity();
  final Set<String> _publishedImageAssetIds = {};
  final Set<String> _currentImageAssetIds = {};
  final Map<String, Object?> _pendingImageAssets = {};
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
    final notifier = _container.read(agentChatNotifierProvider.notifier);
    switch (name) {
      case 'dockRequested':
        await _container
            .read(layoutStateNotifierProvider.notifier)
            .setRightPanelExpanded(true);
      case 'sendText':
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
      case 'newSession':
        await notifier.newSession();
      case 'switchSession':
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
        if (value is! bool) {
          throw const FormatException('resolveApproval requires bool value');
        }
        notifier.resolveToolApproval(value);
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

  Future<void> _publishNow(AgentChatState state) {
    _pendingImageAssets.clear();
    _currentImageAssetIds.clear();
    final config = _container.read(promptAssistantConfigProvider);
    final chatSettings = _container.read(agentSettingsProvider).settings.chat;
    final modelReference = chatSettings.modelReference;
    final operation = AgentWindowRuntime.instance.publishSnapshot(
      AgentWindowSnapshot(
        revision: _revision++,
        payload: {
          'initialized': state.initialized,
          'locale': _container.read(localeNotifierProvider).toLanguageTag(),
          'theme': _container.read(themeNotifierProvider).name,
          'font': _container.read(fontNotifierProvider).key,
          'fontScale': _container.read(fontScaleNotifierProvider),
          'composerText': state.composerText,
          'running': state.status == AgentChatRunStatus.running,
          'workPhase': state.workPhase.name,
          'routeLabel': state.routeLabel,
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
          if (state.contextWindow case final window?) 'contextWindow': window,
          'routeReady': state.routeReady,
          'permissionMode': chatSettings.permissionMode.name,
          'webAccessEnabled': chatSettings.webAccessEnabled,
          'compacting': state.compacting,
          'activeSessionId': state.activeSessionId,
          'sessions': [
            for (final session in state.sessions)
              {'id': session.id, 'name': session.name},
          ],
          'messages': [
            for (final message in state.messages) _serializeMessage(message),
            if (state.streamingMessage case final message?)
              {..._serializeMessage(message), 'live': true},
          ],
          'imageAssets': Map<String, Object?>.from(_pendingImageAssets),
          'referencedImageAssets': _currentImageAssetIds.toList(
            growable: false,
          ),
          'queue': [
            for (final queued in state.queuedMessages)
              {
                'kind': queued.kind.name,
                'id': queued.id,
                'text': queued.text,
                'editable': _messageImages(queued.message).isEmpty,
              },
          ],
          if (state.contextUsage case final usage?)
            'contextUsage': usage.toJson(),
          'activities': [
            for (final activity in state.activities)
              {
                'toolCallId': activity.toolCallId,
                'toolName': activity.toolName,
                'status': activity.status.name,
                'content': activity.content,
              },
          ],
          if (state.approvalRequest case final approval?)
            'approval': {
              'toolCallId': approval.toolCallId,
              'toolName': approval.toolName,
              'estimatedAnlas': approval.estimatedAnlas,
            },
          'resources': [
            for (final reference in state.pendingResources)
              {
                ...AgentChatResourceReferenceCodec.encodeJsonMap(reference),
                'encoded': AgentChatResourceReferenceCodec.encodeJson(
                  reference,
                ),
                'unavailable': state.unavailableResourceKeys.contains(
                  AgentChatResourceReferenceCodec.encodeJson(reference),
                ),
              },
          ],
          if (state.error.isNotEmpty) 'error': state.error,
        },
      ),
    );
    _publishedImageAssetIds.retainAll(_currentImageAssetIds);
    return operation;
  }

  Map<String, Object?> _serializeMessage(Message message) {
    return switch (message) {
      UserMessage() => {
        'role': 'user',
        'text': message.text,
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
          'images': [
            for (final image in _messageImages(message)) _serializeImage(image),
          ],
        },
      AssistantMessage() => {
        'role': 'assistant',
        'text': message.text,
        'thinking': message.content
            .whereType<AssistantThinkingContent>()
            .map((content) => content.thinking)
            .join(),
        'stopReason': message.stopReason.name,
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

  Map<String, Object?> _serializeImage(ImageContent image) {
    if (image.source.base64Data case final data?) {
      final assetId = _imageAssetIds.putIfAbsent(
        image,
        () => 'image-${_nextImageAssetId++}',
      );
      _currentImageAssetIds.add(assetId);
      if (_publishedImageAssetIds.add(assetId)) {
        _pendingImageAssets[assetId] = {
          'base64': data,
          if (image.source.mimeType case final mime?) 'mimeType': mime,
        };
      }
      return {'assetId': assetId};
    }
    return {if (image.source.url case final url?) 'url': url};
  }

  Map<String, Object?> _serializeToolResultMessage(ToolResultMessage message) {
    final details = message.details;
    final files = <String>[
      if (details is Map && details['files'] is List)
        for (final file in details['files'] as List)
          if (file is String) file,
    ];
    final preferFileImages =
        files.isNotEmpty &&
        details is Map &&
        details['preferFileImages'] == true;
    return {
      'role': 'tool',
      'toolCallId': message.toolCallId,
      'toolName': message.toolName,
      'text': message.text,
      'isError': message.isError,
      'images': [
        if (!preferFileImages)
          for (final content in message.content)
            if (content is ToolResultImageContent &&
                !files.contains(content.image.source.url))
              _serializeImage(content.image),
      ],
      'files': files,
    };
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
