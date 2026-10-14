import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/utils/drag_export_file_store.dart';
import 'package:nai_launcher/presentation/widgets/common/card_drag_item.dart';
import 'package:nai_launcher/presentation/widgets/common/card_drag_resource.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:super_native_extensions/raw_clipboard.dart' as raw;

void main() {
  late Directory root;
  late DragExportFileStore store;
  late int preparations;
  final contents = Uint8List.fromList([1, 2, 3]);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('card_drag_item_test_');
    store = DragExportFileStore(root: () async => root);
    preparations = 0;
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  CardDragResource resource() => CardDragResource(
    id: 'a',
    fileName: 'a.png',
    format: Formats.png,
    prepare: () async => contents,
  );

  Future<List<raw.DataRepresentation>> build(
    CardDragResource resource,
    DragFileExportMode mode, {
    File? readyFile,
  }) async {
    final item = await buildCardDragItem(
      resource,
      readyFile: readyFile,
      bytes: cardDragNeedsExport(resource, readyFile)
          ? () async {
              preparations++;
              return contents;
            }
          : null,
      reportFailure: (error, stack) => fail('unexpected failure: $error'),
      exportMode: mode,
      store: store,
    );
    return [for (final data in item.data) ...(await data).representations];
  }

  test('only cards without a ready file need an export', () async {
    final source = File(p.join(root.path, 'source.png'));
    expect(cardDragNeedsExport(resource(), null), isTrue);
    expect(cardDragNeedsExport(resource(), source), isFalse);
    expect(
      cardDragNeedsExport(
        const CardDragResource(id: 'a', fileName: 'a.png'),
        null,
      ),
      isFalse,
    );
  });

  Iterable<String> fileUriFormats() => Formats.fileUri.codec.encodingFormats;

  test('an existing file is offered by path in every mode', () async {
    final source = await File(
      p.join(root.path, 'source.png'),
    ).writeAsBytes([9]);
    for (final mode in DragFileExportMode.values) {
      final representations = await build(resource(), mode, readyFile: source);
      final file = representations
          .whereType<raw.DataRepresentationSimple>()
          .where((r) => fileUriFormats().contains(r.format))
          .single;
      expect(
        file.data,
        Formats.fileUri.codec.encode(source.uri, file.format),
        reason: '$mode',
      );
      expect(
        representations.whereType<raw.DataRepresentationVirtualFile>(),
        isEmpty,
        reason: '$mode',
      );
    }
    expect(preparations, 0);
  });

  test('Windows exports a real file only when a receiver asks', () async {
    final representations = await build(
      resource(),
      DragFileExportMode.onDemandFile,
    );
    expect(
      representations.whereType<raw.DataRepresentationVirtualFile>(),
      isEmpty,
    );
    final lazy = representations.whereType<raw.DataRepresentationLazy>().single;
    expect(fileUriFormats(), contains(lazy.format));
    expect(preparations, 0);

    final encoded = await lazy.dataProvider();

    expect(preparations, 1);
    final exported = (await root.list(recursive: true).toList())
        .whereType<File>()
        .single;
    expect(p.basename(exported.path), 'a.png');
    expect(await exported.readAsBytes(), contents);
    expect(encoded, Formats.fileUri.codec.encode(exported.uri, lazy.format));
  });

  test('prepared mode writes the file before the drag starts', () async {
    final representations = await build(
      resource(),
      DragFileExportMode.preparedFile,
    );
    expect(preparations, 1);
    final exported = (await root.list(recursive: true).toList())
        .whereType<File>()
        .single;
    expect(await exported.readAsBytes(), contents);
    expect(
      representations.whereType<raw.DataRepresentationSimple>().map(
        (r) => r.format,
      ),
      containsAll([Formats.png.providerFormat, ...fileUriFormats()]),
    );
  });

  test('virtual mode keeps the file promise where it is supported', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final representations = await build(
      resource(),
      DragFileExportMode.virtualFile,
    );
    expect(
      representations.whereType<raw.DataRepresentationVirtualFile>(),
      hasLength(1),
    );
    expect(preparations, 0);
    expect(await root.list().isEmpty, isTrue);
  });

  test('virtual mode falls back to a prepared file elsewhere', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final representations = await build(
      resource(),
      DragFileExportMode.virtualFile,
    );
    expect(
      representations.whereType<raw.DataRepresentationVirtualFile>(),
      isEmpty,
    );
    expect(preparations, 1);
  });

  test('resources without exportable contents only carry payloads', () async {
    final representations = await build(
      const CardDragResource(id: 'a', fileName: 'a.png'),
      DragFileExportMode.onDemandFile,
    );
    expect(representations.whereType<raw.DataRepresentationLazy>(), isEmpty);
    expect(await root.list().isEmpty, isTrue);
  });
}
