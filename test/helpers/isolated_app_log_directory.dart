import 'dart:io';

import 'package:nai_launcher/core/utils/app_logger.dart';

/// Points AppLogger's next log files at a private temp directory instead of
/// the shared system temp root that path_provider falls back to in tests.
Directory createIsolatedAppLogDirectory(String prefix) {
  final directory = Directory.systemTemp.createTempSync(prefix);
  AppLogger.debugSetLogDirectoryForTesting(directory.path);
  return directory;
}

Future<void> deleteIsolatedAppLogDirectory(Directory directory) async {
  // Windows refuses to delete the directory while the log file is still open.
  await AppLogger.setFileLoggingEnabled(false);
  AppLogger.debugSetLogDirectoryForTesting(null);
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}
