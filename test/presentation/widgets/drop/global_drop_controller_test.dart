import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:nai_launcher/presentation/widgets/drop/global_drop_controller.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class _Event extends Mock implements PerformDropEvent {}

void main() {
  test(
    'native drop waits for acquisition but returns before destination dialog',
    () async {
      final acquired = Completer<List<DroppedFileData>>();
      final processing = Completer<void>();
      var processingStarted = false;
      var nativeCompleted = false;
      final controller = GlobalDropController(
        readDrop: (_) => acquired.future,
        processFile: (_) {
          processingStarted = true;
          return processing.future;
        },
      );
      addTearDown(controller.dispose);
      final native = controller
          .onPerformDrop(_Event())
          .then((_) => nativeCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(nativeCompleted, isFalse);
      acquired.complete([
        DroppedFileData(fileName: 'image.png', bytes: Uint8List(1)),
      ]);
      await native;
      expect(processingStarted, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(processingStarted, isTrue);
      expect(controller.isProcessing, isTrue);
      processing.complete();
      await Future<void>.delayed(Duration.zero);
      expect(controller.isProcessing, isFalse);
    },
  );

  test('reader failure is reported and releases processing state', () async {
    final controller = GlobalDropController(
      readDrop: (_) async => throw StateError('reader disposed'),
      processFile: (_) async {},
    );
    addTearDown(controller.dispose);
    await expectLater(controller.onPerformDrop(_Event()), throwsStateError);
    expect(controller.isProcessing, isFalse);
  });
}
