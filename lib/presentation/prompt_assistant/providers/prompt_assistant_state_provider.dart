import 'package:flutter_riverpod/flutter_riverpod.dart';

class PromptAssistantOperationState {
  final bool expanded;
  final bool hovering;
  final bool processing;
  final String? action;
  final String? error;

  const PromptAssistantOperationState({
    this.expanded = false,
    this.hovering = false,
    this.processing = false,
    this.action,
    this.error,
  });

  PromptAssistantOperationState copyWith({
    bool? expanded,
    bool? hovering,
    bool? processing,
    String? action,
    String? error,
    bool clearError = false,
    bool clearAction = false,
  }) {
    return PromptAssistantOperationState(
      expanded: expanded ?? this.expanded,
      hovering: hovering ?? this.hovering,
      processing: processing ?? this.processing,
      action: clearAction ? null : (action ?? this.action),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final promptAssistantStateProvider =
    StateNotifierProvider<
      PromptAssistantStateNotifier,
      Map<String, PromptAssistantOperationState>
    >((ref) => PromptAssistantStateNotifier());

class PromptAssistantStateNotifier
    extends StateNotifier<Map<String, PromptAssistantOperationState>> {
  PromptAssistantStateNotifier() : super(const {});

  PromptAssistantOperationState getState(String sessionId) {
    return state[sessionId] ?? const PromptAssistantOperationState();
  }

  void _put(String sessionId, PromptAssistantOperationState value) {
    state = {...state, sessionId: value};
  }

  void setExpanded(String sessionId, bool expanded) {
    _put(sessionId, getState(sessionId).copyWith(expanded: expanded));
  }

  void setHovering(String sessionId, bool hovering) {
    _put(sessionId, getState(sessionId).copyWith(hovering: hovering));
  }

  void startProcessing(String sessionId, String action) {
    _put(
      sessionId,
      getState(
        sessionId,
      ).copyWith(processing: true, action: action, clearError: true),
    );
  }

  void finishProcessing(String sessionId) {
    _put(
      sessionId,
      getState(sessionId).copyWith(processing: false, clearAction: true),
    );
  }

  void setError(String sessionId, String error) {
    _put(
      sessionId,
      getState(
        sessionId,
      ).copyWith(processing: false, clearAction: true, error: error),
    );
  }
}
