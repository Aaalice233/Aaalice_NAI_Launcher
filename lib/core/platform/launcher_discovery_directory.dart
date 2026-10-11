import 'dart:io';

import 'package:path/path.dart' as p;

/// Per-user directory where launcher-side local servers publish discovery
/// files for external processes.
Directory resolveLauncherDiscoveryDirectory({
  Map<String, String>? environment,
}) {
  final env = environment ?? Platform.environment;
  final appData = env['APPDATA'];
  if (appData != null && appData.isNotEmpty) {
    return Directory(p.join(appData, 'nai-launcher'));
  }
  final home = env['HOME'] ?? env['USERPROFILE'] ?? Directory.current.path;
  return Directory(p.join(home, '.nai-launcher'));
}
