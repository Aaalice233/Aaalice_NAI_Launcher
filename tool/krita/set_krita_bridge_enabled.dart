import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1 && args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/krita/set_krita_bridge_enabled.dart <hive-directory> [true|false]',
    );
    exitCode = 64;
    return;
  }

  final hiveDir = Directory(args.first);
  final enabled = args.length == 1 ? true : _parseBool(args[1]);
  if (enabled == null) {
    stderr.writeln('Expected true or false, got: ${args[1]}');
    exitCode = 64;
    return;
  }
  if (!hiveDir.existsSync()) {
    stderr.writeln('Hive directory does not exist: ${hiveDir.path}');
    exitCode = 66;
    return;
  }

  Hive.init(hiveDir.path);
  final box = await Hive.openBox<dynamic>(StorageKeys.settingsBox);
  try {
    final before = box.get(
      StorageKeys.kritaBridgeEnabled,
      defaultValue: false,
    );
    await box.put(StorageKeys.kritaBridgeEnabled, enabled);
    await box.flush();
    final after = box.get(StorageKeys.kritaBridgeEnabled);

    stdout.writeln('hive_dir=${hiveDir.path}');
    stdout.writeln('key=${StorageKeys.kritaBridgeEnabled}');
    stdout.writeln('before=$before');
    stdout.writeln('after=$after');
  } finally {
    await box.close();
  }
}

bool? _parseBool(String value) {
  final normalized = value.toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return null;
}
