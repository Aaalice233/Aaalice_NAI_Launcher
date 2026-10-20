import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/repositories/character_prompt_repository.dart';

import '../../helpers/log_capture.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'character_prompt_repository_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('corrupt config falls back without logging the prompts', () async {
    await Hive.box(StorageKeys.settingsBox).put(
      'character_prompt_config',
      '{"characters":[{"prompt":"secret lighthouse keeper",',
    );

    final logs = await captureLogs(() {
      expect(CharacterPromptRepository().load().characters, isEmpty);
    });

    expect(
      logs.where((line) => line.contains('character prompt config')),
      hasLength(1),
    );
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
