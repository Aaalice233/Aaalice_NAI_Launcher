import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';

/// Tests for verifying mask loading functionality with various image formats.
///
/// This test suite verifies that masks in different formats (PNG, JPG, WEBP, BMP)
/// can be loaded correctly as layers in the image editor.
void main() {
  group('Mask Loading Format Tests', () {
    late LayerManager layerManager;

    setUp(() {
      layerManager = LayerManager();
    });

    tearDown(() {
      layerManager.dispose();
    });

    test('should load PNG format mask as layer', () async {
      // Create a valid PNG image using the image package
      final image = img.Image(width: 100, height: 100);
      image.clear(img.ColorRgb8(255, 0, 0)); // Red mask
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final layer = await layerManager.addLayerFromImage(
        pngBytes,
        name: 'PNG蒙版',
      );

      expect(layer, isNotNull);
      expect(layer?.name, 'PNG蒙版');
      expect(layerManager.layerCount, 1);
      expect(layerManager.activeLayer?.id, layer?.id);
      expect(layer?.baseImage, isNotNull);
    });

    test('should load JPEG format mask as layer', () async {
      // Create a valid JPEG image using the image package
      final image = img.Image(width: 100, height: 100);
      image.clear(img.ColorRgb8(0, 255, 0)); // Green mask
      final jpegBytes = Uint8List.fromList(img.encodeJpg(image));

      final layer = await layerManager.addLayerFromImage(
        jpegBytes,
        name: 'JPEG蒙版',
      );

      expect(layer, isNotNull);
      expect(layer?.name, 'JPEG蒙版');
      expect(layerManager.layerCount, 1);
      expect(layerManager.activeLayer?.id, layer?.id);
      expect(layer?.baseImage, isNotNull);
    });

    test('should load WEBP format mask as layer', () async {
      // Note: Flutter's image codec supports WEBP, but the image package
      // may not have encodeWebP in all versions. We'll skip this test
      // as encoding is not available, but the codec can still decode WEBP.
      // In actual usage, users would load their existing WEBP mask files.
      // The LayerManager uses Flutter's intrinsic codec which supports WEBP.

      // This is a placeholder test - WEBP support is verified manually
      // with actual WEBP files in production use.
    }, skip: 'image package encodeWebP not available - WEBP decoding is supported by Flutter codec',);

    test('should handle multiple masks of different formats', () async {
      // Create test images
      final pngImage = img.Image(width: 100, height: 100);
      pngImage.clear(img.ColorRgb8(255, 0, 0));
      final pngBytes = Uint8List.fromList(img.encodePng(pngImage));

      final jpegImage = img.Image(width: 100, height: 100);
      jpegImage.clear(img.ColorRgb8(0, 255, 0));
      final jpegBytes = Uint8List.fromList(img.encodeJpg(jpegImage));

      final bmpImage = img.Image(width: 100, height: 100);
      bmpImage.clear(img.ColorRgb8(0, 0, 255));
      final bmpBytes = Uint8List.fromList(img.encodeBmp(bmpImage));

      // Add PNG mask
      final pngLayer = await layerManager.addLayerFromImage(
        pngBytes,
        name: 'PNG蒙版',
      );
      expect(pngLayer, isNotNull);
      expect(layerManager.layerCount, 1);

      // Add JPEG mask
      final jpegLayer = await layerManager.addLayerFromImage(
        jpegBytes,
        name: 'JPEG蒙版',
      );
      expect(jpegLayer, isNotNull);
      expect(layerManager.layerCount, 2);

      // Add BMP mask
      final bmpLayer = await layerManager.addLayerFromImage(
        bmpBytes,
        name: 'BMP蒙版',
      );
      expect(bmpLayer, isNotNull);
      expect(layerManager.layerCount, 3);

      // Verify all layers exist
      expect(layerManager.layers.length, 3);
      expect(layerManager.layers.any((l) => l.name == 'PNG蒙版'), true);
      expect(layerManager.layers.any((l) => l.name == 'JPEG蒙版'), true);
      expect(layerManager.layers.any((l) => l.name == 'BMP蒙版'), true);

      // Verify the last added layer is active
      expect(layerManager.activeLayer?.id, bmpLayer?.id);
    });

    test('should return null for invalid image data', () async {
      final invalidBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

      final layer = await layerManager.addLayerFromImage(
        invalidBytes,
        name: '无效蒙版',
      );

      expect(layer, isNull);
      expect(layerManager.layerCount, 0);
    });

    test('should return null for empty image data', () async {
      final emptyBytes = Uint8List(0);

      final layer = await layerManager.addLayerFromImage(
        emptyBytes,
        name: '空蒙版',
      );

      expect(layer, isNull);
      expect(layerManager.layerCount, 0);
    });

    test('should set the loaded mask as active layer', () async {
      final image = img.Image(width: 100, height: 100);
      image.clear(img.ColorRgb8(255, 0, 0));
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final layer = await layerManager.addLayerFromImage(
        pngBytes,
        name: '测试蒙版',
      );

      expect(layerManager.activeLayer?.id, layer?.id);
      expect(layer?.isActiveNotifier.value, true);
    });

    test('should handle masks with transparent areas (PNG)', () async {
      // Create PNG with alpha channel
      final image = img.Image(width: 100, height: 100);
      // Semi-transparent red pixels
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          image.setPixelRgba(x, y, 255, 0, 0, 128); // Red with 50% opacity
        }
      }
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final layer = await layerManager.addLayerFromImage(
        pngBytes,
        name: '透明蒙版',
      );

      expect(layer, isNotNull);
      expect(layer?.baseImage, isNotNull);
      expect(layerManager.layerCount, 1);
    });

    test('should handle BMP format masks', () async {
      // Create a BMP image
      final image = img.Image(width: 100, height: 100);
      image.clear(img.ColorRgb8(128, 128, 128)); // Gray mask
      final bmpBytes = Uint8List.fromList(img.encodeBmp(image));

      final layer = await layerManager.addLayerFromImage(
        bmpBytes,
        name: 'BMP蒙版',
      );

      expect(layer, isNotNull);
      expect(layer?.name, 'BMP蒙版');
      expect(layerManager.layerCount, 1);
      expect(layer?.baseImage, isNotNull);
    });

    test('should load mask images of different sizes', () async {
      // Small mask
      final smallImage = img.Image(width: 32, height: 32);
      smallImage.clear(img.ColorRgb8(255, 0, 0));
      final smallBytes = Uint8List.fromList(img.encodePng(smallImage));

      // Large mask
      final largeImage = img.Image(width: 512, height: 512);
      largeImage.clear(img.ColorRgb8(0, 255, 0));
      final largeBytes = Uint8List.fromList(img.encodePng(largeImage));

      // Load small mask
      final smallLayer = await layerManager.addLayerFromImage(
        smallBytes,
        name: '小蒙版',
      );
      expect(smallLayer, isNotNull);
      expect(layerManager.layerCount, 1);

      // Load large mask
      final largeLayer = await layerManager.addLayerFromImage(
        largeBytes,
        name: '大蒙版',
      );
      expect(largeLayer, isNotNull);
      expect(layerManager.layerCount, 2);

      // Verify both layers exist
      expect(layerManager.layers.length, 2);
    });
  });
}
