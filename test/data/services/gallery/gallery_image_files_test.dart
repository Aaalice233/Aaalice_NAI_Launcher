import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:nai_launcher/data/services/gallery/gallery_image_files.dart';
import 'package:path/path.dart' as p;

void main() {
  final root = Directory(p.absolute('cache', 'temp', 'gallery'));
  final bad = Directory(p.join(root.path, 'unreadable'));
  final sibling = Directory(p.join(root.path, 'visible'));
  final nested = Directory(p.join(sibling.path, 'deep'));

  test('枚举告警只记录跳过总数和错误码分组', () async {
    final temp = await Directory.systemTemp.createTemp('gallery_log_');
    addTearDown(() => temp.delete(recursive: true));
    final blocked = [
      for (final name in ['private-one', 'private-two', 'private-three'])
        Directory(p.join(temp.path, name)),
    ];
    final images = GalleryImageFiles(
      listDirectory: (dir) {
        if (dir.path == temp.path) return Stream.fromIterable(blocked);
        return Stream.error(
          FileSystemException(
            'private failure message',
            dir.path,
            dir == blocked.last ? null : const OSError('private OS message', 5),
          ),
        );
      },
    );
    final warnings = <String>[];
    void capture(LogEvent event) {
      if (event.level == Level.warning) warnings.add(event.message.toString());
    }

    Logger.addLogListener(capture);
    addTearDown(() => Logger.removeLogListener(capture));

    await images.list(temp).drain<void>();

    final warning = warnings.single;
    expect(warning, contains('跳过 3 个无法读取的图库目录'));
    expect(warning, contains('FileSystemException(errno: 5): 2'));
    expect(warning, contains('FileSystemException: 1'));
    expect(warning, isNot(contains(temp.path)));
    for (final dir in blocked) {
      expect(warning, isNot(contains(p.basename(dir.path))));
    }
    expect(warning, isNot(contains('private failure message')));
    expect(warning, isNot(contains('private OS message')));
  });

  test(
    'a failed child listing leaves siblings and descendants readable',
    () async {
      final visits = <String>[];
      final tree = {
        root.path: [sibling, bad, Link(p.join(root.path, 'link'))],
        sibling.path: [nested, File(p.join(sibling.path, 'a.PNG'))],
        nested.path: [File(p.join(nested.path, 'b.jpg'))],
      };
      final images = GalleryImageFiles(
        listDirectory: (dir) async* {
          visits.add(dir.path);
          if (dir.path == bad.path) {
            throw FileSystemException('denied', dir.path);
          }
          yield* Stream.fromIterable(tree[dir.path]!);
        },
      );

      final files = await images
          .list(root)
          .map((f) => p.basename(f.path))
          .toList();
      expect(files, unorderedEquals(['a.PNG', 'b.jpg']));
      expect(
        visits,
        unorderedEquals([root.path, bad.path, sibling.path, nested.path]),
      );
    },
  );

  test('a failed starting directory propagates the listing error', () async {
    final error = FileSystemException('gone', root.path);
    final images = GalleryImageFiles(listDirectory: (_) => Stream.error(error));
    await expectLater(images.list(root).toList(), throwsA(same(error)));
  });
}
