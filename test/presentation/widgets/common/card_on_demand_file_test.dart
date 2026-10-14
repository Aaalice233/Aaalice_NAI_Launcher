import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/card_on_demand_file.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:super_native_extensions/raw_clipboard.dart' as raw;

void main() {
  final exportedFile = File('exported/a.png');

  Future<raw.DataRepresentationLazy> lazyFileUri(DragItem item) async {
    final representations = [
      for (final data in item.data) ...(await data).representations,
    ];
    return representations.single as raw.DataRepresentationLazy;
  }

  Object? encoded(raw.DataRepresentationLazy representation, File file) =>
      Formats.fileUri.codec.encode(file.uri, representation.format);

  test('the file is exported once, on the first request only', () async {
    final item = DragItem();
    var exports = 0;
    final failures = <Object>[];
    addCardOnDemandFile(
      item,
      export: () async {
        exports++;
        return exportedFile;
      },
      reportFailure: (error, _) => failures.add(error),
    );
    final representation = await lazyFileUri(item);
    expect(exports, 0);

    final first = await representation.dataProvider();
    final second = await representation.dataProvider();

    expect(exports, 1);
    expect(first, encoded(representation, exportedFile));
    expect(second, first);
    expect(failures, isEmpty);
  });

  test('a failed export is reported once and fails every request', () async {
    final item = DragItem();
    var exports = 0;
    final failures = <Object>[];
    const error = FileSystemException('synthetic export failure');
    addCardOnDemandFile(
      item,
      export: () async {
        exports++;
        throw error;
      },
      reportFailure: (error, _) => failures.add(error),
    );
    final representation = await lazyFileUri(item);

    await expectLater(
      Future.sync(representation.dataProvider),
      throwsA(same(error)),
    );
    await expectLater(
      Future.sync(representation.dataProvider),
      throwsA(same(error)),
    );

    expect(exports, 1);
    expect(failures, [same(error)]);
  });

  test('an export that never finishes releases the receiver', () async {
    final item = DragItem();
    final pending = Completer<File>();
    final failures = <Object>[];
    addCardOnDemandFile(
      item,
      export: () => pending.future,
      reportFailure: (error, _) => failures.add(error),
      timeout: const Duration(milliseconds: 20),
    );
    final representation = await lazyFileUri(item);

    await expectLater(
      Future.sync(representation.dataProvider),
      throwsA(isA<TimeoutException>()),
    );
    expect(failures.single, isA<TimeoutException>());
  });
}
