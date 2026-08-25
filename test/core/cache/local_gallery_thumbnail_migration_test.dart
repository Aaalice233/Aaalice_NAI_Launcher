import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/local_gallery_thumbnail_migration.dart';

void main() {
  group('LocalGalleryThumbnailMigration', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'nai_legacy_thumbnail_migration_',
      );
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('只删除可验证的旧缩略图并保留原图与未知文件', () async {
      final source = File('${root.path}${Platform.pathSeparator}source.png');
      final sourceBytes = img.encodePng(img.Image(width: 640, height: 480));
      await source.writeAsBytes(sourceBytes, flush: true);

      final thumbs = Directory('${root.path}${Platform.pathSeparator}.thumbs');
      await thumbs.create();
      final legacy = File(
        '${thumbs.path}${Platform.pathSeparator}'
        'source.small.thumb.jpg',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await legacy.writeAsBytes(
        img.encodeJpg(img.Image(width: 180, height: 135)),
        flush: true,
      );
      final userFile = File(
        '${thumbs.path}${Platform.pathSeparator}keep-me.jpg',
      );
      await userFile.writeAsBytes([1, 2, 3], flush: true);
      final tagCatalog = File(
        '${root.path}${Platform.pathSeparator}tag_catalog.db',
      );
      final ffdkj = File('${root.path}${Platform.pathSeparator}tag.sqlite');
      await tagCatalog.writeAsBytes([4, 5, 6]);
      await ffdkj.writeAsBytes([7, 8, 9]);

      final result = await const LocalGalleryThumbnailMigration().cleanup(
        root.path,
      );

      expect(result.removedFiles, 1);
      expect(result.removedBytes, greaterThan(0));
      expect(result.preservedFiles, 1);
      expect(result.failures, 0);
      expect(await legacy.exists(), isFalse);
      expect(await source.readAsBytes(), sourceBytes);
      expect(await userFile.readAsBytes(), [1, 2, 3]);
      expect(await tagCatalog.readAsBytes(), [4, 5, 6]);
      expect(await ffdkj.readAsBytes(), [7, 8, 9]);
      expect(await thumbs.exists(), isTrue);
    });

    test('不删除缺少对应原图的同名文件', () async {
      final thumbs = Directory('${root.path}${Platform.pathSeparator}.thumbs');
      await thumbs.create();
      final unknown = File(
        '${thumbs.path}${Platform.pathSeparator}'
        'missing.small.thumb.jpg',
      );
      await unknown.writeAsBytes(
        img.encodeJpg(img.Image(width: 180, height: 135)),
      );

      final result = await const LocalGalleryThumbnailMigration().cleanup(
        root.path,
      );

      expect(result.removedFiles, 0);
      expect(result.preservedFiles, 1);
      expect(await unknown.exists(), isTrue);
    });

    test('删除最后一个已验证产物后只移除空的 .thumbs 目录', () async {
      final source = File('${root.path}${Platform.pathSeparator}source.png');
      await source.writeAsBytes(
        img.encodePng(img.Image(width: 640, height: 480)),
      );
      final thumbs = Directory('${root.path}${Platform.pathSeparator}.thumbs');
      await thumbs.create();
      final legacy = File(
        '${thumbs.path}${Platform.pathSeparator}'
        'source.micro.thumb.jpg',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await legacy.writeAsBytes(
        img.encodeJpg(img.Image(width: 80, height: 60)),
      );

      final result = await const LocalGalleryThumbnailMigration().cleanup(
        root.path,
      );

      expect(result.removedFiles, 1);
      expect(await thumbs.exists(), isFalse);
      expect(await source.exists(), isTrue);
    });

    test('从最深层开始清理旧版本生成的嵌套 .thumbs', () async {
      final source = File('${root.path}${Platform.pathSeparator}source.png');
      await source.writeAsBytes(
        img.encodePng(img.Image(width: 640, height: 480)),
      );
      final thumbs = Directory('${root.path}${Platform.pathSeparator}.thumbs');
      final nested = Directory(
        '${thumbs.path}${Platform.pathSeparator}.thumbs',
      );
      await nested.create(recursive: true);
      final legacy = File(
        '${thumbs.path}${Platform.pathSeparator}source.small.thumb.jpg',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await legacy.writeAsBytes(
        img.encodeJpg(img.Image(width: 180, height: 135)),
      );
      final nestedLegacy = File(
        '${nested.path}${Platform.pathSeparator}'
        'source.small.thumb.micro.thumb.jpg',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await nestedLegacy.writeAsBytes(
        img.encodeJpg(img.Image(width: 80, height: 60)),
      );

      final result = await const LocalGalleryThumbnailMigration().cleanup(
        root.path,
      );

      expect(result.removedFiles, 2);
      expect(result.failures, 0);
      expect(await thumbs.exists(), isFalse);
      expect(await source.exists(), isTrue);
    });

    test('不把无扩展名用户文件误认为旧缩略图来源', () async {
      final extensionless = File('${root.path}${Platform.pathSeparator}source');
      await extensionless.writeAsBytes([1, 2, 3]);
      final thumbs = Directory('${root.path}${Platform.pathSeparator}.thumbs');
      await thumbs.create();
      final userJpeg = File(
        '${thumbs.path}${Platform.pathSeparator}source.small.thumb.jpg',
      );
      await userJpeg.writeAsBytes(
        img.encodeJpg(img.Image(width: 180, height: 135)),
      );

      final result = await const LocalGalleryThumbnailMigration().cleanup(
        root.path,
      );

      expect(result.removedFiles, 0);
      expect(result.preservedFiles, 1);
      expect(await extensionless.exists(), isTrue);
      expect(await userJpeg.exists(), isTrue);
    });

    test('损坏的匹配文件会显式保留而不阻塞其他文件', () async {
      final source = File('${root.path}${Platform.pathSeparator}source.png');
      await source.writeAsBytes(
        img.encodePng(img.Image(width: 640, height: 480)),
      );
      final thumbs = Directory('${root.path}${Platform.pathSeparator}.thumbs');
      await thumbs.create();
      final broken = File(
        '${thumbs.path}${Platform.pathSeparator}'
        'source.small.thumb.jpg',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await broken.writeAsBytes([0, 1, 2, 3]);

      final result = await const LocalGalleryThumbnailMigration().cleanup(
        root.path,
      );

      expect(result.removedFiles, 0);
      expect(result.preservedFiles, 1);
      expect(result.failures, 0);
      expect(await broken.exists(), isTrue);
    });

    test('成功迁移后写入 marker，后续启动不会重复执行', () async {
      final support = Directory(
        '${root.path}${Platform.pathSeparator}application-support',
      );
      final migration = LocalGalleryThumbnailMigration(
        supportDirectoryProvider: () async => support,
      );

      final first = await migration.runOnce(root.path);
      final second = await migration.runOnce(root.path);

      expect(first.alreadyCompleted, isFalse);
      expect(first.failures, 0);
      expect(second.alreadyCompleted, isTrue);
    });

    test('图库根目录暂时不可用时不写完成 marker', () async {
      final unavailable = Directory(
        '${root.path}${Platform.pathSeparator}offline-gallery',
      );
      final support = Directory(
        '${root.path}${Platform.pathSeparator}application-support',
      );
      final migration = LocalGalleryThumbnailMigration(
        supportDirectoryProvider: () async => support,
      );

      final first = await migration.runOnce(unavailable.path);
      await unavailable.create();
      final second = await migration.runOnce(unavailable.path);

      expect(first.failures, 1);
      expect(first.alreadyCompleted, isFalse);
      expect(second.failures, 0);
      expect(second.alreadyCompleted, isFalse);
    });
  });
}
