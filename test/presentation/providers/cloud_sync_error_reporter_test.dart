import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_error_reporter.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';

import '../../helpers/log_capture.dart';

void main() {
  test(
    'redacts the full query and repeated key before bounding the log',
    () async {
      var state = const CloudSyncUiState();
      final reporter = CloudSyncErrorReporter(
        readState: () => state,
        writeState: (next) => state = next,
      );
      const endpoint = 'https://cloud.example.test/items';
      const apiKey = 'sync-fixture-key';
      final error = StateError(
        '$endpoint?api_key=$apiKey&login=bob&tags=${'x' * 600} '
        'retry saw $apiKey',
      );

      final logs = await captureLogs(() => reporter.record(error));

      expect(logs.single, contains('$endpoint retry saw [REDACTED]'));
      expect(logs.single, isNot(contains(apiKey)));
      expect(logs.single, isNot(contains('&login=')));
      expect(logs.single, isNot(contains('&tags=')));
    },
  );
}
