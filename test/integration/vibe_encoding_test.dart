import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference_v4.dart';

void main() {
  group('VibeEncoding', () {
    group('Zero-Point Consumption', () {
      test('should cost zero for pre-encoded PNG vibe images', () {
        // Arrange
        final preEncodedPngVibe = VibeReferenceV4(
          displayName: 'test_vibe.png',
          vibeEncoding: 'base64_encoded_data_here',
          strength: 0.6,
          sourceType: VibeSourceType.png, // Pre-encoded
        );

        final params = ImageParams(
          vibeReferencesV4: [preEncodedPngVibe],
        );

        // Act
        final cost = params.vibeEncodingCost;

        // Assert
        expect(
          cost,
          0,
          reason: 'Pre-encoded PNG images should not consume any Anlas points',
        );
      });

      test('should cost zero for .naiv4vibe files', () {
        // Arrange
        final naiv4vibeFile = VibeReferenceV4(
          displayName: 'test_vibe.naiv4vibe',
          vibeEncoding: 'base64_encoded_data_here',
          strength: 0.7,
          sourceType: VibeSourceType.naiv4vibe, // Pre-encoded
        );

        final params = ImageParams(
          vibeReferencesV4: [naiv4vibeFile],
        );

        // Act
        final cost = params.vibeEncodingCost;

        // Assert
        expect(
          cost,
          0,
          reason: '.naiv4vibe files should not consume any Anlas points',
        );
      });

      test('should cost zero for .naiv4vibebundle files', () {
        // Arrange
        final bundleVibe = VibeReferenceV4(
          displayName: 'bundle.naiv4vibebundle',
          vibeEncoding: 'base64_encoded_data_here',
          strength: 0.5,
          sourceType: VibeSourceType.naiv4vibebundle, // Pre-encoded
        );

        final params = ImageParams(
          vibeReferencesV4: [bundleVibe],
        );

        // Act
        final cost = params.vibeEncodingCost;

        // Assert
        expect(
          cost,
          0,
          reason: '.naiv4vibebundle files should not consume any Anlas points',
        );
      });

      test('should cost 2 Anlas for raw image vibe', () {
        // Arrange
        final rawImageVibe = VibeReferenceV4(
          displayName: 'raw_image.jpg',
          vibeEncoding: '',
          rawImageData: Uint8List.fromList([0, 1, 2, 3]),
          strength: 0.6,
          sourceType: VibeSourceType.rawImage, // Requires encoding
        );

        final params = ImageParams(
          vibeReferencesV4: [rawImageVibe],
        );

        // Act
        final cost = params.vibeEncodingCost;

        // Assert
        expect(
          cost,
          2,
          reason: 'Raw images should consume 2 Anlas for server-side encoding',
        );
      });

      test('should calculate cost correctly for multiple pre-encoded vibes',
          () {
        // Arrange
        final preEncodedVibes = List.generate(
          3,
          (index) => VibeReferenceV4(
            displayName: 'vibe_$index.png',
            vibeEncoding: 'base64_encoded_$index',
            strength: 0.6,
            sourceType: VibeSourceType.png,
          ),
        );

        final params = ImageParams(
          vibeReferencesV4: preEncodedVibes,
        );

        // Act
        final cost = params.vibeEncodingCost;

        // Assert
        expect(
          cost,
          0,
          reason: 'Multiple pre-encoded images should still cost zero',
        );
      });

      test('should calculate cost correctly for multiple raw image vibes', () {
        // Arrange
        final rawImageVibes = List.generate(
          5,
          (index) => VibeReferenceV4(
            displayName: 'raw_$index.jpg',
            vibeEncoding: '',
            rawImageData: Uint8List.fromList([index]),
            strength: 0.6,
            sourceType: VibeSourceType.rawImage,
          ),
        );

        final params = ImageParams(
          vibeReferencesV4: rawImageVibes,
        );

        // Act
        final cost = params.vibeEncodingCost;

        // Assert
        expect(
          cost,
          10, // 5 images × 2 Anlas each
          reason: 'Each raw image should cost 2 Anlas',
        );
      });

      test('should calculate cost correctly for mixed pre-encoded and raw vibes',
          () {
        // Arrange
        final mixedVibes = [
          // Pre-encoded PNG
          VibeReferenceV4(
            displayName: 'pre_encoded.png',
            vibeEncoding: 'base64_data',
            strength: 0.6,
            sourceType: VibeSourceType.png,
          ),
          // Raw image
          VibeReferenceV4(
            displayName: 'raw.jpg',
            vibeEncoding: '',
            rawImageData: Uint8List.fromList([0, 1, 2]),
            strength: 0.7,
            sourceType: VibeSourceType.rawImage,
          ),
          // Pre-encoded .naiv4vibe
          VibeReferenceV4(
            displayName: 'vibe.naiv4vibe',
            vibeEncoding: 'base64_data_2',
            strength: 0.5,
            sourceType: VibeSourceType.naiv4vibe,
          ),
          // Another raw image
          VibeReferenceV4(
            displayName: 'raw2.png',
            vibeEncoding: '',
            rawImageData: Uint8List.fromList([3, 4, 5]),
            strength: 0.8,
            sourceType: VibeSourceType.rawImage,
          ),
        ];

        final params = ImageParams(
          vibeReferencesV4: mixedVibes,
        );

        // Act
        final cost = params.vibeEncodingCost;

        // Assert
        expect(
          cost,
          4, // Only 2 raw images × 2 Anlas each
          reason: 'Only raw images should contribute to cost, pre-encoded are free',
        );
      });

      test('should cost zero when no vibe references are present', () {
        // Arrange
        final params = ImageParams(
          vibeReferencesV4: [],
        );

        // Act
        final cost = params.vibeEncodingCost;

        // Assert
        expect(
          cost,
          0,
          reason: 'No vibe references should mean zero cost',
        );
      });

      test('should correctly identify pre-encoded sources', () {
        // Arrange & Act & Assert
        expect(
          VibeSourceType.png.isPreEncoded,
          true,
          reason: 'PNG source should be marked as pre-encoded',
        );
        expect(
          VibeSourceType.naiv4vibe.isPreEncoded,
          true,
          reason: '.naiv4vibe source should be marked as pre-encoded',
        );
        expect(
          VibeSourceType.naiv4vibebundle.isPreEncoded,
          true,
          reason: '.naiv4vibebundle source should be marked as pre-encoded',
        );
        expect(
          VibeSourceType.rawImage.isPreEncoded,
          false,
          reason: 'rawImage source should NOT be marked as pre-encoded',
        );
      });

      test('should count only non-pre-encoded vibes for encoding', () {
        // Arrange
        final vibes = [
          VibeReferenceV4(
            displayName: 'pre1.png',
            vibeEncoding: 'data1',
            sourceType: VibeSourceType.png,
          ),
          VibeReferenceV4(
            displayName: 'raw1.jpg',
            vibeEncoding: '',
            rawImageData: Uint8List.fromList([1]),
            sourceType: VibeSourceType.rawImage,
          ),
          VibeReferenceV4(
            displayName: 'pre2.naiv4vibe',
            vibeEncoding: 'data2',
            sourceType: VibeSourceType.naiv4vibe,
          ),
          VibeReferenceV4(
            displayName: 'raw2.png',
            vibeEncoding: '',
            rawImageData: Uint8List.fromList([2]),
            sourceType: VibeSourceType.rawImage,
          ),
          VibeReferenceV4(
            displayName: 'pre3.naiv4vibebundle',
            vibeEncoding: 'data3',
            sourceType: VibeSourceType.naiv4vibebundle,
          ),
        ];

        final params = ImageParams(vibeReferencesV4: vibes);

        // Act
        final encodingCount = params.vibeEncodingCount;

        // Assert
        expect(
          encodingCount,
          2,
          reason: 'Only raw images should be counted for encoding',
        );
      });
    });
  });
}
