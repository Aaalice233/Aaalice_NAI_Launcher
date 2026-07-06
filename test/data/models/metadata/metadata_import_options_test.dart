import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';

void main() {
  group('MetadataImportOptions', () {
    test('all should include generation parameters', () {
      final options = MetadataImportOptions.all();

      expect(options.importSeed, isTrue);
      expect(options.importSteps, isTrue);
      expect(options.importScale, isTrue);
      expect(options.importSize, isTrue);
      expect(options.importSampler, isTrue);
      expect(options.importModel, isTrue);
      expect(options.importNoiseSchedule, isTrue);
      expect(options.importCfgRescale, isTrue);
      expect(options.importVarietyPlus, isTrue);
    });

    test('prompt-only selected count should ignore empty prompt subgroups', () {
      const metadata = NaiImageMetadata(
        prompt: '1girl, city',
        negativePrompt: 'bad hands',
      );
      final options = MetadataImportOptions.promptsOnly();

      expect(options.selectedCountFor(metadata), 2);
    });

    test('selected count should include only available reference data', () {
      const metadata = NaiImageMetadata(
        prompt: '1girl',
        negativePrompt: 'bad hands',
        seed: 1,
      );
      final options = MetadataImportOptions.all();

      expect(options.selectedCountFor(metadata), 3);
    });

    test('generation selected count should match visible parameter chips', () {
      const metadata = NaiImageMetadata(
        prompt: '1girl',
        negativePrompt: 'bad hands',
        seed: 1,
        steps: 28,
        scale: 5.0,
        width: 832,
        height: 1216,
        sampler: 'k_euler_ancestral',
        model: 'nai-diffusion-4-5-full',
        noiseSchedule: 'karras',
        cfgRescale: 0.4,
        qualityToggle: true,
        ucPreset: 0,
        smea: false,
        smeaDyn: false,
        varietyPlus: true,
      );
      final options = MetadataImportOptions.generationOnly();

      expect(options.selectedCountFor(metadata), 11);
    });
  });
}
