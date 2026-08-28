import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgentPromptDraftState {
  const AgentPromptDraftState({
    this.saved = '',
    this.draft = '',
    this.revision = 0,
    this.saving = false,
  });

  final String saved;
  final String draft;
  final int revision;
  final bool saving;

  bool get dirty => draft != saved;

  AgentPromptDraftState copyWith({
    String? saved,
    String? draft,
    int? revision,
    bool? saving,
  }) => AgentPromptDraftState(
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
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

  void synchronizeSaved(String value) {
    if (state.dirty || state.saving) return;
    state = AgentPromptDraftState(
      saved: value,
      draft: value,
      revision: state.revision,
    );
  }

  void updateDraft(String value) {
    state = state.copyWith(draft: value, revision: state.revision + 1);
  }

  void discard() {
    state = state.copyWith(draft: state.saved, revision: state.revision + 1);
  }

  void beginSave() => state = state.copyWith(saving: true);

  void finishSave({required int revision, required String saved}) {
    state = state.copyWith(
      saved: saved,
      draft: state.revision == revision ? saved : state.draft,
      saving: false,
    );
  }

  void failSave() => state = state.copyWith(saving: false);
}
