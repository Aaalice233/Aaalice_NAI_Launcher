import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/utils/internal_drag_protocol.dart';

void main() {
  test('history producer localData contains only source and imageId', () {
    final data = buildHistoryInternalDragLocalData('image-1');

    expect(data.keys.toSet(), {'source', 'imageId'});
    expect(data, {'source': 'history_internal', 'imageId': 'image-1'});
    expect(data, isNot(contains('bytes')));
    expect(data, isNot(contains('path')));
    expect(data, isNot(contains('filePath')));
  });

  test('resolves a matching draggable history image from original bytes', () {
    final image = _image('history');
    final result = resolveInternalHistoryDropPayload(
      buildHistoryInternalDragLocalData(image.id),
      ImageGenerationState(history: [image]),
    );

    expect(result, isNotNull);
    expect(result!.fileName, 'history_history.png');
    expect(result.bytes, same(image.bytes));
    expect(result.sourcePath, isNull);
  });

  test('resolves display-only image retained after history clearing', () {
    final image = _image('display');
    final result = resolveInternalHistoryDropPayload(
      buildHistoryInternalDragLocalData(image.id),
      ImageGenerationState(displayImages: [image]),
    );

    expect(result?.bytes, same(image.bytes));
  });

  test('rejects gallery, missing, unknown, and non-draggable payloads', () {
    final failed = _image(
      'failed',
      kind: GeneratedImageKind.failedStreamSnapshot,
    );
    final state = ImageGenerationState(history: [failed]);

    expect(
      resolveInternalHistoryDropPayload(const {
        'source': 'gallery_internal',
        'imageId': 'failed',
      }, state),
      isNull,
    );
    expect(
      resolveInternalHistoryDropPayload(const {
        'source': 'history_internal',
      }, state),
      isNull,
    );
    expect(
      resolveInternalHistoryDropPayload(const {
        'source': 'history_internal',
        'imageId': 'unknown',
      }, state),
      isNull,
    );
    expect(
      resolveInternalHistoryDropPayload(
        buildHistoryInternalDragLocalData('failed'),
        state,
      ),
      isNull,
    );
  });

  test('accepts additional fields for forward compatibility', () {
    final image = _image('image');
    final result = resolveInternalHistoryDropPayload(const {
      'source': 'history_internal',
      'imageId': 'image',
      'futureField': 1,
    }, ImageGenerationState(currentImages: [image]));

    expect(result, isNotNull);
  });

  test(
    'gallery classification does not misclassify history or external data',
    () {
      expect(
        isGalleryInternalDragLocalData(const {
          'source': 'gallery_internal',
          'path': 'x',
        }),
        isTrue,
      );
      expect(
        isGalleryInternalDragLocalData(const {
          'source': 'history_internal',
          'imageId': 'x',
        }),
        isFalse,
      );
      expect(isGalleryInternalDragLocalData(null), isFalse);
    },
  );
}

GeneratedImage _image(
  String id, {
  GeneratedImageKind kind = GeneratedImageKind.completed,
}) {
  return GeneratedImage(
    id: id,
    bytes: Uint8List.fromList([1, 2, 3]),
    width: 1,
    height: 1,
    kind: kind,
  );
}
