import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/document_transaction.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';

void main() {
  test(
    'DocumentTransaction restores an immutable byte and value snapshot',
    () async {
      final source = Uint8List.fromList([1, 2, 3]);
      DocumentSnapshot? restored;
      final transaction = DocumentTransaction(
        snapshot: DocumentSnapshot(
          bytes: {'source': source},
          values: const {'width': 3, 'focused': true},
        ),
        restore: (snapshot) async => restored = snapshot,
      );

      source[0] = 9;
      await expectLater(
        transaction.run<void>(() async => throw StateError('failed mutation')),
        throwsStateError,
      );

      expect(restored!.bytes['source'], [1, 2, 3]);
      expect(restored!.values, {'width': 3, 'focused': true});
    },
  );

  test('ImageEditorController rejects superseded and disposed operations', () {
    final controller = ImageEditorController();
    final first = controller.beginOperation();
    expect(controller.accepts(first), isTrue);

    final second = controller.beginOperation();
    expect(controller.accepts(first), isFalse);
    expect(controller.accepts(second), isTrue);

    controller.dispose();
    expect(controller.accepts(second), isFalse);
  });
}
