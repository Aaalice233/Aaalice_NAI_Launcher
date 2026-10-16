import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/image_editor/effects/editor_effects.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/services/effects_service.dart';

import '../../../../helpers/shared_compute_gate.dart';

void main() {
  final source = img.Image(width: 16, height: 12);
  img.fill(source, color: img.ColorRgb8(200, 120, 40));
  final job = EditorEffectJob(
    imageBytes: Uint8List.fromList(img.encodePng(source)),
    effectType: EditorEffectType.sepia,
    intensity: editorEffectDefaultIntensity(EditorEffectType.sepia),
  );

  test('effects match a direct run behind the compute gate', () async {
    final expected = runEditorEffectJob(job);

    final result = await expectQueuedBehindSharedComputeGate(
      () => const EditorEffectsService().apply(job),
    );

    expect((result.width, result.height), (expected.width, expected.height));
    expect(result.bytes, orderedEquals(expected.bytes));
  });

  test('queued previews run only the newest; apply always runs', () async {
    const service = EditorEffectsService();
    final expected = runEditorEffectJob(job);
    final started = <int>[];
    var newest = 0;
    Future<EditorEffectResult?> requestPreview() {
      final generation = ++newest;
      return service.preview(
        job,
        isCurrent: () {
          final current = generation == newest;
          if (current) started.add(generation);
          return current;
        },
      );
    }

    final release = holdSharedComputeGate();
    final previews = [requestPreview(), requestPreview(), requestPreview()];
    final applied = service.apply(job);
    await release();

    final results = await Future.wait(previews);
    expect(started, [3]);
    expect(results.take(2), everyElement(isNull));
    expect(results.last!.bytes, orderedEquals(expected.bytes));
    expect((await applied).bytes, orderedEquals(expected.bytes));
  });

  test('a preview that already started still returns its result', () async {
    var current = true;
    final preview = const EditorEffectsService().preview(
      job,
      isCurrent: () => current,
    );
    await Future<void>.delayed(Duration.zero);
    current = false;

    expect(await preview, isNotNull);
  });
}
