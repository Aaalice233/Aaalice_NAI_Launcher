import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/image_editor/effects/editor_effects.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/services/effects_service.dart';

import '../../../../helpers/shared_compute_gate.dart';

void main() {
  test('effects match a direct run behind the compute gate', () async {
    final source = img.Image(width: 16, height: 12);
    img.fill(source, color: img.ColorRgb8(200, 120, 40));
    final job = EditorEffectJob(
      imageBytes: Uint8List.fromList(img.encodePng(source)),
      effectType: EditorEffectType.sepia,
      intensity: editorEffectDefaultIntensity(EditorEffectType.sepia),
    );
    final expected = runEditorEffectJob(job);

    final result = await expectQueuedBehindSharedComputeGate(
      () => const EditorEffectsService().apply(job),
    );

    expect((result.width, result.height), (expected.width, expected.height));
    expect(result.bytes, orderedEquals(expected.bytes));
  });
}
