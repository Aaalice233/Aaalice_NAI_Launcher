import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/services/vibe_library_hive_repository.dart';
import 'package:nai_launcher/data/services/vibe_library_migration_service.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Repository extends Mock implements VibeLibraryRepositoryProtocol {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String hivePath;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('vibe_migration_test_');
    PathProviderPlatform.instance = _PathProvider(root.path);
    hivePath = p.join(root.path, 'support', 'hive');
  });

  tearDownAll(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  setUp(() async {
    Hive.init(hivePath);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    final directory = Directory(hivePath);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('rewriting the source table marks the display rows stale', () async {
    final box = await Hive.openLazyBox<VibeLibraryEntry>(
      HiveVibeLibraryRepository.entriesBoxName,
    );
    await box.close();
    final repository = _Repository();
    when(() => repository.setDisplayCacheReady(false)).thenAnswer((_) async {});

    final result = await VibeLibraryMigrationService(
      repository: repository,
    ).migrateIfNeeded();

    expect(result.success, isTrue);
    verify(() => repository.setDisplayCacheReady(false)).called(1);
    expect(
      Hive.box(StorageKeys.settingsBox).get('vibe_library_schema_version'),
      23,
    );
  });

  test('an up-to-date schema leaves the display rows alone', () async {
    await Hive.box(
      StorageKeys.settingsBox,
    ).put('vibe_library_schema_version', 23);
    final repository = _Repository();

    final result = await VibeLibraryMigrationService(
      repository: repository,
    ).migrateIfNeeded();

    expect(result.success, isTrue);
    verifyZeroInteractions(repository);
  });
}

class _PathProvider extends PathProviderPlatform {
  _PathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => p.join(root, 'support');

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(root, 'documents');
}
