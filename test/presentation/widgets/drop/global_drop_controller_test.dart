import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:nai_launcher/presentation/widgets/drop/global_drop_controller.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class _Event extends Mock implements PerformDropEvent {}

void main() {
  test('native drop issues the read and returns before acquisition', () async {
    final acquired = Completer<List<DroppedFileData>>();
    final processing = Completer<void>();
    var readIssued = false;
    var processingStarted = false;
    final controller = GlobalDropController(
      readDrop: (_) {
        readIssued = true;
        return acquired.future;
      },
      processFile: (_) {
        processingStarted = true;
        return processing.future;
      },
    );
    addTearDown(controller.dispose);

    final native = controller.onPerformDrop(_Event());
    expect(readIssued, isTrue);
    await native;
    expect(controller.isProcessing, isTrue);
    expect(processingStarted, isFalse);

    acquired.complete([
      DroppedFileData(fileName: 'image.png', bytes: Uint8List(1)),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(processingStarted, isTrue);
    expect(controller.isProcessing, isTrue);
    processing.complete();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isProcessing, isFalse);
  });

  test('reader failure is reported and releases processing state', () async {
    final reported = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previousOnError);
    final controller = GlobalDropController(
      readDrop: (_) async => throw StateError('reader disposed'),
      processFile: (_) async {},
    );
    addTearDown(controller.dispose);

    await controller.onPerformDrop(_Event());
    await Future<void>.delayed(Duration.zero);

    expect(controller.isProcessing, isFalse);
    expect(reported.single.exception, isA<StateError>());
    expect(reported.single.library, 'GlobalDropController');
  });
}
