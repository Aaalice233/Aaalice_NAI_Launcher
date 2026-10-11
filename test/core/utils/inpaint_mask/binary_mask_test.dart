import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';

void main() {
  final mask = BinaryMask(
    pixels: Uint8List.fromList([1, 0, 0, 1, 1, 1]),
    width: 3,
    height: 2,
  );

  test('placedIn copies rows to the offset and leaves the rest empty', () {
    final placed = mask.placedIn(
      canvasWidth: 5,
      canvasHeight: 4,
      left: 1,
      top: 2,
    );

    expect(placed.width, 5);
    expect(placed.height, 4);
    expect(
      placed.pixels,
      Uint8List.fromList([
        0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 1, 1, 1, 0, //
      ]),
    );
  });

  test('placedIn clips parts that fall outside the canvas', () {
    final topLeft = mask.placedIn(
      canvasWidth: 3,
      canvasHeight: 2,
      left: -1,
      top: -1,
    );
    expect(
      topLeft.pixels,
      Uint8List.fromList([
        1, 1, 0, //
        0, 0, 0, //
      ]),
    );

    final bottomRight = mask.placedIn(
      canvasWidth: 3,
      canvasHeight: 2,
      left: 1,
      top: 1,
    );
    expect(
      bottomRight.pixels,
      Uint8List.fromList([
        0, 0, 0, //
        0, 1, 0, //
      ]),
    );
  });

  test('placedIn is empty when the mask misses the canvas entirely', () {
    final placed = mask.placedIn(
      canvasWidth: 4,
      canvasHeight: 4,
      left: 4,
      top: 0,
    );

    expect(placed.pixels.every((value) => value == 0), isTrue);
  });
}
