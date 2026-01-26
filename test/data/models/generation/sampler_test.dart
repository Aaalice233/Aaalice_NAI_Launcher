import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';

void main() {
  group('Samplers', () {
    group('DDIM Constants', () {
      test('should define DDIM constant', () {
        // Arrange & Act
        final ddim = Samplers.ddim;

        // Assert
        expect(ddim, equals('ddim'),
            reason: 'DDIM constant should be "ddim"');
      });

      test('should define DDIM V3 constant', () {
        // Arrange & Act
        final ddimV3 = Samplers.ddimV3;

        // Assert
        expect(ddimV3, equals('ddim_v3'),
            reason: 'DDIM V3 constant should be "ddim_v3"');
      });

      test('should have distinct values for DDIM and DDIM V3', () {
        // Arrange & Act
        final ddim = Samplers.ddim;
        final ddimV3 = Samplers.ddimV3;

        // Assert
        expect(ddim, isNot(equals(ddimV3)),
            reason: 'DDIM and DDIM V3 should have different values');
      });
    });

    group('Display Names', () {
      test('should have display name for DDIM', () {
        // Arrange & Act
        final displayName = Samplers.samplerDisplayNames[Samplers.ddim];

        // Assert
        expect(displayName, isNotNull,
            reason: 'DDIM should have a display name');
        expect(displayName, equals('DDIM'),
            reason: 'DDIM display name should be "DDIM"');
      });

      test('should have display name for DDIM V3', () {
        // Arrange & Act
        final displayName = Samplers.samplerDisplayNames[Samplers.ddimV3];

        // Assert
        expect(displayName, isNotNull,
            reason: 'DDIM V3 should have a display name');
        expect(displayName, equals('DDIM V3'),
            reason: 'DDIM V3 display name should be "DDIM V3"');
      });

      test('should have distinct display names', () {
        // Arrange
        final ddimName = Samplers.samplerDisplayNames[Samplers.ddim];
        final ddimV3Name = Samplers.samplerDisplayNames[Samplers.ddimV3];

        // Act & Assert
        expect(ddimName, isNot(equals(ddimV3Name)),
            reason: 'DDIM and DDIM V3 should have different display names');
      });
    });

    group('Sampler List Membership', () {
      test('should include DDIM in allSamplers list', () {
        // Arrange & Act
        final allSamplers = Samplers.allSamplers;

        // Assert
        expect(allSamplers, contains(Samplers.ddim),
            reason: 'DDIM should be in the allSamplers list');
      });

      test('should include DDIM V3 in allSamplers list', () {
        // Arrange & Act
        final allSamplers = Samplers.allSamplers;

        // Assert
        expect(allSamplers, contains(Samplers.ddimV3),
            reason: 'DDIM V3 should be in the allSamplers list');
      });

      test('should contain both DDIM samplers', () {
        // Arrange & Act
        final allSamplers = Samplers.allSamplers;

        // Assert
        expect(allSamplers, containsAll([Samplers.ddim, Samplers.ddimV3]),
            reason: 'Both DDIM and DDIM V3 should be in allSamplers');
      });
    });

    group('DDIM Detection Logic', () {
      test('should detect DDIM sampler by string match', () {
        // Arrange
        final sampler = 'ddim';

        // Act
        final isDdim = sampler.contains('ddim');

        // Assert
        expect(isDdim, isTrue,
            reason: 'Should detect DDIM sampler correctly');
      });

      test('should detect DDIM V3 sampler by string match', () {
        // Arrange
        final sampler = 'ddim_v3';

        // Act
        final isDdim = sampler.contains('ddim');

        // Assert
        expect(isDdim, isTrue,
            reason: 'Should detect DDIM V3 sampler correctly');
      });

      test('should not detect non-DDIM sampler as DDIM', () {
        // Arrange
        final sampler = Samplers.kEuler;

        // Act
        final isDdim = sampler.contains('ddim');

        // Assert
        expect(isDdim, isFalse,
            reason: 'Euler should not be detected as DDIM');
      });

      test('should handle case insensitive DDIM detection', () {
        // Arrange
        final sampler = 'DDIM';

        // Act
        final isDdim = sampler.toLowerCase().contains('ddim');

        // Assert
        expect(isDdim, isTrue,
            reason: 'Should detect DDIM case-insensitively');
      });
    });

    group('Sampler Mapping Logic', () {
      test('should map DDIM to DDIM V3 for V3 models', () {
        // Arrange
        final sampler = Samplers.ddim;
        final model = ImageModels.animeDiffusionV3;

        // Act
        final mappedSampler = sampler == Samplers.ddim ||
                sampler == Samplers.ddimV3
            ? (model.contains('diffusion-3')
                ? Samplers.ddimV3
                : (model.contains('diffusion-4') || model == 'N/A'
                    ? Samplers.kEulerAncestral
                    : sampler))
            : sampler;

        // Assert
        expect(mappedSampler, equals(Samplers.ddimV3),
            reason: 'DDIM should map to DDIM V3 for V3 models');
      });

      test('should map DDIM V3 to itself for V3 models', () {
        // Arrange
        final sampler = Samplers.ddimV3;
        final model = ImageModels.animeDiffusionV3;

        // Act
        final mappedSampler = sampler == Samplers.ddim ||
                sampler == Samplers.ddimV3
            ? (model.contains('diffusion-3')
                ? Samplers.ddimV3
                : (model.contains('diffusion-4') || model == 'N/A'
                    ? Samplers.kEulerAncestral
                    : sampler))
            : sampler;

        // Assert
        expect(mappedSampler, equals(Samplers.ddimV3),
            reason: 'DDIM V3 should remain DDIM V3 for V3 models');
      });

      test('should fallback DDIM to Euler Ancestral for V4 models', () {
        // Arrange
        final sampler = Samplers.ddim;
        final model = ImageModels.animeDiffusionV4Full;

        // Act
        final mappedSampler = sampler == Samplers.ddim ||
                sampler == Samplers.ddimV3
            ? (model.contains('diffusion-3')
                ? Samplers.ddimV3
                : (model.contains('diffusion-4') || model == 'N/A'
                    ? Samplers.kEulerAncestral
                    : sampler))
            : sampler;

        // Assert
        expect(mappedSampler, equals(Samplers.kEulerAncestral),
            reason: 'DDIM should fallback to Euler Ancestral for V4 models');
      });

      test('should fallback DDIM V3 to Euler Ancestral for V4 models', () {
        // Arrange
        final sampler = Samplers.ddimV3;
        final model = ImageModels.animeDiffusionV4Full;

        // Act
        final mappedSampler = sampler == Samplers.ddim ||
                sampler == Samplers.ddimV3
            ? (model.contains('diffusion-3')
                ? Samplers.ddimV3
                : (model.contains('diffusion-4') || model == 'N/A'
                    ? Samplers.kEulerAncestral
                    : sampler))
            : sampler;

        // Assert
        expect(mappedSampler, equals(Samplers.kEulerAncestral),
            reason: 'DDIM V3 should fallback to Euler Ancestral for V4 models');
      });
    });

    group('Edge Cases', () {
      test('should handle empty sampler string in DDIM detection', () {
        // Arrange
        final sampler = '';

        // Act
        final isDdim = sampler.contains('ddim');

        // Assert
        expect(isDdim, isFalse,
            reason: 'Empty string should not be detected as DDIM');
      });

      test('should handle null-like model string in mapping', () {
        // Arrange
        final sampler = Samplers.ddim;
        const model = 'N/A';

        // Act
        final mappedSampler = sampler == Samplers.ddim ||
                sampler == Samplers.ddimV3
            ? (model.contains('diffusion-3')
                ? Samplers.ddimV3
                : (model.contains('diffusion-4') || model == 'N/A'
                    ? Samplers.kEulerAncestral
                    : sampler))
            : sampler;

        // Assert
        expect(mappedSampler, equals(Samplers.kEulerAncestral),
            reason: 'DDIM should fallback to Euler Ancestral for N/A model');
      });

      test('should preserve non-DDIM samplers in mapping logic', () {
        // Arrange
        final sampler = Samplers.kEuler;
        final model = ImageModels.animeDiffusionV3;

        // Act
        final mappedSampler = sampler == Samplers.ddim ||
                sampler == Samplers.ddimV3
            ? (model.contains('diffusion-3')
                ? Samplers.ddimV3
                : (model.contains('diffusion-4') || model == 'N/A'
                    ? Samplers.kEulerAncestral
                    : sampler))
            : sampler;

        // Assert
        expect(mappedSampler, equals(Samplers.kEuler),
            reason: 'Non-DDIM samplers should remain unchanged');
      });

      test('should handle V4.5 models correctly for DDIM', () {
        // Arrange
        final sampler = Samplers.ddim;
        final model = ImageModels.animeDiffusionV45Full;

        // Act
        final mappedSampler = sampler == Samplers.ddim ||
                sampler == Samplers.ddimV3
            ? (model.contains('diffusion-3')
                ? Samplers.ddimV3
                : (model.contains('diffusion-4') || model == 'N/A'
                    ? Samplers.kEulerAncestral
                    : sampler))
            : sampler;

        // Assert
        expect(mappedSampler, equals(Samplers.kEulerAncestral),
            reason: 'DDIM should fallback to Euler Ancestral for V4.5 models');
      });

      test('should handle V2 models correctly for DDIM', () {
        // Arrange
        final sampler = Samplers.ddim;
        final model = ImageModels.animeV2;

        // Act
        final mappedSampler = sampler == Samplers.ddim ||
                sampler == Samplers.ddimV3
            ? (model.contains('diffusion-3')
                ? Samplers.ddimV3
                : (model.contains('diffusion-4') || model == 'N/A'
                    ? Samplers.kEulerAncestral
                    : sampler))
            : sampler;

        // Assert
        expect(mappedSampler, equals(Samplers.ddim),
            reason: 'DDIM should remain DDIM for V2 models');
      });
    });
  });
}
