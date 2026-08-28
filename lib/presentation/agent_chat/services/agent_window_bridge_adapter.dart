import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/windowing/agent_window_protocol.dart';
import '../../../core/windowing/agent_window_runtime.dart';
import '../providers/agent_chat_notifier.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../providers/layout_state_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../prompt_assistant/providers/web_access_provider.dart';

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
  ProviderSubscription<WebAccessConfigState>? _webAccessSubscription;
  int _revision = 0;

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
    adapter._webAccessSubscription = container.listen<WebAccessConfigState>(
      webAccessConfigProvider,
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
        await notifier.send(text.trim());
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
      case 'setWebAccess':
        final value = payload['value'];
        if (value is! bool) throw const FormatException('value must be bool');
        await _container
            .read(webAccessConfigProvider.notifier)
            .setEnabled(value);
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

  Future<void> _publish(AgentChatState state) {
    return AgentWindowRuntime.instance.publishSnapshot(
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
          'routeLabel': state.routeLabel,
          'routeReady': state.routeReady,
          'permissionMode': _container
              .read(promptAssistantConfigProvider)
              .agentPermissionMode
              .name,
          'webAccessEnabled': _container
              .read(webAccessConfigProvider)
              .config
              .enabled,
          'compacting': state.compacting,
          'activeSessionId': state.activeSessionId,
          'sessions': [
            for (final session in state.sessions)
              {'id': session.id, 'name': session.name},
          ],
          'messages': [
            for (final message in state.messages) _serializeMessage(message),
            if (state.streamingText.isNotEmpty)
              {'role': 'assistant', 'text': state.streamingText, 'live': true},
          ],
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
  }

  Map<String, Object?> _serializeMessage(Message message) {
    return switch (message) {
      UserMessage() => {'role': 'user', 'text': message.text},
      HarnessCustomMessage() when message.customType == 'agentResourcePrompt' =>
        {
          'role': 'user',
          'text': message.content
              .skip(1)
              .whereType<UserTextContent>()
              .map((content) => content.text)
              .join(),
        },
      AssistantMessage() => {'role': 'assistant', 'text': message.text},
      ToolResultMessage() => {'role': 'tool', 'text': message.text},
      _ => {'role': 'system', 'text': message.toString()},
    };
  }

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
    _webAccessSubscription?.close();
    _webAccessSubscription = null;
  }
}
