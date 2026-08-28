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
    final message = '$error';
    writeState(
      state.copyWith(
        activityStatus: resetActivity ? CloudSyncActivityStatus.idle : null,
        clearProgress: resetActivity,
        error: message,
        logs: [
          ...state.logs,
          CloudSyncLogEntry(time: DateTime.now(), message: message),
        ],
      ),
    );
  }
}
