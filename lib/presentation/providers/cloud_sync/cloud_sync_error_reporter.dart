import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/cloud_sync/models.dart';
import '../../../core/cloud_sync/sync_types.dart';
import 'cloud_sync_operation_runner.dart';
import 'cloud_sync_ui_provider.dart';

class CloudSyncErrorReporter {
  const CloudSyncErrorReporter({
    required this.readState,
    required this.writeState,
  });

  final CloudSyncStateReader readState;
  final CloudSyncStateWriter writeState;

  void record(Object error, {bool resetActivity = false}) {
    final state = readState();
    final message = cloudSyncErrorMessage(error);
    if (!resetActivity && state.error == message) return;
    writeState(
      state.copyWith(
        activityStatus: resetActivity ? CloudSyncActivityStatus.idle : null,
        clearProgress: resetActivity,
        error: message,
        logs: [
          ...state.logs.length > 99
              ? state.logs.sublist(state.logs.length - 99)
              : state.logs,
          CloudSyncLogEntry(time: DateTime.now(), message: message),
        ],
      ),
    );
  }
}

String cloudSyncErrorMessage(Object error) => switch (error) {
  CloudBackendException(kind: final kind) => 'backend.${kind.name}',
  CloudPreviewStaleException() => 'previewStale',
  CloudFormatException() => 'format',
  FormatException() => 'configuration',
  StateError() => 'state',
  _ => 'unknown',
};
