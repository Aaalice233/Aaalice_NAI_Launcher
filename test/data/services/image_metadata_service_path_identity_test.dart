import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';

import '../../helpers/fixed_tag_usage_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'metadata-path-identity-',
    );
    Hive.init(directory.path);
    await ImageMetadataService().initialize();
  });

  tearDown(() async {
    await ImageMetadataService().clearCache();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'overwriting a file in place drops the metadata of the old pixels',
    () async {
      final original = await novelAiPngBytes('prompt-A');
      final replacement = await novelAiPngBytes('prompt-B');
      expect(replacement.length, original.length);
      final file = File('${directory.path}/same-path.png');
      await file.writeAsBytes(original, flush: true);
      await file.setLastModified(DateTime(2026, 9, 1));

      final service = ImageMetadataService();
      expect((await service.getMetadata(file.path))?.prompt, 'prompt-A');
      expect(service.getCached(file.path)?.prompt, 'prompt-A');

      await file.writeAsBytes(replacement, flush: true);
      await file.setLastModified(DateTime(2026, 9, 2));

      expect(service.getCached(file.path), isNull);
      expect((await service.getMetadata(file.path))?.prompt, 'prompt-B');
      expect(service.getCached(file.path)?.prompt, 'prompt-B');
    },
  );

  test('a deleted file no longer answers from the sync cache', () async {
    final file = File('${directory.path}/deleted.png');
    await file.writeAsBytes(await novelAiPngBytes('gone'), flush: true);
    final service = ImageMetadataService();
    expect((await service.getMetadata(file.path))?.prompt, 'gone');

    await file.delete();

    expect(service.getCached(file.path), isNull);
  });
}
