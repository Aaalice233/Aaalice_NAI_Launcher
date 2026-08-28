import 'cloud_sync_ui_provider.dart';

/// Keeps pending UI conflict decisions separate from coordinator execution.
class CloudSyncConflictSelections {
  final Map<String, CloudSyncConflictChoice> choices = {};

  List<CloudSyncConflictView> chooseOne(
    List<CloudSyncConflictView> conflicts,
    String conflictId,
    CloudSyncConflictChoice choice,
  ) {
    choices[conflictId] = choice;
    return [
      for (final conflict in conflicts)
        _copy(conflict, conflict.id == conflictId ? choice : conflict.choice),
    ];
  }

  List<CloudSyncConflictView> chooseAll(
    List<CloudSyncConflictView> conflicts,
    CloudSyncConflictChoice choice,
  ) {
    for (final conflict in conflicts) {
      choices[conflict.id] = choice;
    }
    return [for (final conflict in conflicts) _copy(conflict, choice)];
  }

  void clear() => choices.clear();

  CloudSyncConflictView _copy(
    CloudSyncConflictView conflict,
    CloudSyncConflictChoice? choice,
  ) => CloudSyncConflictView(
    id: conflict.id,
    kind: conflict.kind,
    title: conflict.title,
    baseSummary: conflict.baseSummary,
    localSummary: conflict.localSummary,
    remoteSummary: conflict.remoteSummary,
    choice: choice,
  );
}
