import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/network/request_builders/precise_reference_send_filter.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';

void main() {
  test('models without outfit support discard costume before sending', () {
    final costume = PreciseReference(
      image: Uint8List(1),
      type: PreciseRefType.costume,
    );
    expect(
      resolveSendablePreciseReferences(
        ImageParams(
          model: ImageModels.animeDiffusionV45Full,
          preciseReferences: [costume],
        ),
      ),
      isEmpty,
    );
  });
  final first = PreciseReference(
    image: Uint8List.fromList([1]),
    type: PreciseRefType.character,
  );
  final disabled = PreciseReference(
    image: Uint8List.fromList([2]),
    type: PreciseRefType.style,
    enabled: false,
  );
  final last = PreciseReference(
    image: Uint8List.fromList([3]),
    type: PreciseRefType.characterAndStyle,
    strength: 2.5,
    fidelity: -1.25,
  );

  test('unsupported models send no precise references', () {
    expect(
      resolveSendablePreciseReferences(
        ImageParams(
          model: ImageModels.animeDiffusionV4Full,
          preciseReferences: [first, disabled, last],
        ),
      ),
      isEmpty,
    );
  });

  test('filters only disabled items and preserves order and objects', () {
    final input = [first, disabled, last];
    final sent = resolveSendablePreciseReferences(
      ImageParams(
        model: ImageModels.animeDiffusionV45Full,
        preciseReferences: input,
      ),
    );
    expect(sent, hasLength(2));
    expect(sent[0], same(first));
    expect(sent[1], same(last));
    expect(input, [first, disabled, last]);
  });

  test('all disabled references produce an empty list', () {
    expect(
      resolveSendablePreciseReferences(
        ImageParams(
          model: ImageModels.animeDiffusionV45Full,
          preciseReferences: [disabled],
        ),
      ),
      isEmpty,
    );
  });
}
