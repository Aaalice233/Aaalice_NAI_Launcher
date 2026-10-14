import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/drag_export_file_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late DragExportFileStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('drag_export_store_test_');
    store = DragExportFileStore(root: () async => root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('receivers see the plain file name with the exported bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final file = await store.write('history_42.png', bytes);

    expect(p.basename(file.path), 'history_42.png');
    expect(await file.readAsBytes(), bytes);
    expect(p.isWithin(root.path, file.path), isTrue);
  });

  test('items sharing a name never overwrite each other', () async {
    final first = await store.write('a.png', Uint8List.fromList([1]));
    final second = await store.write('a.png', Uint8List.fromList([2]));

    expect(first.path, isNot(second.path));
    expect(await first.readAsBytes(), [1]);
    expect(await second.readAsBytes(), [2]);
  });

  test('files survive until the run is cleared', () async {
    final file = await store.write('a.png', Uint8List.fromList([1]));
    expect(await file.exists(), isTrue);

    await store.clear();

    expect(await file.exists(), isFalse);
    expect(await root.exists(), isTrue);
    final next = await store.write('b.png', Uint8List.fromList([2]));
    expect(await next.exists(), isTrue);
  });

  test('clearing before any export is a no-op', () async {
    await store.clear();
    expect(await root.list().isEmpty, isTrue);
  });

  test('unsafe names are cleaned before reaching the disk', () async {
    final file = await store.write('dir/a:b?.png', Uint8List.fromList([1]));
    expect(p.basename(file.path), 'a_b_.png');
  });
}
