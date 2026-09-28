import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_operation_runner.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';

void main() {
  test(
    'pending preview blocks every operation that could replace it',
    () async {
      const pending = CloudSyncPreviewView(changes: []);
      var state = const CloudSyncUiState(pendingPreview: pending);
      final runner = CloudSyncOperationRunner(
        coordinator: () => null,
        readState: () => state,
        writeState: (value) => state = value,
        recordError: (_, {bool resetActivity = false}) {},
        readPendingFfdkjIntent: () => false,
        persistSyncState: (_, __) async {},
      );

      await expectLater(runner.previewInitial(), throwsStateError);
      await expectLater(
        runner.previewRestore('older-snapshot', OperationToken()),
        throwsStateError,
      );
      expect(state.pendingPreview, same(pending));
    },
  );
}
