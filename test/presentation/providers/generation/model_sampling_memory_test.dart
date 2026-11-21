import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/generation/model_sampling_memory.dart';

void main() {
  const archived = ModelSamplingParams(
    steps: 30,
    scale: 6.5,
    cfgRescale: 0.2,
    sampler: Samplers.kDpmpp2m,
    noiseSchedule: NoiseSchedules.native,
    varietyPlus: true,
  );

  group('ModelSamplingMemory.slotOf', () {
    test('groups inpainting variants and effort levels with their entry', () {
      expect(
        ModelSamplingMemory.slotOf(ImageModels.animeDiffusionV45FullInpainting),
        ImageModels.animeDiffusionV45Full,
      );
      expect(
        ModelSamplingMemory.slotOf(ImageModels.animeDiffusionV5FullMedium),
        ImageModels.animeDiffusionV5Full,
      );
      expect(
        ModelSamplingMemory.slotOf(ImageModels.v5StagingKey),
        ImageModels.animeDiffusionV5Curated,
      );
    });
  });

  group('ModelSamplingParams', () {
    test('round-trips through JSON', () {
      final parsed = ModelSamplingParams.tryParse(archived.toJson())!;
      expect(parsed.steps, archived.steps);
      expect(parsed.scale, archived.scale);
      expect(parsed.cfgRescale, archived.cfgRescale);
      expect(parsed.sampler, archived.sampler);
      expect(parsed.noiseSchedule, archived.noiseSchedule);
      expect(parsed.varietyPlus, archived.varietyPlus);
    });

    test('accepts JSON integers', () {
      final json = {...archived.toJson(), 'scale': 6, 'cfgRescale': 0};
      final parsed = ModelSamplingParams.tryParse(json);
      expect(parsed?.scale, 6.0);
      expect(parsed?.cfgRescale, 0.0);
    });

    test('rejects entries with missing or mistyped fields', () {
      expect(ModelSamplingParams.tryParse(null), isNull);
      expect(ModelSamplingParams.tryParse('steps'), isNull);
      expect(
        ModelSamplingParams.tryParse({...archived.toJson()}..remove('sampler')),
        isNull,
      );
      expect(
        ModelSamplingParams.tryParse({...archived.toJson(), 'steps': 30.5}),
        isNull,
      );
    });

    test('corrects noise schedule and Variety+ for the target model', () {
      final v45 = archived.applyTo(
        const ImageParams(model: ImageModels.animeDiffusionV45Full),
      );
      expect(v45.noiseSchedule, NoiseSchedules.karras);
      expect(v45.varietyPlus, isTrue);

      final v5 = archived.applyTo(
        const ImageParams(model: ImageModels.animeDiffusionV5Full),
      );
      expect(v5.varietyPlus, isFalse);
      expect(v5.steps, 30);
      expect(v5.scale, 6.5);
      expect(v5.cfgRescale, 0.2);
      expect(v5.sampler, Samplers.kDpmpp2m);
    });
  });
}
