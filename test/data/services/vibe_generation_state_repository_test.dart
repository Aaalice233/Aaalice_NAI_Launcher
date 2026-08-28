import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/vibe_generation_state_repository.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'generation state round-trips through the document repository',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'vibe_state_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/generation_state.json');
      final repository = VibeGenerationStateRepository(
        fileResolver: ({required createDirectory}) async {
          if (createDirectory) await file.parent.create(recursive: true);
          return file;
        },
      );

      await repository.saveJson('{"unknown":{"kept":true}}');

      expect(await repository.loadJson(), '{"unknown":{"kept":true}}');
      await repository.clear();
      expect(await repository.loadJson(), isNull);
    },
  );

  test('malformed generation state recovers as null', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = VibeGenerationStateRepository(
      fileResolver: ({required createDirectory}) async => null,
    );
    await repository.saveJson('{broken json');
    final storage = VibeLibraryStorageService(
      generationStateRepository: repository,
    );
    addTearDown(storage.close);

    expect(await storage.loadGenerationState(), isNull);
  });

  test(
    'generation state falls back to legacy preference on file failure',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = VibeGenerationStateRepository(
        fileResolver: ({required createDirectory}) async =>
            throw const FileSystemException('unavailable'),
      );

      await repository.saveJson('{"vibeReferences":[]}');

      expect(await repository.loadJson(), '{"vibeReferences":[]}');
    },
  );
}
