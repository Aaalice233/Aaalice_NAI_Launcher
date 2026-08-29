import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/agent/agent_settings.dart';

class AgentPromptDraftState {
  const AgentPromptDraftState({
    this.saved = '',
    this.draft = '',
    this.savedMode = AgentSystemPromptMode.append,
    this.draftMode = AgentSystemPromptMode.append,
    this.revision = 0,
    this.saving = false,
  });

  final String saved;
  final String draft;
  final AgentSystemPromptMode savedMode;
  final AgentSystemPromptMode draftMode;
  final int revision;
  final bool saving;

  bool get dirty => draft != saved || draftMode != savedMode;

  AgentPromptDraftState copyWith({
    String? saved,
    String? draft,
    AgentSystemPromptMode? savedMode,
    AgentSystemPromptMode? draftMode,
    int? revision,
    bool? saving,
  }) => AgentPromptDraftState(
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    savedMode: savedMode ?? this.savedMode,
    draftMode: draftMode ?? this.draftMode,
    revision: revision ?? this.revision,
    saving: saving ?? this.saving,
  );
}

final agentPromptDraftProvider =
    StateNotifierProvider<AgentPromptDraftNotifier, AgentPromptDraftState>(
      (ref) => AgentPromptDraftNotifier(),
    );

class AgentPromptDraftNotifier extends StateNotifier<AgentPromptDraftState> {
  AgentPromptDraftNotifier() : super(const AgentPromptDraftState());

  void synchronizeSaved({
    required String value,
    required AgentSystemPromptMode mode,
  }) {
    if (state.dirty || state.saving) return;
    state = AgentPromptDraftState(
      saved: value,
      draft: value,
      savedMode: mode,
      draftMode: mode,
      revision: state.revision,
    );
  }

  void updateDraft(String value) {
    state = state.copyWith(draft: value, revision: state.revision + 1);
  }

  void updateMode(AgentSystemPromptMode mode) {
    state = state.copyWith(draftMode: mode, revision: state.revision + 1);
  }

  void discard() {
    state = state.copyWith(
      draft: state.saved,
      draftMode: state.savedMode,
      revision: state.revision + 1,
    );
  }

  void beginSave() => state = state.copyWith(saving: true);

  void finishSave({
    required int revision,
    required String saved,
    required AgentSystemPromptMode savedMode,
  }) {
    state = state.copyWith(
      saved: saved,
      savedMode: savedMode,
      draft: state.revision == revision ? saved : state.draft,
      draftMode: state.revision == revision ? savedMode : state.draftMode,
      saving: false,
    );
  }

  void failSave() => state = state.copyWith(saving: false);
}
