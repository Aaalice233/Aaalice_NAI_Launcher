import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/datasources/local/random_tag_library_data_source.dart';
import 'package:nai_launcher/data/services/tag_library_service.dart';

import '../../helpers/log_capture.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('tag_library_');
    Hive.init(hiveDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('corrupt local library loads as absent without logging its tags', () async {
    await (await Hive.openBox('tag_library')).put(
      'library',
      '{"categories":{"custom":[{"tag":"secret lighthouse keeper",',
    );
    final service = TagLibraryService(RandomTagLibraryDataSource());

    final logs = await captureLogs(
      () async => expect(await service.loadLocalLibrary(), isNull),
    );

    expect(logs.where((line) => line.contains('Failed to load')), hasLength(1));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
