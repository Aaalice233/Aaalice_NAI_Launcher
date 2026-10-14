import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/core/utils/share_temp_directories.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('share_temp_sweep_test_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> file(String folder, String name, DateTime modified) async {
    final target = File(p.join(root.path, folder, name));
    await target.create(recursive: true);
    await target.setLastModified(modified);
    return target;
  }

  test('only entries from earlier runs are removed', () async {
    // Directory times cannot be set directly; real gaps keep them ordered
    // even with the coarse file system clock tick.
    final staleRun = Directory(
      p.join(root.path, ShareTempDirectories.dragExport, 'run_old'),
    );
    await File(p.join(staleRun.path, 'item', 'a.png')).create(recursive: true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final launchedAt = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final currentRun = Directory(
      p.join(root.path, ShareTempDirectories.dragExport, 'run_new'),
    );
    await currentRun.create(recursive: true);

    final before = launchedAt.subtract(const Duration(hours: 1));
    final after = launchedAt.add(const Duration(hours: 1));
    final staleShare = await file(
      ShareTempDirectories.share,
      'old.png',
      before,
    );
    final freshShare = await file(ShareTempDirectories.share, 'new.png', after);
    final staleCache = await file(
      ShareTempDirectories.shareCache,
      'id_raw_original.png',
      before,
    );
    final freshCache = await file(
      ShareTempDirectories.shareCache,
      'id_strip_original.png',
      after,
    );
    final unrelated = await file('somebody_else', 'old.png', before);

    final removed = await ShareTempDirectories.sweepPreviousRuns(
      launchedAt,
      root: root,
    );

    expect(removed, 3);
    expect(await staleRun.exists(), isFalse);
    expect(await currentRun.exists(), isTrue);
    expect(await staleShare.exists(), isFalse);
    expect(await freshShare.exists(), isTrue);
    expect(await staleCache.exists(), isFalse);
    expect(await freshCache.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
  });

  test('missing folders are skipped', () async {
    expect(
      await ShareTempDirectories.sweepPreviousRuns(DateTime.now(), root: root),
      0,
    );
  });

  group('files the launcher exports itself', () {
    late PathProviderPlatform original;

    setUp(() {
      original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryPathProvider(root.path);
    });
    tearDown(() => PathProviderPlatform.instance = original);

    test('are transient and never count as an image source', () async {
      final exports = await ShareTempDirectories.resolve(
        ShareTempDirectories.dragExport,
      );

      expect(
        ShareTempDirectories.isTransient(p.join(exports.path, 'run', 'a.png')),
        isTrue,
      );
      expect(
        ShareTempDirectories.isTransient(p.join(root.path, 'gallery', 'a.png')),
        isFalse,
      );
    });

    test('cached share files keep the image name for receivers', () async {
      final file = await ImageShareSanitizer.writeCachedShareFile(
        'id 1_strip_original',
        SanitizedShareImage(
          bytes: Uint8List.fromList([1, 2]),
          fileName: 'a?b.PNG',
          mimeType: 'image/png',
        ),
      );

      expect(
        file.path,
        p.join(
          root.path,
          ShareTempDirectories.shareCache,
          'id_1_strip_original',
          'a_b.png',
        ),
      );
      expect(await file.readAsBytes(), [1, 2]);
      expect(ShareTempDirectories.isTransient(file.path), isTrue);
    });
  });
}

class _TemporaryPathProvider extends PathProviderPlatform {
  _TemporaryPathProvider(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}
