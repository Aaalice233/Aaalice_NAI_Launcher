import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/services/vibe_file_storage_service.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_protocol.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';

class _FailingRepository extends Mock
    implements VibeLibraryRepositoryProtocol {}

void main() {
  test('entry list readers recover from repository failures', () async {
    final repository = _FailingRepository();
    when(repository.readAllEntries).thenThrow(StateError('hive read failed'));
    when(
      repository.isDisplayCacheReady,
    ).thenThrow(StateError('display cache failed'));
    final storage = VibeLibraryStorageService(
      repository: repository,
      fileStorage: VibeFileStorageService(),
    );

    expect(await storage.getAllEntries(), isEmpty);
    expect(await storage.getDisplayEntries(), isEmpty);
    expect(await storage.searchEntries('query'), isEmpty);
    expect(await storage.getFavoriteEntries(), isEmpty);
    expect(await storage.getRecentEntries(), isEmpty);
    expect(await storage.getRecentDisplayEntries(), isEmpty);
  });

  test('display thumbnail does not depend on the settings box', () async {
    final repository = _FailingRepository();
    final thumbnail = Uint8List.fromList([1, 2, 3]);
    when(
      () => repository.readThumbnail('entry'),
    ).thenAnswer((_) async => thumbnail);
    final storage = VibeLibraryStorageService(
      repository: repository,
      fileStorage: VibeFileStorageService(),
    );

    expect(await storage.getDisplayThumbnail('entry'), thumbnail);
  });
}
