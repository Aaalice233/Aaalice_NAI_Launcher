import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/tag_library_portable_thumbnail_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late PathProviderPlatform previousPlatform;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tag-thumbnail-sync-');
    previousPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _PathProvider(root.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPlatform;
    await root.delete(recursive: true);
  });

  test(
    'extension replacement removes the old extension after commit',
    () async {
      final directory = Directory(p.join(root.path, 'tag_library_thumbnails'))
        ..createSync(recursive: true);
      final old = File(p.join(directory.path, 'entry.png'))
        ..writeAsBytesSync([1]);
      const store = TagLibraryPortableThumbnailStore();

      final mutation = await store.stage(
        'entry',
        extension: '.webp',
        bytes: Stream.value([2]),
        existingPath: old.path,
      );
      await mutation.commit();

      expect(old.existsSync(), isFalse);
      expect(File(p.join(directory.path, 'entry.webp')).readAsBytesSync(), [2]);
    },
  );

  test('tombstone deletes thumbnail and rollback restores it', () async {
    final directory = Directory(p.join(root.path, 'tag_library_thumbnails'))
      ..createSync(recursive: true);
    final old = File(p.join(directory.path, 'entry.jpg'))
      ..writeAsBytesSync([3]);
    const store = TagLibraryPortableThumbnailStore();

    final mutation = await store.stage(
      'entry',
      extension: null,
      bytes: null,
      existingPath: old.path,
    );
    expect(old.existsSync(), isFalse);
    await mutation.rollback();

    expect(old.readAsBytesSync(), [3]);

    final committedTombstone = await store.stage(
      'entry',
      extension: null,
      bytes: null,
      existingPath: old.path,
    );
    await committedTombstone.commit();
    expect(old.existsSync(), isFalse);
  });
}

class _PathProvider extends PathProviderPlatform {
  _PathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
