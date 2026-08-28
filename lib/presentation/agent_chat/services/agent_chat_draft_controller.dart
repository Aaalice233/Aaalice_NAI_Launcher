import 'dart:convert';

import '../../../core/agent/agent.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/resources/agent_chat_resource_draft_store.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../providers/agent_chat_state.dart';
import 'agent_resource_resolver.dart';

class AgentChatSessionDraft {
  const AgentChatSessionDraft({
    required this.resources,
    required this.composerText,
  });

  final List<AgentChatResourceReference> resources;
  final String composerText;
}

/// Owns persistence and availability checks for composer and resource drafts.
class AgentChatDraftController {
  AgentChatDraftController({
    required AgentChatResourceDraftStore resourceStore,
    required LocalStorageService localStorage,
    required AgentChatState Function() readState,
    required void Function(AgentChatState state) writeState,
    required AgentResourceResolver Function() createResourceResolver,
    required bool Function() isMounted,
  }) : _resourceStore = resourceStore,
       _localStorage = localStorage,
       _readState = readState,
       _writeState = writeState,
       _createResourceResolver = createResourceResolver,
       _isMounted = isMounted;

  final AgentChatResourceDraftStore _resourceStore;
  final LocalStorageService _localStorage;
  final AgentChatState Function() _readState;
  final void Function(AgentChatState) _writeState;
  final AgentResourceResolver Function() _createResourceResolver;
  final bool Function() _isMounted;

  Future<void>? _composerDraftSaveFuture;
  bool _composerDraftDirty = false;

  Future<AgentChatSessionDraft> loadSession(String sessionId) async {
    final resources = await _resourceStore.load(sessionId);
    final composerText =
        _localStorage.getSetting<String>(
          'agent_chat_composer_draft:$sessionId',
          defaultValue: '',
        ) ??
        '';
    return AgentChatSessionDraft(
      resources: resources,
      composerText: composerText,
    );
  }

  Future<void> deleteSession(String sessionId) =>
      _resourceStore.deleteSession(sessionId);

  Future<void> savePendingResources(
    String sessionId,
    List<AgentChatResourceReference> resources,
  ) => _resourceStore.save(sessionId, resources);

  Future<void> addPendingResource(AgentChatResourceReference reference) async {
    AgentChatResourceReferenceCodec.encodeJson(reference);
    final current = _readState();
    if (current.activeSessionId.isEmpty ||
        current.pendingResources.contains(reference)) {
      return;
    }
    final resources = [...current.pendingResources, reference];
    _writeState(current.copyWith(pendingResources: resources));
    await _resourceStore.save(current.activeSessionId, resources);
  }

  Future<void> removePendingResource(int index) async {
    final current = _readState();
    if (index < 0 || index >= current.pendingResources.length) return;
    final resources = [...current.pendingResources]..removeAt(index);
    final removedKey = AgentChatResourceReferenceCodec.encodeJson(
      current.pendingResources[index],
    );
    final unavailable = {...current.unavailableResourceKeys}
      ..remove(removedKey);
    _writeState(
      current.copyWith(
        pendingResources: resources,
        unavailableResourceKeys: unavailable,
      ),
    );
    await _resourceStore.save(current.activeSessionId, resources);
  }

  Future<void> clearPendingResources() async {
    final current = _readState();
    if (current.pendingResources.isEmpty) return;
    _writeState(current.copyWith(pendingResources: const []));
    await _resourceStore.save(current.activeSessionId, const []);
    _writeState(_readState().copyWith(unavailableResourceKeys: const {}));
  }

  void setComposerText(String value) {
    final current = _readState();
    if (value == current.composerText) return;
    _writeState(current.copyWith(composerText: value));
    _composerDraftDirty = true;
    _composerDraftSaveFuture ??= _saveComposerDraftLoop();
  }

  Future<void> _saveComposerDraftLoop() async {
    try {
      while (_composerDraftDirty) {
        _composerDraftDirty = false;
        final current = _readState();
        if (current.activeSessionId.isNotEmpty) {
          await _localStorage.setSetting(
            'agent_chat_composer_draft:${current.activeSessionId}',
            current.composerText,
          );
        }
      }
    } finally {
      _composerDraftSaveFuture = null;
      if (_composerDraftDirty) {
        _composerDraftSaveFuture = _saveComposerDraftLoop();
      }
    }
  }

  Future<void> clearComposerText() async {
    _composerDraftDirty = false;
    await _composerDraftSaveFuture;
    final current = _readState();
    _writeState(current.copyWith(composerText: ''));
    if (current.activeSessionId.isNotEmpty) {
      await _localStorage.setSetting(
        'agent_chat_composer_draft:${current.activeSessionId}',
        '',
      );
    }
  }

  Future<void> refreshPendingResourceAvailability({
    bool resolveExternal = false,
  }) async {
    final current = _readState();
    if (!_isMounted() || current.pendingResources.isEmpty) {
      if (_isMounted() && current.unavailableResourceKeys.isNotEmpty) {
        _writeState(current.copyWith(unavailableResourceKeys: const {}));
      }
      return;
    }
    final unavailable = <String>{};
    for (final reference in current.pendingResources) {
      var exists = true;
      try {
        final resolver = _createResourceResolver();
        exists = resolveExternal
            ? await resolver.exists(reference)
            : await resolver.existsWithoutExternalResolution(reference);
      } catch (error, stackTrace) {
        exists = false;
        AppLogger.e(
          'Failed to resolve an Agent resource reference',
          error,
          stackTrace,
          'AgentResource',
        );
      }
      if (!exists) {
        unavailable.add(AgentChatResourceReferenceCodec.encodeJson(reference));
      }
    }
    if (_isMounted()) {
      _writeState(_readState().copyWith(unavailableResourceKeys: unavailable));
    }
  }

  Future<bool> validatePendingResourcesForSend() async {
    await refreshPendingResourceAvailability(resolveExternal: true);
    final current = _readState();
    if (current.unavailableResourceKeys.isEmpty) return true;
    _writeState(
      current.copyWith(
        error: 'Remove unavailable resource references before sending.',
      ),
    );
    return false;
  }

  Future<ResolvedAgentResource?> resolveResourcePreview(
    AgentChatResourceReference reference,
  ) => _createResourceResolver().resolve(reference);

  HarnessCustomMessage resourcePromptMessage(
    UserMessage userMessage,
    List<AgentChatResourceReference> references,
  ) {
    final unavailable = _readState().unavailableResourceKeys;
    final payload = {
      'schemaVersion': 1,
      'references': [
        for (final reference in references)
          {
            ...AgentChatResourceReferenceCodec.encodeJsonMap(reference),
            'available': !unavailable.contains(
              AgentChatResourceReferenceCodec.encodeJson(reference),
            ),
          },
      ],
    };
    return HarnessCustomMessage(
      customType: 'agentResourcePrompt',
      display: true,
      blockContent: [
        UserTextContent(
          '<agent-resource-references>\n${jsonEncode(payload)}\n'
          '</agent-resource-references>\n'
          'Resolve available references through their owning application '
          'tools. Do not use references marked unavailable.',
        ),
        ...userMessage.content,
      ],
      details: {
        'visibleContentOffset': 1,
        'references': [
          for (final reference in references)
            AgentChatResourceReferenceCodec.encodeJsonMap(reference),
        ],
      },
      timestamp: userMessage.timestamp,
    );
  }

  Future<void> consumePendingResources(
    List<AgentChatResourceReference> consumed,
  ) async {
    if (consumed.isEmpty) return;
    final current = _readState();
    final remaining = [
      for (final reference in current.pendingResources)
        if (!consumed.contains(reference)) reference,
    ];
    _writeState(
      current.copyWith(
        pendingResources: remaining,
        unavailableResourceKeys: {
          for (final reference in remaining)
            AgentChatResourceReferenceCodec.encodeJson(reference),
        }.intersection(current.unavailableResourceKeys),
      ),
    );
    await _resourceStore.save(current.activeSessionId, remaining);
  }
}
